import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/obd_data_provider.dart';
import '../theme/app_theme.dart';

/// 侧边统计面板（车辆状态综合面板）
class SideStatsPanel extends StatelessWidget {
  const SideStatsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    // 各字段独立精确订阅：
    // - throttle/load/voltage 来自 updateRealTimeData（OBD 轮询频率）
    // - leanAngle/leanDirection 来自 updateLeanAngle（传感器 66Hz）
    // - pressure/pressureHistory 来自 updateRealTimeData（OBD 低频）
    // 拆分后 leanAngle 66Hz 更新不再触发 throttle/load/voltage/pressure 等的重建
    final throttle =
        context.select<OBDDataProvider, int>((p) => p.data.throttle);
    final load = context.select<OBDDataProvider, int>((p) => p.data.load);
    final leanAngle =
        context.select<OBDDataProvider, int>((p) => p.data.leanAngle);
    final leanDirection =
        context.select<OBDDataProvider, String>((p) => p.data.leanDirection);
    final pressure =
        context.select<OBDDataProvider, int>((p) => p.data.pressure);
    final voltage =
        context.select<OBDDataProvider, double>((p) => p.data.voltage);

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: AppTheme.surfaceBorder(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题（静态，不依赖数据）
          const Text('车辆状态', style: AppTheme.labelMediumPrimary),

          const SizedBox(height: 2),

          // 内容区域
          Expanded(
            child: Column(
              children: [
                // 油门进度条
                _ProgressBar(
                  icon: Icons.speed,
                  iconColor: AppTheme.accentCyan,
                  label: '油门开度',
                  value: throttle,
                  color: AppTheme.accentCyan,
                ),

                const SizedBox(height: 6),

                // 负载进度条
                _ProgressBar(
                  icon: Icons.settings,
                  iconColor: AppTheme.accentOrange,
                  label: '发动机负载',
                  value: load,
                  color: AppTheme.accentOrange,
                ),

                const SizedBox(height: 6),

                // 倾斜角度指示器
                _LeanAngleIndicator(
                  angle: leanAngle,
                  direction: leanDirection,
                ),

                const SizedBox(height: 6),

                // 气压趋势图：pressureHistory 是 List 引用，select 无法检测内容变化
                // 单独用 Consumer 包裹，仅此处订阅完整 provider
                Consumer<OBDDataProvider>(
                  builder: (context, provider, _) => _PressureChart(
                    pressure: pressure,
                    pressureHistory: provider.pressureHistory,
                  ),
                ),

                const SizedBox(height: 6),

                // 电压显示
                _VoltageDisplay(voltage: voltage),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 温度卡片
class _TempCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _TempCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: const BoxDecoration(
        color: AppTheme.backgroundDark30,
        borderRadius: BorderRadius.all(Radius.circular(AppTheme.radiusSmall)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 14),
              const SizedBox(width: 4),
              Text(label, style: AppTheme.labelMediumPrimary),
            ],
          ),
          const SizedBox(height: 3),
          Text(value, style: AppTheme.valueMedium),
        ],
      ),
    );
  }
}

/// 进度条
class _ProgressBar extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final int value;
  final Color color;

  const _ProgressBar({
    required this.icon,
    required this.iconColor,
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
        borderRadius: BorderRadius.all(Radius.circular(AppTheme.radiusSmall)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 14),
              const SizedBox(width: 4),
              Text(label, style: AppTheme.labelMediumPrimary),
              const Spacer(),
              Text('$value%',
                  style: AppTheme.valueSmall.copyWith(color: color)),
            ],
          ),
          const SizedBox(height: 6),
          Stack(
            children: [
              Container(
                height: 10,
                decoration: const BoxDecoration(
                  color: AppTheme.slateGray,
                  borderRadius: BorderRadius.all(Radius.circular(3)),
                ),
              ),
              FractionallySizedBox(
                widthFactor: value / 100,
                child: Container(
                  height: 10,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
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
    // 将倾角转为带符号的度数：左倾为负，右倾为正
    final signedAngle = angle == 0 ? 0 : (direction == 'LEFT' ? -angle : angle);

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: const BoxDecoration(
        color: AppTheme.backgroundDark30,
        borderRadius: BorderRadius.all(Radius.circular(AppTheme.radiusSmall)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.rotate_right, color: AppTheme.primary, size: 14),
              const SizedBox(width: 4),
              const Text('车辆倾角', style: AppTheme.labelMediumPrimary),
              const Spacer(),
              Row(
                children: [
                  Text('$angle°', style: AppTheme.valueSmall),
                  const SizedBox(width: 4),
                  Text(
                    angle == 0 ? '无' : (direction == 'LEFT' ? '左' : '右'),
                    style:
                        AppTheme.valueSmall.copyWith(color: AppTheme.primary),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          // 滚动刻度尺
          RepaintBoundary(
            child: SizedBox(
              height: 30,
              width: double.infinity,
              child: CustomPaint(
                painter: _LeanAngleRulerPainter(signedAngle: signedAngle),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 滚动刻度尺 Painter
class _LeanAngleRulerPainter extends CustomPainter {
  final int signedAngle; // 负=左倾，正=右倾，范围 -60~+60

  static const double _maxAngle = 60.0;
  static const double _fadeWidth = 18.0; // 边缘渐隐宽度

  // 渐隐遮罩 Paint 缓存（shader 依赖 size，首次或 size 变化时重建）
  Size? _cachedSize;
  Paint? _fadeLeftPaint;
  Paint? _fadeRightPaint;

  _LeanAngleRulerPainter({required this.signedAngle});

  Color get _activeColor {
    final abs = signedAngle.abs();
    if (abs >= 45) return Colors.red;
    if (abs >= 30) return AppTheme.accentOrange;
    return AppTheme.primary;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    // 每1度对应的像素
    final pixPerDeg = (w / 2) / _maxAngle;
    // 刻度尺整体向左偏移量（右倾时刻度左移，左倾时右移）
    final offset = -signedAngle * pixPerDeg;
    final center = w / 2;

    final mutedPaint = Paint()
      ..color = AppTheme.textMuted
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final activePaint = Paint()
      ..color = _activeColor
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    // 背景底线
    canvas.drawLine(
      Offset(0, h - 1),
      Offset(w, h - 1),
      Paint()
        ..color = AppTheme.primary30
        ..strokeWidth = 1.0,
    );

    // 绘制刻度线和标签（-70 到 +70 范围，超出画布的自动跳过）
    final textStyle = ui.TextStyle(
      color: AppTheme.textMuted,
      fontSize: 9,
    );

    for (int deg = -70; deg <= 70; deg += 10) {
      final x = center + offset + deg * pixPerDeg;
      if (x < -10 || x > w + 10) continue;

      final isMajor = deg % 30 == 0;
      final isZero = deg == 0;
      final lineH = isZero ? 18.0 : (isMajor ? 14.0 : 9.0);
      final paint = (isZero || isMajor) ? activePaint : mutedPaint;

      canvas.drawLine(Offset(x, 0), Offset(x, lineH), paint);

      // 主刻度标签
      if (isMajor) {
        final label = deg == 0 ? '0°' : '${deg.abs()}°';
        final pb = ui.ParagraphBuilder(ui.ParagraphStyle(
          textAlign: TextAlign.center,
          fontSize: 9,
        ))
          ..pushStyle(textStyle)
          ..addText(label);
        final paragraph = pb.build()
          ..layout(const ui.ParagraphConstraints(width: 28));
        canvas.drawParagraph(paragraph, Offset(x - 14, lineH + 1));
      }
    }

    // 激活区域高亮底线（从0到当前角度）
    if (signedAngle != 0) {
      final zeroX = center + offset;
      final currentX = center + offset + signedAngle * pixPerDeg;
      final highlightPaint = Paint()
        ..color = _activeColor.withOpacity(0.5)
        ..strokeWidth = 2.0;
      canvas.drawLine(
        Offset(zeroX.clamp(0.0, w), h - 1),
        Offset(currentX.clamp(0.0, w), h - 1),
        highlightPaint,
      );
    }

    // 左右边缘渐隐遮罩（缓存 shader，size 不变时直接复用）
    if (size != _cachedSize) {
      _cachedSize = size;
      const bgColor = AppTheme.backgroundDark30;
      _fadeLeftPaint = Paint()
        ..shader = const LinearGradient(
          colors: [bgColor, Color(0x00000000)],
        ).createShader(Rect.fromLTWH(0, 0, _fadeWidth, h));
      _fadeRightPaint = Paint()
        ..shader = const LinearGradient(
          colors: [Color(0x00000000), bgColor],
        ).createShader(Rect.fromLTWH(w - _fadeWidth, 0, _fadeWidth, h));
    }
    canvas.drawRect(Rect.fromLTWH(0, 0, _fadeWidth, h), _fadeLeftPaint!);
    canvas.drawRect(
        Rect.fromLTWH(w - _fadeWidth, 0, _fadeWidth, h), _fadeRightPaint!);

    // 中央固定指针（倒三角 ▼）
    const pointerW = 8.0;
    const pointerH = 6.0;
    final pointerColor = _activeColor;
    final pointerPaint = Paint()
      ..color = pointerColor
      ..style = PaintingStyle.fill;
    final glowPaint = Paint()
      ..color = pointerColor.withOpacity(0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);
    final path = Path()
      ..moveTo(center - pointerW / 2, 0)
      ..lineTo(center + pointerW / 2, 0)
      ..lineTo(center, pointerH)
      ..close();
    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, pointerPaint);
  }

  @override
  bool shouldRepaint(_LeanAngleRulerPainter old) =>
      old.signedAngle != signedAngle;
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
        borderRadius: BorderRadius.all(Radius.circular(AppTheme.radiusSmall)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.compress, color: AppTheme.primary, size: 14),
              const SizedBox(width: 4),
              const Text('进气歧管压力', style: AppTheme.labelMediumPrimary),
              const Spacer(),
              Text('$pressure kPa', style: AppTheme.valueSmall),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 36,
            child: CustomPaint(
              size: const Size(double.infinity, 36),
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

/// 气压图表绘制器（柱状图，最近30个点，全直角矩形柱）
class PressureChartPainter extends CustomPainter {
  final List<int> pressureHistory;
  final int minPressure;
  final int maxPressure;

  static const int _maxBars = 30;
  static const double _gap = 1.5;

  PressureChartPainter({
    required this.pressureHistory,
    required this.minPressure,
    required this.maxPressure,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (pressureHistory.isEmpty) return;

    final width = size.width;
    final height = size.height;

    // 取最后 30 个点
    final start = math.max(0, pressureHistory.length - _maxBars);
    final data = pressureHistory.sublist(start);
    final count = data.length;

    // 计算柱宽
    final totalGap = _gap * (count - 1);
    final barW = (width - totalGap) / count;
    final range = (maxPressure - minPressure).toDouble();

    // 底部基线
    final baselinePaint = Paint()
      ..color = AppTheme.primary30
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(0, height), Offset(width, height), baselinePaint);

    // 柱子渐变画笔：共享一个覆盖整个画布高度的 shader，避免逐柱重建
    // 竖向渐变从 Y=0（primary）到 Y=height（primary30），所有普通柱子共用
    final sharedShader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [AppTheme.primary, AppTheme.primary30],
    ).createShader(Rect.fromLTWH(0, 0, 1, height));

    final barPaint = Paint()..shader = sharedShader;
    final lastBarPaint = Paint()..color = AppTheme.primary;
    final glowPaint = Paint()
      ..color = const Color(0x72006EAF) // AppTheme.primary.withOpacity(0.45) 预算
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);

    for (int i = 0; i < count; i++) {
      final left = i * (barW + _gap);
      final normalized = (data[i] - minPressure) / range;
      final barH = normalized * height;
      final top = height - barH;
      final rect = Rect.fromLTWH(left, top, barW, barH);

      // 最新一根柱子（最右侧）高亮发光
      if (i == count - 1) {
        canvas.drawRect(rect, glowPaint);
        canvas.drawRect(rect, lastBarPaint);
      } else {
        canvas.drawRect(rect, barPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant PressureChartPainter oldDelegate) {
    // pressureHistory 是原地修改的同一 List 实例，last 比较无效，直接返回 true
    return true;
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
        borderRadius: BorderRadius.all(Radius.circular(AppTheme.radiusSmall)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Row(
            children: [
              Icon(Icons.battery_charging_full,
                  color: AppTheme.accentGreen, size: 14),
              SizedBox(width: 4),
              Text('控制模块电压', style: AppTheme.labelMediumPrimary),
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
