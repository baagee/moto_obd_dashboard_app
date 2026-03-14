import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
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
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final colors = themeProvider.currentColors;

        return SizedBox(
          width: width,
          height: height,
          child: GestureDetector(
            onTap: isLoading ? null : onPressed,
            child: _buildButton(colors),
          ),
        );
      },
    );
  }

  Widget _buildButton(colors) {
    switch (type) {
      case CyberButtonType.primary:
        return _buildPrimaryButton(colors);
      case CyberButtonType.secondary:
        return _buildSecondaryButton(colors);
      case CyberButtonType.danger:
        return _buildDangerButton(colors);
      case CyberButtonType.success:
        return _buildSuccessButton(colors);
    }
  }

  /// 主按钮 - 蓝色背景 + 霓虹发光
  Widget _buildPrimaryButton(colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: colors.primary,
        borderRadius: BorderRadius.circular(5),
        boxShadow: AppTheme.glowShadow(colors.primary, blur: 10),
      ),
      child: _buildContent(Colors.white),
    );
  }

  /// 次按钮 - 透明背景 + 边框
  Widget _buildSecondaryButton(colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: colors.primary.withValues(alpha: 0.8),
          width: 1,
        ),
      ),
      child: _buildContent(colors.primary),
    );
  }

  /// 危险按钮 - 红色背景 + 霓虹发光
  Widget _buildDangerButton(colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: colors.accentRed,
        borderRadius: BorderRadius.circular(5),
        boxShadow: AppTheme.glowShadow(colors.accentRed, blur: 10),
      ),
      child: _buildContent(Colors.white),
    );
  }

  /// 成功按钮 - 绿色背景 + 霓虹发光
  Widget _buildSuccessButton(colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: colors.accentGreen,
        borderRadius: BorderRadius.circular(5),
        boxShadow: AppTheme.glowShadow(colors.accentGreen, blur: 10),
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
