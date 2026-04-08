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
    // 各字段独立精确订阅：
    // - throttle/load/voltage 来自 updateRealTimeData（OBD 轮询频率）
    // - leanAngle/leanDirection 来自 updateLeanAngle（传感器 66Hz）
    // - pressure/pressureHistory 来自 updateRealTimeData（OBD 低频）
    // 拆分后 leanAngle 66Hz 更新不再触发 throttle/load/voltage/pressure 等的重建
    final throttle =
        context.select<OBDDataProvider, int>((p) => p.data.throttle);
    final load = context.select<OBDDataProvider, int>((p) => p.data.load);
    final leanAngle =
        context.select<OBDDataProvider, int>((p) => p.data.leanAngle);
    final leanDirection =
        context.select<OBDDataProvider, String>((p) => p.data.leanDirection);
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
                // 油门进度条
                _ProgressBar(
                  icon: Icons.speed,
                  iconColor: AppTheme.accentCyan,
                  label: '油门开度',
                  value: throttle,
                  color: AppTheme.accentCyan,
                ),

                const SizedBox(height: 6),

                // 负载进度条
                _ProgressBar(
                  icon: Icons.settings,
                  iconColor: AppTheme.accentOrange,
                  label: '发动机负载',
                  value: load,
                  color: AppTheme.accentOrange,
                ),

                const SizedBox(height: 6),

                // 倾斜角度指示器
                _LeanAngleIndicator(
                  angle: leanAngle,
                  direction: leanDirection,
                ),

                const SizedBox(height: 6),

                // 气压趋势图：pressureHistory 是 List 引用，select 无法检测内容变化
                // 单独用 Consumer 包裹，仅此处订阅完整 provider
                Consumer<OBDDataProvider>(
                  builder: (context, provider, _) => _PressureChart(
                    pressure: pressure,
                    pressureHistory: provider.pressureHistory,
                  ),
                ),

                const SizedBox(height: 6),

                // 电压显示
                _VoltageDisplay(voltage: voltage),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 温度卡片
class _TempCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _TempCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: const BoxDecoration(
        color: AppTheme.backgroundDark30,
        borderRadius: BorderRadius.all(Radius.circular(AppTheme.radiusSmall)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 14),
              const SizedBox(width: 4),
              Text(label, style: AppTheme.labelMediumPrimary),
            ],
          ),
          const SizedBox(height: 3),
          Text(value, style: AppTheme.valueMedium),
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
        borderRadius: BorderRadius.all(Radius.circular(AppTheme.radiusSmall)),
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
                height: 10,
                decoration: const BoxDecoration(
                  color: AppTheme.slateGray,
                  borderRadius: BorderRadius.all(Radius.circular(3)),
                ),
              ),
              FractionallySizedBox(
                widthFactor: value / 100,
                child: Container(
                  height: 10,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
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

/// 倾斜角度指示器
class _LeanAngleIndicator extends StatelessWidget {
  final int angle;
  final String direction;

  const _LeanAngleIndicator({
    required this.angle,
    required this.direction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: const BoxDecoration(
        color: AppTheme.backgroundDark30,
        borderRadius: BorderRadius.all(Radius.circular(AppTheme.radiusSmall)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.rotate_right, color: AppTheme.primary, size: 14),
              const SizedBox(width: 4),
              const Text('车辆倾角', style: AppTheme.labelMediumPrimary),
              const Spacer(),
              Row(
                children: [
                  Text('$angle°', style: AppTheme.valueSmall),
                  const SizedBox(width: 4),
                  Text(
                    angle == 0 ? '无' : (direction == 'LEFT' ? '左' : '右'),
                    style:
                        AppTheme.valueSmall.copyWith(color: AppTheme.primary),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          LayoutBuilder(
            builder: (context, constraints) {
              // 计算指示器位置：50%为中间，最大60度，角度为0时居中
              final leanPercent = angle == 0
                  ? 50
                  : 50 + (direction == 'LEFT' ? -angle : angle) * (50 / 60);
              return Stack(
                children: [
                  // 背景条
                  Container(
                    height: 12,
                    decoration: const BoxDecoration(
                      color: Color(0xFF1E293B),
                      borderRadius: BorderRadius.all(
                          Radius.circular(AppTheme.radiusSmall)),
                    ),
                  ),
                  // 中心线
                  Positioned(
                    left: constraints.maxWidth / 2 - 0.5,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: 1,
                      color: AppTheme.primary30,
                    ),
                  ),
                  // 指示器
                  Positioned(
                    left: (leanPercent / 100) * constraints.maxWidth - 2,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: 4,
                      decoration: BoxDecoration(
                        color: AppTheme.accentCyan,
                        borderRadius: BorderRadius.circular(2),
                        boxShadow: [
                          BoxShadow(color: AppTheme.accentCyan, blurRadius: 6),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 6),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('左60°',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 8)),
              Text('0°',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 8)),
              Text('右60°',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 8)),
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
        borderRadius: BorderRadius.all(Radius.circular(AppTheme.radiusSmall)),
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
            height: 36,
            child: CustomPaint(
              size: const Size(double.infinity, 36),
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

    // 柱子渐变画笔（从顶部 primary 到底部 primary30）
    final barPaint = Paint();

    for (int i = 0; i < count; i++) {
      final left = i * (barW + _gap);
      final normalized = (data[i] - minPressure) / range;
      final barH = normalized * height;
      final top = height - barH;

      final rect = Rect.fromLTWH(left, top, barW, barH);

      // 最新一根柱子（最右侧）高亮发光
      if (i == count - 1) {
        final glowPaint = Paint()
          ..color = AppTheme.primary.withOpacity(0.45)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);
        canvas.drawRect(rect, glowPaint);
        barPaint.color = AppTheme.primary;
      } else {
        barPaint.shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppTheme.primary, AppTheme.primary30],
        ).createShader(rect);
      }

      canvas.drawRect(rect, barPaint);
      barPaint.shader = null;
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
      padding: const EdgeInsets.all(6),
      decoration: const BoxDecoration(
        color: AppTheme.backgroundDark30,
        borderRadius: BorderRadius.all(Radius.circular(AppTheme.radiusSmall)),
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
            style: AppTheme.valueMedium.copyWith(color: AppTheme.accentGreen),
          ),
        ],
      ),
    );
  }
}
