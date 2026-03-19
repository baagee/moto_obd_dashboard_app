import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/obd_data_provider.dart';
import '../theme/app_theme.dart';

/// 侧边统计面板（车辆状态综合面板）
class SideStatsPanel extends StatelessWidget {
  const SideStatsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<OBDDataProvider>(
      builder: (context, provider, child) {
        final data = provider.data;

        return Container(
          padding: const EdgeInsets.all(6),
          decoration: AppTheme.surfaceBorder(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题
              const Text('车辆状态', style: AppTheme.labelMediumPrimary),

              const SizedBox(height: 2),

              // 内容区域 - 不滚动
              Expanded(
                child: Column(
                  children: [
                    // 温度区域
                    // Row(
                    //   children: [
                    //     Expanded(
                    //       child: _TempCard(
                    //         icon: Icons.device_thermostat,
                    //         iconColor: AppTheme.accentOrange,
                    //         label: '冷却水温',
                    //         value: '${data.coolantTemp}°C',
                    //       ),
                    //     ),
                    //     const SizedBox(width: 6),
                    //     Expanded(
                    //       child: _TempCard(
                    //         icon: Icons.ac_unit,
                    //         iconColor: AppTheme.accentCyan,
                    //         label: '进气温度',
                    //         value: '${data.intakeTemp}°C',
                    //       ),
                    //     ),
                    //   ],
                    // ),
                    //
                    // const SizedBox(height: 3),

                    // 油门进度条
                    _ProgressBar(
                      icon: Icons.speed,
                      iconColor: AppTheme.accentCyan,
                      label: '油门开度',
                      value: data.throttle,
                      color: AppTheme.accentCyan,
                    ),

                    const SizedBox(height: 3),

                    // 负载进度条
                    _ProgressBar(
                      icon: Icons.settings,
                      iconColor: AppTheme.accentOrange,
                      label: '发动机负载',
                      value: data.load,
                      color: AppTheme.accentOrange,
                    ),

                    const SizedBox(height: 3),

                    // 倾斜角度指示器
                    _LeanAngleIndicator(
                      angle: data.leanAngle,
                      direction: data.leanDirection,
                    ),

                    const SizedBox(height: 3),

                    // 气压趋势图
                    _PressureChart(
                      pressure: data.pressure,
                      pressureHistory: provider.pressureHistory,
                    ),

                    const SizedBox(height: 3),

                    // 电压显示
                    _VoltageDisplay(voltage: data.voltage),
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
        borderRadius: BorderRadius.all(Radius.circular(6)),
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
        borderRadius: BorderRadius.all(Radius.circular(6)),
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
              Text('$value%', style: AppTheme.valueSmall.copyWith(color: color)),
            ],
          ),
          const SizedBox(height: 3),
          Stack(
            children: [
              Container(
                height: 6,
                decoration: const BoxDecoration(
                  color: Color(0xFF1E293B),
                  borderRadius: BorderRadius.all(Radius.circular(3)),
                ),
              ),
              FractionallySizedBox(
                widthFactor: value / 100,
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(3),
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
        borderRadius: BorderRadius.all(Radius.circular(6)),
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
                    style: AppTheme.valueSmall.copyWith(color: AppTheme.primary),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          LayoutBuilder(
            builder: (context, constraints) {
              // 计算指示器位置：50%为中间，最大60度，角度为0时居中
              final leanPercent = angle == 0 ? 50 : 50 + (direction == 'LEFT' ? -angle : angle) * (50 / 60);
              return Stack(
                children: [
                  // 背景条
                  Container(
                    height: 7,
                    decoration: const BoxDecoration(
                      color: Color(0xFF1E293B),
                      borderRadius: BorderRadius.all(Radius.circular(6)),
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
          const SizedBox(height: 3),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('左60°', style: TextStyle(color: AppTheme.textMuted, fontSize: 8)),
              Text('0°', style: TextStyle(color: AppTheme.textMuted, fontSize: 8)),
              Text('右60°', style: TextStyle(color: AppTheme.textMuted, fontSize: 8)),
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
        borderRadius: BorderRadius.all(Radius.circular(6)),
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
          const SizedBox(height: 3),
          SizedBox(
            height: 24,
            child: CustomPaint(
              size: const Size(double.infinity, 24),
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

/// 气压图表绘制器
class PressureChartPainter extends CustomPainter {
  final List<int> pressureHistory;
  final int minPressure;
  final int maxPressure;

  PressureChartPainter({
    required this.pressureHistory,
    required this.minPressure,
    required this.maxPressure,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (pressureHistory.length < 2) return;

    final width = size.width;
    final height = size.height;
    const padding = 2.0;

    // 计算点位置
    final points = <Offset>[];
    final step = width / (pressureHistory.length - 1);

    for (int i = 0; i < pressureHistory.length; i++) {
      final x = i * step;
      final y = height - padding - ((pressureHistory[i] - minPressure) / (maxPressure - minPressure)) * (height - 2 * padding);
      points.add(Offset(x, y));
    }

    // 绘制面积
    final areaPath = Path();
    areaPath.moveTo(points.first.dx, height);
    areaPath.lineTo(points.first.dx, points.first.dy);

    for (int i = 1; i < points.length; i++) {
      areaPath.lineTo(points[i].dx, points[i].dy);
    }

    areaPath.lineTo(points.last.dx, height);
    areaPath.close();

    final areaPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [AppTheme.primary30, Colors.transparent],
      ).createShader(Rect.fromLTWH(0, 0, width, height));

    canvas.drawPath(areaPath, areaPaint);

    // 绘制线条
    final linePath = Path();
    linePath.moveTo(points.first.dx, points.first.dy);

    for (int i = 1; i < points.length; i++) {
      linePath.lineTo(points[i].dx, points[i].dy);
    }

    final linePaint = Paint()
      ..color = AppTheme.primary
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(linePath, linePaint);
  }

  @override
  bool shouldRepaint(covariant PressureChartPainter oldDelegate) {
    if (oldDelegate.pressureHistory.length != pressureHistory.length) return true;
    if (pressureHistory.isEmpty) return false;
    return oldDelegate.pressureHistory.last != pressureHistory.last;
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
        borderRadius: BorderRadius.all(Radius.circular(6)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Row(
            children: [
              Icon(Icons.battery_charging_full, color: AppTheme.accentGreen, size: 14),
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
