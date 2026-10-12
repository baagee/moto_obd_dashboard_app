/// 导航 HUD 算法对拍 / 回归工具（Phase 4·4a 常驻工具）
///
/// 用途：`lib/data/amap/` 三个文件与 JS 参考实现对齐，任何算法改动都可能
/// 悄悄破坏里程索引或动作队列。本工具用**真实离线样本**跑一遍核心算法，
/// 把关键指纹打印出来并与基线比对，作为改动前的回归门禁。
///
/// 用法：
/// ```bash
/// # 离线样本对拍（默认路径：amap_test01/amap-live/sample-restoration.json）
/// dart run tool/verify_navi.dart
///
/// # 指定样本
/// dart run tool/verify_navi.dart amap_test01/amap-live/sample-restoration.json
///
/// # 投影对拍（与 JS 版 window.__debug 同构，输出 {"dist":x,"off":y}）
/// dart run tool/verify_navi.dart --project <lon> <lat>
/// ```
///
/// 退出码：0 = 全部基线与自检通过；1 = 有断言失败（可挂进 CI）。
library;

import 'dart:io';

import 'package:obd_dashboard/data/amap/models.dart';
import 'package:obd_dashboard/data/amap/route_analyzer.dart';

// ---------------------------------------------------------------------------
// 基线（与 phase4-navi-hud-plan.md §5.2 保持一致）
// ---------------------------------------------------------------------------

const String _defaultSample = 'amap_test01/amap-live/sample-restoration.json';

/// 真实样本 27.7km 的路线指纹基线
const int _baseDistance = 27734;
const int _baseLinks = 335;
const int _baseCoords = 526;
const int _baseSegments = 21;
const int _baseActions = 21;

/// 相邻 link 的 coords 下标差值分布基线：==0 有 298 处、==1 有 35 处、>1 有 1 处
const int _baseGapEq0 = 298;
const int _baseGapEq1 = 35;
const int _baseGapGt1 = 1;

/// 连续多动作场景（德胜门桥附近，绝对里程）
/// 17441m 直行(8) → 17594m 左转(1) → 17625m 靠左(9) → 17676m 向右前方行驶(4)
const double _multiActionProbe = 17560;
const List<double> _multiActionTargets = [17594, 17625, 17676];

final List<String> _failures = [];

void _check(String label, Object actual, Object expected) {
  final ok = '$actual' == '$expected';
  stdout.writeln('  ${ok ? "✓" : "✗"} $label = $actual'
      '${ok ? "" : "  （基线 $expected）"}');
  if (!ok) _failures.add('$label 实际=$actual 基线=$expected');
}

Future<void> main(List<String> argv) async {
  if (argv.isNotEmpty && argv.first == '--project') {
    _project(argv);
    return;
  }
  final file = argv.isNotEmpty ? argv.first : _defaultSample;
  if (!File(file).existsSync()) {
    stderr.writeln('样本不存在：$file');
    exit(2);
  }
  _offline(file);
  if (_failures.isEmpty) {
    stdout.writeln('\n全部基线与自检通过 ✓');
    exit(0);
  }
  stderr.writeln('\n以下项与基线不一致：');
  for (final f in _failures) {
    stderr.writeln('  - $f');
  }
  exit(1);
}

/// `--project <lon> <lat>`：读默认样本，输出投影结果 JSON（与 JS 版对拍）。
void _project(List<String> argv) {
  if (argv.length < 3) {
    stderr.writeln('用法：dart run tool/verify_navi.dart --project <lon> <lat>');
    exit(2);
  }
  final env = RouteEnvelope.parse(File(_defaultSample).readAsStringSync());
  final analyzer = RouteAnalyzer(env.route);
  final p = analyzer.project(double.parse(argv[1]), double.parse(argv[2]));
  stdout.writeln('{"dist":${p.distance.toStringAsFixed(1)},'
      '"off":${p.offset.toStringAsFixed(1)}}');
}

void _offline(String file) {
  final env = RouteEnvelope.parse(File(file).readAsStringSync());
  final route = env.route;
  final a = RouteAnalyzer(route);

  stdout.writeln('=' * 68);
  stdout.writeln('样本  $file');
  stdout.writeln('=' * 68);

  // ── 1. 路线指纹 ──
  stdout.writeln('\n[1] 路线指纹');
  _check('distance', a.totalDistance.toInt(), _baseDistance);
  _check('links', a.links.length, _baseLinks);
  _check('coords', a.path.coords.length, _baseCoords);
  _check('segments', a.segments.length, _baseSegments);
  _check('actions', a.actions.length, _baseActions);

  // ── 2. 里程自检：Σ link.length == paths[].distance ──
  final sum = a.links.fold<double>(0, (x, y) => x + y.length);
  stdout.writeln('\n[2] 里程自检  Σlink.length=${sum.toStringAsFixed(1)}'
      '  distance=${a.totalDistance.toStringAsFixed(1)}');
  _check('lengthConsistent', a.lengthConsistent, true);

  // ── 3. 相邻 link 的 coords 下标差（相邻 link 下标不连续是已知特性）──
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
  stdout.writeln('\n[3] 相邻 link 下标差  ==0:$eq0  ==1:$eq1  >1:$gt1');
  _check('gap==0', eq0, _baseGapEq0);
  _check('gap==1', eq1, _baseGapEq1);
  _check('gap>1', gt1, _baseGapGt1);

  // ── 4. coordAt / project 往返自检 ──
  stdout.writeln('\n[4] coordAt ↔ project 往返（误差应 < 1m，offset ≈ 0）');
  var maxDistErr = 0.0, maxOffset = 0.0;
  for (final frac in [0.0, 0.13, 0.37, 0.5, 0.71, 0.93, 1.0]) {
    final d = a.totalDistance * frac;
    final c = a.coordAt(d);
    final p = a.project(c.lon, c.lat);
    maxDistErr = maxDistErr > (p.distance - d).abs()
        ? maxDistErr
        : (p.distance - d).abs();
    maxOffset = maxOffset > p.offset ? maxOffset : p.offset;
  }
  stdout.writeln('  最大里程误差 ${maxDistErr.toStringAsFixed(2)} m'
      ' / 最大偏移 ${maxOffset.toStringAsFixed(2)} m');
  _check('往返里程误差 < 1m', maxDistErr < 1.0, true);
  _check('往返偏移 < 1m', maxOffset < 1.0, true);

  // ── 5. 动作队列：严格按里程升序、不含已过动作 ──
  stdout.writeln('\n[5] 动作队列');
  var ascending = true;
  var excludesPassed = true;
  for (var i = 0; i < a.actions.length; i++) {
    if (i > 0 && a.actions[i].atDistance < a.actions[i - 1].atDistance) {
      ascending = false;
    }
  }
  for (final d in [0.0, 1234.0, 9000.0, _multiActionProbe, 26000.0]) {
    for (final act in a.upcomingActions(d, limit: 5)) {
      if (act.atDistance <= d) excludesPassed = false;
    }
  }
  _check('actions 按里程升序', ascending, true);
  _check('upcomingActions 不含已过动作', excludesPassed, true);

  // ── 6. 连续多动作：d=17560 时 limit:3 应为 17594/17625/17676 ──
  stdout.writeln('\n[6] 连续多动作队列（d=${_multiActionProbe.toStringAsFixed(0)}m）');
  final triple = a.upcomingActions(_multiActionProbe, limit: 3);
  final gotDistances =
      triple.map((x) => x.atDistance.toStringAsFixed(0)).toList();
  final wantDistances =
      _multiActionTargets.map((x) => x.toStringAsFixed(0)).toList();
  stdout.writeln('  实际 ${gotDistances.join(" → ")}');
  stdout.writeln('  基线 ${wantDistances.join(" → ")}');
  _check('三点均返回', triple.length, 3);
  _check('顺序与里程正确', gotDistances.join(','), wantDistances.join(','));
  final eta = _etaSeconds(triple, _multiActionProbe, 80);
  stdout.writeln('  80km/h 下 ETA '
      '${eta.map((e) => "${e.toStringAsFixed(1)}s").join(" / ")}'
      '  → ${eta.every((e) => e < 8) ? "三个动作同时落在 8 秒窗口内" : "未全部落入窗口"}');

  // ── 7. 跳点风险量化：1Hz 采样下每步前进 distance 的丢动作风险 ──
  stdout.writeln('\n[7] 跳点风险（1Hz 采样，单位：可能被跳过的 segment 数）');
  for (final kmh in [40, 80, 120]) {
    stdout.writeln('  ${kmh.toString().padLeft(3)} km/h → 每跳 '
        '${(kmh / 3.6).toStringAsFixed(1)} m，'
        '跳过 ${_skipRisk(a, kmh / 3.6)} 个 segment');
  }

  // ── 8. 限速点（4d 数据源）──
  stdout.writeln('\n[8] 限速设施（cameras type==0 带 speed / general type==10）');
  final limits = _speedLimits(route);
  stdout.writeln('  可用限速点 ${limits.length} 个：'
      '${limits.map((e) => "${e.speed}km/h@${e.atDistance.toStringAsFixed(0)}m").join(", ")}');
  stdout.writeln('  （脏坐标已过滤：|lon|>180 或 |lat|>90）');
  stdout.writeln('=' * 68);
}

/// 1Hz 采样下，以 [speedMs] 前进时可能被整段跳过的 segment 数。
///
/// 相邻 link 下标不连续意味着 coords 中存在孤点，而 GPS 每秒前进的距离
/// 可能超过短 segment 的长度 —— 这类 segment 用"查当前所在段"会被跳过，
/// 但 [RouteAnalyzer.upcomingActions] 的队列查询不受影响。
int _skipRisk(RouteAnalyzer a, double speedMs) {
  var risk = 0;
  for (var i = 0; i < a.segments.length; i++) {
    final len = a.segments[i].end - a.segments[i].start;
    if (len < speedMs) risk++;
  }
  return risk;
}

/// 从 restoration 的 facilities 中挑出可用限速点，并换算成沿路里程。
List<({int speed, double atDistance})> _speedLimits(AmapRoute route) {
  final a = RouteAnalyzer(route);
  final out = <({int speed, double atDistance})>[];

  void add(double lon, double lat, int segIdx, int linkIdx, int? speed,
      int? type) {
    if (speed == null || speed <= 0) return;
    if (lon.abs() > 180 || lat.abs() > 90) return; // 脏坐标过滤
    // 由 (segment, link) 反查该 link 的累计里程
    double? at;
    for (final span in a.links) {
      if (span.segmentIndex == segIdx &&
          span.link.linkIndex == linkIdx) {
        at = span.start;
        break;
      }
    }
    at ??= a.project(lon, lat).distance; // 兜底：用坐标投影
    out.add((speed: speed, atDistance: at));
  }

  for (final c in route.facilities.cameras) {
    if (c.type != 0) continue; // type 0 = 带限速值的测速点
    add(c.lon, c.lat, c.segmentIndex, c.linkIndex, c.speed, c.type);
  }
  for (final g in route.facilities.general) {
    if (g.type != 10) continue; // type 10 = 限速标志
    add(g.lon, g.lat, g.segmentIndex, g.linkIndex, g.speed, g.type);
  }
  out.sort((x, y) => x.atDistance.compareTo(y.atDistance));
  return out;
}

/// 以 [speedKmh] 从 [from] 出发，各动作的预计到达秒数
List<double> _etaSeconds(List<ActionPoint> actions, double from, double speedKmh) {
  final ms = (speedKmh / 3.6).clamp(2.0, double.infinity);
  return [for (final a in actions) (a.atDistance - from) / ms];
}
