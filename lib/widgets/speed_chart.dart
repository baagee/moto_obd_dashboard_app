import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../models/riding_record.dart';
import '../theme/app_theme.dart';

/// 速度曲线图组件
/// - X轴：时间（距骑行开始的秒数）
/// - Y轴：速度（km/h）
/// - 支持拖动游标，抬手后游标保留直到下次拖动
class SpeedChart extends StatefulWidget {
  final List<RidingWaypoint> waypoints;
  final List<RidingRecordEvent> events;

  /// 骑行记录中的极速字段（与右侧统计卡保持一致）
  final double recordMaxSpeed;

  /// 当前游标指向的 waypoint 索引（由父层控制）
  final int? cursorIndex;

  /// 拖动时回调新的 waypoint 索引
  final ValueChanged<int> onCursorChanged;

  const SpeedChart({
    super.key,
    required this.waypoints,
    required this.events,
    this.recordMaxSpeed = 0,
    this.cursorIndex,
    required this.onCursorChanged,
  });

  @override
  State<SpeedChart> createState() => _SpeedChartState();
}

class _SpeedChartState extends State<SpeedChart> {
  // 最多渲染 600 个点，等间隔抽稀
  static const int _maxPoints = 600;

  // 抽稀后的索引 → 原始 waypoints 索引
  late List<int> _sampledIndices;
  // 抽稀后的 FlSpot 列表
  late List<FlSpot> _spots;
  // 最大速度（用于 Y 轴上边界）
  late double _maxSpeed;
  // 总时长（秒）
  late double _totalSeconds;
  // 缓存的 bars（数据不变时直接复用，避免游标拖动每帧重建）
  List<LineChartBarData>? _cachedBars;

  @override
  void initState() {
    super.initState();
    _buildChartData();
  }

  @override
  void didUpdateWidget(SpeedChart old) {
    super.didUpdateWidget(old);
    if (old.waypoints != widget.waypoints ||
        old.recordMaxSpeed != widget.recordMaxSpeed) {
      _buildChartData();
    }
  }

  void _buildChartData() {
    final wps = widget.waypoints;
    if (wps.isEmpty) {
      _sampledIndices = [];
      _spots = [];
      _maxSpeed = 100;
      _totalSeconds = 1;
      return;
    }

    final total = wps.length;

    // ── 1. 锁定必须保留的关键点 ──
    final keySet = <int>{0, total - 1};

    // 极速点
    int maxSpeedIdx = 0;
    for (int i = 1; i < total; i++) {
      if (wps[i].speed > wps[maxSpeedIdx].speed) maxSpeedIdx = i;
    }
    keySet.add(maxSpeedIdx);

    // 每个事件最近的 waypoint（30s 内才纳入）
    // 使用二分查找 O(logN)，替代原来的 O(N) 线性搜索
    for (final event in widget.events) {
      int lo = 0, hi = total - 1;
      while (lo < hi) {
        final mid = (lo + hi) >> 1;
        if (wps[mid].timestamp < event.timestamp) {
          lo = mid + 1;
        } else {
          hi = mid;
        }
      }
      // 检查 lo-1 是否更近
      int minIdx = lo;
      if (lo > 0) {
        final d1 = (wps[lo].timestamp - event.timestamp).abs();
        final d0 = (wps[lo - 1].timestamp - event.timestamp).abs();
        if (d0 < d1) minIdx = lo - 1;
      }
      final minDiff = (wps[minIdx].timestamp - event.timestamp).abs();
      if (minDiff < 30000) keySet.add(minIdx);
    }

    // ── 2. 剩余配额等间隔填充 ──
    final quota = _maxPoints - keySet.length;
    if (quota > 0 && total > keySet.length) {
      final step = (total / quota).ceil().clamp(1, total);
      for (int i = 0; i < total; i += step) {
        keySet.add(i);
      }
    }

    // ── 3. 排序、生成 FlSpot ──
    final indices = keySet.toList()..sort();

    final t0 = wps.first.timestamp;
    final spots = indices.map((i) {
      final x = (wps[i].timestamp - t0) / 1000.0; // ms → s
      final y = wps[i].speed;
      return FlSpot(x, y);
    }).toList();

    double maxS = 0;
    for (final s in spots) {
      if (s.y > maxS) maxS = s.y;
    }

    // Y 轴上限取 waypoints 实测最大速度与 record.maxSpeed 的较大值再留 10% 余量
    final effectiveMax = math.max(maxS, widget.recordMaxSpeed);
    _sampledIndices = indices;
    _spots = spots;
    _maxSpeed = effectiveMax < 10 ? 100 : effectiveMax * 1.1;
    _totalSeconds = spots.last.x;
    // 数据变化时清空 bars 缓存
    _cachedBars = null;
  }

  /// 将图表内 localDx 换算为最近的 waypoint 索引
  int _dxToWaypointIndex(double localDx, double chartWidth) {
    if (_spots.isEmpty || chartWidth <= 0) return 0;
    // localDx 对应的时间比例
    const leftPad = 28.0; // 与 titlesData left padding 对应
    const rightPad = 8.0;
    final plotWidth = chartWidth - leftPad - rightPad;
    final ratio = ((localDx - leftPad) / plotWidth).clamp(0.0, 1.0);
    final targetSec = ratio * _totalSeconds;

    // 在 _spots 里找最近的 x
    int nearest = 0;
    double minDiff = (_spots[0].x - targetSec).abs();
    for (int i = 1; i < _spots.length; i++) {
      final diff = (_spots[i].x - targetSec).abs();
      if (diff < minDiff) {
        minDiff = diff;
        nearest = i;
      }
    }
    return _sampledIndices[nearest];
  }

  /// 将 waypoint 原始索引反查为图表内游标的 x 比例（0~1）
  double? _waypointIndexToCursorRatio(int? idx) {
    if (idx == null || _spots.isEmpty || _totalSeconds <= 0) return null;
    final wps = widget.waypoints;
    if (idx >= wps.length) return null;
    final t0 = wps.first.timestamp;
    final sec = (wps[idx].timestamp - t0) / 1000.0;
    return (sec / _totalSeconds).clamp(0.0, 1.0);
  }

  /// 速度 → 图表曲线颜色（霓虹风格：青 → 品红 → 粉红）
  Color _speedColor(double speed) {
    if (speed <= 40) return const Color(0xFF00F5FF); // 霓虹青
    if (speed <= 80) {
      final t = (speed - 40) / 40;
      return Color.lerp(
          const Color(0xFF00F5FF), const Color(0xFFFF00FF), t)!; // 青→品红
    }
    final t = ((speed - 80) / 40).clamp(0.0, 1.0);
    return Color.lerp(
        const Color(0xFFFF00FF), const Color(0xFFFF2D87), t)!; // 品红→粉红
  }

  /// 按速度分段生成多条 LineChartBarData，每段颜色对应该段平均速度
  List<LineChartBarData> _buildColoredBars() {
    if (_spots.length < 2) return [];
    final bars = <LineChartBarData>[];
    for (int i = 0; i < _spots.length - 1; i++) {
      final avgSpeed = (_sampledIndices[i] < widget.waypoints.length &&
              _sampledIndices[i + 1] < widget.waypoints.length)
          ? (widget.waypoints[_sampledIndices[i]].speed +
                  widget.waypoints[_sampledIndices[i + 1]].speed) /
              2
          : (_spots[i].y + _spots[i + 1].y) / 2;
      final color = _speedColor(avgSpeed);
      bars.add(LineChartBarData(
        spots: [_spots[i], _spots[i + 1]],
        isCurved: false,
        barWidth: 2,
        dotData: const FlDotData(show: false),
        color: color,
        belowBarData: BarAreaData(
          show: true,
          color: color.withOpacity(0.12),
        ),
      ));
    }
    return bars;
  }

  @override
  Widget build(BuildContext context) {
    if (_spots.length < 2) return const SizedBox.shrink();

    final cursorRatio = _waypointIndexToCursorRatio(widget.cursorIndex);

    return LayoutBuilder(builder: (context, constraints) {
      final chartWidth = constraints.maxWidth;
      final chartHeight = constraints.maxHeight;

      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: (d) {
          final idx = _dxToWaypointIndex(d.localPosition.dx, chartWidth);
          widget.onCursorChanged(idx);
        },
        onTapDown: (d) {
          final idx = _dxToWaypointIndex(d.localPosition.dx, chartWidth);
          widget.onCursorChanged(idx);
        },
        child: Stack(
          children: [
            // ── 折线图 ──
            LineChart(
              LineChartData(
                minX: 0,
                maxX: _totalSeconds,
                minY: 0,
                maxY: _maxSpeed,
                clipData: const FlClipData.all(),
                lineTouchData: const LineTouchData(enabled: false),
                backgroundColor: Colors.transparent,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: _maxSpeed / 4,
                  getDrawingHorizontalLine: (_) => const FlLine(
                    color: Color(0x22FFFFFF),
                    strokeWidth: 0.5,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: _maxSpeed / 4,
                      getTitlesWidget: (val, _) => Text(
                        val.toInt().toString(),
                        style: const TextStyle(
                          color: Color(0x88FFFFFF),
                          fontSize: 8,
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 14,
                      interval: _totalSeconds / 4,
                      getTitlesWidget: (val, _) {
                        final mins = (val / 60).floor();
                        final secs = (val % 60).floor();
                        return Text(
                          mins > 0 ? '${mins}m' : '${secs}s',
                          style: const TextStyle(
                            color: Color(0x88FFFFFF),
                            fontSize: 8,
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                lineBarsData: _cachedBars ??= _buildColoredBars(),
                // 事件竖线标记
                extraLinesData: ExtraLinesData(
                  verticalLines: [
                    // 游标竖线
                    if (cursorRatio != null)
                      VerticalLine(
                        x: cursorRatio * _totalSeconds,
                        color: const Color(0xFF00F5FF).withOpacity(0.9),
                        strokeWidth: 1.2,
                        dashArray: [4, 3],
                      ),
                    // 事件时间竖线（半透明黄色细线）
                    ..._buildEventLines(),
                  ],
                ),
              ),
            ),

            // ── 游标顶部小圆点 ──
            if (cursorRatio != null)
              _buildCursorDot(cursorRatio, chartWidth, chartHeight),

            // ── 游标信息气泡 ──
            if (widget.cursorIndex != null &&
                widget.cursorIndex! < widget.waypoints.length)
              _buildCursorBubble(cursorRatio!, chartWidth),
          ],
        ),
      );
    });
  }

  List<VerticalLine> _buildEventLines() {
    if (widget.waypoints.isEmpty) return [];
    final t0 = widget.waypoints.first.timestamp;
    return widget.events.map((e) {
      final sec = (e.timestamp - t0) / 1000.0;
      return VerticalLine(
        x: sec.clamp(0, _totalSeconds),
        color: const Color(0xFFFFE600).withOpacity(0.6),
        strokeWidth: 1,
        dashArray: [2, 4],
      );
    }).toList();
  }

  Widget _buildCursorDot(double ratio, double chartWidth, double chartHeight) {
    const leftPad = 28.0;
    const rightPad = 8.0;
    const bottomPad = 14.0;
    const topPad = 8.0;
    final plotWidth = chartWidth - leftPad - rightPad;
    final dx = leftPad + ratio * plotWidth;

    // 找游标点对应的速度
    final idx = widget.cursorIndex!;
    if (idx >= widget.waypoints.length) return const SizedBox.shrink();
    final speed = widget.waypoints[idx].speed;
    final plotHeight = chartHeight - bottomPad - topPad;
    final yRatio = (speed / _maxSpeed).clamp(0.0, 1.0);
    final dy = topPad + plotHeight * (1 - yRatio);

    return Positioned(
      left: dx - 5,
      top: dy - 5,
      child: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: _speedColor(speed),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF00F5FF), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: _speedColor(speed).withOpacity(0.8),
              blurRadius: 8,
              spreadRadius: 2,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCursorBubble(double ratio, double chartWidth) {
    const leftPad = 28.0;
    const rightPad = 8.0;
    final plotWidth = chartWidth - leftPad - rightPad;
    final dx = leftPad + ratio * plotWidth;

    final idx = widget.cursorIndex!;
    if (idx >= widget.waypoints.length) return const SizedBox.shrink();
    final wp = widget.waypoints[idx];
    final t0 = widget.waypoints.first.timestamp;
    final elapsed = (wp.timestamp - t0) / 1000;
    final mins = (elapsed / 60).floor();
    final secs = (elapsed % 60).floor();
    final timeStr = mins > 0 ? '${mins}m${secs}s' : '${secs}s';

    // 气泡宽 72，靠近右侧时向左偏移
    const bubbleW = 72.0;
    double bubbleLeft = dx - bubbleW / 2;
    if (bubbleLeft < leftPad) bubbleLeft = leftPad;
    if (bubbleLeft + bubbleW > chartWidth - rightPad) {
      bubbleLeft = chartWidth - rightPad - bubbleW;
    }

    return Positioned(
      left: bubbleLeft,
      top: 4,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: AppTheme.backgroundDark.withOpacity(0.88),
          borderRadius: BorderRadius.circular(0),
          border: Border.all(color: AppTheme.primary20.withOpacity(0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${wp.speed.toStringAsFixed(0)} km/h',
              style: TextStyle(
                color: _speedColor(wp.speed),
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              timeStr,
              style: const TextStyle(
                color: AppTheme.textMuted,
                fontSize: 9,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
