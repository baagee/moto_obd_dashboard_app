import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/obd_data_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';

/// 实时遥测图表卡片
class TelemetryChartCard extends StatelessWidget {
  const TelemetryChartCard({super.key});

  /// 将 maxRpm 均分为 4 段，从上到下生成 5 个刻度标签
  static List<String> _buildRpmLabels(int maxRpm) {
    return List.generate(5, (i) {
      final value = maxRpm * (4 - i) ~/ 4;
      return value == 0
          ? '0'
          : '${(value / 1000).toStringAsFixed(value % 1000 == 0 ? 0 : 1)}k';
    });
  }

  /// 将 maxSpeed 均分为 4 段，从上到下生成 5 个刻度标签
  static List<String> _buildSpeedLabels(int maxSpeed) {
    return List.generate(5, (i) {
      final value = maxSpeed * (4 - i) ~/ 4;
      return value.toString();
    });
  }

  @override
  Widget build(BuildContext context) {
    // 精确订阅量程字段，仅在量程变化时重建
    final maxRpm = context.select<SettingsProvider, int>((s) => s.maxRpm);
    final maxSpeed = context.select<SettingsProvider, int>((s) => s.maxSpeed);

    // 静态标题行和图例提到 Consumer 外，不随数据更新重建
    final header = Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: const [
        Text('近期趋势', style: AppTheme.labelMediumPrimary),
        Row(
          children: [
            _LegendDot(color: AppTheme.primary, label: '转速'),
            SizedBox(width: 10),
            _LegendDot(color: AppTheme.accentCyan, label: '速度 (km/h)'),
          ],
        ),
      ],
    );

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: AppTheme.surface40,
        border: Border.all(color: AppTheme.primary10),
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header,
          const SizedBox(height: 5),
          // 图表区域（带左右Y轴）
          Expanded(
            child: Consumer<OBDDataProvider>(
              builder: (context, provider, _) {
                return Row(
                  children: [
                    _YAxisLabels(
                      labels: _buildRpmLabels(maxRpm),
                      color: AppTheme.primary,
                      isLeft: true,
                    ),
                    // ValueKey 已移除：shouldRepaint 负责控制重绘，ValueKey 会强制销毁重建整个 Widget
                    Expanded(
                      child: _ChartArea(
                        rpmHistory: provider.rpmHistory,
                        velocityHistory: provider.velocityHistory,
                        maxRpm: maxRpm,
                        maxSpeed: maxSpeed,
                      ),
                    ),
                    _YAxisLabels(
                      labels: _buildSpeedLabels(maxSpeed),
                      color: AppTheme.accentCyan,
                      isLeft: false,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
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
        Text(label.toUpperCase(), style: AppTheme.labelTiny),
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
            style: AppTheme.labelTiny.copyWith(color: color),
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
  final int maxRpm;
  final int maxSpeed;

  const _ChartArea({
    super.key,
    required this.rpmHistory,
    required this.velocityHistory,
    required this.maxRpm,
    required this.maxSpeed,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        size: Size.infinite,
        painter: TelemetryChartPainter(
          rpmHistory: rpmHistory,
          velocityHistory: velocityHistory,
          maxRpm: maxRpm,
          maxSpeed: maxSpeed,
        ),
      ),
    );
  }
}

/// 遥测图表绘制器
class TelemetryChartPainter extends CustomPainter {
  final List<int> rpmHistory;
  final List<int> velocityHistory;
  final int maxRpm;
  final int maxSpeed;

  TelemetryChartPainter({
    required this.rpmHistory,
    required this.velocityHistory,
    required this.maxRpm,
    required this.maxSpeed,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;
    const padding = 5.0;

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
        maxRpm,
        AppTheme.primary,
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
        maxSpeed,
        AppTheme.accentCyan,
      );
    }
  }

  void _drawGridLines(Canvas canvas, double width, double height) {
    final gridPaint = Paint()
      ..color = AppTheme.primary10
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
      final y =
          height - padding - ((data[i] / maxValue) * (height - 2 * padding));
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
          color.withOpacity(0.2),
          color.withOpacity(0),
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
      final y =
          height - padding - ((data[i] / maxValue) * (height - 2 * padding));
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
    // rpmHistory/velocityHistory 是原地修改的同一 List 实例，
    // oldDelegate 和 this 持有相同引用，比较 last 永远相等，无法检测变化。
    // Painter 只在 Consumer 触发时才重建（OBD 新数据到来），直接返回 true 即可。
    return true;
  }
}
