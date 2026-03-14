import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/theme_colors.dart';
import '../providers/obd_data_provider.dart';
import '../providers/theme_provider.dart';

/// 实时遥测图表卡片
class TelemetryChartCard extends StatelessWidget {
  const TelemetryChartCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final colors = themeProvider.currentColors;

        return Consumer<OBDDataProvider>(
          builder: (context, provider, child) {
            final data = provider.data;

            return Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: colors.surface.withValues(alpha: 0.4),
                border: Border.all(color: colors.primary.withValues(alpha: 0.1)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 标题行
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '近期趋势',
                        style: TextStyle(
                          color: colors.primary,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Row(
                        children: [
                          _LegendDot(color: colors.primary, label: '转速'),
                          const SizedBox(width: 10),
                          _LegendDot(color: colors.accentCyan, label: '速度 (km/h)'),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 6),

                  // 图表区域（带左右Y轴）
                  Expanded(
                    child: Row(
                      children: [
                        // 左侧Y轴（转速）
                        _YAxisLabels(
                          labels: ['12k', '9k', '6k', '3k', '0'],
                          color: colors.primary,
                          isLeft: true,
                        ),

                        // 中间图表 - 使用 RepaintBoundary 隔离重绘
                        Expanded(
                          child: _ChartArea(
                            rpmHistory: data.rpmHistory,
                            velocityHistory: data.velocityHistory,
                            colors: colors,
                          ),
                        ),

                        // 右侧Y轴（时速）
                        _YAxisLabels(
                          labels: ['250', '187', '125', '62', '0'],
                          color: colors.accentCyan,
                          isLeft: false,
                        ),
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

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _YAxisLabels extends StatelessWidget {
  final List<String> labels;
  final Color color;
  final bool isLeft;

  const _YAxisLabels({
    required this.labels,
    required this.color,
    required this.isLeft,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: labels.map((label) {
          return Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
            textAlign: isLeft ? TextAlign.right : TextAlign.left,
          );
        }).toList(),
      ),
    );
  }
}

/// 图表绘制区域 - 使用 RepaintBoundary 隔离重绘
class _ChartArea extends StatelessWidget {
  final List<int> rpmHistory;
  final List<int> velocityHistory;
  final ThemeColors colors;

  const _ChartArea({
    required this.rpmHistory,
    required this.velocityHistory,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        size: Size.infinite,
        painter: TelemetryChartPainter(
          rpmHistory: rpmHistory,
          velocityHistory: velocityHistory,
          colors: colors,
        ),
      ),
    );
  }
}

/// 遥测图表绘制器
class TelemetryChartPainter extends CustomPainter {
  final List<int> rpmHistory;
  final List<int> velocityHistory;
  final ThemeColors colors;

  TelemetryChartPainter({
    required this.rpmHistory,
    required this.velocityHistory,
    required this.colors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;
    const padding = 10.0;

    // 绘制网格线
    _drawGridLines(canvas, width, height);

    // 绘制RPM面积和线条
    if (rpmHistory.isNotEmpty) {
      _drawAreaAndLine(
        canvas,
        width,
        height,
        padding,
        rpmHistory,
        12000,
        colors.primary,
      );
    }

    // 绘制速度线条
    if (velocityHistory.isNotEmpty) {
      _drawDashedLine(
        canvas,
        width,
        height,
        padding,
        velocityHistory,
        250,
        colors.accentCyan,
      );
    }
  }

  void _drawGridLines(Canvas canvas, double width, double height) {
    final gridPaint = Paint()
      ..color = colors.primary.withValues(alpha: 0.1)
      ..strokeWidth = 1;

    // 水平网格线
    for (int i = 1; i < 4; i++) {
      final y = height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(width, y), gridPaint);
    }
  }

  void _drawAreaAndLine(
    Canvas canvas,
    double width,
    double height,
    double padding,
    List<int> data,
    int maxValue,
    Color color,
  ) {
    final points = <Offset>[];
    final step = width / (data.length - 1);

    for (int i = 0; i < data.length; i++) {
      final x = i * step;
      final y = height - padding - ((data[i] / maxValue) * (height - 2 * padding));
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
          color.withValues(alpha: 0.2),
          color.withValues(alpha: 0),
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
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(linePath, linePaint);
  }

  void _drawDashedLine(
    Canvas canvas,
    double width,
    double height,
    double padding,
    List<int> data,
    int maxValue,
    Color color,
  ) {
    final points = <Offset>[];
    final step = width / (data.length - 1);

    for (int i = 0; i < data.length; i++) {
      final x = i * step;
      final y = height - padding - ((data[i] / maxValue) * (height - 2 * padding));
      points.add(Offset(x, y));
    }

    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // 绘制虚线
    for (int i = 0; i < points.length - 1; i++) {
      _drawDashedSegment(
        canvas,
        points[i],
        points[i + 1],
        linePaint,
        dashLength: 4,
        gapLength: 4,
      );
    }
  }

  void _drawDashedSegment(
    Canvas canvas,
    Offset start,
    Offset end,
    Paint paint, {
    required double dashLength,
    required double gapLength,
  }) {
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final distance = sqrt(dx * dx + dy * dy);
    final unitX = dx / distance;
    final unitY = dy / distance;

    double current = 0;
    while (current < distance) {
      final x1 = start.dx + unitX * current;
      final y1 = start.dy + unitY * current;
      final x2 = start.dx + unitX * min(current + dashLength, distance);
      final y2 = start.dy + unitY * min(current + dashLength, distance);

      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), paint);
      current += dashLength + gapLength;
    }
  }

  @override
  bool shouldRepaint(covariant TelemetryChartPainter oldDelegate) {
    // 优化：比较长度和最后一个元素，避免深度比较
    if (oldDelegate.rpmHistory.length != rpmHistory.length) return true;
    if (oldDelegate.velocityHistory.length != velocityHistory.length) return true;
    if (rpmHistory.isEmpty || velocityHistory.isEmpty) return false;
    return oldDelegate.rpmHistory.last != rpmHistory.last ||
        oldDelegate.velocityHistory.last != velocityHistory.last;
  }
}
