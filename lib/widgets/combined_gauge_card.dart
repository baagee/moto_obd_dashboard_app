import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/obd_data_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';

/// 组合仪表盘卡片（转速+时速+温度）
/// 量程参数从 SettingsProvider 动态读取，修改设置后实时生效
class CombinedGaugeCard extends StatelessWidget {
  const CombinedGaugeCard({super.key});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<OBDDataProvider>().data;
    // codeflicker-fix: OPT-Issue-6/omvh7ni7j93qpiynr7sw
    // 用 context.select 精确订阅 SettingsProvider 中实际用到的 11 个字段，
    // 避免 settings 任何字段变化都触发高频 OBDDataProvider 重建
    final maxRpm = context.select<SettingsProvider, int>((s) => s.maxRpm);
    final warnRpm = context.select<SettingsProvider, int>((s) => s.warnRpm);
    final dangerRpm = context.select<SettingsProvider, int>((s) => s.dangerRpm);
    final maxSpeed = context.select<SettingsProvider, int>((s) => s.maxSpeed);
    final warnSpeed = context.select<SettingsProvider, int>((s) => s.warnSpeed);
    final dangerSpeed =
        context.select<SettingsProvider, int>((s) => s.dangerSpeed);
    final flashThreshold =
        context.select<SettingsProvider, int>((s) => s.flashThreshold);
    final maxCoolantTemp =
        context.select<SettingsProvider, int>((s) => s.maxCoolantTemp);
    final coolantWarnTemp =
        context.select<SettingsProvider, int>((s) => s.coolantWarnTemp);
    final maxIntakeTemp =
        context.select<SettingsProvider, int>((s) => s.maxIntakeTemp);
    final intakeWarnTemp =
        context.select<SettingsProvider, int>((s) => s.intakeWarnTemp);

    return Container(
      padding: const EdgeInsets.all(8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return CustomPaint(
            size: Size(constraints.maxWidth, constraints.maxHeight),
            painter: CombinedGaugePainter(
              rpm: data.rpm,
              speed: data.speed,
              gear: 0,
              coolantTemp: data.coolantTemp,
              intakeTemp: data.intakeTemp,
              maxRpm: maxRpm,
              warnRpm: warnRpm,
              dangerRpm: dangerRpm,
              maxSpeed: maxSpeed,
              warnSpeed: warnSpeed,
              dangerSpeed: dangerSpeed,
              flashThreshold: flashThreshold,
              maxCoolantTemp: maxCoolantTemp,
              coolantWarnTemp: coolantWarnTemp,
              maxIntakeTemp: maxIntakeTemp,
              intakeWarnTemp: intakeWarnTemp,
            ),
          );
        },
      ),
    );
  }
}

/// 组合仪表盘绘制器
/// 量程参数从 SettingsProvider 注入，不再使用 static const
class CombinedGaugePainter extends CustomPainter {
  final int rpm;
  final int speed;
  final int gear;
  final int coolantTemp;
  final int intakeTemp;

  // 量程参数（从 SettingsProvider 注入）
  final int maxRpm;
  final int warnRpm;
  final int dangerRpm;
  final int maxSpeed;
  final int warnSpeed;
  final int dangerSpeed;
  final int flashThreshold;
  final int maxCoolantTemp;
  final int coolantWarnTemp;
  final int maxIntakeTemp;
  final int intakeWarnTemp;

  static const int tempSegmentCount = 6; // 温度进度条分段数（固定）

  /// 车速到角度的线性映射
  double _speedToAngle(double speed) {
    return (speed / maxSpeed) * pi;
  }

  /// RPM 到角度的非线性映射
  /// 0-4000RPM 占据前 20% 角度，4000-maxRpm 占据后 80%
  double _rpmToAngle(double rpm) {
    const double normalMax = 4000;
    const double normalRatio = 0.20;

    if (rpm <= normalMax) {
      return (rpm / normalMax) * normalRatio * pi;
    } else {
      final double extendedMax = maxRpm - 4000;
      return normalRatio * pi +
          ((rpm - normalMax) / extendedMax) * (1 - normalRatio) * pi;
    }
  }

  CombinedGaugePainter({
    required this.rpm,
    required this.speed,
    required this.gear,
    required this.coolantTemp,
    required this.intakeTemp,
    this.maxRpm = 12000,
    this.warnRpm = 7000,
    this.dangerRpm = 9000,
    this.maxSpeed = 240,
    this.warnSpeed = 120,
    this.dangerSpeed = 180,
    this.flashThreshold = 100,
    this.maxCoolantTemp = 120,
    this.coolantWarnTemp = 100,
    this.maxIntakeTemp = 80,
    this.intakeWarnTemp = 50,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    // 使用宽度和高度中较小的值作为基准
    final radius =
        (size.width < size.height ? size.width : size.height) / 2 - 10;

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

    // 绘制温度进度条
    _drawTemperatureGauges(canvas, size, radius);
  }

  void _drawBackground(Canvas canvas, Offset center, double radius) {
    // 背景渐变
    final gradient = RadialGradient(
      colors: [
        AppTheme.backgroundDark,
        AppTheme.slateGray.withValues(alpha: 0.5),
      ],
    );

    final paint = Paint()
      ..shader = gradient
          .createShader(Rect.fromCircle(center: center, radius: radius + 20));

    canvas.drawCircle(center, radius + 20, paint);

    // 超速红色闪烁效果
    if (speed >= flashThreshold) {
      // _drawSpeedWarningGlow(canvas, center, radius);
    }
  }

  // codeflicker-fix: OPT-Issue-13/omvh7ni7j93qpiynr7sw — _drawSpeedWarningGlow 未被引用，已删除

  void _drawTickBackground(Canvas canvas, Offset center, double radius) {
    final paint = Paint()
      ..color = AppTheme.slateGray
      ..style = PaintingStyle.stroke
      ..strokeWidth = 27 // 加粗0.5倍 (18 * 1.5)
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
      color = AppTheme.primary; // 蓝色 - 正常
    } else if (rpm <= dangerRpm) {
      color = AppTheme.accentOrange; // 橙色 - 警告
    } else {
      color = AppTheme.accentRed; // 红色 - 危险
    }

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 27 // 加粗0.5倍 (18 * 1.5)
      ..strokeCap = StrokeCap.butt; // 平头样式，避免与对向弧冲突

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      pi,
      sweepAngle, // 顺时针，经过上方
      false,
      paint,
    );

    // 发光效果
    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 36 // 加粗0.5倍 (24 * 1.5)
      ..strokeCap = StrokeCap.butt // 平头样式
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      pi,
      sweepAngle, // 顺时针，经过上方
      false,
      glowPaint,
    );
  }

  void _drawSpeedProgress(Canvas canvas, Offset center, double radius) {
    final sweepAngle = _speedToAngle(speed.toDouble());

    // 阶段颜色 - 青色(正常) → 紫色(警告) → 红色(危险)
    Color color;
    if (speed <= warnSpeed) {
      color = AppTheme.accentCyan; // 青色 - 正常
    } else if (speed <= dangerSpeed) {
      color = AppTheme.accentPurple; // 紫色 - 警告
    } else {
      color = AppTheme.accentRed; // 红色 - 危险
    }

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 27 // 加粗0.5倍 (18 * 1.5)
      ..strokeCap = StrokeCap.butt; // 平头样式，避免与对向弧冲突

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      pi,
      -sweepAngle, // 逆时针
      false,
      paint,
    );

    // 发光效果
    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 36 // 加粗0.5倍 (24 * 1.5)
      ..strokeCap = StrokeCap.butt // 平头样式
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      pi,
      -sweepAngle, // 逆时针
      false,
      glowPaint,
    );
  }

  void _drawRPMPointer(Canvas canvas, Offset center, double radius) {
    if (rpm <= 0) return;

    // 固定颜色 - 橙色，与数字蓝色区分
    const color = AppTheme.accentOrange;

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
    final dotPaint = Paint()..color = Colors.white.withValues(alpha: 0.8);
    canvas.drawCircle(center, headRadius * 0.5, dotPaint);
  }

  void _drawSpeedPointer(Canvas canvas, Offset center, double radius) {
    if (speed <= 0) return;

    // 固定颜色 - 品红色，与数字青色区分
    const color = AppTheme.accentPink;

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
    final dotPaint = Paint()..color = Colors.white.withValues(alpha: 0.8);
    canvas.drawCircle(center, headRadius * 0.5, dotPaint);
  }

  void _drawTicks(Canvas canvas, Offset center, double radius) {
    final tickPaint = Paint()
      ..color = AppTheme.accentCyan
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4; // 加粗 (原3)

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
      final textX =
          center.dx + textRadius * cos(zeroAngle) - textPainter.width / 2;
      final textY =
          center.dy + textRadius * sin(zeroAngle) - textPainter.height / 2;

      textPainter.paint(canvas, Offset(textX, textY));
    }

    // 上半圆刻度 (RPM) - 顺时针从π到2π，经过上方
    // 大刻度动态生成：0-4000 每 2000 一个，4000-maxRpm 每 1000 一个
    final rpmMajorTicks = <int>[0, 2000];
    for (int v = 4000; v <= maxRpm; v += 1000) {
      rpmMajorTicks.add(v);
    }
    for (final i in rpmMajorTicks) {
      // 顺时针：π → 3π/2 → 2π
      final sweepAngle = _rpmToAngle(i.toDouble());
      final angle = pi + sweepAngle;
      final innerRadius = radius - 32;
      final outerRadius = radius - 22;

      // 根据刻度值区间确定颜色
      Color tickColor;
      if (i < warnRpm) {
        tickColor = AppTheme.primary; // 蓝色 - 正常
      } else if (i < dangerRpm) {
        tickColor = AppTheme.accentOrange; // 橙色 - 警告
      } else {
        tickColor = AppTheme.accentRed; // 红色 - 危险
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
      final textY =
          center.dy + textRadius * sin(angle) - textPainter.height / 2;

      textPainter.paint(canvas, Offset(textX, textY));
    }

    // 细粒度刻度 (RPM) - 根据区间变色
    // 0-4000 每 1000 的中间值（1000,3000），4000+ 每 1000 的中间值（4500,5500,...）
    final rpmFineTicks = <int>[1000, 3000];
    for (int v = 4500; v < maxRpm; v += 1000) {
      rpmFineTicks.add(v);
    }
    for (final i in rpmFineTicks) {
      final sweepAngle = _rpmToAngle(i.toDouble());
      final angle = pi + sweepAngle;
      // 显示在进度弧内部（更靠近圆心）
      final innerRadius = radius - 40;
      final outerRadius = radius - 30;

      // 根据刻度值区间确定颜色
      Color tickColor;
      if (i < warnRpm) {
        tickColor = AppTheme.primary.withValues(alpha: 0.6); // 蓝色 - 正常
      } else if (i < dangerRpm) {
        tickColor = AppTheme.accentOrange.withValues(alpha: 0.6); // 橙色 - 警告
      } else {
        tickColor = AppTheme.accentRed.withValues(alpha: 0.6); // 红色 - 危险
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
    // 大刻度：每 30 km/h，动态生成到 maxSpeed（不含 maxSpeed 本身，避免与末端重叠）
    final speedMajorTicks = <int>[];
    for (int v = 0; v < maxSpeed; v += 30) {
      speedMajorTicks.add(v);
    }
    for (final i in speedMajorTicks) {
      // 逆时针：π → π/2 → 0
      final sweepAngle = _speedToAngle(i.toDouble());
      final angle = pi - sweepAngle;
      final innerRadius = radius - 32;
      final outerRadius = radius - 22;

      // 根据刻度值区间确定颜色
      Color tickColor;
      if (i < warnSpeed) {
        tickColor = AppTheme.accentCyan; // 青色 - 正常
      } else if (i < dangerSpeed) {
        tickColor = AppTheme.accentPurple; // 紫色 - 警告
      } else {
        tickColor = AppTheme.accentRed; // 红色 - 危险
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
      final textY =
          center.dy + textRadius * sin(angle) - textPainter.height / 2;

      textPainter.paint(canvas, Offset(textX, textY));
    }

    // 小刻度 (Speed) - 每 30 km/h 的中间值（15, 45, ...），动态生成
    final speedFineTicks = <int>[];
    for (int v = 15; v < maxSpeed; v += 30) {
      speedFineTicks.add(v);
    }
    for (final i in speedFineTicks) {
      final sweepAngle = _speedToAngle(i.toDouble());
      final angle = pi - sweepAngle;
      // 显示在进度弧内部（更靠近圆心）
      final innerRadius = radius - 40;
      final outerRadius = radius - 30;

      // 根据刻度值区间确定颜色
      Color tickColor;
      if (i < warnSpeed) {
        tickColor = AppTheme.accentCyan.withValues(alpha: 0.6); // 青色 - 正常
      } else if (i < dangerSpeed) {
        tickColor = AppTheme.accentPurple.withValues(alpha: 0.6); // 紫色 - 警告
      } else {
        tickColor = AppTheme.accentRed.withValues(alpha: 0.6); // 红色 - 危险
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
        color: AppTheme.primary.withValues(alpha: 0.7),
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
        oldDelegate.gear != gear ||
        oldDelegate.coolantTemp != coolantTemp ||
        oldDelegate.intakeTemp != intakeTemp ||
        oldDelegate.maxRpm != maxRpm ||
        oldDelegate.warnRpm != warnRpm ||
        oldDelegate.dangerRpm != dangerRpm ||
        oldDelegate.maxSpeed != maxSpeed ||
        oldDelegate.warnSpeed != warnSpeed ||
        oldDelegate.dangerSpeed != dangerSpeed ||
        oldDelegate.flashThreshold != flashThreshold ||
        oldDelegate.maxCoolantTemp != maxCoolantTemp ||
        oldDelegate.coolantWarnTemp != coolantWarnTemp ||
        oldDelegate.maxIntakeTemp != maxIntakeTemp ||
        oldDelegate.intakeWarnTemp != intakeWarnTemp;
  }

  /// 绘制倒梯形温度进度条
  void _drawTemperatureGauges(Canvas canvas, Size size, double radius) {
    // 左上角 - 以父容器左上角为基准
    _drawInvertedTrapezoidTempGauge(
      canvas: canvas,
      size: size,
      x: 0,
      y: radius * 0.23,
      radius: radius,
      value: coolantTemp,
      maxValue: maxCoolantTemp,
      warnValue: coolantWarnTemp,
      label: '冷却水温',
      alignRight: true, // 靠右对齐
    );

    // 右上角 - 以父容器右上角为基准
    _drawInvertedTrapezoidTempGauge(
      canvas: canvas,
      size: size,
      x: size.width,
      y: radius * 0.23,
      radius: radius,
      value: intakeTemp,
      maxValue: maxIntakeTemp,
      warnValue: intakeWarnTemp,
      label: '进气温度',
      alignRight: false, // 靠左对齐
    );
  }

  /// 绘制单个倒梯形温度进度条
  /// 倒梯形：上宽下窄（顶部宽，底部窄）
  void _drawInvertedTrapezoidTempGauge({
    required Canvas canvas,
    required Size size,
    required double x,
    required double y,
    required double radius,
    required int value,
    required int maxValue,
    required int warnValue,
    required String label,
    required bool alignRight, // true=靠右对齐, false=靠左对齐
  }) {
    // 倒梯形尺寸 - 上宽下窄
    final topWidth = radius * 0.5; // 顶部宽
    final bottomWidth = radius * 0.125; // 底部窄
    final height = radius * 0.33;

    // 直接使用传入的 x, y 坐标作为中心点
    final trapezoidCenter = Offset(x, y);

    // 顶部和底部的Y坐标
    final topY = trapezoidCenter.dy - height / 2;
    final bottomY = trapezoidCenter.dy + height / 2;

    // 计算填充比例
    final fillRatio = (value / maxValue).clamp(0.0, 1.0);
    final filledSegments = (fillRatio * tempSegmentCount).ceil();

    // 每个分段的高度（包含间隙）
    final segmentHeight =
        (height - (tempSegmentCount - 1) * 2) / tempSegmentCount;

    // 根据对齐方式计算 x 坐标
    double getLeftX(double centerX, double width) {
      return alignRight ? centerX : centerX - width;
    }

    // 背景槽：使用半透明填充，显示轮廓
    final bgPaint = Paint()
      ..color = AppTheme.slateGray.withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;

    final bgPath = Path()
      ..moveTo(getLeftX(trapezoidCenter.dx, topWidth), topY) // 左上
      ..lineTo(getLeftX(trapezoidCenter.dx, topWidth) + topWidth, topY) // 右上
      ..lineTo(getLeftX(trapezoidCenter.dx, bottomWidth) + bottomWidth,
          bottomY) // 右下
      ..lineTo(getLeftX(trapezoidCenter.dx, bottomWidth), bottomY) // 左下
      ..close();

    canvas.drawPath(bgPath, bgPaint);

    // 绘制分段进度（从底部向上，宽度递增 - 上宽下窄）
    for (int i = 0; i < tempSegmentCount; i++) {
      // 计算当前分段的位置（从底部开始，i=0 是最底部）
      final segTopY = bottomY - (i + 1) * (segmentHeight + 2) + 2;
      final segBottomY = bottomY - i * (segmentHeight + 2);

      // 使用归一化坐标确保斜率完全一致
      // i=0: 0/6 到 1/6, i=5: 5/6 到 6/6
      final segmentStartRatio = i / tempSegmentCount;
      final segmentEndRatio = (i + 1) / tempSegmentCount;

      // 根据归一化位置计算宽度，确保与背景槽斜率一致
      final segTopWidth =
          bottomWidth + (topWidth - bottomWidth) * segmentEndRatio;
      final segBottomWidth =
          bottomWidth + (topWidth - bottomWidth) * segmentStartRatio;

      // 判断当前分段是否应该填充（从底部向上填充）
      final isFilled = i < filledSegments;

      // 确定颜色
      Color segmentColor;
      if (!isFilled) {
        segmentColor = AppTheme.slateGray;
      } else {
        // 根据温度区间确定颜色
        final segmentRatio = (i + 1) / tempSegmentCount;
        if (segmentRatio <= 0.5) {
          segmentColor = AppTheme.accentCyan;
        } else if (segmentRatio <= 0.83) {
          segmentColor = AppTheme.accentOrange;
        } else {
          segmentColor = AppTheme.accentRed;
        }
      }

      // 绘制分段
      final segPaint = Paint()
        ..color = segmentColor
        ..style = PaintingStyle.fill;

      // 根据对齐方式计算 x 坐标
      double getLeftX(double centerX, double width) {
        return alignRight ? centerX : centerX - width;
      }

      final segPath = Path()
        ..moveTo(getLeftX(trapezoidCenter.dx, segTopWidth), segTopY)
        ..lineTo(
            getLeftX(trapezoidCenter.dx, segTopWidth) + segTopWidth, segTopY)
        ..lineTo(getLeftX(trapezoidCenter.dx, segBottomWidth) + segBottomWidth,
            segBottomY)
        ..lineTo(getLeftX(trapezoidCenter.dx, segBottomWidth), segBottomY)
        ..close();

      canvas.drawPath(segPath, segPaint);

      // 已填充分段添加发光效果
      if (isFilled) {
        final glowPaint = Paint()
          ..color = segmentColor.withValues(alpha: 0.4)
          ..style = PaintingStyle.fill
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

        canvas.drawPath(segPath, glowPaint);
      }
    }

    // 绘制标签和数值
    _drawTempLabel(canvas, trapezoidCenter, height, value, label, alignRight);
  }

  /// 绘制温度标签和数值
  void _drawTempLabel(Canvas canvas, Offset center, double height, int value,
      String label, bool alignRight) {
    final labelStyle = AppTheme.labelMediumPrimary12;
    //  TextStyle(
    //       color: AppTheme.accentCyan.withValues(alpha: 0.99),
    //       fontSize: 12,
    //       fontWeight: FontWeight.w500,
    //     );

    const valueStyle = TextStyle(
      color: AppTheme.textPrimary,
      fontSize: 13,
      fontWeight: FontWeight.bold,
    );

    // 根据对齐方式计算 x 坐标
    double getLeftX(double centerX, double width) {
      return alignRight ? centerX : centerX - width;
    }

    // 绘制标签 - 放到进度条上方
    final labelSpan = TextSpan(text: label, style: labelStyle);
    final labelPainter = TextPainter(
      text: labelSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    labelPainter.paint(
      canvas,
      Offset(getLeftX(center.dx, labelPainter.width),
          center.dy - height / 2 - labelPainter.height - 4),
    );

    // 绘制数值 - 维持在进度条下方
    final valueSpan = TextSpan(text: '$value°', style: valueStyle);
    final valuePainter = TextPainter(
      text: valueSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    valuePainter.paint(
      canvas,
      Offset(
          getLeftX(center.dx, valuePainter.width), center.dy + height / 2 + 4),
    );
  }
}
