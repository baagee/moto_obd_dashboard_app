import 'dart:async';
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

class _RidingTrackScreenState extends State<RidingTrackScreen> {
  final MapController _mapController = MapController();

  // 所有轨迹点（加载后缓存）
  List<RidingWaypoint> _allWaypoints = [];

  // GCJ-02 坐标缓存（加载时一次性转换）
  List<LatLng> _cachedGcjPoints = [];

  // 骑行事件
  List<RidingRecordEvent> _events = [];

  // 当前缩放级别（用于抽稀）
  double _currentZoom = 14.0;

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

      // 一次性转换 WGS-84 → GCJ-02，结果缓存
      final gcjPoints = waypoints.map((w) {
        final coords = GeocodingService.wgs84ToGcj02(w.latitude, w.longitude);
        return LatLng(coords[0], coords[1]);
      }).toList();

      setState(() {
        _allWaypoints = waypoints;
        _cachedGcjPoints = gcjPoints;
        _events = events;
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

  /// 根据缩放级别抽稀轨迹点（返回索引列表）
  List<int> _sampleIndices(double zoom) {
    final total = _allWaypoints.length;
    if (total == 0) return [];

    int step;
    if (zoom < 10) {
      step = 20;
    } else if (zoom < 13) {
      step = 5;
    } else if (zoom < 15) {
      step = 2;
    } else {
      step = 1;
    }

    final indices = <int>[];
    for (int i = 0; i < total; i += step) {
      indices.add(i);
    }
    if (indices.isEmpty || indices.last != total - 1) {
      indices.add(total - 1);
    }
    return indices;
  }

  /// 速度映射颜色（绿 → 橙 → 红 三段渐变）
  Color _speedToColor(double speed) {
    if (speed <= 40) {
      return const Color(0xFF00FF85);
    } else if (speed <= 80) {
      final t = (speed - 40) / 40;
      return Color.lerp(const Color(0xFF00FF85), const Color(0xFFFF8C00), t)!;
    } else {
      final t = ((speed - 80) / 40).clamp(0.0, 1.0);
      return Color.lerp(const Color(0xFFFF8C00), const Color(0xFFFF3B50), t)!;
    }
  }

  /// 生成速度渐变 Polyline 列表（使用缓存的 GCJ-02 坐标）
  List<Polyline> _buildGradientPolylines(double zoom) {
    final sampledIdx = _sampleIndices(zoom);
    if (sampledIdx.length < 2) return [];

    final polylines = <Polyline>[];
    for (int i = 0; i < sampledIdx.length - 1; i++) {
      final i1 = sampledIdx[i];
      final i2 = sampledIdx[i + 1];
      final avgSpeed = (_allWaypoints[i1].speed + _allWaypoints[i2].speed) / 2;
      polylines.add(Polyline(
        points: [_cachedGcjPoints[i1], _cachedGcjPoints[i2]],
        color: _speedToColor(avgSpeed),
        strokeWidth: 4.0,
      ));
    }
    return polylines;
  }

  /// 找到与事件时间戳最近的轨迹点坐标（找不到或偏差 >30s 返回 null）
  LatLng? _findNearestWaypointPosition(int eventTs) {
    if (_allWaypoints.isEmpty) return null;

    int minDiff = (_allWaypoints.first.timestamp - eventTs).abs();
    int minIdx = 0;

    for (int i = 1; i < _allWaypoints.length; i++) {
      final diff = (_allWaypoints[i].timestamp - eventTs).abs();
      if (diff < minDiff) {
        minDiff = diff;
        minIdx = i;
      }
    }

    if (minDiff > 30000) return null;
    if (minIdx >= _cachedGcjPoints.length) return null;
    return _cachedGcjPoints[minIdx];
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
              child: _WaypointBadge(
                count: _allWaypoints.length,
                zoom: _currentZoom,
              ),
            ),
        ],
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

    // 构建事件 Marker 列表（无法定位时静默忽略）
    final eventMarkers = <Marker>[];
    for (final event in _events) {
      final pos = _findNearestWaypointPosition(event.timestamp);
      if (pos == null) continue;
      final color = RidingEventItem.colorFromType(event.type);
      final icon = RidingEventItem.iconFromType(event.type);
      eventMarkers.add(Marker(
        point: pos,
        width: 32,
        height: 32,
        child: GestureDetector(
          onTap: () => _showEventDetail(context, event),
          child: Container(
            decoration: BoxDecoration(
              color: color.withOpacity(0.9),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.5),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 15),
          ),
        ),
      ));
    }

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _cachedGcjPoints.first,
        initialZoom: _currentZoom,
        onPositionChanged: (camera, _) {
          _debounceTimer?.cancel();
          _debounceTimer = Timer(const Duration(milliseconds: 300), () {
            if (mounted && camera.zoom != _currentZoom) {
              setState(() => _currentZoom = camera.zoom);
            }
          });
        },
      ),
      children: [
        // 高德标准路网瓦片 + ColorFiltered 暗色处理（公开API无原生夜间模式）
        ColorFiltered(
          colorFilter: const ColorFilter.matrix([
            // 反色 + 降饱和 + 色调偏蓝灰，模拟暗色地图
            -0.6, 0, 0, 0, 180,
            0, -0.6, 0, 0, 180,
            0, 0, -0.6, 0, 200,
            0, 0, 0, 1, 0,
          ]),
          child: TileLayer(
            urlTemplate:
                'https://webrd01.is.autonavi.com/appmaptile?lang=zh_cn&size=1&scale=1&style=8&x={x}&y={y}&z={z}',
            userAgentPackageName: 'com.example.obd_dashboard',
            subdomains: const ['webrd01', 'webrd02', 'webrd03', 'webrd04'],
            tileProvider: NetworkTileProvider(),
          ),
        ),
        // 速度渐变轨迹折线
        PolylineLayer(
          polylines: _buildGradientPolylines(_currentZoom),
        ),
        // 骑行事件 Marker
        MarkerLayer(markers: eventMarkers),
        // 起点 Marker
        MarkerLayer(
          markers: [
            Marker(
              point: _cachedGcjPoints.first,
              width: 20,
              height: 20,
              child: _TrackPin(
                  color: const Color(0xFF00E676), icon: Icons.play_arrow),
            ),
          ],
        ),
        // 终点 Marker
        MarkerLayer(
          markers: [
            Marker(
              point: _cachedGcjPoints.last,
              width: 20,
              height: 20,
              child:
                  _TrackPin(color: const Color(0xFFFF4D4D), icon: Icons.stop),
            ),
          ],
        ),
        // 游标位置圆点（拖动速度曲线图时联动）
        if (_cursorIndex != null && _cursorIndex! < _cachedGcjPoints.length)
          MarkerLayer(
            markers: [
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
                  'TRACK REPLAY',
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
        // 只有左侧两个圆角，右侧贴边
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(AppTheme.radiusCard),
          bottomLeft: Radius.circular(AppTheme.radiusCard),
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
  final IconData icon;

  const _TrackPin({required this.color, required this.icon});

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
      child: Icon(icon, color: Colors.white, size: 10),
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
