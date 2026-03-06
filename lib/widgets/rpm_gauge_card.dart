import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/obd_data_provider.dart';
import '../theme/app_theme.dart';

/// RPM半圆表盘卡片
class RPMGaugeCard extends StatelessWidget {
  const RPMGaugeCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<OBDDataProvider>(
      builder: (context, provider, child) {
        final data = provider.data;

        return Container(
          padding: const EdgeInsets.all(16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // 占满整个区域
              final width = constraints.maxWidth;
              final height = constraints.maxHeight;

              return SizedBox(
                width: width,
                height: height,
                child: CustomPaint(
                  painter: SemiCircleGaugePainter(
                    value: data.rpm,
                    maxValue: 12000,
                    warnThreshold: 6000,
                    dangerThreshold: 9000,
                    tickInterval: 1000,
                    unit: 'RPM',
                    gaugeWidth: width,
                    gaugeHeight: height,
                  ),
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.only(top: height * 0.18),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _formatRPM(data.rpm),
                            style: AppTheme.valueMedium.copyWith(
                              fontSize: height * 0.28,
                              letterSpacing: -1,
                            ),
                          ),
                          Text(
                            'RPM',
                            style: AppTheme.labelTinyPrimary.copyWith(
                              fontSize: height * 0.09,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
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

/// 半圆仪表盘绘制器
class SemiCircleGaugePainter extends CustomPainter {
  final int value;
  final int maxValue;
  final int warnThreshold;
  final int dangerThreshold;
  final int tickInterval;
  final String unit;
  final double gaugeWidth;
  final double gaugeHeight;

  SemiCircleGaugePainter({
    required this.value,
    required this.maxValue,
    required this.warnThreshold,
    required this.dangerThreshold,
    required this.tickInterval,
    required this.unit,
    required this.gaugeWidth,
    required this.gaugeHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 使用传入的尺寸
    final width = gaugeWidth;
    final height = gaugeHeight;

    final center = Offset(width / 2, height);
    final radius = width / 2 - 24;

    // 绘制背景半圆弧
    final bgPaint = Paint()
      ..color = const Color(0xFF1E293B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      pi, // 从左侧开始
      pi, // 180度
      false,
      bgPaint,
    );

    // 绘制刻度背景弧(更细的刻度条)
    _drawTickBackground(canvas, center, radius);

    // 绘制进度弧(带颜色分区)
    _drawProgressArc(canvas, center, radius);

    // 绘制刻度线和数值
    _drawTicks(canvas, center, radius);
  }

  void _drawTickBackground(Canvas canvas, Offset center, double radius) {
    final tickBgPaint = Paint()
      ..color = const Color(0xFF334155)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // 大刻度
    for (int i = 0; i <= maxValue; i += tickInterval) {
      final angle = pi + (i / maxValue) * pi;
      final innerRadius = radius - 24;
      final outerRadius = radius - 16;

      final x1 = center.dx + innerRadius * cos(angle);
      final y1 = center.dy + innerRadius * sin(angle);
      final x2 = center.dx + outerRadius * cos(angle);
      final y2 = center.dy + outerRadius * sin(angle);

      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), tickBgPaint);
    }

    // 小刻度 (每1000区间5个小刻度，每200一个)
    final smallTickPaint = Paint()
      ..color = const Color(0xFF2D3A4D)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (int i = 0; i <= maxValue; i += 1000) {
      for (int j = 1; j < 5; j++) {
        final tickValue = i + j * 200;
        if (tickValue > maxValue) break;

        final angle = pi + (tickValue / maxValue) * pi;
        final innerRadius = radius - 22;
        final outerRadius = radius - 18;

        final x1 = center.dx + innerRadius * cos(angle);
        final y1 = center.dy + innerRadius * sin(angle);
        final x2 = center.dx + outerRadius * cos(angle);
        final y2 = center.dy + outerRadius * sin(angle);

        canvas.drawLine(Offset(x1, y1), Offset(x2, y2), smallTickPaint);
      }
    }

  }

  void _drawProgressArc(Canvas canvas, Offset center, double radius) {
    final progress = value / maxValue;
    final sweepAngle = pi * progress;

    // 根据当前值计算渐变颜色
    List<Color> gradientColors;
    if (value <= warnThreshold) {
      // 蓝色 -> 青色
      gradientColors = [
        AppTheme.primary,
        Color.lerp(AppTheme.primary, AppTheme.accentCyan, value / warnThreshold)!,
      ];
    } else if (value <= dangerThreshold) {
      // 青色 -> 黄色
      gradientColors = [
        AppTheme.accentCyan,
        Color.lerp(AppTheme.accentCyan, const Color(0xFFFFC107), (value - warnThreshold) / (dangerThreshold - warnThreshold))!,
      ];
    } else {
      // 黄色 -> 红色
      gradientColors = [
        const Color(0xFFFFC107),
        Color.lerp(const Color(0xFFFFC107), const Color(0xFFF44336), (value - dangerThreshold) / (maxValue - dangerThreshold))!,
      ];
    }

    // 绘制渐变进度弧
    final gradient = SweepGradient(
      startAngle: pi,
      endAngle: pi + sweepAngle,
      colors: gradientColors,
    );

    final progressPaint = Paint()
      ..shader = gradient.createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      pi,
      sweepAngle,
      false,
      progressPaint,
    );

    // 发光效果使用渐变的结束颜色
    final glowColor = gradientColors.last;
    final glowPaint = Paint()
      ..color = glowColor.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 24
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      pi,
      sweepAngle,
      false,
      glowPaint,
    );
  }

  void _drawTicks(Canvas canvas, Offset center, double radius) {
    final tickPaint = Paint()
      ..color = AppTheme.primary60
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final textStyle = TextStyle(
      color: AppTheme.textMuted,
      fontSize: gaugeWidth * 0.025,
      fontWeight: FontWeight.w500,
    );

    for (int i = 0; i <= maxValue; i += tickInterval) {
      // 长刻度线
      final angle = pi + (i / maxValue) * pi;
      final innerRadius = radius - 32;
      final outerRadius = radius - 24;

      final x1 = center.dx + innerRadius * cos(angle);
      final y1 = center.dy + innerRadius * sin(angle);
      final x2 = center.dx + outerRadius * cos(angle);
      final y2 = center.dy + outerRadius * sin(angle);

      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), tickPaint);

      // 绘制刻度值
      final textSpan = TextSpan(
        text: i >= 1000 ? '${i ~/ 1000}k' : i.toString(),
        style: textStyle,
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();

      final textRadius = radius - 46;
      final textX = center.dx + textRadius * cos(angle) - textPainter.width / 2;
      final textY = center.dy + textRadius * sin(angle) - textPainter.height / 2;

      textPainter.paint(canvas, Offset(textX, textY));
    }
  }

  @override
  bool shouldRepaint(covariant SemiCircleGaugePainter oldDelegate) {
    return oldDelegate.value != value ||
        oldDelegate.maxValue != maxValue ||
        oldDelegate.warnThreshold != warnThreshold ||
        oldDelegate.dangerThreshold != dangerThreshold ||
        oldDelegate.gaugeWidth != gaugeWidth ||
        oldDelegate.gaugeHeight != gaugeHeight;
  }
}
