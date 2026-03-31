import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';

// ═══════════════════════════════════════════════
// 通用设置字段 Widget 集合（水平两栏紧凑布局）
// 左侧：标签 + 默认值 + hint 描述
// 右侧：控件（输入框 / 开关 / 当前值）
// ═══════════════════════════════════════════════

/// 数字输入字段（带增减箭头）
class SettingsNumberField extends StatefulWidget {
  final String label;
  final String? hint;
  final String? unit;
  final double currentValue;
  final double defaultValue;
  final double? minValue;
  final double? maxValue;
  final int decimalPlaces;
  final double step;
  final ValueChanged<double> onChanged;

  const SettingsNumberField({
    super.key,
    required this.label,
    this.hint,
    this.unit,
    required this.currentValue,
    required this.defaultValue,
    this.minValue,
    this.maxValue,
    this.decimalPlaces = 0,
    this.step = 1,
    required this.onChanged,
  });

  @override
  State<SettingsNumberField> createState() => _SettingsNumberFieldState();
}

class _SettingsNumberFieldState extends State<SettingsNumberField> {
  late TextEditingController _controller;
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _format(widget.currentValue));
  }

  @override
  void didUpdateWidget(SettingsNumberField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_hasFocus && oldWidget.currentValue != widget.currentValue) {
      _controller.text = _format(widget.currentValue);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _format(double v) => widget.decimalPlaces == 0
      ? v.toInt().toString()
      : v.toStringAsFixed(widget.decimalPlaces);

  void _commit(String text) {
    final v = double.tryParse(text);
    if (v == null) {
      _controller.text = _format(widget.currentValue);
      return;
    }
    final clamped = _clamp(v);
    _controller.text = _format(clamped);
    if (clamped != widget.currentValue) widget.onChanged(clamped);
  }

  double _clamp(double v) {
    if (widget.minValue != null && v < widget.minValue!) {
      return widget.minValue!;
    }
    if (widget.maxValue != null && v > widget.maxValue!) {
      return widget.maxValue!;
    }
    return v;
  }

  void _increment() {
    final next = _clamp(widget.currentValue + widget.step);
    _controller.text = _format(next);
    widget.onChanged(next);
  }

  void _decrement() {
    final next = _clamp(widget.currentValue - widget.step);
    _controller.text = _format(next);
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── 左侧：标签 + 默认值 + hint ──
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(widget.label,
                        style: AppTheme.labelMedium.copyWith(fontSize: 13)),
                    const SizedBox(width: 6),
                    Text(
                      '默认: ${_format(widget.defaultValue)}',
                      style: const TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                if (widget.hint != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    widget.hint!,
                    style: const TextStyle(
                        color: AppTheme.textMuted, fontSize: 11),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          // ── 右侧：输入框 + 单位 ──
          _buildInput(),
          if (widget.unit != null) ...[
            const SizedBox(width: 4),
            Text(widget.unit!,
                style: AppTheme.labelMedium.copyWith(fontSize: 13)),
          ],
        ],
      ),
    );
  }

  Widget _buildInput() {
    return Container(
      width: 120,
      height: 34,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border.all(
          color: _hasFocus
              ? AppTheme.primary
              : AppTheme.primary.withValues(alpha: 0.35),
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      ),
      child: Row(
        children: [
          Expanded(
            child: Focus(
              onFocusChange: (f) => setState(() => _hasFocus = f),
              child: TextField(
                controller: _controller,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true, signed: false),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                ],
                decoration: const InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(vertical: 7, horizontal: 4),
                ),
                onSubmitted: _commit,
                onEditingComplete: () => _commit(_controller.text),
              ),
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ArrowButton(Icons.keyboard_arrow_up, onTap: _increment),
              _ArrowButton(Icons.keyboard_arrow_down, onTap: _decrement),
            ],
          ),
        ],
      ),
    );
  }
}

class _ArrowButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _ArrowButton(this.icon, {required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 18,
        height: 14,
        alignment: Alignment.center,
        child: Icon(icon, size: 12, color: AppTheme.primary),
      ),
    );
  }
}

// ───────────────────────────────────────────────

/// 开关字段
class SettingsToggleField extends StatelessWidget {
  final String label;
  final String? hint;
  final bool value;
  final ValueChanged<bool> onChanged;

  const SettingsToggleField({
    super.key,
    required this.label,
    this.hint,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── 左侧：标签 + hint ──
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: AppTheme.labelMedium.copyWith(fontSize: 13)),
                if (hint != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    hint!,
                    style: const TextStyle(
                        color: AppTheme.textMuted, fontSize: 11),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          // ── 右侧：Switch ──
          Transform.scale(
            scale: 0.8,
            child: Switch(
              value: value,
              activeColor: AppTheme.primary,
              inactiveTrackColor: AppTheme.primary.withValues(alpha: 0.2),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────────────────────────

/// Slider 字段
/// 布局：上方一行（标签 + 默认值 + 当前值），下方 Slider（hint 可选显示在标签下）
class SettingsSliderField extends StatelessWidget {
  final String label;
  final String? hint;
  final double value;
  final double defaultValue;
  final double min;
  final double max;
  final int? divisions;
  final String Function(double) valueFormatter;
  final ValueChanged<double> onChanged;

  const SettingsSliderField({
    super.key,
    required this.label,
    this.hint,
    required this.value,
    required this.defaultValue,
    required this.min,
    required this.max,
    this.divisions,
    required this.valueFormatter,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 顶部一行：标签 + 默认值 + 当前值
          Row(
            children: [
              Text(label, style: AppTheme.labelMedium.copyWith(fontSize: 13)),
              const SizedBox(width: 6),
              Text(
                '默认: ${valueFormatter(defaultValue)}',
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
              ),
              if (hint != null) ...[
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    hint!,
                    style: const TextStyle(
                        color: AppTheme.textMuted, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ] else
                const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  border: Border.all(
                      color: AppTheme.primary.withValues(alpha: 0.4)),
                ),
                child: Text(
                  valueFormatter(value),
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          // 赛博朋克分段式滑轨
          _CyberSlider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────────────────────────

/// 赛博朋克风格滑轨
/// 设计：细线轨道（激活/未激活双色）+ divisions 刻度短线 + 圆形滑块（外环 + 发光）
class _CyberSlider extends StatefulWidget {
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final ValueChanged<double> onChanged;

  const _CyberSlider({
    required this.value,
    required this.min,
    required this.max,
    this.divisions,
    required this.onChanged,
  });

  @override
  State<_CyberSlider> createState() => _CyberSliderState();
}

class _CyberSliderState extends State<_CyberSlider> {
  void _handlePos(Offset local, double width) {
    final ratio = (local.dx / width).clamp(0.0, 1.0);
    double v = widget.min + ratio * (widget.max - widget.min);
    if (widget.divisions != null && widget.divisions! > 0) {
      final step = (widget.max - widget.min) / widget.divisions!;
      v = (v / step).round() * step;
    }
    widget.onChanged(v.clamp(widget.min, widget.max));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (d) => _handlePos(d.localPosition, w),
        onHorizontalDragUpdate: (d) => _handlePos(d.localPosition, w),
        child: SizedBox(
          height: 24,
          width: w,
          child: CustomPaint(
            painter: _CyberSliderPainter(
              value: widget.value,
              min: widget.min,
              max: widget.max,
              divisions: widget.divisions,
            ),
          ),
        ),
      );
    });
  }
}

class _CyberSliderPainter extends CustomPainter {
  final double value;
  final double min;
  final double max;
  final int? divisions;

  const _CyberSliderPainter({
    required this.value,
    required this.min,
    required this.max,
    this.divisions,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final ratio = ((value - min) / (max - min)).clamp(0.0, 1.0);
    final cy = size.height / 2;
    final activeX = ratio * size.width;

    // ── 未激活轨道（全长细线）──
    canvas.drawLine(
      Offset(0, cy),
      Offset(size.width, cy),
      Paint()
        ..color = AppTheme.primary.withValues(alpha: 0.18)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );

    // ── 激活轨道 ──
    if (activeX > 0) {
      canvas.drawLine(
        Offset(0, cy),
        Offset(activeX, cy),
        Paint()
          ..color = AppTheme.primary
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
      canvas.drawLine(
        Offset(0, cy),
        Offset(activeX, cy),
        Paint()
          ..color = AppTheme.primary
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round,
      );
    }

    // ── 刻度短线（divisions 个间隔点）──
    if (divisions != null && divisions! > 0) {
      final tickPaint = Paint()
        ..strokeWidth = 1
        ..strokeCap = StrokeCap.round;
      for (int i = 0; i <= divisions!; i++) {
        final x = i / divisions! * size.width;
        final isActive = x <= activeX;
        tickPaint.color = isActive
            ? AppTheme.primary.withValues(alpha: 0.6)
            : AppTheme.primary.withValues(alpha: 0.2);
        canvas.drawLine(Offset(x, cy - 4), Offset(x, cy + 4), tickPaint);
      }
    }

    // ── 滑块：外环 + 发光 + 实心圆 + 内高光 ──
    const r = 7.0;
    final center = Offset(activeX, cy);

    // 发光
    canvas.drawCircle(
      center,
      r + 3,
      Paint()
        ..color = AppTheme.primary.withValues(alpha: 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    // 深色背景圆
    canvas.drawCircle(center, r, Paint()..color = const Color(0xFF0A1114));
    // 外环
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..color = AppTheme.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    // 内实心圆
    canvas.drawCircle(center, r * 0.45, Paint()..color = AppTheme.primary);
  }

  @override
  bool shouldRepaint(_CyberSliderPainter old) =>
      old.value != value ||
      old.min != min ||
      old.max != max ||
      old.divisions != divisions;
}

// ───────────────────────────────────────────────

/// 密码/文本输入字段（水平两栏）
class SettingsPasswordField extends StatefulWidget {
  final String label;
  final String? hint;
  final String currentValue;
  final ValueChanged<String> onChanged;

  const SettingsPasswordField({
    super.key,
    required this.label,
    this.hint,
    required this.currentValue,
    required this.onChanged,
  });

  @override
  State<SettingsPasswordField> createState() => _SettingsPasswordFieldState();
}

class _SettingsPasswordFieldState extends State<SettingsPasswordField> {
  late TextEditingController _controller;
  bool _obscure = true;
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentValue);
  }

  @override
  void didUpdateWidget(SettingsPasswordField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_hasFocus && oldWidget.currentValue != widget.currentValue) {
      _controller.text = widget.currentValue;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── 左侧：标签 + hint ──
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(widget.label,
                    style: AppTheme.labelMedium.copyWith(fontSize: 13)),
                if (widget.hint != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    widget.hint!,
                    style: const TextStyle(
                        color: AppTheme.textMuted, fontSize: 11),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          // ── 右侧：输入框（宽度固定，允许较长内容）──
          SizedBox(
            width: 200,
            height: 34,
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.surface,
                border: Border.all(
                  color: _hasFocus
                      ? AppTheme.primary
                      : AppTheme.primary.withValues(alpha: 0.35),
                ),
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Focus(
                      onFocusChange: (f) => setState(() => _hasFocus = f),
                      child: TextField(
                        controller: _controller,
                        obscureText: _obscure,
                        style: const TextStyle(
                            color: AppTheme.textPrimary, fontSize: 13),
                        decoration: const InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        ),
                        onChanged: widget.onChanged,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _obscure = !_obscure),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(
                        _obscure
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 16,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
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

/// 设置面板顶部提示横幅（统一样式）
enum SettingsBannerType { info, warning, danger }

class SettingsBanner extends StatelessWidget {
  final String message;
  final SettingsBannerType type;

  const SettingsBanner({
    super.key,
    required this.message,
    this.type = SettingsBannerType.info,
  });

  @override
  Widget build(BuildContext context) {
    final Color color;
    final IconData icon;
    switch (type) {
      case SettingsBannerType.info:
        color = AppTheme.primary;
        icon = Icons.info_outline;
      case SettingsBannerType.warning:
        color = AppTheme.accentOrange;
        icon = Icons.warning_amber_outlined;
      case SettingsBannerType.danger:
        color = AppTheme.accentRed;
        icon = Icons.warning_outlined;
    }

    return Container(
      padding: const EdgeInsets.all(10),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: color, fontSize: 9, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────────────────────────

/// 分隔线
class SettingsDivider extends StatelessWidget {
  const SettingsDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(vertical: 6),
      color: AppTheme.primary.withValues(alpha: 0.12),
    );
  }
}

// ───────────────────────────────────────────────

/// 步进器字段（适用于高精度小数，如传动比 0.001 步长）
///
/// 布局：
///   第一行：标签  默认:xxx        [ 当前值 badge ]
///   第二行：hint（可选）  +  [−−] [−]  数值  [+] [++]
///
/// [−−]/[++] 为大步长（bigStep，默认 step×10），[−]/[+] 为小步长（step）。
/// 长按任意按钮可持续步进。
class SettingsStepperField extends StatefulWidget {
  final String label;
  final String? hint;
  final double value;
  final double defaultValue;
  final double step;
  final double? bigStep;
  final double? minValue;
  final double? maxValue;
  final int decimalPlaces;
  final String? unit;
  final ValueChanged<double> onChanged;

  const SettingsStepperField({
    super.key,
    required this.label,
    this.hint,
    required this.value,
    required this.defaultValue,
    required this.step,
    this.bigStep,
    this.minValue,
    this.maxValue,
    this.decimalPlaces = 3,
    this.unit,
    required this.onChanged,
  });

  @override
  State<SettingsStepperField> createState() => _SettingsStepperFieldState();
}

class _SettingsStepperFieldState extends State<SettingsStepperField> {
  bool _pressing = false;

  String _fmt(double v) => v.toStringAsFixed(widget.decimalPlaces);

  double _clamp(double v) {
    if (widget.minValue != null && v < widget.minValue!)
      return widget.minValue!;
    if (widget.maxValue != null && v > widget.maxValue!)
      return widget.maxValue!;
    return v;
  }

  double _round(double v) {
    // 避免浮点累积误差
    final factor = pow(10, widget.decimalPlaces);
    return (v * factor).round() / factor;
  }

  void _step(double delta) {
    widget.onChanged(_clamp(_round(widget.value + delta)));
  }

  Future<void> _startLongPress(double delta) async {
    _pressing = true;
    // 延迟 300ms 后开始连续步进
    await Future.delayed(const Duration(milliseconds: 300));
    while (_pressing && mounted) {
      _step(delta);
      await Future.delayed(const Duration(milliseconds: 80));
    }
  }

  void _stopLongPress() => _pressing = false;

  @override
  void dispose() {
    _pressing = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final big = widget.bigStep ?? widget.step * 10;
    final badge = widget.unit != null
        ? '${_fmt(widget.value)} ${widget.unit}'
        : _fmt(widget.value);
    final defBadge = widget.unit != null
        ? '${_fmt(widget.defaultValue)} ${widget.unit}'
        : _fmt(widget.defaultValue);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── 行1：标签 + 默认值 + 当前值 badge ──
          Row(
            children: [
              Text(widget.label,
                  style: AppTheme.labelMedium.copyWith(fontSize: 13)),
              const SizedBox(width: 6),
              Text('默认: $defBadge',
                  style:
                      const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  border: Border.all(
                      color: AppTheme.primary.withValues(alpha: 0.4)),
                ),
                child: Text(
                  badge,
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // ── 行2：hint（左）+ 步进控件（右）──
          Row(
            children: [
              if (widget.hint != null)
                Expanded(
                  child: Text(
                    widget.hint!,
                    style: const TextStyle(
                        color: AppTheme.textMuted, fontSize: 11),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                )
              else
                const Spacer(),
              _StepButton(
                  label: '−−',
                  onTap: () => _step(-big),
                  onLongPressStart: () => _startLongPress(-big),
                  onLongPressEnd: _stopLongPress),
              const SizedBox(width: 4),
              _StepButton(
                  label: '−',
                  onTap: () => _step(-widget.step),
                  onLongPressStart: () => _startLongPress(-widget.step),
                  onLongPressEnd: _stopLongPress),
              const SizedBox(width: 6),
              // 数值显示区
              Container(
                width: 64,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  border: Border.all(
                      color: AppTheme.primary.withValues(alpha: 0.35)),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                ),
                child: Text(
                  _fmt(widget.value),
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              _StepButton(
                  label: '+',
                  onTap: () => _step(widget.step),
                  onLongPressStart: () => _startLongPress(widget.step),
                  onLongPressEnd: _stopLongPress),
              const SizedBox(width: 4),
              _StepButton(
                  label: '++',
                  onTap: () => _step(big),
                  onLongPressStart: () => _startLongPress(big),
                  onLongPressEnd: _stopLongPress),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final Future<void> Function() onLongPressStart;
  final VoidCallback onLongPressEnd;

  const _StepButton({
    required this.label,
    required this.onTap,
    required this.onLongPressStart,
    required this.onLongPressEnd,
  });

  @override
  State<_StepButton> createState() => _StepButtonState();
}

class _StepButtonState extends State<_StepButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onLongPressStart: (_) {
        setState(() => _pressed = true);
        widget.onLongPressStart();
      },
      onLongPressEnd: (_) {
        widget.onLongPressEnd();
        if (mounted) setState(() => _pressed = false);
      },
      onLongPressCancel: () {
        widget.onLongPressEnd();
        if (mounted) setState(() => _pressed = false);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        width: 26,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _pressed
              ? AppTheme.primary.withValues(alpha: 0.2)
              : Colors.transparent,
          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.6)),
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        ),
        child: Text(
          widget.label,
          style: TextStyle(
            color: AppTheme.primary,
            fontSize: widget.label.length > 1 ? 10 : 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

// ───────────────────────────────────────────────

/// 小节标题
class SettingsSectionTitle extends StatelessWidget {
  final String title;
  const SettingsSectionTitle(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, top: 2),
      child: Text(
        title,
        style: const TextStyle(
          color: AppTheme.primary,
          fontSize: 14,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}
