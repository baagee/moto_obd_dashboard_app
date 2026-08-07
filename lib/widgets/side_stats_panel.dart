import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/obd_data_provider.dart';
import '../theme/app_theme.dart';

/// 侧边统计面板（车辆状态综合面板）
class SideStatsPanel extends StatelessWidget {
  const SideStatsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final throttle =
        context.select<OBDDataProvider, int>((p) => p.data.throttle);
    final load = context.select<OBDDataProvider, int>((p) => p.data.load);
    final pressure =
        context.select<OBDDataProvider, int>((p) => p.data.pressure);
    final voltage =
        context.select<OBDDataProvider, double>((p) => p.data.voltage);

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: AppTheme.surfaceBorder(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题（静态，不依赖数据）
          const Text('车辆状态', style: AppTheme.labelMediumPrimary),

          const SizedBox(height: 2),

          // 内容区域
          Expanded(
            child: Column(
              children: [
                _ProgressBar(
                  icon: Icons.speed,
                  iconColor: AppTheme.gaugeNormal,
                  label: '油门开度',
                  value: throttle,
                  color: AppTheme.gaugeNormal,
                ),

                const SizedBox(height: 12),

                _ProgressBar(
                  icon: Icons.settings,
                  iconColor: AppTheme.gaugeWarn,
                  label: '发动机负载',
                  value: load,
                  color: AppTheme.gaugeWarn,
                ),

                const SizedBox(height: 12),

                Consumer<OBDDataProvider>(
                  builder: (context, provider, _) => _PressureChart(
                    pressure: pressure,
                    pressureHistory: provider.pressureHistory,
                  ),
                ),

                const SizedBox(height: 12),

                _VoltageDisplay(voltage: voltage),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 进度条
class _ProgressBar extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final int value;
  final Color color;

  const _ProgressBar({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: const BoxDecoration(
        color: AppTheme.backgroundDark30,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 14),
              const SizedBox(width: 4),
              Text(label, style: AppTheme.labelMediumPrimary),
              const Spacer(),
              Text('$value%',
                  style: AppTheme.valueSmall.copyWith(color: color)),
            ],
          ),
          const SizedBox(height: 6),
          Stack(
            children: [
              Container(
                height: 14,
                decoration: const BoxDecoration(
                  color: AppTheme.slateGray,
                ),
              ),
              FractionallySizedBox(
                widthFactor: value / 100,
                child: Container(
                  height: 14,
                  decoration: BoxDecoration(
                    color: color,
                    boxShadow: [
                      BoxShadow(color: color, blurRadius: 8, spreadRadius: -2),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 气压趋势图
class _PressureChart extends StatelessWidget {
  final int pressure;
  final List<int> pressureHistory;

  const _PressureChart({
    required this.pressure,
    required this.pressureHistory,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: const BoxDecoration(
        color: AppTheme.backgroundDark30,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.compress, color: AppTheme.primary, size: 14),
              const SizedBox(width: 4),
              const Text('进气歧管压力', style: AppTheme.labelMediumPrimary),
              const Spacer(),
              Text('$pressure kPa', style: AppTheme.valueSmall),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 56,
            child: CustomPaint(
              size: Size.infinite,
              painter: PressureChartPainter(
                pressureHistory: pressureHistory,
                minPressure: 0,
                maxPressure: 150,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 气压图表绘制器（柱状图，最近30个点，全直角矩形柱）
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
    if (pressureHistory.isEmpty) return;

    final width = size.width;
    final height = size.height;

    // 取最后 30 个点
    final start = math.max(0, pressureHistory.length - _maxBars);
    final data = pressureHistory.sublist(start);
    final count = data.length;

    // 计算柱宽
    final totalGap = _gap * (count - 1);
    final barW = (width - totalGap) / count;
    final range = (maxPressure - minPressure).toDouble();

    // 底部基线
    final baselinePaint = Paint()
      ..color = AppTheme.primary30
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(0, height), Offset(width, height), baselinePaint);

    // 柱子渐变画笔：共享一个覆盖整个画布高度的 shader，避免逐柱重建
    // 竖向渐变从 Y=0（primary）到 Y=height（primary30），所有普通柱子共用
    final sharedShader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [AppTheme.primary, AppTheme.primary30],
    ).createShader(Rect.fromLTWH(0, 0, 1, height));

    final barPaint = Paint()..shader = sharedShader;
    final lastBarPaint = Paint()..color = AppTheme.primary;
    final glowPaint = Paint()
      ..color = const Color(0x72006EAF) // AppTheme.primary.withOpacity(0.45) 预算
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);

    for (int i = 0; i < count; i++) {
      final left = i * (barW + _gap);
      final normalized = (data[i] - minPressure) / range;
      final barH = normalized * height;
      final top = height - barH;
      final rect = Rect.fromLTWH(left, top, barW, barH);

      // 最新一根柱子（最右侧）高亮发光
      if (i == count - 1) {
        canvas.drawRect(rect, glowPaint);
        canvas.drawRect(rect, lastBarPaint);
      } else {
        canvas.drawRect(rect, barPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant PressureChartPainter oldDelegate) {
    // pressureHistory 是原地修改的同一 List 实例，last 比较无效，直接返回 true
    return true;
  }
}

/// 电压显示
class _VoltageDisplay extends StatelessWidget {
  final double voltage;

  const _VoltageDisplay({required this.voltage});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: const BoxDecoration(
        color: AppTheme.backgroundDark30,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Row(
            children: [
              Icon(Icons.battery_charging_full,
                  color: AppTheme.accentGreen, size: 14),
              SizedBox(width: 4),
              Text('控制模块电压', style: AppTheme.labelMediumPrimary),
            ],
          ),
          Text(
            '${voltage.toStringAsFixed(1)}V',
            style: AppTheme.valueSmall.copyWith(color: AppTheme.accentGreen),
          ),
        ],
      ),
    );
  }
}
