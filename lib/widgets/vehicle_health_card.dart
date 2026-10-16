import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/obd_data_provider.dart';
import '../theme/app_fonts.dart';
import '../theme/app_theme.dart';

/// 右上车辆健康卡：三个横向数据块，水温含低频真实采样的微趋势。
/// 没有定时器、阴影或模糊；仅健康数据变化时重建。
class VehicleHealthCard extends StatelessWidget {
  const VehicleHealthCard({super.key});

  static const int _coolantDangerAt = 110;
  static const int _intakeWarmAt = 50;
  static const int _intakeHighAt = 65;
  static const double _voltageLow = 12.0;
  static const double _voltageCharging = 12.5;
  static const double _voltageHigh = 14.8;

  @override
  Widget build(BuildContext context) {
    final coolant =
        context.select<OBDDataProvider, int>((p) => p.data.coolantTemp);
    final intake =
        context.select<OBDDataProvider, int>((p) => p.data.intakeTemp);
    final voltage =
        context.select<OBDDataProvider, double>((p) => p.data.voltage);
    final connected =
        context.select<OBDDataProvider, bool>((p) => p.isDeviceConnected);
    final hasCoolant =
        context.select<OBDDataProvider, bool>((p) => p.hasCoolantTemp);
    final hasIntake =
        context.select<OBDDataProvider, bool>((p) => p.hasIntakeTemp);
    final hasVoltage =
        context.select<OBDDataProvider, bool>((p) => p.hasVoltage);
    final coolantHistory = context.select<OBDDataProvider, List<int>>(
      (p) => p.coolantTempHistory,
    );

    final coolantState = !connected || !hasCoolant
        ? const _HealthValue('--', '', 'NO DATA', AppTheme.textSecondary)
        : _HealthValue(
            '$coolant',
            '°C',
            coolantTemperatureStatus(coolant),
            coolant >= _coolantDangerAt
                ? AppTheme.gaugeDanger
                : coolant >= 100
                    ? AppTheme.gaugeWarn
                    : AppTheme.gaugeNormal,
          );
    final intakeState = !connected || !hasIntake
        ? const _HealthValue('--', '', 'NO DATA', AppTheme.textSecondary)
        : intake < 10
            ? _HealthValue('$intake', '°C', 'COLD', AppTheme.gaugeNormal)
            : intake < _intakeWarmAt
                ? _HealthValue('$intake', '°C', 'NORMAL', AppTheme.gaugeNormal)
                : intake < _intakeHighAt
                    ? _HealthValue('$intake', '°C', 'WARM', AppTheme.gaugeWarn)
                    : _HealthValue('$intake', '°C', 'HIGH', AppTheme.gaugeWarn);
    final voltageState = !connected || !hasVoltage || voltage <= 0
        ? const _HealthValue('--', '', 'NO DATA', AppTheme.textSecondary)
        : voltage < _voltageLow
            ? _HealthValue(
                voltage.toStringAsFixed(1), 'V', 'LOW', AppTheme.gaugeWarn)
            : voltage < _voltageCharging
                ? _HealthValue(voltage.toStringAsFixed(1), 'V', 'STABLE',
                    AppTheme.gaugeNormal)
                : voltage <= _voltageHigh
                    ? _HealthValue(voltage.toStringAsFixed(1), 'V', 'CHARGING',
                        AppTheme.gaugeNormal)
                    : _HealthValue(voltage.toStringAsFixed(1), 'V', 'HIGH',
                        AppTheme.gaugeWarn);
    final overall = !connected || !hasCoolant
        ? const _HealthValue('', '', 'NO DATA', AppTheme.textSecondary)
        : coolant >= _coolantDangerAt
            ? const _HealthValue('', '', 'OVERHEAT', AppTheme.gaugeDanger)
            : coolant >= 100 ||
                    (hasIntake && intake >= _intakeWarmAt) ||
                    (hasVoltage &&
                        voltage > 0 &&
                        (voltage < _voltageLow || voltage > _voltageHigh))
                ? const _HealthValue('', '', 'CHECK', AppTheme.gaugeWarn)
                : coolant < 60
                    ? const _HealthValue('', '', 'COLD', AppTheme.gaugeNormal)
                    : const _HealthValue(
                        '', '', 'NORMAL', AppTheme.gaugeNormal);

    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 350;
        final short = constraints.maxHeight < 100;
        return Container(
          padding: EdgeInsets.all(short ? 5 : 6),
          decoration: AppTheme.surfaceBorder(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: short ? 16 : 18,
                child: Row(
                  children: [
                    const Expanded(
                      child: Text('车辆健康',
                          maxLines: 1, style: AppTheme.dashboardCardTitle),
                    ),
                    Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle, color: overall.color)),
                    const SizedBox(width: 5),
                    Text(overall.status,
                        style: AppTheme.dashboardStatus
                            .copyWith(color: overall.color)),
                  ],
                ),
              ),
              const SizedBox(height: 3),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      flex: narrow ? 9 : 11,
                      child: _CoolantMetric(
                        value: coolantState,
                        history:
                            connected && hasCoolant ? coolantHistory : const [],
                        compact: short,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      flex: narrow ? 5 : 4,
                      child: _CompactMetric(
                          label: '进气温度', value: intakeState, compact: short),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      flex: narrow ? 5 : 4,
                      child: _CompactMetric(
                          label: '模块电压', value: voltageState, compact: short),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HealthValue {
  final String number;
  final String unit;
  final String status;
  final Color color;

  const _HealthValue(this.number, this.unit, this.status, this.color);
}

class _CoolantMetric extends StatelessWidget {
  final _HealthValue value;
  final List<int> history;
  final bool compact;

  const _CoolantMetric(
      {required this.value, required this.history, required this.compact});

  @override
  Widget build(BuildContext context) {
    return _MetricSurface(
      accent: value.color,
      padding: compact ? 4 : 6,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final showChart = constraints.maxHeight >= 48 &&
              constraints.maxWidth >= 110 &&
              history.isNotEmpty;
          final tight = constraints.maxHeight < 68;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('冷却水温',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: compact
                      ? AppTheme.dashboardMetricLabelCompact
                      : AppTheme.dashboardMetricLabel),
              const SizedBox(height: 2),
              Row(
                children: [
                  Expanded(
                      child: _ValueReadout(
                          value: value, fontSize: compact ? 22 : 28)),
                  if (constraints.maxWidth >= 130)
                    Text(value.status,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.dashboardStatus
                            .copyWith(color: value.color)),
                ],
              ),
              if (showChart) ...[
                SizedBox(height: tight ? 1 : 3),
                SizedBox(
                  height: tight ? 10 : 17,
                  child: Row(
                    children: [
                      Expanded(
                          child: RepaintBoundary(
                        child: CustomPaint(
                          painter: CoolantTrendPainter(
                              history: history, color: value.color),
                        ),
                      )),
                      const SizedBox(width: 5),
                      if (!tight)
                        Text('近16次',
                            style: AppTheme.dashboardStatus.copyWith(
                                fontSize: 9, color: AppTheme.textSecondary)),
                    ],
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

class _CompactMetric extends StatelessWidget {
  final String label;
  final _HealthValue value;
  final bool compact;

  const _CompactMetric(
      {required this.label, required this.value, required this.compact});

  @override
  Widget build(BuildContext context) {
    return _MetricSurface(
      accent: value.color,
      padding: compact ? 3 : 5,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.labelMediumPrimary
                  .copyWith(fontSize: compact ? 10 : 11)),
          const SizedBox(height: 2),
          _ValueReadout(value: value, fontSize: compact ? 16 : 20),
          const SizedBox(height: 2),
          Text(value.status,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.dashboardStatus.copyWith(color: value.color)),
        ],
      ),
    );
  }
}

class _MetricSurface extends StatelessWidget {
  final Color accent;
  final double padding;
  final Widget child;

  const _MetricSurface(
      {required this.accent, required this.padding, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(padding),
      decoration: const BoxDecoration(color: AppTheme.backgroundDark30),
      child: Row(
        children: [
          Container(width: 2, color: accent),
          const SizedBox(width: 4),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _ValueReadout extends StatelessWidget {
  final _HealthValue value;
  final double fontSize;

  const _ValueReadout({required this.value, required this.fontSize});

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text.rich(TextSpan(children: [
        TextSpan(
            text: value.number,
            style: AppFonts.monoStyle(
                fontSize: fontSize,
                color: value.unit.isEmpty
                    ? value.color
                    : value.color == AppTheme.gaugeWarn ||
                            value.color == AppTheme.gaugeDanger
                        ? value.color
                        : AppTheme.dashboardValue)),
        if (value.unit.isNotEmpty)
          TextSpan(
              text: value.unit,
              style: AppFonts.monoStyle(
                  fontSize: fontSize * 0.57, color: value.color)),
      ])),
    );
  }
}

/// 最近 16 次冷却液 PID 采样的微趋势，不绘制虚构的时间轴或长期历史。
/// 绘图是静态路径，无模糊；随低频水温样本变化才需要重绘。
class CoolantTrendPainter extends CustomPainter {
  final List<int> history;
  final Color color;

  const CoolantTrendPainter({required this.history, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final centerY = size.height / 2;
    final guide = Paint()
      ..color = AppTheme.primary20
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, centerY), Offset(size.width, centerY), guide);
    if (history.isEmpty) return;

    final low = history.reduce(math.min);
    final high = history.reduce(math.max);
    // 小幅变化保留最小 8°C 视野，避免 1°C 波动被放大成剧烈抖动。
    final span = math.max((high - low).toDouble(), 8.0);
    final midpoint = (low + high) / 2;
    final path = Path();
    for (var i = 0; i < history.length; i++) {
      final x = history.length == 1
          ? size.width
          : size.width * i / (history.length - 1);
      final y = (centerY - (history[i] - midpoint) * (size.height - 3) / span)
          .clamp(1.5, size.height - 1.5);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    final stroke = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    if (history.length > 1) canvas.drawPath(path, stroke);
    final lastY =
        (centerY - (history.last - midpoint) * (size.height - 3) / span)
            .clamp(1.5, size.height - 1.5);
    canvas.drawCircle(
        Offset(size.width - 2, lastY), 2.5, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant CoolantTrendPainter oldDelegate) =>
      oldDelegate.history != history || oldDelegate.color != color;
}

/// 水温在 -40～120°C 范围内的位置，供后续刻度视图复用。
double coolantTemperatureRatio(int temperature) =>
    ((temperature.clamp(-40, 120) + 40) / 160).clamp(0.0, 1.0);

String coolantTemperatureStatus(int temperature) {
  if (temperature < 60) return 'COLD';
  if (temperature < 100) return 'NORMAL';
  if (temperature < 110) return 'WARM';
  return 'OVERHEAT';
}
