import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// 赛博朋克风格按钮类型
enum CyberButtonType {
  primary,   // 主按钮 - 蓝色背景 + 发光效果
  secondary, // 次按钮 - 透明背景 + 边框
  danger,    // 危险按钮 - 红色背景 + 发光效果
  success,   // 成功按钮 - 绿色背景 + 发光效果
}

/// 赛博朋克风格通用按钮
class CyberButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final CyberButtonType type;
  final double? width;
  final double height;
  final double fontSize;
  final bool isLoading;
  final IconData? icon;

  const CyberButton({
    super.key,
    required this.text,
    this.onPressed,
    this.type = CyberButtonType.primary,
    this.width,
    this.height = 40,
    this.fontSize = 12,
    this.isLoading = false,
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
    this.isLoading = false,
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
    this.isLoading = false,
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
    this.isLoading = false,
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
    this.isLoading = false,
    this.icon,
  }) : type = CyberButtonType.success;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: GestureDetector(
        onTap: isLoading ? null : onPressed,
        child: _buildButton(),
      ),
    );
  }

  Widget _buildButton() {
    switch (type) {
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

  /// 主按钮 - 蓝色背景 + 霓虹发光
  Widget _buildPrimaryButton() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.primary,
        borderRadius: BorderRadius.circular(5),
        boxShadow: AppTheme.glowShadow(AppTheme.primary, blur: 10),
      ),
      child: _buildContent(Colors.white),
    );
  }

  /// 次按钮 - 透明背景 + 边框
  Widget _buildSecondaryButton() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: AppTheme.primary.withOpacity(0.8),
          width: 1,
        ),
      ),
      child: _buildContent(AppTheme.primary),
    );
  }

  /// 危险按钮 - 红色背景 + 霓虹发光
  Widget _buildDangerButton() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.accentRed,
        borderRadius: BorderRadius.circular(5),
        boxShadow: AppTheme.glowShadow(AppTheme.accentRed, blur: 10),
      ),
      child: _buildContent(Colors.white),
    );
  }

  /// 成功按钮 - 绿色背景 + 霓虹发光
  Widget _buildSuccessButton() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.accentGreen,
        borderRadius: BorderRadius.circular(5),
        boxShadow: AppTheme.glowShadow(AppTheme.accentGreen, blur: 10),
      ),
      child: _buildContent(Colors.white),
    );
  }

  Widget _buildContent(Color textColor) {
    if (isLoading) {
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
        if (icon != null) ...[
          Icon(icon, color: textColor, size: fontSize + 2),
          const SizedBox(width: 6),
        ],
        Text(
          text,
          style: TextStyle(
            color: textColor,
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }
}
