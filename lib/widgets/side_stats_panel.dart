import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/obd_data_provider.dart';
import '../theme/app_theme.dart';

/// 侧边统计面板（车辆状态综合面板）
class SideStatsPanel extends StatelessWidget {
  const SideStatsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<OBDDataProvider>(
      builder: (context, provider, child) {
        final data = provider.data;

        return Container(
          padding: const EdgeInsets.all(6),
          decoration: AppTheme.surfaceBorder(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题
              // const Text('车辆状态', style: AppTheme.labelTinyPrimary),
              //
              // const SizedBox(height: 2),

              // 内容区域 - 不滚动
              Expanded(
                child: Column(
                  children: [
                    // 油耗趋势图
                    _FuelChart(
                      instantFuel: data.instantFuel,
                      fuelHistory: provider.fuelHistory,
                    ),

                    const SizedBox(height: 3),

                    // 油门进度条
                    _ProgressBar(
                      label: '油门开度',
                      value: data.throttle,
                      color: AppTheme.accentCyan,
                    ),

                    const SizedBox(height: 3),

                    // 负载进度条
                    _ProgressBar(
                      label: '发动机负载',
                      value: data.load,
                      color: AppTheme.accentOrange,
                    ),

                    const SizedBox(height: 3),

                    // 倾斜角度指示器
                    _LeanAngleIndicator(
                      angle: data.leanAngle,
                      direction: data.leanDirection,
                    ),

                    const SizedBox(height: 3),

                    // 气压趋势图
                    _PressureChart(
                      pressure: data.pressure,
                      pressureHistory: provider.pressureHistory,
                    ),

                    const SizedBox(height: 3),

                    // 电压显示
                    _VoltageDisplay(voltage: data.voltage),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 进度条
class _ProgressBar extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _ProgressBar({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: const BoxDecoration(
        color: AppTheme.backgroundDark30,
        borderRadius: BorderRadius.all(Radius.circular(6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: AppTheme.labelMedium),
              Text('$value%', style: AppTheme.valueSmall.copyWith(color: color)),
            ],
          ),
          const SizedBox(height: 3),
          Stack(
            children: [
              Container(
                height: 6,
                decoration: const BoxDecoration(
                  color: Color(0xFF1E293B),
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

  const _LeanAngleIndicator({
    required this.angle,
    required this.direction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: const BoxDecoration(
        color: AppTheme.backgroundDark30,
        borderRadius: BorderRadius.all(Radius.circular(6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('车辆倾角', style: AppTheme.labelMedium),
              Row(
                children: [
                  Text('$angle°', style: AppTheme.valueSmall),
                  const SizedBox(width: 4),
                  Text(
                    angle == 0 ? '无' : (direction == 'LEFT' ? '左' : '右'),
                    style: AppTheme.valueSmall.copyWith(color: AppTheme.primary),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          LayoutBuilder(
            builder: (context, constraints) {
              // 计算指示器位置：50%为中间，最大60度，角度为0时居中
              final leanPercent = angle == 0 ? 50 : 50 + (direction == 'LEFT' ? -angle : angle) * (50 / 60);
              return Stack(
                children: [
                  // 背景条
                  Container(
                    height: 7,
                    decoration: const BoxDecoration(
                      color: Color(0xFF1E293B),
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
                      color: AppTheme.primary30,
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
                        color: AppTheme.accentCyan,
                        borderRadius: BorderRadius.circular(2),
                        boxShadow: [
                          BoxShadow(color: AppTheme.accentCyan, blurRadius: 6),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 3),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('左60°', style: TextStyle(color: AppTheme.textMuted, fontSize: 8)),
              Text('0°', style: TextStyle(color: AppTheme.textMuted, fontSize: 8)),
              Text('右60°', style: TextStyle(color: AppTheme.textMuted, fontSize: 8)),
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

  const _PressureChart({
    required this.pressure,
    required this.pressureHistory,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: const BoxDecoration(
        color: AppTheme.backgroundDark30,
        borderRadius: BorderRadius.all(Radius.circular(6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('进气歧管压力', style: AppTheme.labelMedium),
              Text('$pressure kPa', style: AppTheme.valueSmall),
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

  PressureChartPainter({
    required this.pressureHistory,
    required this.minPressure,
    required this.maxPressure,
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
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [AppTheme.primary30, Colors.transparent],
      ).createShader(Rect.fromLTWH(0, 0, width, height));

    canvas.drawPath(areaPath, areaPaint);

    // 绘制线条
    final linePath = Path();
    linePath.moveTo(points.first.dx, points.first.dy);

    for (int i = 1; i < points.length; i++) {
      linePath.lineTo(points[i].dx, points[i].dy);
    }

    final linePaint = Paint()
      ..color = AppTheme.primary
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

/// 油耗图表
class _FuelChart extends StatelessWidget {
  final double instantFuel;
  final List<double> fuelHistory;

  const _FuelChart({
    required this.instantFuel,
    required this.fuelHistory,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: const BoxDecoration(
        color: AppTheme.backgroundDark30,
        borderRadius: BorderRadius.all(Radius.circular(6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('瞬时油耗', style: AppTheme.labelMedium),
              Text('${instantFuel.toStringAsFixed(1)} L/100km', style: AppTheme.valueSmall),
            ],
          ),
          const SizedBox(height: 2),
          SizedBox(
            height: 40,
            child: Row(
              children: [
                // Y轴刻度标签
                SizedBox(
                  width: 14,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('8', style: AppTheme.labelTiny.copyWith(fontSize: 9, color: AppTheme.accentCyan)),
                      Text('4', style: AppTheme.labelTiny.copyWith(fontSize: 9, color: AppTheme.accentCyan)),
                      Text('0', style: AppTheme.labelTiny.copyWith(fontSize: 9, color: AppTheme.accentCyan)),
                    ],
                  ),
                ),
                const SizedBox(width: 1),
                // 图表
                Expanded(
                  child: CustomPaint(
                    painter: FuelChartPainter(
                      fuelHistory: fuelHistory,
                      minFuel: 0,
                      maxFuel: 9,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 油耗图表绘制器
class FuelChartPainter extends CustomPainter {
  final List<double> fuelHistory;
  final double minFuel;
  final double maxFuel;

  FuelChartPainter({
    required this.fuelHistory,
    required this.minFuel,
    required this.maxFuel,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;
    const padding = 2.0;

    // 绘制横向刻度线（在0、3、6处划线）
    final gridPaint = Paint()
      ..color = AppTheme.primary10
      ..strokeWidth = 1;

    // Y轴标签是9、6、3、0，在0、3、6处画网格线
    final labels = [6, 3, 0];
    for (final label in labels) {
      final y = height * (maxFuel - label) / maxFuel;
      canvas.drawLine(Offset(0, y), Offset(width, y), gridPaint);
    }

    // 没有足够数据时不绘制曲线
    if (fuelHistory.length < 2) return;

    // 计算点位置
    final points = <Offset>[];
    final step = width / (fuelHistory.length - 1);

    for (int i = 0; i < fuelHistory.length; i++) {
      final x = i * step;
      final y = height - padding - ((fuelHistory[i] - minFuel) / (maxFuel - minFuel)) * (height - 2 * padding);
      points.add(Offset(x, y.clamp(padding, height - padding)));
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
        colors: [AppTheme.accentCyan.withAlpha(77), Colors.transparent],
      ).createShader(Rect.fromLTWH(0, 0, width, height));

    canvas.drawPath(areaPath, areaPaint);

    // 绘制线条
    final linePath = Path();
    linePath.moveTo(points.first.dx, points.first.dy);

    for (int i = 1; i < points.length; i++) {
      linePath.lineTo(points[i].dx, points[i].dy);
    }

    final linePaint = Paint()
      ..color = AppTheme.accentCyan
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(linePath, linePaint);
  }

  @override
  bool shouldRepaint(covariant FuelChartPainter oldDelegate) {
    if (oldDelegate.fuelHistory.length != fuelHistory.length) return true;
    if (fuelHistory.isEmpty) return false;
    return oldDelegate.fuelHistory.last != fuelHistory.last;
  }
}

/// 电压显示
class _VoltageDisplay extends StatelessWidget {
  final double voltage;

  const _VoltageDisplay({required this.voltage});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: const BoxDecoration(
        color: AppTheme.backgroundDark30,
        borderRadius: BorderRadius.all(Radius.circular(6)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Row(
            children: [
              Icon(Icons.battery_charging_full, color: AppTheme.accentGreen, size: 14),
              SizedBox(width: 4),
              Text('控制模块电压', style: AppTheme.labelMedium),
            ],
          ),
          Text(
            '${voltage.toStringAsFixed(1)}V',
            style: AppTheme.valueMedium.copyWith(color: AppTheme.accentGreen),
          ),
        ],
      ),
    );
  }
}
