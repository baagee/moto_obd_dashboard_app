import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/obd_data_provider.dart';
import '../../providers/settings_provider.dart';
import '../../theme/app_fonts.dart';
import '../../theme/app_theme.dart';
import '../danger_pulse_overlay.dart';

// ───────────────────────────────────────────────
// 经典风格档位指示器（两表中间上方）
// ───────────────────────────────────────────────
class ClassicGearIndicator extends StatelessWidget {
  const ClassicGearIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final gear = context.select<OBDDataProvider, int>((p) => p.data.gear);
    final isNeutral = gear == 0;
    final glowColor = isNeutral ? AppTheme.gaugeWarn : AppTheme.gaugeNormal;
    final displayText = isNeutral ? 'N' : '$gear';

    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: AppTheme.surface50,
        border: Border.all(
          color: glowColor.withValues(alpha: 0.85),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: glowColor.withValues(alpha: 0.55),
            blurRadius: 8,
            spreadRadius: -1,
          ),
          BoxShadow(
            color: glowColor.withValues(alpha: 0.20),
            blurRadius: 18,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'GEAR',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
              color: AppTheme.primary.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 1),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            transitionBuilder: (child, anim) => ScaleTransition(
              scale: anim,
              child: FadeTransition(opacity: anim, child: child),
            ),
            child: Text(
              displayText,
              key: ValueKey(gear),
              style: AppFonts.displayStyle(
                fontSize: 32,
                color: glowColor,
              ).copyWith(
                shadows: [
                  Shadow(color: glowColor, blurRadius: 10),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────────────────────────
// 常量：270° 弧，起始于左下 135°（逆时针修正后）
// ───────────────────────────────────────────────
const double _startAngleDeg = 135.0;
const double _sweepAngleDeg = 270.0;

const double _startAngleRad = _startAngleDeg * pi / 180;
const double _sweepAngleRad = _sweepAngleDeg * pi / 180;

// 图片路径（两表共用同一份素材）
const _bgPath = 'assets/gauges/classic/bg.png';
const _pointerPath = 'assets/gauges/classic/pointer.png';

// ───────────────────────────────────────────────
// 图片解码共享缓存：两个表共用同一份解码结果，避免重复解码
// ───────────────────────────────────────────────
final Map<String, Future<ui.Image>> _imageCache = {};

Future<ui.Image> _loadSharedImage(String assetPath) {
  return _imageCache.putIfAbsent(assetPath, () async {
    final data = await rootBundle.load(assetPath);
    final bytes = data.buffer.asUint8List();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  });
}

// ───────────────────────────────────────────────
// 经典仪表盘布局（屏幕平分两半）
// ───────────────────────────────────────────────
class ClassicDashboardLayout extends StatelessWidget {
  const ClassicDashboardLayout({super.key});

  @override
  Widget build(BuildContext context) {
    // 危险状态：RPM 或速度超过 danger 阈值时触发呼吸闪烁
    // select 监听 bool 翻转，数据每帧变化不会导致布局重建
    final dangerRpm = context.select<SettingsProvider, int>((s) => s.dangerRpm);
    final dangerSpeed =
        context.select<SettingsProvider, int>((s) => s.dangerSpeed);
    final rpmDanger = context
        .select<OBDDataProvider, bool>((p) => p.data.rpm > dangerRpm);
    final speedDanger = context
        .select<OBDDataProvider, bool>((p) => p.data.speed > dangerSpeed);

    return Stack(
      children: [
        // 底层：两个仪表盘（保持原样）
        const Row(
          children: [
            Expanded(child: ClassicGaugeWidget(type: GaugeType.rpm)),
            Expanded(child: ClassicGaugeWidget(type: GaugeType.speed)),
          ],
        ),
        // 危险状态呼吸闪烁（红框包围整个双表区域）
        Positioned.fill(
          child: DangerPulseOverlay(danger: rpmDanger || speedDanger),
        ),
        // 顶层：档位指示器，水平居中，距底部 12dp
        const Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: ClassicGearIndicator(),
          ),
        ),
      ],
    );
  }
}

// ───────────────────────────────────────────────
// 仪表盘类型
// ───────────────────────────────────────────────
enum GaugeType { rpm, speed }

// ───────────────────────────────────────────────
// 单个经典仪表盘 Widget
// ───────────────────────────────────────────────
class ClassicGaugeWidget extends StatefulWidget {
  final GaugeType type;

  const ClassicGaugeWidget({super.key, required this.type});

  @override
  State<ClassicGaugeWidget> createState() => _ClassicGaugeWidgetState();
}

class _ClassicGaugeWidgetState extends State<ClassicGaugeWidget>
    with SingleTickerProviderStateMixin {
  // ── 图片资源 ──
  ui.Image? _bgImage;
  ui.Image? _pointerImage;
  bool _loading = true;
  String? _error;

  // ── 自检动画 ──
  late AnimationController _checkCtrl;
  late Animation<double> _riseAnim; // 0 → maxValue
  late Animation<double> _fallAnim; // maxValue → 0
  bool _selfCheckDone = false;
  int _maxValueCache = 0; // 图片加载完成时缓存 maxValue 用于动画

  @override
  void initState() {
    super.initState();
    _checkCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _loadImages();
  }

  @override
  void dispose() {
    _checkCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadImages() async {
    try {
      final results = await Future.wait([
        _loadSharedImage(_bgPath),
        _loadSharedImage(_pointerPath),
      ]);
      if (!mounted) return;

      // 图片加载完成后读取 maxValue 并初始化动画
      final settings = context.read<SettingsProvider>();
      final maxValue = widget.type == GaugeType.rpm
          ? settings.maxRpm.toDouble()
          : settings.maxSpeed.toDouble();
      _maxValueCache = maxValue.toInt();

      _riseAnim = Tween<double>(begin: 0, end: maxValue).animate(
        CurvedAnimation(
          parent: _checkCtrl,
          curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
        ),
      );
      _fallAnim = Tween<double>(begin: maxValue, end: 0).animate(
        CurvedAnimation(
          parent: _checkCtrl,
          curve: const Interval(0.6, 1.0, curve: Curves.easeIn),
        ),
      );

      setState(() {
        _bgImage = results[0];
        _pointerImage = results[1];
        _loading = false;
      });

      // 图片就绪后延迟 350ms 启动自检
      Future.delayed(const Duration(milliseconds: 350), () {
        _checkCtrl.forward().whenComplete(() {
          if (mounted) setState(() => _selfCheckDone = true);
        });
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  // 自检阶段的模拟值
  int get _selfCheckValue {
    if (_checkCtrl.value <= 0.6) return _riseAnim.value.round();
    return _fallAnim.value.round();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppTheme.primary,
          strokeWidth: 2,
        ),
      );
    }

    if (_error != null || _bgImage == null || _pointerImage == null) {
      return Center(
        child: Text(
          _error ?? '图片加载失败',
          style: const TextStyle(color: AppTheme.gaugeDanger, fontSize: 12),
        ),
      );
    }

    // 精确订阅：仅本表关心的字段变化才触发重建
    final isRpm = widget.type == GaugeType.rpm;
    final obdValue = context.select<OBDDataProvider, int>(
        (p) => isRpm ? p.data.rpm : p.data.speed);
    final maxValue = context.select<SettingsProvider, int>(
        (s) => isRpm ? s.maxRpm : s.maxSpeed);
    final warnValue = context.select<SettingsProvider, int>(
        (s) => isRpm ? s.warnRpm : s.warnSpeed);
    final dangerValue = context.select<SettingsProvider, int>(
        (s) => isRpm ? s.dangerRpm : s.dangerSpeed);
    final unit = isRpm ? 'rpm' : 'km/h';

    return LayoutBuilder(
      builder: (context, constraints) {
        // 以高度为基准撑满可视区域，保留刻度标签边距
        final availableSize =
            constraints.maxHeight.clamp(0.0, constraints.maxWidth);
        // 增大半径到 1.14，并下移中心点到 53% 高度位置
        final radius = availableSize / 2 * 1.13;
        final cx = constraints.maxWidth / 2;
        final cy = constraints.maxHeight * 0.58; // 下移中心
        final center = Offset(cx, cy);
        final size = Size(constraints.maxWidth, constraints.maxHeight);

        // 静态层：背景图 + 弧道 + 刻度，仅量程设置/尺寸变化时重绘
        final staticLayer = CustomPaint(
          size: size,
          painter: _ClassicGaugeStaticPainter(
            bgImage: _bgImage!,
            maxValue: maxValue,
            warnValue: warnValue,
            dangerValue: dangerValue,
            center: center,
            radius: radius,
            isRpm: isRpm,
          ),
        );

        // 自检阶段用动画值，完成后用真实 OBD 值
        if (!_selfCheckDone) {
          return Stack(
            children: [
              staticLayer,
              RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _checkCtrl,
                  builder: (context, _) {
                    return CustomPaint(
                      size: size,
                      painter: _ClassicGaugeDynamicPainter(
                        pointerImage: _pointerImage!,
                        value: _selfCheckValue,
                        maxValue:
                            _maxValueCache > 0 ? _maxValueCache : maxValue,
                        warnValue: warnValue,
                        dangerValue: dangerValue,
                        center: center,
                        radius: radius,
                        unit: unit,
                        isRpm: isRpm,
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        }

        return Stack(
          children: [
            staticLayer,
            // 动态层：指针（手）+ 数值，独立图层不波及静态层
            RepaintBoundary(
              child: CustomPaint(
                size: size,
                painter: _ClassicGaugeDynamicPainter(
                  pointerImage: _pointerImage!,
                  value: obdValue,
                  maxValue: maxValue,
                  warnValue: warnValue,
                  dangerValue: dangerValue,
                  center: center,
                  radius: radius,
                  unit: unit,
                  isRpm: isRpm,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ───────────────────────────────────────────────
// 共享绘制辅助函数
// ───────────────────────────────────────────────

/// 值到角度的线性映射（270° 弧）
double _valueToAngle(double v, int maxValue) {
  final ratio = (v / maxValue).clamp(0.0, 1.0);
  return _startAngleRad + ratio * _sweepAngleRad;
}

/// 计算最优主刻度步长，使刻度值为整洁数（如 1000、2000 或 24、48）
int _calcTickStep(int max) {
  const int targetCount = 10;
  final rawStep = max / targetCount;
  final magnitude =
      pow(10, (log(rawStep) / log(10)).floor()).toInt().clamp(1, max);
  final candidates = [
    magnitude,
    magnitude * 2,
    magnitude * 5,
    magnitude * 10,
  ];
  for (final step in candidates) {
    if (step > 0 && max % step == 0) {
      final count = max ~/ step;
      if (count >= 6 && count <= 14) return step;
    }
  }
  // 兜底：取第二候选（2×magnitude）
  return (magnitude * 2).clamp(1, max);
}

/// 区间语义色：正常-青 / 警告-琥珀 / 危险-红
Color _zoneColor(double tickValue, int warnValue, int dangerValue) {
  if (tickValue >= dangerValue) return AppTheme.gaugeDanger;
  if (tickValue >= warnValue) return AppTheme.gaugeWarn;
  return AppTheme.gaugeNormal;
}

/// 文本绘制（居中于指定点）
void _drawGaugeText(
  Canvas canvas,
  String text,
  Offset center, {
  required Color color,
  required double fontSize,
  FontWeight fontWeight = FontWeight.normal,
  String? fontFamily,
}) {
  final span = TextSpan(
    text: text,
    style: TextStyle(
      color: color,
      fontSize: fontSize,
      fontWeight: fontWeight,
      fontFamily: fontFamily,
    ),
  );
  final painter = TextPainter(text: span, textDirection: TextDirection.ltr)
    ..layout();
  painter.paint(
      canvas, center - Offset(painter.width / 2, painter.height / 2));
}

// ───────────────────────────────────────────────
// 静态层 Painter：背景图（乌鸦哥）+ 弧道 + 刻度线/标签
// 仅量程设置/尺寸变化时重绘，正常骑行吃图层缓存
// ───────────────────────────────────────────────
class _ClassicGaugeStaticPainter extends CustomPainter {
  final ui.Image bgImage;
  final int maxValue;
  final int warnValue;
  final int dangerValue;
  final Offset center;
  final double radius;
  final bool isRpm;

  // 刻度参数
  static const int _subTickPerMain = 5;
  static const double _mainTickLenRatio = 0.10;
  static const double _subTickLenRatio = 0.055;
  static const double _tickInnerRatio = 0.82;
  static const double _labelRadiusRatio = 0.68;

  _ClassicGaugeStaticPainter({
    required this.bgImage,
    required this.maxValue,
    required this.warnValue,
    required this.dangerValue,
    required this.center,
    required this.radius,
    this.isRpm = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // ── 1. 背景图 ──
    final bgSide = radius * 1.2;
    final bgRect =
        Rect.fromCenter(center: center, width: bgSide, height: bgSide);
    final bgSrc = Rect.fromLTWH(
        0, 0, bgImage.width.toDouble(), bgImage.height.toDouble());
    canvas.drawImageRect(bgImage, bgSrc, bgRect, Paint());

    // ── 2. 分段弧形轨道 ──
    _drawArcTrack(canvas);

    // ── 3. 刻度线 + 数值标签 ──
    _drawTicks(canvas);
  }

  void _drawArcTrack(Canvas canvas) {
    // 轨道半径：紧贴主刻度线外端稍外移
    final trackRadius = radius * (_tickInnerRatio + _mainTickLenRatio + 0.03);
    final trackStrokeWidth = (radius * 0.045).clamp(3.0, 8.0);

    final arcRect = Rect.fromCenter(
      center: center,
      width: trackRadius * 2,
      height: trackRadius * 2,
    );

    final normalEnd = _valueToAngle(warnValue.toDouble(), maxValue);
    final warnEnd = _valueToAngle(dangerValue.toDouble(), maxValue);
    final dangerEnd = _valueToAngle(maxValue.toDouble(), maxValue);

    final segments = [
      (_startAngleRad, normalEnd, AppTheme.gaugeNormal, 0.55),
      (normalEnd, warnEnd, AppTheme.gaugeWarn, 0.55),
      (warnEnd, dangerEnd, AppTheme.gaugeDanger, 0.55),
    ];

    for (final seg in segments) {
      final start = seg.$1;
      final end = seg.$2;
      final color = seg.$3;
      final alpha = seg.$4;
      final sweep = end - start;
      if (sweep <= 0) continue;

      // 底层：发光散射
      canvas.drawArc(
        arcRect,
        start,
        sweep,
        false,
        Paint()
          ..color = color.withValues(alpha: alpha * 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = trackStrokeWidth * 2.5
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );

      // 上层：清晰轨道线
      canvas.drawArc(
        arcRect,
        start,
        sweep,
        false,
        Paint()
          ..color = color.withValues(alpha: alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = trackStrokeWidth
          ..strokeCap = StrokeCap.butt,
      );
    }
  }

  void _drawTicks(Canvas canvas) {
    final step = _calcTickStep(maxValue);
    final tickCount = maxValue ~/ step;

    final mainOuter = radius * (_tickInnerRatio + _mainTickLenRatio);
    final mainInner = radius * _tickInnerRatio;
    final subOuter = radius * (_tickInnerRatio + _subTickLenRatio);
    final subInner = radius * _tickInnerRatio;

    for (int i = 0; i <= tickCount; i++) {
      final tickValue = (step * i).toDouble();
      final angle = _valueToAngle(tickValue, maxValue);
      final color = _zoneColor(tickValue, warnValue, dangerValue);

      canvas.drawLine(
        Offset(center.dx + mainInner * cos(angle),
            center.dy + mainInner * sin(angle)),
        Offset(center.dx + mainOuter * cos(angle),
            center.dy + mainOuter * sin(angle)),
        Paint()
          ..color = color
          ..strokeWidth = 2.0
          ..strokeCap = StrokeCap.round,
      );

      final labelR = radius * _labelRadiusRatio;
      final labelFontSize = (radius * 0.25).clamp(10.0, 20.0);
      // rpm 刻度标签除以 1000 显示（1、2、3...12），speed 直接显示原值
      final labelText =
          isRpm ? (tickValue ~/ 1000).toString() : tickValue.toInt().toString();
      _drawGaugeText(
        canvas,
        labelText,
        Offset(
            center.dx + labelR * cos(angle), center.dy + labelR * sin(angle)),
        color: color.withValues(alpha: 0.9),
        fontSize: labelFontSize,
        fontWeight: FontWeight.bold,
        fontFamily: AppFonts.mono,
      );

      // 副刻度：步长可被 _subTickPerMain 整除时才绘制
      if (i < tickCount) {
        final subStep = step / _subTickPerMain;
        for (int j = 1; j < _subTickPerMain; j++) {
          final subValue = tickValue + subStep * j;
          final subAngle = _valueToAngle(subValue, maxValue);
          final subColor = _zoneColor(subValue, warnValue, dangerValue);
          canvas.drawLine(
            Offset(center.dx + subInner * cos(subAngle),
                center.dy + subInner * sin(subAngle)),
            Offset(center.dx + subOuter * cos(subAngle),
                center.dy + subOuter * sin(subAngle)),
            Paint()
              ..color = subColor.withValues(alpha: 0.6)
              ..strokeWidth = 1.0
              ..strokeCap = StrokeCap.round,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ClassicGaugeStaticPainter old) {
    return old.bgImage != bgImage ||
        old.maxValue != maxValue ||
        old.warnValue != warnValue ||
        old.dangerValue != dangerValue ||
        old.radius != radius ||
        old.center != center ||
        old.isRpm != isRpm;
  }
}

// ───────────────────────────────────────────────
// 动态层 Painter：指针（招手手臂）+ 当前数值
// 每帧仅重绘本层，背景/刻度由静态层缓存
// ───────────────────────────────────────────────
class _ClassicGaugeDynamicPainter extends CustomPainter {
  final ui.Image pointerImage;
  final int value;
  final int maxValue;
  final int warnValue;
  final int dangerValue;
  final Offset center;
  final double radius;
  final String unit;
  final bool isRpm;

  // 指针参数
  static const double _pointerLenRatio = 0.82;
  static const double _pointerMaxWidthRatio = 0.33;

  _ClassicGaugeDynamicPainter({
    required this.pointerImage,
    required this.value,
    required this.maxValue,
    required this.warnValue,
    required this.dangerValue,
    required this.center,
    required this.radius,
    required this.unit,
    this.isRpm = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // ── 1. 指针 ──
    _drawPointer(canvas);

    // ── 2. 当前数值（圆心正下方）──
    _drawValueText(canvas);
  }

  void _drawPointer(Canvas canvas) {
    final angle = _valueToAngle(value.toDouble(), maxValue);
    final pointerLen = radius * _pointerLenRatio;

    final imgW = pointerImage.width.toDouble();
    final imgH = pointerImage.height.toDouble();
    final ratioW = pointerLen * (imgW / imgH);
    final maxW = radius * _pointerMaxWidthRatio;
    final pointerW = ratioW.clamp(0.0, maxW);

    final srcRect = Rect.fromLTWH(0, 0, imgW, imgH);
    final dstRect =
        Rect.fromLTWH(-pointerW / 2, -pointerLen, pointerW, pointerLen);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle + pi / 2);
    canvas.drawImageRect(pointerImage, srcRect, dstRect, Paint());
    canvas.restore();
  }

  void _drawValueText(Canvas canvas) {
    final valueFontSize = (radius * 0.2).clamp(14.0, 32.0);
    final unitFontSize = (radius * 0.1).clamp(9.0, 16.0);

    final Color valueColor;
    if (value >= dangerValue) {
      valueColor = AppTheme.gaugeDanger;
    } else if (value >= warnValue) {
      valueColor = AppTheme.gaugeWarn;
    } else {
      valueColor = AppTheme.textPrimary;
    }

    final valueY = center.dy + radius * 0.50;
    final unitY = valueY + valueFontSize * 0.9;

    // rpm 显示实际值；单位行加 ×1000 标识
    final displayUnit = isRpm ? '×1000  $unit' : unit;

    _drawGaugeText(
      canvas,
      value.toString(),
      Offset(center.dx, valueY),
      color: valueColor,
      fontSize: valueFontSize,
      fontWeight: FontWeight.bold,
      fontFamily: AppFonts.display,
    );
    _drawGaugeText(
      canvas,
      displayUnit,
      Offset(center.dx, unitY),
      color: AppTheme.textSecondary,
      fontSize: unitFontSize,
      fontWeight: FontWeight.w500,
    );
  }

  @override
  bool shouldRepaint(covariant _ClassicGaugeDynamicPainter old) {
    return old.pointerImage != pointerImage ||
        old.value != value ||
        old.maxValue != maxValue ||
        old.warnValue != warnValue ||
        old.dangerValue != dangerValue ||
        old.radius != radius ||
        old.center != center ||
        old.isRpm != isRpm;
  }
}
