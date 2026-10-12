import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../models/riding_record.dart';
import '../providers/riding_record_provider.dart';
import '../services/geocoding_service.dart';
import '../theme/app_theme.dart';
import '../widgets/cyber_dialog.dart';
import '../widgets/riding_event_item.dart';
import '../widgets/speed_chart.dart';

/// 骑行轨迹全屏地图页面
class RidingTrackScreen extends StatefulWidget {
  final RidingRecord record;

  const RidingTrackScreen({super.key, required this.record});

  @override
  State<RidingTrackScreen> createState() => _RidingTrackScreenState();
}

// 曲线图高度常量
const double _kChartHeight = 90.0;

// 速度颜色量化档数（越大颜色过渡越细腻，但同色段合并越少）
const int _kSpeedColorSteps = 12;

// 轨迹点超过该阈值时，GCJ 转换 + 抽稀放到后台 isolate（compute 有固定开销，小数据同步更划算）
const int _kGcjComputeThreshold = 1500;

// 地图样式
enum _MapStyle { dark, satellite }

/// 后台 isolate 返回值：全量 GCJ 坐标 + 折线渲染用的抽稀索引
class _GcjDecimationResult {
  final List<List<double>> gcj; // 与 waypoints 一一对应
  final List<int> keptIndices; // 抽稀保留的 waypoint 索引（升序，含首尾）

  _GcjDecimationResult(this.gcj, this.keptIndices);
}

/// 后台 isolate：WGS-84 → GCJ-02 全量转换（每点多次三角函数，CPU 密集）。
/// 同时做一次轻量距离抽稀，去掉静止/密集采样产生的冗余点，并硬性限制折线渲染点数。
_GcjDecimationResult _convertAndDecimateWaypoints(
    List<RidingWaypoint> waypoints) {
  const minDistM = 2.0; // 相邻点小于 2 米视为冗余
  const maxKept = 5000; // 折线渲染点数上限

  final n = waypoints.length;
  final gcj = <List<double>>[];
  for (final w in waypoints) {
    gcj.add(GeocodingService.wgs84ToGcj02(w.latitude, w.longitude));
  }
  if (n == 0) return _GcjDecimationResult(gcj, const []);

  final kept = <int>[];
  for (int i = 0; i < n; i++) {
    if (kept.isEmpty) {
      kept.add(i);
      continue;
    }
    final a = gcj[kept.last];
    final b = gcj[i];
    final dLat = (b[0] - a[0]) * 111000;
    final dLng = (b[1] - a[1]) * 111000 * math.cos(a[0] * math.pi / 180);
    if (dLat * dLat + dLng * dLng >= minDistM * minDistM) {
      kept.add(i);
    }
  }

  // 超上限时均匀 stride 二次抽稀
  if (kept.length > maxKept) {
    final stride = (kept.length / maxKept).ceil();
    final capped = <int>[];
    for (int k = 0; k < kept.length; k += stride) {
      capped.add(kept[k]);
    }
    kept
      ..clear()
      ..addAll(capped);
  }

  // 保证首尾都在（fitBounds / 起终点依赖）
  if (kept.first != 0) kept.insert(0, 0);
  if (kept.last != n - 1) kept.add(n - 1);

  return _GcjDecimationResult(gcj, kept);
}

class _RidingTrackScreenState extends State<RidingTrackScreen> {
  final MapController _mapController = MapController();

  // 地图样式
  _MapStyle _mapStyle = _MapStyle.dark;

  // 所有轨迹点（加载后缓存）
  List<RidingWaypoint> _allWaypoints = [];

  // GCJ-02 坐标缓存（加载时一次性转换）
  List<LatLng> _cachedGcjPoints = [];

  // 骑行事件
  List<RidingRecordEvent> _events = [];

  // 当前缩放级别（ValueNotifier 驱动局部重建，避免整页 setState）
  final ValueNotifier<double> _zoomNotifier = ValueNotifier(14.0);

  // 速度渐变折线（加载时一次性构建，配合 flutter_map 内置 simplificationTolerance 按 zoom 简化）
  List<Polyline> _gradientPolylines = [];

  // 有效事件列表（过滤掉无对应轨迹点的事件），与三套 Circle 缓存下标一一对应
  List<_MappedEvent> _mappedEvents = [];

  // 三套 CircleMarker 缓存（按 zoom 档预构建，地图交互时直接取引用，零分配）
  List<CircleMarker> _circleCacheL0 = []; // zoom < 12：小圆点
  List<CircleMarker> _circleCacheL1 = []; // 12 <= zoom < 15：中圆点
  List<CircleMarker> _circleCacheL2 = []; // zoom >= 15：大圆点

  // 当前点击选中的事件（用于高亮叠加层）
  _MappedEvent? _selectedEvent;

  // 加载状态
  bool _isLoading = true;
  String? _errorMessage;

  // 防抖定时器
  Timer? _debounceTimer;

  // 速度曲线图游标（waypoint 原始索引）
  int? _cursorIndex;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _zoomNotifier.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final provider = context.read<RidingRecordProvider>();
      final recordId = widget.record.id!;

      final results = await Future.wait([
        provider.getWaypointsForRecord(recordId),
        provider.getEventsForRecord(recordId),
      ]);

      final waypoints = results[0] as List<RidingWaypoint>;
      final events = results[1] as List<RidingRecordEvent>;

      // WGS-84 → GCJ-02：每点多次三角函数、CPU 密集，点量大时放后台 isolate；
      // 同时做一次轻量距离抽稀，去冗余并限制折线渲染点数。
      final dec = waypoints.length > _kGcjComputeThreshold
          ? await compute(_convertAndDecimateWaypoints, waypoints)
          : _convertAndDecimateWaypoints(waypoints);
      final gcjPoints = <LatLng>[
        for (final c in dec.gcj) LatLng(c[0], c[1]),
      ];

      // 数据加载完成后一次性构建事件圆点缓存 + 渐变折线（避免每次 build 重建）
      _buildMappedEvents(events, gcjPoints, waypoints);
      final polylines =
          _buildGradientPolylines(waypoints, gcjPoints, dec.keptIndices);

      setState(() {
        _allWaypoints = waypoints;
        _cachedGcjPoints = gcjPoints;
        _events = events;
        _gradientPolylines = polylines;
        _isLoading = false;
      });

      // 自动 fitBounds
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitBounds());
    } catch (e) {
      setState(() {
        _errorMessage = '轨迹加载失败: $e';
        _isLoading = false;
      });
    }
  }

  /// 自动调整地图视角以包含整条轨迹
  void _fitBounds() {
    if (_cachedGcjPoints.length < 2) return;

    double minLat = _cachedGcjPoints.first.latitude;
    double maxLat = _cachedGcjPoints.first.latitude;
    double minLng = _cachedGcjPoints.first.longitude;
    double maxLng = _cachedGcjPoints.first.longitude;

    for (final pt in _cachedGcjPoints) {
      if (pt.latitude < minLat) minLat = pt.latitude;
      if (pt.latitude > maxLat) maxLat = pt.latitude;
      if (pt.longitude < minLng) minLng = pt.longitude;
      if (pt.longitude > maxLng) maxLng = pt.longitude;
    }

    final bounds = LatLngBounds(
      LatLng(minLat, minLng),
      LatLng(maxLat, maxLng),
    );

    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(40),
      ),
    );
  }

  /// 速度映射颜色（霓虹青 → 品红 → 粉红 三段渐变）
  /// 颜色做量化分档，让相邻速度点共享同一颜色 → 同色连续段合并成更少的折线段
  Color _speedToColor(double speed) {
    if (speed <= 40) {
      return const Color(0xFF00F5FF); // 霓虹青
    }
    if (speed <= 80) {
      final t = (speed - 40) / 40;
      final q = (t * _kSpeedColorSteps).round() / _kSpeedColorSteps;
      return Color.lerp(
          const Color(0xFF00F5FF), const Color(0xFFFF00FF), q)!; // 青→品红
    }
    final t = ((speed - 80) / 40).clamp(0.0, 1.0);
    final q = (t * _kSpeedColorSteps).round() / _kSpeedColorSteps;
    return Color.lerp(
        const Color(0xFFFF00FF), const Color(0xFFFF2D87), q)!; // 品红→霓虹粉
  }

  /// 一次性构建速度渐变折线（颜色量化后同色连续段合并）。
  /// 抽稀交给 flutter_map 内置 `simplificationTolerance` 按 zoom 完成，这里不再手工 Douglas-Peucker。
  List<Polyline> _buildGradientPolylines(
    List<RidingWaypoint> waypoints,
    List<LatLng> gcjPoints,
    List<int> keptIndices,
  ) {
    final m = keptIndices.length;
    if (m < 2) return [];

    final polylines = <Polyline>[];
    var segPoints = <LatLng>[
      gcjPoints[keptIndices[0]],
      gcjPoints[keptIndices[1]],
    ];
    var segColor = _speedToColor(
        (waypoints[keptIndices[0]].speed + waypoints[keptIndices[1]].speed) /
            2);

    for (int i = 2; i < m; i++) {
      final i0 = keptIndices[i - 1];
      final i1 = keptIndices[i];
      final avgSpeed = (waypoints[i0].speed + waypoints[i1].speed) / 2;
      final color = _speedToColor(avgSpeed);

      if (color == segColor) {
        segPoints.add(gcjPoints[i1]);
      } else {
        // 颜色变化：flush 当前段，新段从上一段末尾点延续，保证轨迹连续
        polylines.add(Polyline(
          points: segPoints,
          color: segColor,
          strokeWidth: 4.0,
        ));
        segPoints = <LatLng>[gcjPoints[i0], gcjPoints[i1]];
        segColor = color;
      }
    }
    polylines.add(Polyline(
      points: segPoints,
      color: segColor,
      strokeWidth: 4.0,
    ));

    return polylines;
  }

  /// 二分查找最近轨迹点索引（轨迹点按 timestamp 升序排列）
  /// 时间复杂度 O(logN)，替代原来的 O(N) 线性搜索
  int _findNearestWaypointIndex(List<RidingWaypoint> waypoints, int timestamp) {
    int lo = 0, hi = waypoints.length - 1;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (waypoints[mid].timestamp < timestamp) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    // 检查 lo-1 是否更近
    if (lo > 0) {
      final d1 = (waypoints[lo].timestamp - timestamp).abs();
      final d0 = (waypoints[lo - 1].timestamp - timestamp).abs();
      if (d0 < d1) return lo - 1;
    }
    return lo;
  }

  /// 一次性构建有效事件列表 + 三套 CircleMarker 缓存（数据加载完成后调用一次）
  void _buildMappedEvents(
    List<RidingRecordEvent> events,
    List<LatLng> gcjPoints,
    List<RidingWaypoint> waypoints,
  ) {
    if (gcjPoints.isEmpty || waypoints.isEmpty) return;
    final mapped = <_MappedEvent>[];
    for (final event in events) {
      // 二分查找最近轨迹点（O(logN)）
      final idx = _findNearestWaypointIndex(waypoints, event.timestamp);
      if ((waypoints[idx].timestamp - event.timestamp).abs() > 30000) continue;
      if (idx >= gcjPoints.length) continue;
      mapped.add(_MappedEvent(
        event: event,
        point: gcjPoints[idx],
        color: RidingEventItem.colorFromType(event.type),
        icon: RidingEventItem.iconFromType(event.type),
      ));
    }
    _mappedEvents = mapped;
    // 预构建三套缓存，地图交互时直接取引用，零分配
    _circleCacheL0 = _buildCircles(radius: 4, borderWidth: 0, opacity: 0.6);
    _circleCacheL1 = _buildCircles(radius: 8, borderWidth: 1.5, opacity: 0.85);
    _circleCacheL2 = _buildCircles(radius: 11, borderWidth: 2.0, opacity: 0.95);
  }

  List<CircleMarker> _buildCircles({
    required double radius,
    required double borderWidth,
    required double opacity,
  }) {
    return _mappedEvents
        .map((e) => CircleMarker(
              point: e.point,
              radius: radius,
              color: e.color.withOpacity(opacity),
              borderColor: borderWidth > 0
                  ? Colors.white.withOpacity(0.6)
                  : Colors.transparent,
              borderStrokeWidth: borderWidth,
              useRadiusInMeter: false, // 屏幕像素，缩放时大小固定
            ))
        .toList();
  }

  /// 按 zoom 档返回对应缓存引用（不重建对象，零分配）
  List<CircleMarker> _getCircleCache(double zoom) {
    if (zoom < 12) return _circleCacheL0;
    if (zoom < 15) return _circleCacheL1;
    return _circleCacheL2;
  }

  /// 选中态高亮 Marker（圆环 + icon），最多同时存在 1 个
  Marker _buildSelectedEventMarker(_MappedEvent me) {
    return Marker(
      point: me.point,
      width: 44,
      height: 44,
      child: RepaintBoundary(
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 外发光环
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: me.color, width: 2),
                color: me.color.withOpacity(0.15),
              ),
            ),
            // 中心 icon
            Icon(me.icon, color: me.color, size: 18),
          ],
        ),
      ),
    );
  }

  /// onTap 命中检测（屏幕像素空间，精度高且与缩放无关）
  static const double _kHitRadiusPx = 28.0;

  void _handleMapTap(TapPosition tapPos) {
    final zoom = _zoomNotifier.value;
    if (zoom < 12 || _mappedEvents.isEmpty) {
      if (_selectedEvent != null) setState(() => _selectedEvent = null);
      return;
    }
    final tapPx = tapPos.relative;
    if (tapPx == null) return;

    double minDistSq = double.infinity;
    _MappedEvent? nearest;

    for (final me in _mappedEvents) {
      final pt = _mapController.camera.latLngToScreenOffset(me.point);
      final dx = pt.dx - tapPx.dx;
      final dy = pt.dy - tapPx.dy;
      final distSq = dx * dx + dy * dy;
      if (distSq < minDistSq) {
        minDistSq = distSq;
        nearest = me;
      }
    }

    const hitSq = _kHitRadiusPx * _kHitRadiusPx;
    if (nearest != null && minDistSq <= hitSq) {
      setState(() => _selectedEvent = nearest);
      _showEventDetail(context, nearest.event);
    } else {
      if (_selectedEvent != null) setState(() => _selectedEvent = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: Stack(
        children: [
          // ── 地图主体 ──
          if (!_isLoading && _errorMessage == null)
            _buildMap()
          else if (_isLoading)
            const Center(
              child: CircularProgressIndicator(color: AppTheme.primary),
            )
          else
            Center(
              child: Text(
                _errorMessage ?? '未知错误',
                style: const TextStyle(color: AppTheme.textSecondary),
              ),
            ),

          // ── 顶部导航栏 ──
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildAppBar(context),
          ),

          // ── 底部速度曲线图（全屏宽度） ──
          if (!_isLoading && _allWaypoints.length >= 2)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: _kChartHeight,
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.backgroundDark.withOpacity(0.82),
                  border: const Border(
                    top: BorderSide(color: Color(0x33FFFFFF), width: 0.5),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                child: SpeedChart(
                  waypoints: _allWaypoints,
                  events: _events,
                  recordMaxSpeed: widget.record.maxSpeed,
                  cursorIndex: _cursorIndex,
                  onCursorChanged: (idx) {
                    setState(() => _cursorIndex = idx);
                  },
                ),
              ),
            ),
          // ── 统计卡（右侧竖列，吸附屏幕右边，紧贴折线图上方） ──
          Positioned(
            right: 0,
            bottom: _kChartHeight + 8,
            child: _buildStatsColumn(),
          ),
          // ── 轨迹点 badge（折线图左上角） ──
          if (!_isLoading && _allWaypoints.isNotEmpty)
            Positioned(
              left: 8,
              bottom: _kChartHeight + 8,
              child: ValueListenableBuilder<double>(
                valueListenable: _zoomNotifier,
                builder: (context, zoom, _) {
                  return _WaypointBadge(
                    count: _allWaypoints.length,
                    zoom: zoom,
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  // 暗色底图滤镜（反色 + 降饱和 + 色调偏蓝灰，模拟暗色地图）
  static const ColorFilter _darkMapColorFilter = ColorFilter.matrix([
    -0.6,
    0,
    0,
    0,
    180,
    0,
    -0.6,
    0,
    0,
    180,
    0,
    0,
    -0.6,
    0,
    200,
    0,
    0,
    0,
    1,
    0,
  ]);

  // 共享瓦片 provider：复用同一个 HTTP 客户端 + 内置磁盘缓存（BuiltInMapCachingProvider）。
  // 避免每次 build 重建 NetworkTileProvider 导致 HTTP 客户端泄漏（游标拖动会高频触发 build）。
  final NetworkTileProvider _tileProvider = NetworkTileProvider();

  Widget _buildTileLayer() {
    if (_mapStyle == _MapStyle.satellite) {
      // 卫星实景底图（高德卫星瓦片）
      return TileLayer(
        urlTemplate:
            'https://webst01.is.autonavi.com/appmaptile?style=6&x={x}&y={y}&z={z}',
        userAgentPackageName: 'com.example.obd_dashboard',
        tileProvider: _tileProvider,
      );
    }

    // 赛博朋克暗色路网底图：整层 ColorFiltered（官方推荐方式，比逐瓦片 tileBuilder 更省）
    return ColorFiltered(
      colorFilter: _darkMapColorFilter,
      child: TileLayer(
        urlTemplate:
            'https://webrd01.is.autonavi.com/appmaptile?lang=zh_cn&size=1&scale=1&style=8&x={x}&y={y}&z={z}',
        userAgentPackageName: 'com.example.obd_dashboard',
        subdomains: const ['webrd01', 'webrd02', 'webrd03', 'webrd04'],
        tileProvider: _tileProvider,
      ),
    );
  }

  Widget _buildMap() {
    if (_cachedGcjPoints.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.map_outlined, color: AppTheme.primary, size: 48),
            const SizedBox(height: 12),
            const Text(
              '此次骑行暂无轨迹数据',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ],
        ),
      );
    }

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _cachedGcjPoints.first,
        initialZoom: _zoomNotifier.value,
        onPositionChanged: (camera, _) {
          _debounceTimer?.cancel();
          _debounceTimer = Timer(const Duration(milliseconds: 300), () {
            if (mounted && camera.zoom != _zoomNotifier.value) {
              _zoomNotifier.value = camera.zoom;
            }
          });
        },
        // 全局 onTap：替代每个 Marker 的 GestureDetector，减少命中测试压力
        onTap: (tapPos, _) => _handleMapTap(tapPos),
      ),
      children: [
        // 1. 底图（根据样式切换）
        _buildTileLayer(),

        // 2. 速度渐变轨迹折线：一次性构建 + flutter_map 内置 simplificationTolerance 按 zoom 简化。
        //    保持 PolylineLayer widget 稳定（不放 ValueListenableBuilder），
        //    避免每次 zoom 变化触发 didUpdateWidget 清空投影/简化缓存。
        if (_gradientPolylines.isNotEmpty)
          PolylineLayer(
            polylines: _gradientPolylines,
            simplificationTolerance: 0.5,
          ),

        // 3~4. zoom 分级图层（事件圆点三档 / 选中高亮 Marker），用 ValueListenableBuilder 局部重建
        ValueListenableBuilder<double>(
          valueListenable: _zoomNotifier,
          builder: (context, zoom, _) {
            return Stack(
              children: [
                if (_mappedEvents.isNotEmpty)
                  CircleLayer(circles: _getCircleCache(zoom)),
                if (_selectedEvent != null && zoom >= 12)
                  MarkerLayer(
                      markers: [_buildSelectedEventMarker(_selectedEvent!)]),
              ],
            );
          },
        ),

        // 5. 起点 / 终点 / 游标（固定 2~3 个，与事件层分离，各自 RepaintBoundary 缓存）
        MarkerLayer(
          markers: [
            // 起点 Marker
            Marker(
              point: _cachedGcjPoints.first,
              width: 20,
              height: 20,
              child: const RepaintBoundary(
                child: _TrackPin(
                  color: Color(0xFF00F5FF),
                  label: '起',
                ),
              ),
            ),
            // 终点 Marker
            Marker(
              point: _cachedGcjPoints.last,
              width: 20,
              height: 20,
              child: const RepaintBoundary(
                child: _TrackPin(
                  color: Color(0xFFFF2D87),
                  label: '终',
                ),
              ),
            ),
            // 游标位置圆点（拖动速度曲线图时联动）
            if (_cursorIndex != null && _cursorIndex! < _cachedGcjPoints.length)
              Marker(
                point: _cachedGcjPoints[_cursorIndex!],
                width: 20,
                height: 20,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    shape: BoxShape.circle,
                    border:
                        Border.all(color: const Color(0xFF00FF85), width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withOpacity(0.5),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return SafeArea(
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.backgroundDark.withOpacity(0.9),
              AppTheme.backgroundDark.withOpacity(0),
            ],
          ),
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppTheme.surface.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(AppTheme.radiusButton),
                  border: Border.all(color: AppTheme.primary20),
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new,
                  color: AppTheme.primary,
                  size: 16,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '轨迹回放',
                  style: TextStyle(
                    color: AppTheme.primary70,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                Text(
                  widget.record.formattedStartTime,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Spacer(),
            // 地图样式切换按钮
            GestureDetector(
              onTap: () => setState(() {
                _mapStyle = _mapStyle == _MapStyle.dark
                    ? _MapStyle.satellite
                    : _MapStyle.dark;
              }),
              child: Container(
                height: 28,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: AppTheme.surface.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(AppTheme.radiusButton),
                  border: Border.all(
                    color: _mapStyle == _MapStyle.satellite
                        ? AppTheme.accentOrange.withOpacity(0.7)
                        : AppTheme.primary.withOpacity(0.5),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _mapStyle == _MapStyle.satellite
                          ? Icons.map_outlined
                          : Icons.satellite_alt,
                      size: 13,
                      color: _mapStyle == _MapStyle.satellite
                          ? AppTheme.accentOrange
                          : AppTheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _mapStyle == _MapStyle.satellite ? '街道' : '卫星',
                      style: TextStyle(
                        color: _mapStyle == _MapStyle.satellite
                            ? AppTheme.accentOrange
                            : AppTheme.primary,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            // 重新定位按钮
            GestureDetector(
              onTap: _fitBounds,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppTheme.surface.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(AppTheme.radiusButton),
                  border: Border.all(color: AppTheme.primary20),
                ),
                child: const Icon(
                  Icons.center_focus_strong_outlined,
                  color: AppTheme.primary,
                  size: 18,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 弹出事件详情弹窗
  void _showEventDetail(BuildContext ctx, RidingRecordEvent event) {
    final color = RidingEventItem.colorFromType(event.type);
    final icon = RidingEventItem.iconFromType(event.type);
    CyberDialog.show(
      context: ctx,
      title: event.title,
      icon: icon,
      accentColor: color,
      barrierDismissible: true,
      width: 420,
      actions: const [],
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _EventDetailRow(label: '事件类型', value: event.type),
            if (event.description != null && event.description!.isNotEmpty)
              _EventDetailRow(label: '描述', value: event.description!),
            _EventDetailRow(
                label: '触发值', value: event.triggerValue.toStringAsFixed(1)),
            _EventDetailRow(
                label: '阈值', value: event.threshold.toStringAsFixed(1)),
            _EventDetailRow(label: '触发时间', value: event.formattedTime),
          ],
        ),
      ),
    );
  }

  /// 统计卡（竖向，吸附屏幕右侧）
  Widget _buildStatsColumn() {
    final record = widget.record;
    return Container(
      width: 88,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
        color: AppTheme.backgroundDark.withOpacity(0.88),
        // 只有左侧有边框，右侧贴边
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(2),
          bottomLeft: Radius.circular(2),
        ),
        border: Border(
          top: BorderSide(color: AppTheme.primary20),
          left: BorderSide(color: AppTheme.primary20),
          bottom: BorderSide(color: AppTheme.primary20),
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(-2, 0),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StatCell(
            icon: Icons.route,
            label: '距离',
            value: record.distance.toStringAsFixed(1),
            unit: 'km',
            color: AppTheme.textPrimary,
          ),
          _StatDivider(),
          _StatCell(
            icon: Icons.timer_outlined,
            label: '时长',
            value: record.formattedDuration,
            unit: '',
            color: AppTheme.accentGreen,
          ),
          _StatDivider(),
          _StatCell(
            icon: Icons.flash_on,
            label: '极速',
            value: record.maxSpeed.toStringAsFixed(0),
            unit: 'km/h',
            color: AppTheme.accentOrange,
          ),
          _StatDivider(),
          _StatCell(
            icon: Icons.speed,
            label: '均速',
            value: record.avgSpeed.toStringAsFixed(0),
            unit: 'km/h',
            color: AppTheme.accentCyan,
          ),
        ],
      ),
    );
  }
}

/// 起/终点图钉
class _TrackPin extends StatelessWidget {
  final Color color;
  final String label;

  const _TrackPin({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.9),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.5),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Center(
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 9,
            fontWeight: FontWeight.bold,
            height: 1,
          ),
        ),
      ),
    );
  }
}

/// 统计单项（竖列）
class _StatCell extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final Color color;

  const _StatCell({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color.withOpacity(0.7), size: 13),
              const SizedBox(width: 3),
              Text(
                label,
                style: const TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 9,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 1),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    height: 1.1,
                  ),
                ),
                if (unit.isNotEmpty)
                  TextSpan(
                    text: ' $unit',
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 9,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      color: AppTheme.primary10,
    );
  }
}

/// 事件详情行
class _EventDetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _EventDetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

/// 轨迹点数量 Badge
class _WaypointBadge extends StatelessWidget {
  final int count;
  final double zoom;

  const _WaypointBadge({required this.count, required this.zoom});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surface.withOpacity(0.8),
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        border: Border.all(color: AppTheme.primary10),
      ),
      child: Text(
        '$count pts · zoom ${zoom.toStringAsFixed(1)}',
        style: const TextStyle(
          color: AppTheme.textMuted,
          fontSize: 9,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

/// 有效事件 + 对应地图位置 + 渲染属性（与三套 CircleMarker 缓存一一对应）
class _MappedEvent {
  final RidingRecordEvent event;
  final LatLng point;
  final Color color;
  final IconData icon;

  const _MappedEvent({
    required this.event,
    required this.point,
    required this.color,
    required this.icon,
  });
}
