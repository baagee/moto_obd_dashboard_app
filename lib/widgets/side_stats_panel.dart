import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/obd_data_provider.dart';
import '../theme/app_fonts.dart';
import '../theme/app_theme.dart';

/// 左侧车辆状态：三块纵向仪表，与右上车辆健康卡共用暗底与实色边线语言。
class SideStatsPanel extends StatelessWidget {
  const SideStatsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: AppTheme.surfaceBorder(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxHeight < 300;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(
                height: 18,
                child: Text('车辆状态', style: AppTheme.dashboardCardTitle),
              ),
              const SizedBox(height: 6),
              Expanded(flex: 2, child: _ThrottleMetric(compact: compact)),
              const SizedBox(height: 6),
              Expanded(flex: 2, child: _EngineLoadMetric(compact: compact)),
              const SizedBox(height: 6),
              Expanded(flex: 3, child: _PressureMetric(compact: compact)),
            ],
          );
        },
      ),
    );
  }
}

class _ThrottleMetric extends StatelessWidget {
  final bool compact;
  const _ThrottleMetric({required this.compact});

  @override
  Widget build(BuildContext context) {
    final value = context.select<OBDDataProvider, int>((p) => p.data.throttle);
    return _PercentMetric(
      label: '油门开度',
      value: value,
      color: AppTheme.gaugeNormal,
      compact: compact,
    );
  }
}

class _EngineLoadMetric extends StatelessWidget {
  final bool compact;
  const _EngineLoadMetric({required this.compact});

  @override
  Widget build(BuildContext context) {
    final value = context.select<OBDDataProvider, int>((p) => p.data.load);
    return _PercentMetric(
      label: '发动机负载',
      value: value,
      color: value >= 70 ? AppTheme.gaugeWarn : AppTheme.gaugeNormal,
      compact: compact,
    );
  }
}

class _PercentMetric extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final bool compact;

  const _PercentMetric({
    required this.label,
    required this.value,
    required this.color,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final display = value.clamp(0, 100);
    return _MetricSurface(
      color: color,
      compact: compact,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final showBar = constraints.maxHeight >= 46;
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: compact
                      ? AppTheme.dashboardMetricLabelCompact
                      : AppTheme.dashboardMetricLabel),
              const SizedBox(height: 2),
              FittedBox(
                alignment: Alignment.centerLeft,
                fit: BoxFit.scaleDown,
                child: Text.rich(TextSpan(children: [
                  TextSpan(
                      text: '$display',
                      style: AppFonts.monoStyle(
                          fontSize: compact ? 19 : 24,
                          color: AppTheme.dashboardValue)),
                  TextSpan(
                      text: '%',
                      style: AppFonts.monoStyle(
                          fontSize: compact ? 11 : 14, color: color)),
                ])),
              ),
              if (showBar) ...[
                SizedBox(height: compact ? 2 : 5),
                Container(
                  height: compact ? 6 : 8,
                  color: AppTheme.slateGray,
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: display / 100,
                    child: Container(
                      decoration: BoxDecoration(
                        // 无离屏模糊：沿用原卡高亮渐变，统一为轻量细数据条。
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color.lerp(color, AppTheme.dashboardValue, 0.35)!,
                            color
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// 压力模块仅监听 010B 历史版本，不因 RPM / 车速每帧刷新柱图。
class _PressureMetric extends StatelessWidget {
  final bool compact;
  const _PressureMetric({required this.compact});

  @override
  Widget build(BuildContext context) {
    context.select<OBDDataProvider, int>((p) => p.pressureHistoryVersion);
    final provider = context.read<OBDDataProvider>();
    final pressure = provider.data.pressure;
    final history = provider.pressureHistory;
    return _MetricSurface(
      color: AppTheme.gaugeNormal,
      compact: compact,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final showChart = constraints.maxHeight >= 55;
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('进气歧管压力',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: compact
                      ? AppTheme.dashboardMetricLabelCompact
                      : AppTheme.dashboardMetricLabel),
              const SizedBox(height: 2),
              FittedBox(
                alignment: Alignment.centerLeft,
                fit: BoxFit.scaleDown,
                child: Text.rich(TextSpan(children: [
                  TextSpan(
                      text: '$pressure',
                      style: AppFonts.monoStyle(
                          fontSize: compact ? 19 : 24,
                          color: AppTheme.dashboardValue)),
                  TextSpan(
                      text: ' kPa',
                      style: AppFonts.monoStyle(
                          fontSize: compact ? 10 : 12,
                          color: AppTheme.gaugeNormal)),
                ])),
              ),
              if (showChart) ...[
                const SizedBox(height: 4),
                Expanded(
                  child: RepaintBoundary(
                    child: CustomPaint(
                      size: Size.infinite,
                      painter: PressureChartPainter(
                        pressureHistory: history,
                        minPressure: 0,
                        maxPressure: 150,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _MetricSurface extends StatelessWidget {
  final Color color;
  final bool compact;
  final Widget child;
  const _MetricSurface(
      {required this.color, required this.compact, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(compact ? 5 : 7),
      decoration: const BoxDecoration(color: AppTheme.backgroundDark30),
      child: Row(
        children: [
          Container(width: 2, color: color),
          const SizedBox(width: 6),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// 压力柱图：最近 30 次 010B 响应，无模糊，末段亮度强调。
class PressureChartPainter extends CustomPainter {
  final List<int> pressureHistory;
  final int minPressure;
  final int maxPressure;

  static const int _maxBars = 30;
  static const double _gap = 1.5;

  PressureChartPainter({
    required this.pressureHistory,
    required this.minPressure,
    required this.maxPressure,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (pressureHistory.isEmpty || size.isEmpty) return;
    final start = math.max(0, pressureHistory.length - _maxBars);
    final data = pressureHistory.sublist(start);
    final totalGap = _gap * (data.length - 1);
    final barW = math.max(0.0, (size.width - totalGap) / data.length);
    if (barW == 0) return;
    final range = (maxPressure - minPressure).toDouble();
    if (range <= 0) return;

    final baselinePaint = Paint()
      ..color = AppTheme.primary30
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
        Offset(0, size.height), Offset(size.width, size.height), baselinePaint);

    final shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [AppTheme.primary, AppTheme.primary30],
    ).createShader(Rect.fromLTWH(0, 0, 1, size.height));
    final barPaint = Paint()..shader = shader;
    final lastBarPaint = Paint()..color = AppTheme.gaugeNormal;
    for (var i = 0; i < data.length; i++) {
      final normalized = ((data[i] - minPressure) / range).clamp(0.0, 1.0);
      final barH = normalized * size.height;
      final rect =
          Rect.fromLTWH(i * (barW + _gap), size.height - barH, barW, barH);
      canvas.drawRect(rect, i == data.length - 1 ? lastBarPaint : barPaint);
      if (i == data.length - 1 && barH > 1.5) {
        canvas.drawRect(Rect.fromLTWH(rect.left, rect.top, rect.width, 1.5),
            Paint()..color = AppTheme.dashboardValue);
      }
    }
  }

  @override
  bool shouldRepaint(covariant PressureChartPainter oldDelegate) =>
      oldDelegate.pressureHistory != pressureHistory ||
      oldDelegate.minPressure != minPressure ||
      oldDelegate.maxPressure != maxPressure;
}
