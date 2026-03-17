import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// 半圆温度计组件
class MiniTempGauge extends StatelessWidget {
  /// 当前温度值
  final int temperature;

  /// 最小温度（用于映射）
  final int minTemp;

  /// 最大温度（用于映射）
  final int maxTemp;

  /// 标签（如 "水温"、"气温"）
  final String label;

  /// 正常颜色
  final Color normalColor;

  /// 警告颜色
  final Color warnColor;

  /// 危险颜色
  final Color dangerColor;

  /// 组件尺寸
  final double size;

  /// 警告温度阈值
  final int warnThreshold;

  /// 危险温度阈值
  final int dangerThreshold;

  const MiniTempGauge({
    super.key,
    required this.temperature,
    required this.minTemp,
    required this.maxTemp,
    required this.label,
    this.normalColor = AppTheme.accentCyan,
    this.warnColor = AppTheme.accentOrange,
    this.dangerColor = AppTheme.accentRed,
    this.size = 80,
    this.warnThreshold = 100,
    this.dangerThreshold = 110,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size * 0.6,
      child: CustomPaint(
        painter: MiniTempGaugePainter(
          temperature: temperature,
          minTemp: minTemp,
          maxTemp: maxTemp,
          label: label,
          normalColor: normalColor,
          warnColor: warnColor,
          dangerColor: dangerColor,
          warnThreshold: warnThreshold,
          dangerThreshold: dangerThreshold,
        ),
      ),
    );
  }
}

/// 半圆温度计绘制器
class MiniTempGaugePainter extends CustomPainter {
  final int temperature;
  final int minTemp;
  final int maxTemp;
  final String label;
  final Color normalColor;
  final Color warnColor;
  final Color dangerColor;
  final int warnThreshold;
  final int dangerThreshold;

  MiniTempGaugePainter({
    required this.temperature,
    required this.minTemp,
    required this.maxTemp,
    required this.label,
    required this.normalColor,
    required this.warnColor,
    required this.dangerColor,
    required this.warnThreshold,
    required this.dangerThreshold,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double width = size.width;
    final double height = size.height;
    final double radius = width / 2 - 4;

    // 圆心位置
    final Offset center = Offset(width / 2, height - 4);

    // 绘制背景弧（半圆）
    _drawBackgroundArc(canvas, center, radius);

    // 绘制温度进度弧
    _drawTempArc(canvas, center, radius);

    // 绘制中心数值和标签
    _drawCenterText(canvas, center, radius);
  }

  /// 绘制背景弧（半圆）
  void _drawBackgroundArc(Canvas canvas, Offset center, double radius) {
    final paint = Paint()
      ..color = const Color(0xFF1E293B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.butt;

    // 从 π 到 2π（半圆，从左到右）
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      pi,
      pi,
      false,
      paint,
    );
  }

  /// 绘制温度进度弧
  void _drawTempArc(Canvas canvas, Offset center, double radius) {
    // 计算温度对应的角度
    final double tempAngle = _tempToAngle(temperature.toDouble());
    final Color tempColor = _getTempColor(tempAngle);

    final paint = Paint()
      ..color = tempColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.butt;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      pi,
      tempAngle,
      false,
      paint,
    );
  }

  /// 绘制指针
  void _drawPointer(Canvas canvas, Offset center, double radius) {
    final double tempAngle = _tempToAngle(temperature.toDouble());
    // 指针角度从 pi 开始（左侧）到 2π（右侧）
    final double pointerAngle = pi + tempAngle;

    // 指针长度
    final double pointerLength = radius - 12;

    // 指针终点
    final double endX = center.dx + pointerLength * cos(pointerAngle);
    final double endY = center.dy + pointerLength * sin(pointerAngle);

    final paint = Paint()
      ..color = _getTempColor(tempAngle)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.butt;

    // 绘制指针线
    canvas.drawLine(center, Offset(endX, endY), paint);

    // 绘制指针头部（圆点）
    final dotPaint = Paint()
      ..color = _getTempColor(tempAngle)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(endX, endY), 3, dotPaint);

    // 绘制中心圆点
    canvas.drawCircle(center, 5, dotPaint);
  }

  /// 绘制中心数值和标签
  void _drawCenterText(Canvas canvas, Offset center, double radius) {
    // 绘制温度数值
    final textPainter = TextPainter(
      text: TextSpan(
        text: '$temperature°',
        style: const TextStyle(
          color: AppTheme.textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.normal,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        center.dx - textPainter.width / 2,
        center.dy - radius * 0.38,
      ),
    );

    // 绘制标签
    final labelPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: AppTheme.textMuted,
          fontSize: 10,
          fontWeight: FontWeight.normal,
          letterSpacing: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    labelPainter.layout();
    labelPainter.paint(
      canvas,
      Offset(
        center.dx - labelPainter.width / 2,
        center.dy - radius * 0.73,
      ),
    );
  }

  /// 温度到角度的映射
  double _tempToAngle(double temp) {
    final double ratio = ((temp - minTemp) / (maxTemp - minTemp)).clamp(0.0, 1.0).toDouble();
    return ratio * pi;
  }

  /// 根据温度获取颜色
  Color _getTempColor(double angle) {
    final double ratio = angle / pi;
    // 根据角度占比判断温度区间
    if (ratio < (warnThreshold - minTemp) / (maxTemp - minTemp)) {
      return normalColor;
    } else if (ratio < (dangerThreshold - minTemp) / (maxTemp - minTemp)) {
      return warnColor;
    } else {
      return dangerColor;
    }
  }

  @override
  bool shouldRepaint(covariant MiniTempGaugePainter oldDelegate) {
    return oldDelegate.temperature != temperature ||
        oldDelegate.minTemp != minTemp ||
        oldDelegate.maxTemp != maxTemp;
  }
}
