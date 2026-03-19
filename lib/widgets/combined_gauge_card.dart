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
                  gear: 0,// 获取不到档位，设置为0
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
  static const int warnRpm = 7000;
  static const int dangerRpm = 9000;

  // Speed 参数
  static const int maxSpeed = 240;
  static const int warnSpeed = 120;
  static const int dangerSpeed = 180;
  static const int flashThreshold = 100; // 闪烁阈值

  /// 车速到角度的线性映射 (0-240 均匀划分)
  double _speedToAngle(double speed) {
    const double maxSpeed = 240;
    return (speed / maxSpeed) * pi;
  }

  /// RPM 到角度的非线性映射
  /// 0-4000RPM 占据前 20% 角度，4000-12000 占据后 80%
  double _rpmToAngle(double rpm) {
    const double normalMax = 4000;
    const double normalRatio = 0.20;

    if (rpm <= normalMax) {
      return (rpm / normalMax) * normalRatio * pi;
    } else {
      const double extendedMax = 12000 - 4000;
      return normalRatio * pi + ((rpm - normalMax) / extendedMax) * (1 - normalRatio) * pi;
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
    if (speed >= flashThreshold) {
      _drawSpeedWarningGlow(canvas, center, radius);
    }
  }

  /// 绘制超速警告红色闪烁光环
  void _drawSpeedWarningGlow(Canvas canvas, Offset center, double radius) {
    // 计算闪烁透明度 (0.5 - 1.0 之间脉冲，更深更明显)
    final time = DateTime.now().millisecondsSinceEpoch;
    final pulse = 0.5 + 0.5 * ((time ~/ 150) % 2 == 0 ? 1 : 0);

    // 外层 - 宽模糊
    final outerPaint = Paint()
      ..color = const Color(0xFFFF0000).withValues(alpha: pulse * 0.6) // 纯红色
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 25);
    canvas.drawCircle(center, radius + 35, outerPaint);

    // 内层 - 窄模糊
    final innerPaint = Paint()
      ..color = const Color(0xFFFF0000).withValues(alpha: pulse)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15);
    canvas.drawCircle(center, radius + 30, innerPaint);
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

    // 阶段颜色 - 青色(正常) → 橙色(警告) → 红色(危险)
    Color color;
    if (rpm <= warnRpm) {
      color = AppTheme.accentCyan; // 青色 - 正常
    } else if (rpm <= dangerRpm) {
      color = const Color(0xFFFF9800); // 橙色 - 警告
    } else {
      color = const Color(0xFFFF0000); // 红色 - 危险
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

    // 阶段颜色 - 蓝色(正常) → 紫色(警告) → 红色(危险)
    Color color;
    if (speed <= warnSpeed) {
      color = AppTheme.primary; // 蓝色 - 正常
    } else if (speed <= dangerSpeed) {
      color = const Color(0xFF9C27B0); // 紫色 - 警告
    } else {
      color = const Color(0xFFFF0000); // 红色 - 危险
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
      fontSize: radius * 0.09, // 调大字体
      fontWeight: FontWeight.w600,
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

      final textRadius = radius - 52;
      final textX = center.dx + textRadius * cos(zeroAngle) - textPainter.width / 2;
      final textY = center.dy + textRadius * sin(zeroAngle) - textPainter.height / 2;

      textPainter.paint(canvas, Offset(textX, textY));
    }

    // 上半圆刻度 (RPM) - 顺时针从π到2π，经过上方
    // 使用非线性映射：0-4000占前20%角度，4000-12000占后80%
    // 大刻度：0, 2, 4, 5k, 6k, 7k, 8k, 9k, 10k, 11k, 12k
    final rpmMajorTicks = [0, 2000, 4000, 5000, 6000, 7000, 8000, 9000, 10000, 11000, 12000];
    for (final i in rpmMajorTicks) {
      // 顺时针：π → 3π/2 → 2π
      final sweepAngle = _rpmToAngle(i.toDouble());
      final angle = pi + sweepAngle;
      final innerRadius = radius - 32;
      final outerRadius = radius - 22;

      // 根据刻度值区间确定颜色
      Color tickColor;
      if (i < warnRpm) {
        tickColor = AppTheme.accentCyan; // 青色 - 正常
      } else if (i < dangerRpm) {
        tickColor = const Color(0xFFFF9800); // 橙色 - 警告
      } else {
        tickColor = const Color(0xFFFF0000); // 红色 - 危险
      }

      final tickPaintColored = Paint()
        ..color = tickColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4;

      final x1 = center.dx + innerRadius * cos(angle);
      final y1 = center.dy + innerRadius * sin(angle);
      final x2 = center.dx + outerRadius * cos(angle);
      final y2 = center.dy + outerRadius * sin(angle);

      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), tickPaintColored);

      // 刻度值 - 使用对应颜色
      final textSpan = TextSpan(
        text: i >= 1000 ? '${i ~/ 1000}k' : i.toString(),
        style: textStyle,
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();

      final textRadius = radius - 52;
      final textX = center.dx + textRadius * cos(angle) - textPainter.width / 2;
      final textY = center.dy + textRadius * sin(angle) - textPainter.height / 2;

      textPainter.paint(canvas, Offset(textX, textY));
    }

    // 细粒度刻度 (RPM) - 根据区间变色
    // 小刻度：0-4000区间每1000一个(1000,3000)，4000+区间每500一个
    final rpmFineTicks = [1000, 3000, 4500, 5500, 6500, 7500, 8500, 9500, 10500, 11500];
    for (final i in rpmFineTicks) {
      final sweepAngle = _rpmToAngle(i.toDouble());
      final angle = pi + sweepAngle;
      // 显示在进度弧内部（更靠近圆心）
      final innerRadius = radius - 40;
      final outerRadius = radius - 30;

      // 根据刻度值区间确定颜色
      Color tickColor;
      if (i < warnRpm) {
        tickColor = AppTheme.accentCyan.withValues(alpha: 0.6); // 青色 - 正常
      } else if (i < dangerRpm) {
        tickColor = const Color(0xFFFF9800).withValues(alpha: 0.6); // 橙色 - 警告
      } else {
        tickColor = const Color(0xFFFF0000).withValues(alpha: 0.6); // 红色 - 危险
      }

      final fineTickPaintColored = Paint()
        ..color = tickColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;

      final x1 = center.dx + innerRadius * cos(angle);
      final y1 = center.dy + innerRadius * sin(angle);
      final x2 = center.dx + outerRadius * cos(angle);
      final y2 = center.dy + outerRadius * sin(angle);

      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), fineTickPaintColored);
    }

    // 下半圆刻度 (Speed) - 逆时针从π到0，经过下方
    // 线性映射：0-240 均匀分布
    // 大刻度：每30 km/h - 0, 30, 60, 90, 120, 150, 180, 210 (不显示240)
    final speedMajorTicks = [0, 30, 60, 90, 120, 150, 180, 210];
    for (final i in speedMajorTicks) {
      // 逆时针：π → π/2 → 0
      final sweepAngle = _speedToAngle(i.toDouble());
      final angle = pi - sweepAngle;
      final innerRadius = radius - 32;
      final outerRadius = radius - 22;

      // 根据刻度值区间确定颜色
      Color tickColor;
      if (i < warnSpeed) {
        tickColor = AppTheme.primary; // 蓝色 - 正常
      } else if (i < dangerSpeed) {
        tickColor = const Color(0xFF9C27B0); // 紫色 - 警告
      } else {
        tickColor = const Color(0xFFFF0000); // 红色 - 危险
      }

      final tickPaintColored = Paint()
        ..color = tickColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4;

      final x1 = center.dx + innerRadius * cos(angle);
      final y1 = center.dy + innerRadius * sin(angle);
      final x2 = center.dx + outerRadius * cos(angle);
      final y2 = center.dy + outerRadius * sin(angle);

      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), tickPaintColored);

      // 刻度值 - 使用对应颜色
      final textSpan = TextSpan(
        text: i.toString(),
        style: textStyle,
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();

      final textRadius = radius - 52;
      final textX = center.dx + textRadius * cos(angle) - textPainter.width / 2;
      final textY = center.dy + textRadius * sin(angle) - textPainter.height / 2;

      textPainter.paint(canvas, Offset(textX, textY));
    }

    // 小刻度 (Speed) - 每 15 km/h（排除大刻度），根据区间变色
    final speedFineTicks = [15, 45, 75, 105, 135, 165, 195, 225];
    for (final i in speedFineTicks) {
      final sweepAngle = _speedToAngle(i.toDouble());
      final angle = pi - sweepAngle;
      // 显示在进度弧内部（更靠近圆心）
      final innerRadius = radius - 40;
      final outerRadius = radius - 30;

      // 根据刻度值区间确定颜色
      Color tickColor;
      if (i < warnSpeed) {
        tickColor = AppTheme.primary.withValues(alpha: 0.6); // 蓝色 - 正常
      } else if (i < dangerSpeed) {
        tickColor = const Color(0xFF9C27B0).withValues(alpha: 0.6); // 紫色 - 警告
      } else {
        tickColor = const Color(0xFFFF0000).withValues(alpha: 0.6); // 红色 - 危险
      }

      final speedFineTickPaint = Paint()
        ..color = tickColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;

      final x1 = center.dx + innerRadius * cos(angle);
      final y1 = center.dy + innerRadius * sin(angle);
      final x2 = center.dx + outerRadius * cos(angle);
      final y2 = center.dy + outerRadius * sin(angle);

      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), speedFineTickPaint);
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
