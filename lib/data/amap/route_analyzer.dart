/// 高德分享路线 · 核心算法
///
/// 解决三件事：
///   1. 把形如 (segment, link) 的设施坐标换算成"距起点多少米"
///   2. 把任意 GPS 坐标投影到路线折线上，得到"已行驶里程"（**这是把
///      info 接口的实时位置变成导航指引的关键一步**）
///   3. 由里程反查：当前在哪条路、多少米后做什么动作、剩余多远多久
///
/// 与 JS 版看板 (amap-live/index.html) 是同一套算法，可用
/// `dart run bin/verify.dart` 跑真实数据对拍。
library;

import 'dart:math' as math;

import 'models.dart';

/// 一条 link 在全程中的位置
class LinkSpan {
  LinkSpan(this.link, this.segmentIndex, this.start, this.end, this.roadName);

  final RouteLink link;
  final int segmentIndex;
  final double start; // 距起点 米（含）
  final double end; // 距起点 米（不含）
  final String roadName;

  double get length => link.length.toDouble();
}

/// 一个导航分段：段末有 main_action
class SegmentSpan {
  SegmentSpan({
    required this.segmentIndex,
    required this.mainAction,
    required this.start,
    required this.end,
    required this.roadName,
    required this.nextRoadName,
    required this.travelTime,
    required this.trafficLightCount,
  });

  final int segmentIndex;
  final int mainAction;
  final double start;
  final double end;

  /// 本段结束时所处的道路
  final String roadName;

  /// 执行完 main_action 之后进入的道路（null = 终点）
  final String? nextRoadName;
  final int travelTime;
  final int trafficLightCount;
}

/// 一个导航动作点：走到该段末尾时要执行的动作。
///
/// 与 [SegmentSpan] 一一对应，但语义聚焦于"要做什么动作、在哪做"，
/// 用于构建**按里程排序的动作队列**。
///
/// 为什么需要队列，而不是查"当前所在 segment"：
/// GPS 在复杂路口可能一跳跨过很短的 segment（1Hz 采样 + 22 m/s ≈ 每次定位
/// 已跑 22 米，而连续路口的 segment 可能只有 20~40 米），直接查当前段会让
/// 中间那个动作**静默消失**。按里程顺序取"前方第一个未过的动作"则不受跳点影响。
class ActionPoint {
  ActionPoint({
    required this.segmentIndex,
    required this.actionCode,
    required this.atDistance,
    required this.roadName,
    required this.nextRoadName,
    required this.travelTime,
  });

  final int segmentIndex;

  /// main_action 动作码，含义见 [ActionCodes]
  final int actionCode;

  /// 执行位置：距路线起点的累计里程（米），即所在 segment 的 end
  final double atDistance;

  /// 执行该动作时所在的道路
  final String roadName;

  /// 执行完之后进入的道路；null 表示这是终点
  final String? nextRoadName;

  /// 该段预计耗时（秒）
  final int travelTime;

  String get label => ActionCodes.of(actionCode);
  String get arrow => ActionCodes.arrowOf(actionCode);

  /// 是否为高可信动作码（1 左转 / 2 右转 / 3 直行 有几何证据，0 为无动作）
  bool get isHighConfidence =>
      actionCode == 0 || actionCode == 1 || actionCode == 2 || actionCode == 3;

  @override
  String toString() =>
      'ActionPoint(seg=$segmentIndex, $label, @${atDistance.toStringAsFixed(0)}m)';
}

/// 投影结果
class Projection {
  const Projection(this.distance, this.offset);
  final double distance; // 沿路线的累计里程 米
  final double offset; // 偏离路线 米；>100 说明位置不在路上
}

/// 视窗切片：一段真实路线几何 + 车辆在其中的位置与前进朝向。
///
/// 供导航卡底图绘制（heading-up）：`points` 已按行进顺序排列，
/// `vehicleIndex` 指向**精确插值出的车辆位置**（不是最近的原始几何点），
/// `bearing` 是该处**路线切线**方向（不是 GPS 朝向 —— GPS 朝向在低速时冻结）。
class RouteSlice {
  const RouteSlice({
    required this.points,
    required this.vehicleIndex,
    required this.vehicleDistance,
    required this.fromDistance,
    required this.toDistance,
    required this.bearing,
    required this.trafficStates,
  });

  static const RouteSlice empty = RouteSlice(
    points: [],
    vehicleIndex: 0,
    vehicleDistance: 0,
    fromDistance: 0,
    toDistance: 0,
    bearing: 0,
    trafficStates: [],
  );

  /// 沿行进顺序的几何点（含车辆点与视窗两端点）
  final List<LonLat> points;

  /// `points` 中车辆所在的下标
  final int vehicleIndex;

  /// 车辆在路线上的累计里程（米）
  final double vehicleDistance;

  /// 视窗起点 / 终点里程（米）
  final double fromDistance;
  final double toDistance;

  /// 车辆处的前进方向（弧度，0=北，顺时针为正）
  final double bearing;

  /// 与 `points` 等长的路况码（取自覆盖该点的 link）
  final List<int> trafficStates;

  bool get isEmpty => points.length < 2;

  /// 视窗内的前方里程（用于底图比例尺）
  double get aheadMeters => toDistance - vehicleDistance;

  /// 视窗内的后方里程
  double get behindMeters => vehicleDistance - fromDistance;
}

/// 路线上的点标记类型
enum RouteMarkerKind {
  trafficLight, // 红绿灯
  speedLimit, // 限速点（value = 限速值 km/h）
}

/// 路线上的一个点标记（红绿灯 / 限速点），坐标已由里程换算为 GCJ-02
class RouteMarker {
  const RouteMarker(this.coord, this.kind, {this.value});
  final LonLat coord;
  final RouteMarkerKind kind;
  final int? value;
}

/// 导航指引
class Guidance {
  Guidance({
    required this.currentRoad,
    required this.linkOrdinal,
    required this.linkTotal,
    required this.traveledDistance,
    required this.distanceToAction,
    required this.actionCode,
    required this.segmentIndex,
  });

  final String currentRoad;
  final int linkOrdinal;
  final int linkTotal;
  final double traveledDistance;

  /// 距本段末（即下一个动作）还有多少米
  final double distanceToAction;
  final int actionCode;
  final int segmentIndex;

  String get actionLabel => ActionCodes.of(actionCode);
  String get actionArrow => ActionCodes.arrowOf(actionCode);
}

/// 视窗切片内部使用的（里程, 坐标）对
class _SlicePoint {
  const _SlicePoint(this.distance, this.coord);
  final double distance;
  final LonLat coord;
}

/// 路线模型：构造时一次性算好所有索引，之后查询都是 O(n) 或 O(log n)
class RouteAnalyzer {
  RouteAnalyzer(this.route, [RoutePath? path])
      : path = path ?? _defaultPath(route) {
    _build();
  }

  /// `paths: []` 时退化为空路线而不是抛异常（接口异常返回时的兜底）
  static RoutePath _defaultPath(AmapRoute route) =>
      route.paths.isEmpty ? RoutePath(const {}) : route.paths.first;

  final AmapRoute route;
  final RoutePath path;

  late final List<LinkSpan> links;
  late final List<SegmentSpan> segments;

  /// 动作点队列（按里程升序），用于"前方还有哪些动作"
  late final List<ActionPoint> actions;

  /// coords[i] 对应的累计里程
  late final List<double> coordDistance;

  /// coords[i] 是否被某条 link 引用。
  ///
  /// 实测相邻 link 下标不连续（本样本 35 处差 1、1 处差 2），存在**孤点**：
  /// 它们的 `coordDistance` 停在默认值 0，切片时必须排除，否则会在起点附近
  /// 注入一堆游离点。
  late final List<bool> coordCovered;

  double get totalDistance => path.distance.toDouble();
  double get totalTime => path.travelTime.toDouble();

  static const double _earthRadius = 6371000;

  /// Haversine，返回米
  static double haversine(LonLat a, LonLat b) {
    final p1 = a.lat * math.pi / 180;
    final p2 = b.lat * math.pi / 180;
    final dp = p2 - p1;
    final dl = (b.lon - a.lon) * math.pi / 180;
    final h = math.pow(math.sin(dp / 2), 2) +
        math.cos(p1) * math.cos(p2) * math.pow(math.sin(dl / 2), 2);
    return 2 * _earthRadius * math.asin(math.min(1, math.sqrt(h)));
  }

  void _build() {
    // --- 1. link 累计里程 + 所在道路 ---
    final ls = <LinkSpan>[];
    var cursor = 0.0;
    for (final seg in path.segments) {
      for (final lk in seg.links) {
        ls.add(LinkSpan(
          lk,
          seg.segmentIndex,
          cursor,
          cursor + lk.length,
          route.roadNameOf(lk.roadNameIndex),
        ));
        cursor += lk.length;
      }
    }
    links = ls;

    // --- 2. segment 累计里程；nextRoadName 取下一段第一条 link 的道路 ---
    final ss = <SegmentSpan>[];
    for (var i = 0; i < path.segments.length; i++) {
      final seg = path.segments[i];
      final own = links.where((l) => l.segmentIndex == seg.segmentIndex).toList();
      if (own.isEmpty) continue;
      String? nextRoad;
      if (i + 1 < path.segments.length) {
        final nxt = path.segments[i + 1].links;
        if (nxt.isNotEmpty) {
          nextRoad = route.roadNameOf(nxt.first.roadNameIndex);
        }
      }
      ss.add(SegmentSpan(
        segmentIndex: seg.segmentIndex,
        mainAction: seg.mainAction,
        start: own.first.start,
        end: own.last.end,
        roadName: own.last.roadName,
        nextRoadName: nextRoad,
        travelTime: own.fold(0, (a, b) => a + b.link.travelTime),
        trafficLightCount: own.where((l) => l.link.hasTrafficLight).length,
      ));
    }
    segments = ss;

    // --- 2b. 动作队列：与 segments 同序（已按里程升序）---
    actions = [
      for (final s in ss)
        ActionPoint(
          segmentIndex: s.segmentIndex,
          actionCode: s.mainAction,
          atDistance: s.end,
          roadName: s.roadName,
          nextRoadName: s.nextRoadName,
          travelTime: s.travelTime,
        ),
    ];

    // --- 3. 每个几何点对应的累计里程 ---
    // link 的 length 是权威值，coords 只用来算比例，所以用 haversine 在 link 内插值
    final cd = List<double>.filled(path.coords.length, 0);
    final covered = List<bool>.filled(path.coords.length, false);
    for (final span in links) {
      final b = span.link.beginIndex, e = span.link.endIndex;
      if (b < 0 || e >= path.coords.length || e < b) continue;
      final full = haversine(path.coords[b], path.coords[e]);
      for (var k = b; k <= e; k++) {
        final t = full > 0
            ? math.min(1, haversine(path.coords[b], path.coords[k]) / full)
            : 0.0;
        cd[k] = span.start + t * span.length;
        covered[k] = true;
      }
    }
    coordDistance = cd;
    coordCovered = covered;
  }

  /// 把 (lon, lat) 投影到路线折线上，返回累计里程与偏离距离。
  ///
  /// 用局部等距圆柱投影把经纬度转成米，再逐边求最近点。
  /// 北京纬度范围内误差可忽略；跨大纬度时建议换 UTM。
  ///
  /// **歧义（必须用 [nearDistance] 抑制）**：路线在空间上贴回自己时
  /// （立交上下匝道、主辅路、往返路段），相隔数百米的两个里程可能只相距
  /// 十几米。纯"最近边"会随机吸附到对面那一段，表现为"下一个动作突然
  /// 跳过后面的转弯"——实测样本里 d=220m 与 d=400m 只相距 18m，
  /// 中间正好隔着 2 个动作。
  ///
  /// 传入 [nearDistance]（上一次的里程，或"上次里程 + 预计前进量"）后：
  /// 只在 `[nearDistance - windowBehind, nearDistance + windowAhead]` 内、
  /// 且偏离不超过 [snapTolerance] 的候选中，取**里程最接近 [nearDistance]**
  /// 的那个（连续性先验优先于几何最近）；窗口内没有可接受候选时
  /// （真偏离 / 重新汇入路线）退回全局最近，交给偏离检测兜底。
  ///
  /// 不传 [nearDistance] 时行为与旧版完全一致（离线对拍基线不变）。
  Projection project(
    double lon,
    double lat, {
    double? nearDistance,
    double windowBehind = 120,
    double windowAhead = 400,
    double snapTolerance = 120,
  }) {
    final cs = path.coords;
    if (cs.isEmpty) return const Projection(0, 0);

    final lat0 = lat * math.pi / 180;
    final mx = 111320 * math.cos(lat0);
    const my = 110540.0;

    var bestD2 = double.infinity;
    var bestDist = 0.0;

    final near = nearDistance;
    final loD = near == null ? 0.0 : near - windowBehind;
    final hiD = near == null ? 0.0 : near + windowAhead;
    final tol2 = snapTolerance * snapTolerance;
    // 两级候选：优先"垂直足落在边内部"的（t 未被夹到 0/1）；
    // 只有当前者不存在时才退到"被夹到端点"的候选（车辆正好停在折线顶点时
    // 两边都会被夹住）。若不加区分，直线路段上相邻边的端点会成为
    // 一个"离得很近、里程又更接近先验"的候选，把位置**拖在后面一个动作点**上。
    var inGap = double.infinity, inDist = 0.0, inD2 = double.infinity;
    var anyGap = double.infinity, anyDist = 0.0, anyD2 = double.infinity;

    for (var i = 0; i < cs.length - 1; i++) {
      // 未被任何 link 引用的孤点会给出错误的累计里程（停在 0），
      // 连续性候选必须排除这类边；全局分支保持旧行为不变（对拍基线）
      final covered = near == null || (coordCovered[i] && coordCovered[i + 1]);

      final ax = (cs[i].lon - lon) * mx;
      final ay = (cs[i].lat - lat) * my;
      final bx = (cs[i + 1].lon - lon) * mx;
      final by = (cs[i + 1].lat - lat) * my;
      final vx = bx - ax, vy = by - ay;
      final l2 = vx * vx + vy * vy;
      var t = l2 > 0 ? -(ax * vx + ay * vy) / l2 : 0.0;
      t = t.clamp(0.0, 1.0);
      final nx = ax + t * vx, ny = ay + t * vy;
      final d2 = nx * nx + ny * ny;
      if (d2 < bestD2) {
        bestD2 = d2;
        bestDist =
            coordDistance[i] + t * (coordDistance[i + 1] - coordDistance[i]);
      }
      if (near != null && covered && d2 <= tol2) {
        final d =
            coordDistance[i] + t * (coordDistance[i + 1] - coordDistance[i]);
        if (d >= loD && d <= hiD) {
          final gap = (d - near).abs();
          if (gap < anyGap) {
            anyGap = gap;
            anyDist = d;
            anyD2 = d2;
          }
          if (t > 0 && t < 1 && gap < inGap) {
            inGap = gap;
            inDist = d;
            inD2 = d2;
          }
        }
      }
    }

    if (near != null) {
      if (inGap < double.infinity) return Projection(inDist, math.sqrt(inD2));
      if (anyGap < double.infinity) return Projection(anyDist, math.sqrt(anyD2));
    }
    return Projection(bestDist, math.sqrt(bestD2));
  }

  LinkSpan linkAt(double distance) {
    for (final l in links) {
      if (distance < l.end) return l;
    }
    return links.last;
  }

  SegmentSpan segmentAt(double distance) {
    for (final s in segments) {
      if (distance < s.end) return s;
    }
    return segments.last;
  }

  /// 由里程生成导航指引 —— 这就是"当前在哪条路 / 多少米后拐弯"的答案
  Guidance guidanceAt(double distance) {
    final lk = linkAt(distance);
    final sg = segmentAt(distance);
    return Guidance(
      currentRoad: lk.roadName,
      linkOrdinal: links.indexOf(lk) + 1,
      linkTotal: links.length,
      traveledDistance: distance,
      distanceToAction: math.max(0, sg.end - distance),
      actionCode: sg.mainAction,
      segmentIndex: sg.segmentIndex,
    );
  }

  /// 前方尚未经过的动作点，按里程升序，最多 [limit] 个。
  ///
  /// 用"按里程过滤"而不是"查当前所在 segment"，因此 GPS 跳点跨过短 segment
  /// 也不会漏掉中间的动作 —— 这是复杂路口不丢提示的关键。
  List<ActionPoint> upcomingActions(double distance, {int limit = 3}) {
    final out = <ActionPoint>[];
    for (final a in actions) {
      if (a.atDistance <= distance) continue;
      out.add(a);
      if (out.length >= limit) break;
    }
    return out;
  }

  /// 刚刚经过的最后一个动作点；[distance] 之前没有动作点时返回 null。
  ///
  /// 用于判断"是否漏播报"：若它距当前位置已经很远，说明中间的动作被跳过了。
  ActionPoint? lastPassedAction(double distance) {
    ActionPoint? passed;
    for (final a in actions) {
      if (a.atDistance > distance) break;
      passed = a;
    }
    return passed;
  }

  /// 返回路线上指定里程处的坐标（GCJ-02），里程夹到 `[0, totalDistance]`。
  ///
  /// 用于模拟定位、放置标记等场景。在所属 link **内部的几何点之间**按累计里程
  /// 插值 —— 不用首尾直线插值，否则弯曲的 link 会偏出路线数米（实测最差 8m）。
  ///
  /// 自检：`project(coordAt(d))` 应满足 `distance ≈ d` 且 `offset ≈ 0`。
  LonLat coordAt(double distance) {
    final cs = path.coords;
    if (cs.isEmpty || links.isEmpty) return const LonLat(0, 0);
    final d = distance.clamp(0.0, totalDistance);
    final span = linkAt(d);
    final b = span.link.beginIndex;
    final e = span.link.endIndex;
    if (b < 0 || e >= cs.length || e < b) return cs.first;

    // 沿 link 内逐个几何点区间查找 d 落在哪一段
    for (var k = b; k < e; k++) {
      final d0 = coordDistance[k];
      final d1 = coordDistance[k + 1];
      if (d1 < d0) continue; // 跳过累计里程未收敛的孤点
      if (d >= d0 && d <= d1) {
        final t = d1 > d0 ? (d - d0) / (d1 - d0) : 0.0;
        return LonLat(
          cs[k].lon + (cs[k + 1].lon - cs[k].lon) * t,
          cs[k].lat + (cs[k + 1].lat - cs[k].lat) * t,
        );
      }
    }

    // 兜底：单点 link，或 d 恰好落在边界
    final t = span.length > 0
        ? ((d - span.start) / span.length).clamp(0.0, 1.0)
        : 0.0;
    return LonLat(
      cs[b].lon + (cs[e].lon - cs[b].lon) * t,
      cs[b].lat + (cs[e].lat - cs[b].lat) * t,
    );
  }

  /// 剩余里程 / 剩余时间（秒） / 剩余红绿灯。按 link 级 travel_time 累加，
  /// 比用整条路线的平均值准。
  ({double meters, double seconds, int lights}) remainingAt(double distance) {
    var meters = 0.0, seconds = 0.0;
    var lights = 0;
    for (final l in links) {
      if (l.end <= distance) continue;
      final from = math.max(distance, l.start);
      final part = l.length > 0 ? (l.end - from) / l.length : 0.0;
      meters += l.length * part;
      seconds += l.link.travelTime * part;
      if (l.link.hasTrafficLight) lights++;
    }
    return (meters: meters, seconds: seconds, lights: lights);
  }

  /// 里程 [distance] 处路线的**前进方向**（弧度；0 = 北，顺时针为正）。
  ///
  /// 用 [coordAt] 在 `d → d+25m` 上求方位角，因此是**路线切线**而不是 GPS 朝向：
  /// 低速/静止时 GPS 朝向会冻结或抖动，而路线切线在同一路段内平滑稳定，
  /// 且与"这条路接下来往哪走"的语义一致（导航卡 heading-up 绘制用）。
  ///
  /// 终点附近自动回溯取点；无法求出方向时返回 null。
  double? bearingAt(double distance) {
    if (path.coords.length < 2 || totalDistance < 1) return null;
    const step = 25.0;
    final d = distance.clamp(0.0, totalDistance);
    var d0 = d;
    var d1 = d + step;
    if (d1 > totalDistance) {
      d1 = totalDistance;
      d0 = math.max(0.0, totalDistance - step);
    }
    if (d1 - d0 < 1.0) return null;

    final a = coordAt(d0);
    final b = coordAt(d1);
    final dx = (b.lon - a.lon) * math.cos(a.lat * math.pi / 180);
    final dy = b.lat - a.lat;
    if (dx.abs() < 1e-12 && dy.abs() < 1e-12) return null;
    return math.atan2(dx, dy);
  }

  /// 导航卡底图用：以 [vehicleDistance] 为锚点，向后 [behindMeters]、
  /// 向前 [aheadMeters] 的一段真实路线切片。
  ///
  /// - 跳过不被任何 link 引用的**孤点**（见 [coordCovered]）
  /// - 用 [coordAt] 精确补上车辆点与视窗两端点，保证车标落在线上、线延伸到边缘
  /// - 点数超过 [maxPoints] 时抽稀，但**始终保留车辆点与首尾**
  RouteSlice routeSlice({
    required double vehicleDistance,
    double behindMeters = 40,
    double aheadMeters = 300,
    int maxPoints = 80,
  }) {
    if (path.coords.isEmpty || links.isEmpty) return RouteSlice.empty;

    final vd = vehicleDistance.clamp(0.0, totalDistance);
    final lo = math.max(0.0, vd - behindMeters);
    final hi = math.min(totalDistance, vd + aheadMeters);

    var entries = <_SlicePoint>[];
    for (var i = 0; i < path.coords.length; i++) {
      if (!coordCovered[i]) continue;
      final d = coordDistance[i];
      if (d < lo || d > hi) continue;
      entries.add(_SlicePoint(d, path.coords[i]));
    }
    entries.add(_SlicePoint(vd, coordAt(vd)));
    entries.add(_SlicePoint(lo, coordAt(lo)));
    entries.add(_SlicePoint(hi, coordAt(hi)));
    entries.sort((a, b) => a.distance.compareTo(b.distance));
    entries = _dedupeByDistance(entries);

    if (entries.length > maxPoints) {
      var vi = 0;
      var best = double.infinity;
      for (var i = 0; i < entries.length; i++) {
        final t = (entries[i].distance - vd).abs();
        if (t < best) {
          best = t;
          vi = i;
        }
      }
      final stride = (entries.length / maxPoints).ceil();
      final kept = <_SlicePoint>[entries.first];
      for (var i = stride; i < entries.length - 1; i += stride) {
        kept.add(entries[i]);
      }
      kept
        ..add(entries[vi])
        ..add(entries.last);
      kept.sort((a, b) => a.distance.compareTo(b.distance));
      entries = _dedupeByDistance(kept);
    }

    var vehicleIndex = 0;
    var best = double.infinity;
    for (var i = 0; i < entries.length; i++) {
      final t = (entries[i].distance - vd).abs();
      if (t < best) {
        best = t;
        vehicleIndex = i;
      }
    }

    return RouteSlice(
      points: [for (final e in entries) e.coord],
      vehicleIndex: vehicleIndex,
      vehicleDistance: vd,
      fromDistance: lo,
      toDistance: hi,
      bearing: bearingAt(vd) ?? 0,
      trafficStates: [for (final e in entries) linkAt(e.distance).link.trafficState],
    );
  }

  static List<_SlicePoint> _dedupeByDistance(List<_SlicePoint> src) {
    final out = <_SlicePoint>[];
    for (final e in src) {
      if (out.isNotEmpty && e.distance <= out.last.distance) continue;
      out.add(e);
    }
    return out;
  }

  /// 某段区间内的路况构成（米），用于画剩余路况条
  Map<int, double> trafficBetween(double from, double to) {
    final agg = <int, double>{};
    for (final l in links) {
      if (l.end <= from) continue;
      final a = math.max(from, l.start), b = math.min(to, l.end);
      if (b > a) {
        agg[l.link.trafficState] =
            (agg[l.link.trafficState] ?? 0) + (b - a);
      }
    }
    return agg;
  }

  /// 自检：link 长度之和应等于 path.distance
  bool get lengthConsistent =>
      (links.fold(0.0, (a, b) => a + b.length) - totalDistance).abs() < 1.0;

  /// 几何转角（度）。正值右转、负值左转。
  ///
  /// 仅用于**标定未知动作码**：拿它和 main_action 交叉验证。
  /// 在立交/匝道处 coords 可能有重复点或方向回折，会算出 ±180 附近的假值，
  /// 所以生产环境应该用 main_action，不要用这个。
  double? turnAngleAtCoord(int k, {double window = 40}) {
    final cs = path.coords;
    if (k <= 0 || k >= cs.length - 1) return null;
    var i0 = k - 1;
    while (i0 > 0 && coordDistance[k] - coordDistance[i0] < window) {
      i0--;
    }
    var j0 = k;
    while (j0 < cs.length - 1 && coordDistance[j0] - coordDistance[k] < window) {
      j0++;
    }
    double bearing(LonLat a, LonLat b) {
      final dx = (b.lon - a.lon) * math.cos(a.lat * math.pi / 180);
      final dy = b.lat - a.lat;
      return math.atan2(dx, dy) * 180 / math.pi;
    }

    final a = cs[i0], b = cs[k], c = cs[k], d = cs[j0];
    if (identical(a, c) || identical(b, d)) return null;
    final raw = bearing(c, d) - bearing(a, b);
    return (raw + 540) % 360 - 180;
  }
}
