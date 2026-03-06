import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/obd_data_provider.dart';
import '../theme/app_theme.dart';

/// 组合仪表盘卡片（转速+时速）
class CombinedGaugeCard extends StatelessWidget {
  const CombinedGaugeCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<OBDDataProvider>(
      builder: (context, provider, child) {
        final data = provider.data;

        return Container(
          padding: const EdgeInsets.all(8),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // 占满整个可用空间
              return CustomPaint(
                size: Size(constraints.maxWidth, constraints.maxHeight),
                painter: CombinedGaugePainter(
                  rpm: data.rpm,
                  speed: data.speed,
                  gear: data.gear,
                ),
              );
            },
          ),
        );
      },
    );
  }
}

/// 组合仪表盘绘制器
class CombinedGaugePainter extends CustomPainter {
  final int rpm;
  final int speed;
  final int gear;

  // RPM 参数
  static const int maxRpm = 12000;
  static const int warnRpm = 6000;
  static const int dangerRpm = 9000;

  // Speed 参数
  static const int maxSpeed = 250;
  static const int warnSpeed = 150;
  static const int dangerSpeed = 200;

  CombinedGaugePainter({
    required this.rpm,
    required this.speed,
    required this.gear,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    // 使用宽度和高度中较小的值作为基准
    final radius = (size.width < size.height ? size.width : size.height) / 2 - 30;

    // 绘制背景
    _drawBackground(canvas, center, radius);

    // 绘制刻度背景
    _drawTickBackground(canvas, center, radius);

    // 绘制上半圆 RPM 进度
    _drawRPMProgress(canvas, center, radius);

    // 绘制下半圆 Speed 进度
    _drawSpeedProgress(canvas, center, radius);

    // 绘制刻度线
    _drawTicks(canvas, center, radius);

    // 绘制中心数值
    _drawCenterValues(canvas, center, radius);
  }

  void _drawBackground(Canvas canvas, Offset center, double radius) {
    // 背景渐变
    final gradient = RadialGradient(
      colors: [
        const Color(0xFF0A1114),
        const Color(0xFF1E293B).withValues(alpha: 0.5),
      ],
    );

    final paint = Paint()
      ..shader = gradient.createShader(Rect.fromCircle(center: center, radius: radius + 20));

    canvas.drawCircle(center, radius + 20, paint);
  }

  void _drawTickBackground(Canvas canvas, Offset center, double radius) {
    final paint = Paint()
      ..color = const Color(0xFF1E293B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 27  // 加粗0.5倍 (18 * 1.5)
      ..strokeCap = StrokeCap.round;

    // 上半圆背景
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      pi,
      pi,
      false,
      paint,
    );

    // 下半圆背景
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      0,
      pi,
      false,
      paint,
    );
  }

  void _drawRPMProgress(Canvas canvas, Offset center, double radius) {
    final progress = rpm / maxRpm;
    final sweepAngle = pi * progress;

    // 阶段颜色（去掉渐变）
    Color color;
    if (rpm <= warnRpm) {
      color = const Color(0xFF2196F3); // 蓝色
    } else if (rpm <= dangerRpm) {
      color = const Color(0xFF00BCD4); // 青色
    } else {
      color = const Color(0xFFF44336); // 红色
    }

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 27  // 加粗0.5倍 (18 * 1.5)
      ..strokeCap = StrokeCap.butt;  // 平头样式，避免与对向弧冲突

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      pi,
      -sweepAngle,  // 逆时针，经过上方
      false,
      paint,
    );

    // 发光效果
    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 36  // 加粗0.5倍 (24 * 1.5)
      ..strokeCap = StrokeCap.butt  // 平头样式
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      pi,
      -sweepAngle,  // 逆时针，经过上方
      false,
      glowPaint,
    );
  }

  void _drawSpeedProgress(Canvas canvas, Offset center, double radius) {
    final progress = speed / maxSpeed;
    final sweepAngle = pi * progress;

    // 阶段颜色（去掉渐变）
    Color color;
    if (speed <= warnSpeed) {
      color = const Color(0xFF2196F3); // 蓝色
    } else if (speed <= dangerSpeed) {
      color = const Color(0xFF00BCD4); // 青色
    } else {
      color = const Color(0xFFF44336); // 红色
    }

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 27  // 加粗0.5倍 (18 * 1.5)
      ..strokeCap = StrokeCap.butt;  // 平头样式，避免与对向弧冲突

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      pi,
      sweepAngle,  // 顺时针
      false,
      paint,
    );

    // 发光效果
    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 36  // 加粗0.5倍 (24 * 1.5)
      ..strokeCap = StrokeCap.butt  // 平头样式
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      pi,
      sweepAngle,  // 顺时针
      false,
      glowPaint,
    );
  }

  void _drawTicks(Canvas canvas, Offset center, double radius) {
    final tickPaint = Paint()
      ..color = AppTheme.primary60
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;  // 加粗0.5倍 (2 * 1.5)

    final textStyle = TextStyle(
      color: AppTheme.textMuted,
      fontSize: radius * 0.07,
      fontWeight: FontWeight.w500,
    );

    // 上半圆刻度 (RPM) - 逆时针从π到0，经过上方
    for (int i = 0; i <= maxRpm; i += 2000) {
      if (i == 0) continue; // 跳过0

      // 逆时针：π → 3π/2 → 0
      final angle = pi - (i / maxRpm) * pi;
      final innerRadius = radius - 28;
      final outerRadius = radius - 22;

      final x1 = center.dx + innerRadius * cos(angle);
      final y1 = center.dy + innerRadius * sin(angle);
      final x2 = center.dx + outerRadius * cos(angle);
      final y2 = center.dy + outerRadius * sin(angle);

      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), tickPaint);

      // 刻度值
      final textSpan = TextSpan(
        text: i >= 1000 ? '${i ~/ 1000}k' : i.toString(),
        style: textStyle,
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();

      final textRadius = radius - 42;
      final textX = center.dx + textRadius * cos(angle) - textPainter.width / 2;
      final textY = center.dy + textRadius * sin(angle) - textPainter.height / 2;

      textPainter.paint(canvas, Offset(textX, textY));
    }

    // 细粒度刻度 (RPM) - 每500一个，显示在进度弧内部
    final fineTickPaint = Paint()
      ..color = const Color(0xFF1E2530)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    for (int i = 0; i <= maxRpm; i += 500) {
      if (i == 0 || i % 2000 == 0) continue; // 跳过0和大刻度位置

      final angle = pi - (i / maxRpm) * pi;
      // 显示在进度弧内部（更靠近圆心）
      final innerRadius = radius - 38;
      final outerRadius = radius - 32;

      final x1 = center.dx + innerRadius * cos(angle);
      final y1 = center.dy + innerRadius * sin(angle);
      final x2 = center.dx + outerRadius * cos(angle);
      final y2 = center.dy + outerRadius * sin(angle);

      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), fineTickPaint);
    }

    // 下半圆刻度 (Speed) - 顺时针从π到0，经过下方
    for (int i = 0; i <= maxSpeed; i += 50) {
      if (i == maxSpeed) continue; // 跳过250

      // 顺时针：π → π/2 → 0
      final angle = pi + (i / maxSpeed) * pi;
      final innerRadius = radius - 28;
      final outerRadius = radius - 22;

      final x1 = center.dx + innerRadius * cos(angle);
      final y1 = center.dy + innerRadius * sin(angle);
      final x2 = center.dx + outerRadius * cos(angle);
      final y2 = center.dy + outerRadius * sin(angle);

      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), tickPaint);

      // 刻度值
      final textSpan = TextSpan(
        text: i.toString(),
        style: textStyle,
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();

      final textRadius = radius - 42;
      final textX = center.dx + textRadius * cos(angle) - textPainter.width / 2;
      final textY = center.dy + textRadius * sin(angle) - textPainter.height / 2;

      textPainter.paint(canvas, Offset(textX, textY));
    }

    // 细粒度刻度 (Speed) - 每10一个，显示在进度弧内部
    for (int i = 0; i <= maxSpeed; i += 10) {
      if (i == 0 || i % 50 == 0) continue; // 跳过0和大刻度位置

      final angle = pi + (i / maxSpeed) * pi;
      // 显示在进度弧内部（更靠近圆心）
      final innerRadius = radius - 38;
      final outerRadius = radius - 32;

      final x1 = center.dx + innerRadius * cos(angle);
      final y1 = center.dy + innerRadius * sin(angle);
      final x2 = center.dx + outerRadius * cos(angle);
      final y2 = center.dy + outerRadius * sin(angle);

      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), fineTickPaint);
    }
  }

  void _drawCenterValues(Canvas canvas, Offset center, double radius) {
    final fontSize = radius * 0.3;

    // RPM 在上半圆视觉中心：数值在 center 上方， 单位在数值更上方
    // RPM 值
    final rpmTextSpan = TextSpan(
      // text: rpm >= 1000 ? '${(rpm / 1000).toStringAsFixed(1)}k' : rpm.toString(),
      text: rpm.toString(),
      style: TextStyle(
        color: AppTheme.primary,
        fontSize: fontSize,
        fontWeight: FontWeight.bold,
        letterSpacing: -1,
      ),
    );
    final rpmTextPainter = TextPainter(
      text: rpmTextSpan,
      textDirection: TextDirection.ltr,
    )..layout();
    // RPM 在上半圆内
    rpmTextPainter.paint(
      canvas,
      Offset(center.dx - rpmTextPainter.width / 2, center.dy - radius * 0.45),
    );

    // RPM 单位 (在RPM值更上方)
    final rpmUnitSpan = TextSpan(
      text: 'RPM',
      style: TextStyle(
        color: AppTheme.primary60,
        fontSize: fontSize * 0.33,
        fontWeight: FontWeight.w500,
      ),
    );
    final rpmUnitPainter = TextPainter(
      text: rpmUnitSpan,
      textDirection: TextDirection.ltr,
    )..layout();
    rpmUnitPainter.paint(
      canvas,
      Offset(center.dx - rpmUnitPainter.width / 2, center.dy - radius * 0.55),
    );

    // 分隔线
    final dividerPaint = Paint()
      ..color = AppTheme.primary30
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(center.dx - radius * 0.08, center.dy),
      Offset(center.dx + radius * 0.08, center.dy),
      dividerPaint,
    );

    // Speed 在下半圆视觉中心：数值在 center 下方， 单位在数值更下方
    // Speed 值
    final speedTextSpan = TextSpan(
      text: '$speed',
      style: TextStyle(
        color: AppTheme.accentCyan,
        fontSize: fontSize,
        fontWeight: FontWeight.bold,
        letterSpacing: -1,
      ),
    );
    final speedTextPainter = TextPainter(
      text: speedTextSpan,
      textDirection: TextDirection.ltr,
    )..layout();
    // 下半圆中心，靠近中心点
    speedTextPainter.paint(
      canvas,
      Offset(center.dx - speedTextPainter.width / 2, center.dy + radius * 0.15),
    );

    // Speed 单位 (在Speed值下方)
    final speedUnitSpan = TextSpan(
      text: 'km/h',
      style: TextStyle(
        color: AppTheme.accentCyan.withValues(alpha: 0.7),
        fontSize: fontSize * 0.33,
        fontWeight: FontWeight.w500,
      ),
    );
    final speedUnitPainter = TextPainter(
      text: speedUnitSpan,
      textDirection: TextDirection.ltr,
    )..layout();
    speedUnitPainter.paint(
      canvas,
      Offset(center.dx - speedUnitPainter.width / 2, center.dy + radius * 0.45),
    );

    // 档位显示在左下角 - 靠近车辆状态模块和屏幕底部
    // 绘制卡片背景
    final cardWidth = radius * 0.45;
    final cardHeight = radius * 0.4;
    // 往左往下移，靠近左边缘和底部，但留边距
    final cardLeft = center.dx - radius - radius * 0.35;
    final cardTop = center.dy + radius - radius * 0.15;
    final cardRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(cardLeft, cardTop, cardWidth, cardHeight),
      const Radius.circular(8),
    );

    // 卡片背景
    final cardBgPaint = Paint()
      ..color = const Color(0xFF1E293B)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(cardRect, cardBgPaint);

    // 卡片边框
    final cardBorderPaint = Paint()
      ..color = AppTheme.primary.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRRect(cardRect, cardBorderPaint);

    // 档位标签
    final gearLabelSpan = TextSpan(
      text: 'N',
      style: TextStyle(
        color: AppTheme.primary60,
        fontSize: radius * 0.07,
        fontWeight: FontWeight.w500,
      ),
    );
    final gearLabelPainter = TextPainter(
      text: gearLabelSpan,
      textDirection: TextDirection.ltr,
    )..layout();
    gearLabelPainter.paint(
      canvas,
      Offset(
        cardLeft + (cardWidth - gearLabelPainter.width) / 2,
        cardTop + cardHeight * 0.1,
      ),
    );

    // 档位数值
    final gearValueSpan = TextSpan(
      text: gear > 0 ? gear.toString() : 'N',
      style: TextStyle(
        color: AppTheme.primary,
        fontSize: radius * 0.2,
        fontWeight: FontWeight.bold,
      ),
    );
    final gearValuePainter = TextPainter(
      text: gearValueSpan,
      textDirection: TextDirection.ltr,
    )..layout();
    gearValuePainter.paint(
      canvas,
      Offset(
        cardLeft + (cardWidth - gearValuePainter.width) / 2,
        cardTop + cardHeight * 0.35,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant CombinedGaugePainter oldDelegate) {
    return oldDelegate.rpm != rpm ||
        oldDelegate.speed != speed ||
        oldDelegate.gear != gear;
  }
}
