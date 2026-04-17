import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/obd_data_provider.dart';
import '../../providers/settings_provider.dart';
import '../../theme/app_theme.dart';

// ───────────────────────────────────────────────
// 常量：270° 弧，起始于左下 135°（逆时针修正后）
// ───────────────────────────────────────────────
const double _startAngleDeg = 135.0;
const double _sweepAngleDeg = 270.0;

const double _startAngleRad = _startAngleDeg * pi / 180;
const double _sweepAngleRad = _sweepAngleDeg * pi / 180;

// 图片路径（写死）
const _bgPaths = {
  'rpm': 'assets/gauges/classic/rpm_bg.png',
  'speed': 'assets/gauges/classic/speed_bg.png',
};
const _pointerPaths = {
  'rpm': 'assets/gauges/classic/rpm_pointer.png',
  'speed': 'assets/gauges/classic/speed_pointer.png',
};

// ───────────────────────────────────────────────
// 经典仪表盘布局（屏幕平分两半）
// ───────────────────────────────────────────────
class ClassicDashboardLayout extends StatelessWidget {
  const ClassicDashboardLayout({super.key});

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: ClassicGaugeWidget(type: GaugeType.rpm)),
        Expanded(child: ClassicGaugeWidget(type: GaugeType.speed)),
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
    final key = widget.type == GaugeType.rpm ? 'rpm' : 'speed';
    try {
      final results = await Future.wait([
        _loadImage(_bgPaths[key]!),
        _loadImage(_pointerPaths[key]!),
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

  Future<ui.Image> _loadImage(String assetPath) async {
    final data = await rootBundle.load(assetPath);
    final bytes = data.buffer.asUint8List();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
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
          style: const TextStyle(color: AppTheme.accentRed, fontSize: 12),
        ),
      );
    }

    // 从 Provider 读取数据
    final settings = context.watch<SettingsProvider>();
    final obd = context.watch<OBDDataProvider>();

    final int obdValue;
    final int maxValue;
    final int warnValue;
    final int dangerValue;
    final String unit;

    if (widget.type == GaugeType.rpm) {
      obdValue = obd.data.rpm;
      maxValue = settings.maxRpm;
      warnValue = settings.warnRpm;
      dangerValue = settings.dangerRpm;
      unit = 'rpm';
    } else {
      obdValue = obd.data.speed;
      maxValue = settings.maxSpeed;
      warnValue = settings.warnSpeed;
      dangerValue = settings.dangerSpeed;
      unit = 'km/h';
    }

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

        // 自检阶段用动画值，完成后用真实 OBD 值
        if (!_selfCheckDone) {
          return AnimatedBuilder(
            animation: _checkCtrl,
            builder: (context, _) {
              return CustomPaint(
                size: Size(constraints.maxWidth, constraints.maxHeight),
                painter: _ClassicGaugePainter(
                  bgImage: _bgImage!,
                  pointerImage: _pointerImage!,
                  value: _selfCheckValue,
                  maxValue: _maxValueCache > 0 ? _maxValueCache : maxValue,
                  warnValue: warnValue,
                  dangerValue: dangerValue,
                  center: center,
                  radius: radius,
                  unit: unit,
                ),
              );
            },
          );
        }

        return CustomPaint(
          size: Size(constraints.maxWidth, constraints.maxHeight),
          painter: _ClassicGaugePainter(
            bgImage: _bgImage!,
            pointerImage: _pointerImage!,
            value: obdValue,
            maxValue: maxValue,
            warnValue: warnValue,
            dangerValue: dangerValue,
            center: center,
            radius: radius,
            unit: unit,
          ),
        );
      },
    );
  }
}

// ───────────────────────────────────────────────
// 经典仪表盘 CustomPainter
// ───────────────────────────────────────────────
class _ClassicGaugePainter extends CustomPainter {
  final ui.Image bgImage;
  final ui.Image pointerImage;
  final int value;
  final int maxValue;
  final int warnValue;
  final int dangerValue;
  final Offset center;
  final double radius;
  final String unit;

  // 刻度参数
  static const int _mainTickCount = 10;
  static const int _subTickPerMain = 5;
  static const double _mainTickLenRatio = 0.10;
  static const double _subTickLenRatio = 0.055;
  static const double _tickInnerRatio = 0.82;
  static const double _labelRadiusRatio = 0.68;

  // 指针参数
  static const double _pointerLenRatio = 0.82;
  static const double _pointerMaxWidthRatio = 0.33;

  _ClassicGaugePainter({
    required this.bgImage,
    required this.pointerImage,
    required this.value,
    required this.maxValue,
    required this.warnValue,
    required this.dangerValue,
    required this.center,
    required this.radius,
    required this.unit,
  });

  double _valueToAngle(double v) {
    final ratio = (v / maxValue).clamp(0.0, 1.0);
    return _startAngleRad + ratio * _sweepAngleRad;
  }

  Color _tickColor(double tickValue) {
    if (tickValue >= dangerValue) return AppTheme.accentRed;
    if (tickValue >= warnValue) return AppTheme.accentOrange;
    return AppTheme.primary;
  }

  @override
  void paint(Canvas canvas, Size size) {
    // ── 1. 背景图 ──
    final bgSide = radius * 1.2;
    final bgRect =
        Rect.fromCenter(center: center, width: bgSide, height: bgSide);
    final bgSrc = Rect.fromLTWH(
        0, 0, bgImage.width.toDouble(), bgImage.height.toDouble());
    canvas.drawImageRect(bgImage, bgSrc, bgRect, Paint());

    // ── 2. 刻度线 + 数值标签 ──
    _drawTicks(canvas);

    // ── 3. 指针 ──
    _drawPointer(canvas);

    // ── 4. 当前数值（圆心正下方）──
    _drawValueText(canvas);
  }

  void _drawTicks(Canvas canvas) {
    final mainOuter = radius * (_tickInnerRatio + _mainTickLenRatio);
    final mainInner = radius * _tickInnerRatio;
    final subOuter = radius * (_tickInnerRatio + _subTickLenRatio);
    final subInner = radius * _tickInnerRatio;

    for (int i = 0; i <= _mainTickCount; i++) {
      final tickValue = (maxValue * i / _mainTickCount).roundToDouble();
      final angle = _valueToAngle(tickValue);
      final color = _tickColor(tickValue);

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
      // 控制刻度标签字体大小
      final labelFontSize = (radius * 0.18).clamp(8.0, 14.0);
      _drawText(
        canvas,
        tickValue.toInt().toString(),
        Offset(
            center.dx + labelR * cos(angle), center.dy + labelR * sin(angle)),
        color: color.withValues(alpha: 0.9),
        fontSize: labelFontSize,
        fontWeight: FontWeight.bold,
      );

      if (i < _mainTickCount) {
        for (int j = 1; j < _subTickPerMain; j++) {
          final subValue =
              tickValue + (maxValue * j / (_mainTickCount * _subTickPerMain));
          final subAngle = _valueToAngle(subValue);
          final subColor = _tickColor(subValue);
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

  void _drawPointer(Canvas canvas) {
    final angle = _valueToAngle(value.toDouble());
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
    final valueFontSize = (radius * 0.18).clamp(14.0, 32.0);
    final unitFontSize = (radius * 0.09).clamp(9.0, 16.0);

    final Color valueColor;
    if (value >= dangerValue) {
      valueColor = AppTheme.accentRed;
    } else if (value >= warnValue) {
      valueColor = AppTheme.accentOrange;
    } else {
      valueColor = AppTheme.textPrimary;
    }

    final valueY = center.dy + radius * 0.45;
    final unitY = valueY + valueFontSize * 0.9;

    _drawText(canvas, value.toString(), Offset(center.dx, valueY),
        color: valueColor,
        fontSize: valueFontSize,
        fontWeight: FontWeight.bold);
    _drawText(canvas, unit, Offset(center.dx, unitY),
        color: AppTheme.textSecondary,
        fontSize: unitFontSize,
        fontWeight: FontWeight.w500);
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset center, {
    required Color color,
    required double fontSize,
    FontWeight fontWeight = FontWeight.normal,
  }) {
    final span = TextSpan(
      text: text,
      style:
          TextStyle(color: color, fontSize: fontSize, fontWeight: fontWeight),
    );
    final painter = TextPainter(text: span, textDirection: TextDirection.ltr)
      ..layout();
    painter.paint(
        canvas, center - Offset(painter.width / 2, painter.height / 2));
  }

  @override
  bool shouldRepaint(covariant _ClassicGaugePainter old) {
    return old.value != value ||
        old.maxValue != maxValue ||
        old.warnValue != warnValue ||
        old.dangerValue != dangerValue ||
        old.radius != radius ||
        old.center != center;
  }
}
