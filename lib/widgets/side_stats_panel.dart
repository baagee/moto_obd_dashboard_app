import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/theme_colors.dart';
import '../providers/obd_data_provider.dart';
import '../providers/theme_provider.dart';

/// 侧边统计面板（车辆状态综合面板）
class SideStatsPanel extends StatelessWidget {
  const SideStatsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final colors = themeProvider.currentColors;

        return Consumer<OBDDataProvider>(
          builder: (context, provider, child) {
            final data = provider.data;

            return Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: colors.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 标题
                  Text(
                    '车辆状态',
                    style: TextStyle(
                      color: colors.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  const SizedBox(height: 2),

                  // 内容区域 - 不滚动
                  Expanded(
                    child: Column(
                      children: [
                        // 温度区域
                        Row(
                          children: [
                            Expanded(
                              child: _TempCard(
                                icon: Icons.device_thermostat,
                                iconColor: colors.accentOrange,
                                label: '冷却水温',
                                value: '${data.coolantTemp}°C',
                                colors: colors,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: _TempCard(
                                icon: Icons.ac_unit,
                                iconColor: colors.accentCyan,
                                label: '进气温度',
                                value: '${data.intakeTemp}°C',
                                colors: colors,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 3),

                        // 油门进度条
                        _ProgressBar(
                          label: '油门开度',
                          value: data.throttle,
                          color: colors.accentCyan,
                          colors: colors,
                        ),

                        const SizedBox(height: 3),

                        // 负载进度条
                        _ProgressBar(
                          label: '发动机负载',
                          value: data.load,
                          color: colors.accentOrange,
                          colors: colors,
                        ),

                        const SizedBox(height: 3),

                        // 倾斜角度指示器
                        _LeanAngleIndicator(
                          angle: data.leanAngle,
                          direction: data.leanDirection,
                          colors: colors,
                        ),

                        const SizedBox(height: 3),

                        // 气压趋势图
                        _PressureChart(
                          pressure: data.pressure,
                          pressureHistory: provider.pressureHistory,
                          colors: colors,
                        ),

                        const SizedBox(height: 3),

                        // 电压显示
                        _VoltageDisplay(voltage: data.voltage, colors: colors),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
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
  final ThemeColors colors;

  const _TempCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: colors.backgroundDark.withValues(alpha: 0.3),
        borderRadius: const BorderRadius.all(Radius.circular(6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 14),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

/// 进度条
class _ProgressBar extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final ThemeColors colors;

  const _ProgressBar({
    required this.label,
    required this.value,
    required this.color,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: colors.backgroundDark.withValues(alpha: 0.3),
        borderRadius: const BorderRadius.all(Radius.circular(6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 12,
                ),
              ),
              Text(
                '$value%',
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Stack(
            children: [
              Container(
                height: 6,
                decoration: BoxDecoration(
                  color: colors.surface,
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
  final ThemeColors colors;

  const _LeanAngleIndicator({
    required this.angle,
    required this.direction,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.backgroundDark.withValues(alpha: 0.3),
        borderRadius: const BorderRadius.all(Radius.circular(6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '车辆倾角',
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 12,
                ),
              ),
              Row(
                children: [
                  Text(
                    '$angle°',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    direction == 'LEFT' ? '左' : '右',
                    style: TextStyle(
                      color: colors.primary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          LayoutBuilder(
            builder: (context, constraints) {
              // 计算指示器位置：50%为中间，最大60度
              final leanPercent = 50 + (direction == 'LEFT' ? -angle : angle) * (50 / 60);
              return Stack(
                children: [
                  // 背景条
                  Container(
                    height: 7,
                    decoration: BoxDecoration(
                      color: colors.surface,
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
                      color: colors.primary.withValues(alpha: 0.3),
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
                        color: colors.accentCyan,
                        borderRadius: BorderRadius.circular(2),
                        boxShadow: [
                          BoxShadow(color: colors.accentCyan, blurRadius: 6),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 3),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '左60°',
                style: TextStyle(color: colors.textMuted, fontSize: 8),
              ),
              Text(
                '0°',
                style: TextStyle(color: colors.textMuted, fontSize: 8),
              ),
              Text(
                '右60°',
                style: TextStyle(color: colors.textMuted, fontSize: 8),
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
  final ThemeColors colors;

  const _PressureChart({
    required this.pressure,
    required this.pressureHistory,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: colors.backgroundDark.withValues(alpha: 0.3),
        borderRadius: const BorderRadius.all(Radius.circular(6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '进气歧管压力',
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 12,
                ),
              ),
              Text(
                '$pressure kPa',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 12,
                ),
              ),
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
                colors: colors,
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
  final ThemeColors colors;

  PressureChartPainter({
    required this.pressureHistory,
    required this.minPressure,
    required this.maxPressure,
    required this.colors,
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
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          colors.primary.withValues(alpha: 0.3),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, width, height));

    canvas.drawPath(areaPath, areaPaint);

    // 绘制线条
    final linePath = Path();
    linePath.moveTo(points.first.dx, points.first.dy);

    for (int i = 1; i < points.length; i++) {
      linePath.lineTo(points[i].dx, points[i].dy);
    }

    final linePaint = Paint()
      ..color = colors.primary
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
  final ThemeColors colors;

  const _VoltageDisplay({required this.voltage, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: colors.backgroundDark.withValues(alpha: 0.3),
        borderRadius: const BorderRadius.all(Radius.circular(6)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.battery_charging_full, color: colors.accentGreen, size: 14),
              const SizedBox(width: 4),
              Text(
                '控制模块电压',
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          Text(
            '${voltage.toStringAsFixed(1)}V',
            style: TextStyle(
              color: colors.accentGreen,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
