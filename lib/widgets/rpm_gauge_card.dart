import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/obd_data_provider.dart';
import '../theme/app_theme.dart';

/// RPM圆形表盘卡片
class RPMGaugeCard extends StatelessWidget {
  const RPMGaugeCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<OBDDataProvider>(
      builder: (context, provider, child) {
        final data = provider.data;

        return Container(
          padding: const EdgeInsets.all(10),
          decoration: AppTheme.surfaceBorder(),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // 根据可用空间计算表盘大小
              final gaugeSize = min(constraints.maxWidth, constraints.maxHeight) * 0.6;

              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // RPM圆形表盘
                  SizedBox(
                    width: gaugeSize,
                    height: gaugeSize,
                    child: CustomPaint(
                      painter: RPMGaugePainter(
                        rpm: data.rpm,
                        maxRpm: 12000,
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'RPM',
                              style: AppTheme.labelTinyPrimary.copyWith(
                                fontSize: gaugeSize * 0.06,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatRPM(data.rpm),
                              style: AppTheme.valueMedium.copyWith(
                                fontSize: gaugeSize * 0.28,
                                letterSpacing: -1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  String _formatRPM(int rpm) {
    if (rpm >= 1000) {
      return '${(rpm / 1000).toStringAsFixed(1)}k';
    }
    return rpm.toString();
  }
}

/// RPM表盘绘制器
class RPMGaugePainter extends CustomPainter {
  final int rpm;
  final int maxRpm;

  RPMGaugePainter({
    required this.rpm,
    required this.maxRpm,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;

    // 背景圆环 - 加粗到10
    final bgPaint = Paint()
      ..color = const Color(0xFF1E293B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    // 进度圆环
    final progress = rpm / maxRpm;
    final sweepAngle = 2 * pi * progress * 0.75; // 最大270度

    final gradient = SweepGradient(
      startAngle: -pi / 2,
      endAngle: -pi / 2 + sweepAngle,
      colors: const [
        AppTheme.primary,
        AppTheme.accentCyan,
      ],
    );

    final progressPaint = Paint()
      ..shader = gradient.createShader(
        Rect.fromCircle(center: center, radius: radius),
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      sweepAngle,
      false,
      progressPaint,
    );

    // 刻度点
    final tickPaint = Paint()
      ..color = AppTheme.primary20
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (int i = 0; i < 60; i++) {
      final angle = (2 * pi * i / 60) - pi / 2;
      final innerRadius = radius - 14;
      final outerRadius = radius - 10;

      final x1 = center.dx + innerRadius * cos(angle);
      final y1 = center.dy + innerRadius * sin(angle);
      final x2 = center.dx + outerRadius * cos(angle);
      final y2 = center.dy + outerRadius * sin(angle);

      canvas.drawLine(
        Offset(x1, y1),
        Offset(x2, y2),
        tickPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant RPMGaugePainter oldDelegate) {
    return oldDelegate.rpm != rpm || oldDelegate.maxRpm != maxRpm;
  }
}