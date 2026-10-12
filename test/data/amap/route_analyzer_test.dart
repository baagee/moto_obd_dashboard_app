import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:obd_dashboard/data/amap/models.dart';
import 'package:obd_dashboard/data/amap/route_analyzer.dart';

/// `RouteAnalyzer` 单元测试（方案 §5.1）
///
/// 覆盖两类样本：
/// - **真实离线样本** `amap_test01/amap-live/sample-restoration.json`（含外层
///   envelope），用于复现方案 §5.2 的对拍基线；样本缺失时自动跳过
/// - **合成最小路线**，用于确定性地验证队列与跳点行为
void main() {
  final sample = _loadSample();

  group('真实样本 · 里程自检与指纹（方案 §5.2 基线）', () {
    test('Σ link.length == paths[].distance', () {
      final a = _require(sample);
      final sum = a.links.fold<double>(0, (x, y) => x + y.length);
      expect(sum, closeTo(a.totalDistance, 1.0));
      expect(a.lengthConsistent, isTrue);
    });

    test('路线指纹与基线一致', () {
      final a = _require(sample);
      expect(a.totalDistance.toInt(), 27734);
      expect(a.links.length, 335);
      expect(a.path.coords.length, 526);
      expect(a.segments.length, 21);
      expect(a.actions.length, 21);
    });

    test('相邻 link 下标差分布（!=0 表示存在孤立几何点，不能首尾相接拼）', () {
      final a = _require(sample);
      var eq0 = 0, eq1 = 0, gt1 = 0;
      for (var i = 1; i < a.links.length; i++) {
        final gap = a.links[i].link.beginIndex - a.links[i - 1].link.endIndex;
        if (gap == 0) {
          eq0++;
        } else if (gap == 1) {
          eq1++;
        } else {
          gt1++;
        }
      }
      expect(eq0, 298);
      expect(eq1, 35);
      expect(gt1, 1);
    });
  });

  group('投影对拍（JS 版参考值）', () {
    test('分享者位置 → dist 6.0m / offset 24.5m', () {
      final a = _require(sample);
      // sample-info.json 的 locInfo（GCJ-02）
      final p = a.project(116.2948275, 40.05403111111111);
      expect(p.distance, closeTo(6.0, 0.1));
      expect(p.offset, closeTo(24.5, 0.1));
    });

    test('路线上的点 offset ≈ 0', () {
      final a = _require(sample);
      final p = a.project(116.3090625, 40.0475);
      expect(p.distance, closeTo(2326.0, 1.0));
      expect(p.offset, lessThan(1.0));
    });
  });

  group('动作队列', () {
    test('严格按里程升序', () {
      final a = _require(sample);
      for (var i = 1; i < a.actions.length; i++) {
        expect(a.actions[i].atDistance,
            greaterThanOrEqualTo(a.actions[i - 1].atDistance));
      }
    });

    test('upcomingActions 不含已过动作，且升序', () {
      final a = _require(sample);
      for (final d in [0.0, 1234.0, 9000.0, 17560.0, 26000.0]) {
        final up = a.upcomingActions(d, limit: 5);
        expect(up.length, lessThanOrEqualTo(5));
        for (var i = 0; i < up.length; i++) {
          expect(up[i].atDistance, greaterThan(d));
          if (i > 0) {
            expect(up[i].atDistance, greaterThanOrEqualTo(up[i - 1].atDistance));
          }
        }
      }
    });

    test('lastPassedAction 定位最后一个已过动作', () {
      final a = _require(sample);
      expect(a.lastPassedAction(0), isNull);
      expect(a.lastPassedAction(17560)!.atDistance, closeTo(17441, 0.5));
      // 恰好落在动作点上时，该动作算"已过"（<= distance）
      expect(a.lastPassedAction(17625)!.atDistance, closeTo(17625, 0.5));
      expect(a.lastPassedAction(17624)!.atDistance, closeTo(17594, 0.5));
    });
  });

  group('连续多动作（实测德胜门桥，方案 §2.4）', () {
    test('d=17560 时 limit:3 返回 17594/17625/17676 三个动作', () {
      final a = _require(sample);
      final up = a.upcomingActions(17560, limit: 3);
      expect(up.map((e) => e.atDistance.round()).toList(), [17594, 17625, 17676]);
      // 153m / 31m / 51m 的连续转弯，动作名依次为 左转(1) / 靠左(9) / 向右前方行驶(4)
      // —— 按官方枚举 §2.11，这是**真实样本**上的一次落地对拍：
      // 早期几何猜测版会把 9 读成"左转"、4 读成"右前方行驶"，与官方表不符。
      expect(up[0].label, '左转');
      expect(up[1].label, '靠左');
      expect(up[2].label, '向右前方行驶');
    });

    test('80km/h 下三个动作同时落在 8 秒窗口内', () {
      final a = _require(sample);
      const speedMs = 80 / 3.6;
      final etas = a
          .upcomingActions(17560, limit: 3)
          .map((e) => (e.atDistance - 17560) / speedMs)
          .toList();
      expect(etas[0], closeTo(1.5, 0.2));
      expect(etas[1], closeTo(2.9, 0.2));
      expect(etas[2], closeTo(5.2, 0.2));
      expect(etas.every((e) => e < 8), isTrue);
    });
  });

  group('coordAt ↔ project 往返自检', () {
    test('往返里程误差 < 1m、偏移 ≈ 0', () {
      final a = _require(sample);
      for (final frac in [0.0, 0.13, 0.37, 0.5, 0.71, 0.93, 1.0]) {
        final d = a.totalDistance * frac;
        final c = a.coordAt(d);
        final p = a.project(c.lon, c.lat);
        expect((p.distance - d).abs(), lessThan(1.0),
            reason: 'frac=$frac coordAt($d) 往返里程偏差过大');
        expect(p.offset, lessThan(1.0), reason: 'frac=$frac offset 应接近 0');
      }
    });

    test('里程越界被夹到 [0, totalDistance]', () {
      final a = _require(sample);
      expect(() => a.coordAt(-500), returnsNormally);
      expect(() => a.coordAt(a.totalDistance + 5000), returnsNormally);
    });
  });

  group('跳点不漏（1Hz 采样跨过短 segment）', () {
    test('真实样本中跨过最窄 segment 后队列仍指向正确的下一个动作', () {
      final a = _require(sample);
      // 取"中途"最短的 segment（排除终点前的最后一段，否则越过之后没有后续动作）：
      // 本样本为 17594..17625 的 31m 段（全局最短是终点前的 11m 段）
      var narrowest = a.segments.first;
      for (final s in a.segments) {
        if (s.end > a.totalDistance - 1) continue;
        if (s.end - s.start < narrowest.end - narrowest.start) narrowest = s;
      }
      final narrowLen = narrowest.end - narrowest.start;
      expect(narrowLen, lessThan(60), reason: '样本应存在 <60m 的中途短 segment');

      // 跳点前（刚驶入该段）：队列第一个就是该段末的动作
      final beforeJump = a.upcomingActions(narrowest.start, limit: 1);
      expect(beforeJump.single.atDistance, closeTo(narrowest.end, 0.5));

      // 一次跳点直接越过该段：队列不应卡在已过动作上
      final afterJump = a.upcomingActions(narrowest.end + 5, limit: 1);
      expect(afterJump.single.atDistance, greaterThan(narrowest.end));
      // 而被越过的动作可由 lastPassedAction 检出（用于"漏播报"判定）
      expect(a.lastPassedAction(narrowest.end + 5)!.atDistance,
          closeTo(narrowest.end, 0.5));
    });

    test('合成路线：27m 跳点跨过 11m 的 segment', () {
      final a = RouteAnalyzer(syntheticRoute());
      expect(a.segments.length, 3);
      // 段里程：0..140 / 140..151 / 151..300
      expect(a.actions.map((e) => e.atDistance.round()).toList(), [140, 151, 300]);

      // 138m 处：下一个动作是 140（第一段末的"向左前方行驶"，官方码 3）
      expect(a.upcomingActions(138, limit: 1).single.atDistance, closeTo(140, 0.5));
      // 140m 处：下一动作是 11m 短段末的 151（左转，官方码 1）
      expect(a.upcomingActions(140, limit: 1).single.atDistance, closeTo(151, 0.5));
      // 一步跳到 165m（越过 151）：队列直接给 300，不返回已过动作
      expect(a.upcomingActions(165, limit: 1).single.atDistance, closeTo(300, 0.5));
      expect(a.lastPassedAction(165)!.atDistance, closeTo(151, 0.5));

      expect(a.lengthConsistent, isTrue);
    });
  });

  group('底图切片 / 朝向（导航卡 v2）', () {
    test('bearingAt：真实样本上与该段几何朝向一致', () {
      final a = _require(sample);
      // 用"切片前后两点的坐标方位角"作为独立参照，验证 bearingAt 的几何正确性
      for (final d in [1000.0, 9000.0, 17000.0, 22000.0, 26000.0]) {
        final b = a.bearingAt(d);
        expect(b, isNotNull);
        final p0 = a.coordAt(d);
        final p1 = a.coordAt(d + 25);
        final expected = _bearingDeg(p0.lon, p0.lat, p1.lon, p1.lat);
        final got = b! * 180 / 3.1415926535897932;
        expect(_angleDiffDeg(got, expected), lessThan(5.0));
      }
    });

    test('bearingAt：终点附近回溯取点，不返回 null', () {
      final a = _require(sample);
      expect(a.bearingAt(a.totalDistance), isNotNull);
      expect(a.bearingAt(a.totalDistance + 5000), isNotNull);
      expect(a.bearingAt(-100), isNotNull);
    });

    test('routeSlice：里程范围、车辆点与朝向', () {
      final a = _require(sample);
      const vd = 9000.0;
      final s = a.routeSlice(vehicleDistance: vd, behindMeters: 40, aheadMeters: 300);

      expect(s.isEmpty, isFalse);
      expect(s.fromDistance, closeTo(vd - 40, 0.01));
      expect(s.toDistance, closeTo(vd + 300, 0.01));
      expect(s.vehicleDistance, closeTo(vd, 0.01));
      expect(s.aheadMeters, closeTo(300, 0.01));

      // 车辆点必须落在线上：与 coordAt(vd) 一致
      final v = a.coordAt(vd);
      final got = s.points[s.vehicleIndex];
      expect(got.lon, closeTo(v.lon, 1e-9));
      expect(got.lat, closeTo(v.lat, 1e-9));
      expect(s.bearing, closeTo(a.bearingAt(vd)!, 1e-9));
      expect(s.trafficStates.length, s.points.length);
    });

    test('routeSlice：起点附近后视里程被夹到 0，且不含孤点游离坐标', () {
      final a = _require(sample);
      final s = a.routeSlice(vehicleDistance: 10, behindMeters: 40, aheadMeters: 300);
      expect(s.fromDistance, 0);
      // 车辆点在 by-distance 排序后紧跟视窗起点
      final v = a.coordAt(10);
      final got = s.points[s.vehicleIndex];
      expect(got.lon, closeTo(v.lon, 1e-9));
      expect(got.lat, closeTo(v.lat, 1e-9));
      // 所有点都应落在窗内（孤点默认里程 0 会污染切片，必须被排除）
      for (var i = 1; i < s.points.length; i++) {
        expect(s.points[i].lon, greaterThan(100));
        expect(s.points[i].lat, greaterThan(30));
      }
    });

    test('routeSlice：视窗里程切换会改变切片跨度', () {
      final a = _require(sample);
      final short = a.routeSlice(vehicleDistance: 9000, aheadMeters: 150);
      final long = a.routeSlice(vehicleDistance: 9000, aheadMeters: 600);
      expect(short.aheadMeters, closeTo(150, 0.01));
      expect(long.aheadMeters, closeTo(600, 0.01));
      expect(long.points.length, greaterThanOrEqualTo(short.points.length));
      for (final s in [short, long]) {
        expect(s.points.length, lessThanOrEqualTo(80));
      }
    });

    test('routeSlice：终点处 ahead 被夹到总里程', () {
      final a = _require(sample);
      final s = a.routeSlice(vehicleDistance: a.totalDistance, aheadMeters: 300);
      expect(s.toDistance, closeTo(a.totalDistance, 0.01));
      expect(s.isEmpty, isFalse);
    });

    test('routeSlice：空路线返回 empty', () {
      final a = RouteAnalyzer(AmapRoute(const {'paths': []}));
      expect(a.routeSlice(vehicleDistance: 0).isEmpty, isTrue);
    });

    test('coordCovered：孤点被标记为未覆盖', () {
      final a = _require(sample);
      expect(a.coordCovered.length, a.path.coords.length);
      expect(a.coordCovered.where((c) => !c).length, greaterThan(0),
          reason: '本样本实测存在不被 link 引用的孤点');
      expect(a.coordCovered.first, isTrue);
    });
  });

  group('投影歧义 / 连续性约束（路线自邻近）', () {
    // 去程里程 d 与回程里程 (2*legLength - d) 在地面上只差 gapMeters（默认 18m），
    // 正对应实测样本里 "d=220 与 d=400 相距 18m、中间隔着 2 个动作" 的形态。
    const gapDegLat = 18 / 110540.0;

    test('歧义客观存在：纯"最近边"会把里程吸到对面那段', () {
      final a = RouteAnalyzer(doubleBackRoute());
      expect(a.totalDistance, 600);
      final c = a.coordAt(100); // 去程 100m 处
      final p = a.project(c.lon, c.lat + gapDegLat); // 正好落在回程线上
      expect(p.offset, lessThan(1));
      expect(p.distance, closeTo(500, 1),
          reason: '回程线上同一位置对应里程 2*300-100=500，比真实值大 400m');
    });

    test('带 nearDistance：窗口内优先里程最接近先验的候选，不跳段', () {
      final a = RouteAnalyzer(doubleBackRoute());
      final c = a.coordAt(100);
      final p = a.project(c.lon, c.lat + gapDegLat, nearDistance: 100);
      expect(p.distance, closeTo(100, 3));
      expect(p.offset, closeTo(18, 2), reason: '偏离量应如实报 18m，不被"更近的对面段"掩盖');
    });

    test('全程单调推进：每个采样点都留在去程，不被吸走', () {
      final a = RouteAnalyzer(doubleBackRoute());
      var prev = 0.0;
      for (var d = 0.0; d <= 300; d += 20) {
        final c = a.coordAt(d);
        final p = a.project(c.lon, c.lat + gapDegLat, nearDistance: prev + 20);
        expect((p.distance - d).abs(), lessThan(25), reason: 'd=$d 被吸到对面段');
        expect(p.distance, greaterThanOrEqualTo(prev - 1), reason: '里程不应回退');
        prev = p.distance;
      }
    });

    test('窗口内无候选（真偏离）时退回全局最近，交给偏离检测', () {
      final a = RouteAnalyzer(doubleBackRoute());
      final c = a.coordAt(100);
      final p = a.project(c.lon, c.lat + 500 / 110540, nearDistance: 100);
      expect(p.offset, closeTo(482, 20));
    });

    test('不传 nearDistance 与旧行为逐位一致（离线对拍不受影响）', () {
      final a = RouteAnalyzer(doubleBackRoute());
      final c = a.coordAt(100);
      final p1 = a.project(c.lon, c.lat);
      final p2 = a.project(c.lon, c.lat, nearDistance: null);
      expect(p1.distance, p2.distance);
      expect(p1.offset, p2.offset);
    });

    test('真实样本 d=6600↔7480（相距 17.5m）：9m 横向误差就被吸到 880m 之后', () {
      final a = _require(sample);
      // 真实的"立交匝道贴回主线"：d=6600 与 d=7480 在地面上只差 17.5m
      const d1 = 6600.0, d2 = 7480.0;
      final c1 = a.coordAt(d1), c2 = a.coordAt(d2);
      final mx = 111320 * math.cos(c1.lat * math.pi / 180);
      const my = 110540.0;
      final dx = (c2.lon - c1.lon) * mx, dy = (c2.lat - c1.lat) * my;
      final gap = math.sqrt(dx * dx + dy * dy);
      expect(gap, lessThan(20), reason: '两处相距实测 17.5m');

      // 位于 d1，但定位误差方向恰好朝对面那段，只挪 9m（> gap/2）
      final lon = c1.lon + dx / gap * 9 / mx;
      final lat = c1.lat + dy / gap * 9 / my;

      final global = a.project(lon, lat);
      expect(global.distance, closeTo(d2, 60),
          reason: '纯"最近边"会整段吸到对面（里程 +880m）');
      expect(a.upcomingActions(global.distance, limit: 1).single.atDistance,
          closeTo(7490, 5),
          reason: '于是"下一个动作"从 7032(左转调头) 变成 7490(向右前方行驶)');

      final fixed = a.project(lon, lat, nearDistance: d1);
      expect(fixed.distance, closeTo(d1, 20));
      expect(fixed.offset, closeTo(9, 2), reason: '偏离量应如实报出');
      expect(a.upcomingActions(fixed.distance, limit: 1).single.atDistance,
          closeTo(7032, 5));
    });
  });

  group('空数据容错', () {
    test('paths: [] 不崩，actions 为空', () {
      final a = RouteAnalyzer(AmapRoute(const {'paths': []}));
      expect(a.actions, isEmpty);
      expect(a.links, isEmpty);
      expect(a.segments, isEmpty);
      expect(a.totalDistance, 0);
      expect(a.lengthConsistent, isTrue);
      expect(a.upcomingActions(0), isEmpty);
      expect(a.remainingAt(0).meters, 0);
      final p = a.project(116.0, 40.0);
      expect(p.distance, 0);
      expect(p.offset, 0);
    });

    test('restorationInfo 为空对象时不崩', () {
      final a = RouteAnalyzer(AmapRoute(const {}));
      expect(a.path.coords, isEmpty);
      expect(a.actions, isEmpty);
    });
  });

  group('剩余量与路况', () {
    test('remainingAt 单调递减且总量自洽', () {
      final a = _require(sample);
      expect(a.remainingAt(0).meters, closeTo(a.totalDistance, 1.0));
      expect(a.remainingAt(a.totalDistance).meters, closeTo(0, 0.5));
      final r = a.remainingAt(9000);
      expect(r.meters, lessThan(a.remainingAt(0).meters));
      expect(r.seconds, greaterThan(0));
      expect(r.lights, greaterThanOrEqualTo(0));
    });

    test('起点与终点里程处的指引不越界', () {
      final a = _require(sample);
      for (final d in [0.0, a.totalDistance]) {
        final g = a.guidanceAt(d);
        expect(g.distanceToAction, greaterThanOrEqualTo(0));
        expect(g.currentRoad, isNotEmpty);
      }
    });
  });
}

// ---------------------------------------------------------------------------
// 辅助
// ---------------------------------------------------------------------------

const String _samplePath = 'amap_test01/amap-live/sample-restoration.json';

RouteAnalyzer? _loadSample() {
  final f = File(_samplePath);
  if (!f.existsSync()) return null;
  return RouteAnalyzer(RouteEnvelope.parse(f.readAsStringSync()).route);
}

/// 样本缺失时跳过（离线样本目录未随仓库分发时的兜底）
RouteAnalyzer _require(RouteAnalyzer? a) {
  if (a == null) {
    markTestSkipped('缺少离线样本 $_samplePath');
  }
  return a!;
}

/// 坐标方位角（度，0=北，顺时针为正）—— 用于独立验证 `bearingAt` 的几何正确性
double _bearingDeg(double lon0, double lat0, double lon1, double lat1) {
  final dx = (lon1 - lon0) * math.cos(lat0 * math.pi / 180);
  final dy = lat1 - lat0;
  return math.atan2(dx, dy) * 180 / math.pi;
}

double _angleDiffDeg(double a, double b) {
  var d = (a - b) % 360;
  if (d > 180) d -= 360;
  if (d < -180) d += 360;
  return d.abs();
}

/// U 形往返路线：去程沿正东、回程在正北 [gapMeters] 处的平行线上折返。
///
/// 去程里程 d 与回程里程 `2*legLength - d` 在地面上只差 `gapMeters`
/// （默认 18m，与实测样本 d=220↔400 相距 18.2m 同量级）。
AmapRoute doubleBackRoute({int legLength = 300, double gapMeters = 18}) {
  const metersPerLon = 111320.0 * 0.766; // cos(40°)
  const metersPerLat = 110540.0;
  const lat = 40.0;
  const lon = 116.30;
  final dLon = legLength / metersPerLon;
  final dLat = gapMeters / metersPerLat;

  Map<String, Object?> link(int begin, int end, int roadNameIndex) => {
        'link_index': 0,
        'length': legLength,
        'begin_index': begin,
        'end_index': end,
        'travel_time': 30,
        'road_name_index': roadNameIndex,
      };

  return AmapRoute({
    'roads_names': [
      {'road_name': '去程路'},
      {'road_name': '回程路'},
    ],
    'paths': [
      {
        'path_index': 0,
        'distance': legLength * 2,
        'travel_time': 60,
        'coords': [
          {'lon': lon, 'lat': lat},
          {'lon': lon + dLon, 'lat': lat},
          {'lon': lon + dLon, 'lat': lat + dLat},
          {'lon': lon, 'lat': lat + dLat},
        ],
        'segments': [
          {'segment_index': 0, 'main_action': 2, 'links': [link(0, 1, 0)]},
          {'segment_index': 1, 'main_action': 3, 'links': [link(2, 3, 1)]},
        ],
        'status': [],
        'group': [],
      },
    ],
  });
}

/// 合成最小路线：三个 segment，其中第二个只有 11m（与实测最窄段同量级）
AmapRoute syntheticRoute() => AmapRoute(const {
      'roads_names': [
        {'road_name': 'A路'},
        {'road_name': 'B路'},
      ],
      'paths': [
        {
          'path_index': 0,
          'distance': 300,
          'travel_time': 23,
          'coords': [
            {'lon': 116.3000, 'lat': 40.0000},
            {'lon': 116.3010, 'lat': 40.0000},
            {'lon': 116.3020, 'lat': 40.0000},
            {'lon': 116.3021, 'lat': 40.0001},
            {'lon': 116.3030, 'lat': 40.0002},
            {'lon': 116.3040, 'lat': 40.0003},
          ],
          'segments': [
            {
              'segment_index': 0,
              'main_action': 3,
              'links': [
                {
                  'link_index': 0,
                  'length': 140,
                  'begin_index': 0,
                  'end_index': 2,
                  'travel_time': 10,
                  'road_name_index': 0,
                },
              ],
            },
            {
              'segment_index': 1,
              'main_action': 1,
              'links': [
                {
                  'link_index': 0,
                  'length': 11,
                  'begin_index': 2,
                  'end_index': 3,
                  'travel_time': 1,
                  'road_name_index': 0,
                },
              ],
            },
            {
              'segment_index': 2,
              'main_action': 2,
              'links': [
                {
                  'link_index': 0,
                  'length': 149,
                  'begin_index': 3,
                  'end_index': 5,
                  'travel_time': 12,
                  'road_name_index': 1,
                },
              ],
            },
          ],
          'status': [
            {'traffic_state': 1, 'len': 300},
          ],
          'group': [
            {'name': 'A路', 'dist': 151, 'start_id': 0, 'count': 2},
            {'name': 'B路', 'dist': 149, 'start_id': 0, 'count': 1},
          ],
        },
      ],
    });
