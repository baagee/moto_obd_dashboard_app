import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// 赛博朋克风格按钮类型
enum CyberButtonType {
  primary, // 主按钮 - 蓝色背景 + 发光效果
  secondary, // 次按钮 - 透明背景 + 边框
  danger, // 危险按钮 - 红色背景 + 发光效果
  success, // 成功按钮 - 绿色背景 + 发光效果
}

/// 赛博朋克风格通用按钮
///
/// onPressed 支持同步（VoidCallback）或异步（Future<void> Function()）。
/// 传入异步函数时，按钮在执行期间自动显示 loading 状态并防止重复点击。
class CyberButton extends StatefulWidget {
  final String text;
  final dynamic onPressed; // VoidCallback? 或 Future<void> Function()?
  final CyberButtonType type;
  final double? width;
  final double height;
  final double fontSize;
  final IconData? icon;

  const CyberButton({
    super.key,
    required this.text,
    this.onPressed,
    this.type = CyberButtonType.primary,
    this.width,
    this.height = 40,
    this.fontSize = 12,
    this.icon,
  });

  /// 主按钮（蓝色）
  const CyberButton.primary({
    super.key,
    required this.text,
    this.onPressed,
    this.width,
    this.height = 40,
    this.fontSize = 12,
    this.icon,
  }) : type = CyberButtonType.primary;

  /// 次按钮（边框）
  const CyberButton.secondary({
    super.key,
    required this.text,
    this.onPressed,
    this.width,
    this.height = 40,
    this.fontSize = 12,
    this.icon,
  }) : type = CyberButtonType.secondary;

  /// 危险按钮（红色）
  const CyberButton.danger({
    super.key,
    required this.text,
    this.onPressed,
    this.width,
    this.height = 40,
    this.fontSize = 12,
    this.icon,
  }) : type = CyberButtonType.danger;

  /// 成功按钮（绿色）
  const CyberButton.success({
    super.key,
    required this.text,
    this.onPressed,
    this.width,
    this.height = 40,
    this.fontSize = 12,
    this.icon,
  }) : type = CyberButtonType.success;

  @override
  State<CyberButton> createState() => _CyberButtonState();
}

class _CyberButtonState extends State<CyberButton> {
  bool _loading = false;

  Future<void> _handleTap() async {
    if (_loading || widget.onPressed == null) return;
    final result = widget.onPressed!();
    if (result is Future) {
      if (mounted) setState(() => _loading = true);
      try {
        await result;
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: GestureDetector(
        onTap: _loading ? null : _handleTap,
        child: _buildButton(),
      ),
    );
  }

  Widget _buildButton() {
    switch (widget.type) {
      case CyberButtonType.primary:
        return _buildPrimaryButton();
      case CyberButtonType.secondary:
        return _buildSecondaryButton();
      case CyberButtonType.danger:
        return _buildDangerButton();
      case CyberButtonType.success:
        return _buildSuccessButton();
    }
  }

  bool get _disabled => widget.onPressed == null && !_loading;

  Widget _buildPrimaryButton() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: _disabled
            ? AppTheme.primary.withValues(alpha: 0.25)
            : AppTheme.primary,
        borderRadius: BorderRadius.circular(AppTheme.radiusButton),
        boxShadow: _disabled
            ? null
            : AppTheme.glowShadow(AppTheme.primary, blur: 10),
      ),
      child: _buildContent(
          _disabled ? AppTheme.primary.withValues(alpha: 0.4) : Colors.white),
    );
  }

  Widget _buildSecondaryButton() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.radiusButton),
        border: Border.all(
          color: AppTheme.primary.withValues(alpha: _disabled ? 0.2 : 0.8),
          width: 1,
        ),
      ),
      child: _buildContent(
          AppTheme.primary.withValues(alpha: _disabled ? 0.25 : 1.0)),
    );
  }

  Widget _buildDangerButton() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.accentRed,
        borderRadius: BorderRadius.circular(AppTheme.radiusButton),
        boxShadow: AppTheme.glowShadow(AppTheme.accentRed, blur: 10),
      ),
      child: _buildContent(Colors.white),
    );
  }

  Widget _buildSuccessButton() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.accentGreen,
        borderRadius: BorderRadius.circular(AppTheme.radiusButton),
        boxShadow: AppTheme.glowShadow(AppTheme.accentGreen, blur: 10),
      ),
      child: _buildContent(Colors.white),
    );
  }

  Widget _buildContent(Color textColor) {
    if (_loading) {
      return Center(
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(textColor),
          ),
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.icon != null) ...[
          Icon(widget.icon, color: textColor, size: widget.fontSize + 2),
          const SizedBox(width: 6),
        ],
        Text(
          widget.text,
          style: TextStyle(
            color: textColor,
            fontSize: widget.fontSize,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }
}
