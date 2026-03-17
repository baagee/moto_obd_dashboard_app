import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/obd_data_provider.dart';
import '../theme/app_theme.dart';
import 'mini_temp_gauge.dart';

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
              return Stack(
                children: [
                  CustomPaint(
                    size: Size(constraints.maxWidth, constraints.maxHeight),
                    painter: CombinedGaugePainter(
                      rpm: data.rpm,
                      speed: data.speed,
                      gear: 0, // 获取不到档位，设置为0
                    ),
                  ),
                  // 左下角 - 冷却水温
                  Positioned(
                    left: 0,
                    bottom: 0,
                    child: MiniTempGauge(
                      temperature: data.coolantTemp,
                      minTemp: 0,
                      maxTemp: 120,
                      label: '水温',
                      normalColor: AppTheme.accentCyan,
                      warnColor: AppTheme.accentOrange,
                      dangerColor: AppTheme.accentRed,
                      size: 64,
                      warnThreshold: 100,
                      dangerThreshold: 110,
                    ),
                  ),
                  // 右下角 - 进气温度
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: MiniTempGauge(
                      temperature: data.intakeTemp,
                      minTemp: -20,
                      maxTemp: 60,
                      label: '气温',
                      normalColor: AppTheme.accentGreen,
                      warnColor: AppTheme.accentOrange,
                      dangerColor: AppTheme.accentRed,
                      size: 64,
                      warnThreshold: 45,
                      dangerThreshold: 60,
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
  static const int flashThreshold = 100; // 闪烁阈值

  /// 车速到角度的非线性映射
  /// 0-180km/h 占据前 85% 角度，180-250 占据后 15%
  double _speedToAngle(double speed) {
    const double normalMax = 180;
    const double normalRatio = 0.85;

    if (speed <= normalMax) {
      return (speed / normalMax) * normalRatio * pi;
    } else {
      final extra = (speed - normalMax) / (maxSpeed - normalMax);
      return (normalRatio + extra * (1 - normalRatio)) * pi;
    }
  }

  /// RPM 到角度的非线性映射
  /// 0-8000RPM 占据前 85% 角度，8000-12000 占据后 15%
  double _rpmToAngle(double rpm) {
    const double normalMax = 8000;
    const double normalRatio = 0.85;

    if (rpm <= normalMax) {
      return (rpm / normalMax) * normalRatio * pi;
    } else {
      final extra = (rpm - normalMax) / (maxRpm - normalMax);
      return (normalRatio + extra * (1 - normalRatio)) * pi;
    }
  }

  CombinedGaugePainter({
    required this.rpm,
    required this.speed,
    required this.gear,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    // 使用宽度和高度中较小的值作为基准
    final radius = (size.width < size.height ? size.width : size.height) / 2 - 10;

    // 绘制背景
    _drawBackground(canvas, center, radius);

    // 绘制刻度背景
    _drawTickBackground(canvas, center, radius);

    // 绘制上半圆 RPM 进度
    _drawRPMProgress(canvas, center, radius);

    // 绘制下半圆 Speed 进度
    _drawSpeedProgress(canvas, center, radius);

    // 绘制指针
    _drawRPMPointer(canvas, center, radius);
    _drawSpeedPointer(canvas, center, radius);

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

    // 超速红色闪烁效果
    if (speed > flashThreshold) {
      _drawSpeedWarningGlow(canvas, center, radius);
    }
  }

  /// 绘制超速警告红色闪烁光环
  void _drawSpeedWarningGlow(Canvas canvas, Offset center, double radius) {
    // 计算闪烁透明度 (0.2 - 0.7 之间脉冲)
    final time = DateTime.now().millisecondsSinceEpoch;
    final pulse = 0.2 + 0.5 * ((time ~/ 200) % 2 == 0 ? 1 : 0);

    final glowPaint = Paint()
      // F13326FF
      ..color = const Color(0xFFF12111).withValues(alpha: pulse)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);

    // 绘制全圈红色光环
    canvas.drawCircle(center, radius + 30, glowPaint);
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
    final sweepAngle = _rpmToAngle(rpm.toDouble());

    // 阶段颜色 - 使用 AppTheme 颜色
    Color color;
    if (rpm <= warnRpm) {
      color = AppTheme.primary; // 蓝色
    } else if (rpm <= dangerRpm) {
      color = AppTheme.accentCyan; // 青色
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
      sweepAngle,  // 顺时针，经过上方
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
      sweepAngle,  // 顺时针，经过上方
      false,
      glowPaint,
    );
  }

  void _drawSpeedProgress(Canvas canvas, Offset center, double radius) {
    final sweepAngle = _speedToAngle(speed.toDouble());

    // 阶段颜色 - 使用 AppTheme 颜色
    Color color;
    if (speed <= warnSpeed) {
      color = AppTheme.accentCyan; // 青色
    } else if (speed <= dangerSpeed) {
      color = AppTheme.primary; // 蓝色
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
      -sweepAngle,  // 逆时针
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
      -sweepAngle,  // 逆时针
      false,
      glowPaint,
    );
  }

  void _drawRPMPointer(Canvas canvas, Offset center, double radius) {
    if (rpm <= 0) return;

    // 固定颜色 - 橙色，与数字蓝色区分
    const color = Color(0xFFFF9800);

    // 使用非线性映射计算角度
    final sweepAngle = _rpmToAngle(rpm.toDouble());
    final angle = pi + sweepAngle;
    final pointerLength = radius - 35;
    final headRadius = radius * 0.06; // 水滴头部半径

    // 指针尖端坐标
    final tipX = center.dx + pointerLength * cos(angle);
    final tipY = center.dy + pointerLength * sin(angle);

    // 绘制指针发光效果
    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    // 绘制水滴形状指针
    final pointerPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // 水滴形状：从尖端到圆心处的圆润头部
    final pointerPath = Path()
    // 从尖端开始
      ..moveTo(tipX, tipY)
    // 左侧曲线延伸到头部
      ..quadraticBezierTo(
        center.dx + headRadius * cos(angle - pi / 2) * 0.5,
        center.dy + headRadius * sin(angle - pi / 2) * 0.5,
        center.dx + headRadius * cos(angle - pi / 2),
        center.dy + headRadius * sin(angle - pi / 2),
      )
    // 头部半圆
      ..arcToPoint(
        Offset(
          center.dx + headRadius * cos(angle + pi / 2),
          center.dy + headRadius * sin(angle + pi / 2),
        ),
        radius: Radius.circular(headRadius),
        clockwise: true,
      )
    // 右侧曲线延伸到尖端
      ..quadraticBezierTo(
        center.dx + headRadius * cos(angle + pi / 2) * 0.5,
        center.dy + headRadius * sin(angle + pi / 2) * 0.5,
        tipX,
        tipY,
      )
      ..close();

    canvas.drawPath(pointerPath, glowPaint);
    canvas.drawPath(pointerPath, pointerPaint);

    // 绘制指针中心亮点
    final dotPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.8);
    canvas.drawCircle(center, headRadius * 0.5, dotPaint);
  }

  void _drawSpeedPointer(Canvas canvas, Offset center, double radius) {
    if (speed <= 0) return;

    // 固定颜色 - 品红色，与数字青色区分
    const color = Color(0xFFE91E63);

    // 使用非线性映射计算角度（逆时针）
    final sweepAngle = _speedToAngle(speed.toDouble());
    final angle = pi - sweepAngle;
    final pointerLength = radius - 35;
    final headRadius = radius * 0.06; // 水滴头部半径

    // 指针尖端坐标
    final tipX = center.dx + pointerLength * cos(angle);
    final tipY = center.dy + pointerLength * sin(angle);

    // 绘制指针发光效果
    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    // 绘制水滴形状指针
    final pointerPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // 水滴形状：从尖端到圆心处的圆润头部
    final pointerPath = Path()
    // 从尖端开始
      ..moveTo(tipX, tipY)
    // 左侧曲线延伸到头部
      ..quadraticBezierTo(
        center.dx + headRadius * cos(angle - pi / 2) * 0.5,
        center.dy + headRadius * sin(angle - pi / 2) * 0.5,
        center.dx + headRadius * cos(angle - pi / 2),
        center.dy + headRadius * sin(angle - pi / 2),
      )
    // 头部半圆
      ..arcToPoint(
        Offset(
          center.dx + headRadius * cos(angle + pi / 2),
          center.dy + headRadius * sin(angle + pi / 2),
        ),
        radius: Radius.circular(headRadius),
        clockwise: true,
      )
    // 右侧曲线延伸到尖端
      ..quadraticBezierTo(
        center.dx + headRadius * cos(angle + pi / 2) * 0.5,
        center.dy + headRadius * sin(angle + pi / 2) * 0.5,
        tipX,
        tipY,
      )
      ..close();

    canvas.drawPath(pointerPath, glowPaint);
    canvas.drawPath(pointerPath, pointerPaint);

    // 绘制指针中心亮点
    final dotPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.8);
    canvas.drawCircle(center, headRadius * 0.5, dotPaint);
  }

  void _drawTicks(Canvas canvas, Offset center, double radius) {
    final tickPaint = Paint()
      ..color = AppTheme.accentCyan
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;  // 加粗 (原3)

    final textStyle = TextStyle(
      color: AppTheme.textMuted,
      fontSize: radius * 0.07,
      fontWeight: FontWeight.w500,
    );

    // 公共0刻度 - 在正下方（π角度）绘制一个共用的0刻度线和标签
        {
      const zeroAngle = pi;
      final innerRadius = radius - 32;
      final outerRadius = radius - 22;

      // 绘制刻度线
      final x1 = center.dx + innerRadius * cos(zeroAngle);
      final y1 = center.dy + innerRadius * sin(zeroAngle);
      final x2 = center.dx + outerRadius * cos(zeroAngle);
      final y2 = center.dy + outerRadius * sin(zeroAngle);
      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), tickPaint);

      // 显示 "0" 标签
      final textSpan = TextSpan(
        text: '0',
        style: textStyle,
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();

      final textRadius = radius - 42;
      final textX = center.dx + textRadius * cos(zeroAngle) - textPainter.width / 2;
      final textY = center.dy + textRadius * sin(zeroAngle) - textPainter.height / 2;

      textPainter.paint(canvas, Offset(textX, textY));
    }

    // 上半圆刻度 (RPM) - 顺时针从π到2π，经过上方
    // 使用非线性映射：0-8000占前85%角度，8000-12000占后15%
    // 大刻度：1k, 2k, 3k, 4k, 5k, 6k, 7k, 8k, 10k, 12k
    final rpmMajorTicks = [1000, 2000, 3000, 4000, 5000, 6000, 7000, 8000, 10000, 12000];
    for (final i in rpmMajorTicks) {
      // 顺时针：π → 3π/2 → 2π
      final sweepAngle = _rpmToAngle(i.toDouble());
      final angle = pi + sweepAngle;
      final innerRadius = radius - 32;
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

    // 细粒度刻度 (RPM) - 只在常用区域0-8000显示，每1000一个
    final fineTickPaint = Paint()
      ..color = AppTheme.primary60
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // 常用区域每1000一个细刻度（排除已显示的大刻度）
    final rpmFineTicks = [500, 1500, 2500, 3500, 4500, 5500, 6500, 7500];
    for (final i in rpmFineTicks) {
      final sweepAngle = _rpmToAngle(i.toDouble());
      final angle = pi + sweepAngle;
      // 显示在进度弧内部（更靠近圆心）
      final innerRadius = radius - 40;
      final outerRadius = radius - 30;

      final x1 = center.dx + innerRadius * cos(angle);
      final y1 = center.dy + innerRadius * sin(angle);
      final x2 = center.dx + outerRadius * cos(angle);
      final y2 = center.dy + outerRadius * sin(angle);

      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), fineTickPaint);
    }

    // 下半圆刻度 (Speed) - 逆时针从π到0，经过下方
    // 使用非线性映射：0-180占前85%角度，180-250占后15%
    // 大刻度：30, 60, 90, 120, 150, 180, 210, 240
    final speedMajorTicks = [30, 60, 90, 120, 150, 180, 210, 230];
    for (final i in speedMajorTicks) {
      // 逆时针：π → π/2 → 0
      final sweepAngle = _speedToAngle(i.toDouble());
      final angle = pi - sweepAngle;
      final innerRadius = radius - 32;
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

    // 细粒度刻度 (Speed) - 只在常用区域0-180显示
    // 额外添加的细刻度（排除已显示的大刻度）
    final speedFineTicks = [10, 20, 40, 50, 70, 80, 100, 110, 130, 140, 160, 170];
    for (final i in speedFineTicks) {
      final sweepAngle = _speedToAngle(i.toDouble());
      final angle = pi - sweepAngle;
      // 显示在进度弧内部（更靠近圆心）
      final innerRadius = radius - 40;
      final outerRadius = radius - 30;

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
    // final dividerPaint = Paint()
    //   ..color = AppTheme.primary30
    //   ..strokeWidth = 1;
    // canvas.drawLine(
    //   Offset(center.dx - radius * 0.08, center.dy),
    //   Offset(center.dx + radius * 0.08, center.dy),
    //   dividerPaint,
    // );

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
  }

  @override
  bool shouldRepaint(covariant CombinedGaugePainter oldDelegate) {
    return oldDelegate.rpm != rpm ||
        oldDelegate.speed != speed ||
        oldDelegate.gear != gear;
  }
}
