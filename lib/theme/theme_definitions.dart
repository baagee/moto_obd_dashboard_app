import 'package:flutter/material.dart';
import '../models/theme_colors.dart';

/// 主题定义 - 包含 4 种静态主题颜色实例
class ThemeDefinitions {
  ThemeDefinitions._();

  /// 赛博蓝主题 - 深色背景 + 蓝色强调
  static const ThemeColors cyberBlue = ThemeColors(
    primary: Color(0xFF0DA6F2),
    backgroundDark: Color(0xFF0A1114),
    surface: Color(0xFF162229),
    accentCyan: Color(0xFF00F2FF),
    accentRed: Color(0xFFFF4D4D),
    accentOrange: Color(0xFFFFAB40),
    accentGreen: Color(0xFF00E676),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFF9CA3AF),
    textMuted: Color(0xFF6B7280),
    accent: Color(0xFF0DA6F2),
  );

  /// 红色主题 - 深色背景 + 红色强调
  static const ThemeColors red = ThemeColors(
    primary: Color(0xFFFF4D4D),
    backgroundDark: Color(0xFF0A1114),
    surface: Color(0xFF162229),
    accentCyan: Color(0xFF00F2FF),
    accentRed: Color(0xFFFF4D4D),
    accentOrange: Color(0xFFFFAB40),
    accentGreen: Color(0xFF00E676),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFF9CA3AF),
    textMuted: Color(0xFF6B7280),
    accent: Color(0xFFFF4D4D),
  );

  /// 橙色主题 - 深色背景 + 橙色强调
  static const ThemeColors orange = ThemeColors(
    primary: Color(0xFFFFAB40),
    backgroundDark: Color(0xFF0A1114),
    surface: Color(0xFF162229),
    accentCyan: Color(0xFF00F2FF),
    accentRed: Color(0xFFFF4D4D),
    accentOrange: Color(0xFFFFAB40),
    accentGreen: Color(0xFF00E676),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFF9CA3AF),
    textMuted: Color(0xFF6B7280),
    accent: Color(0xFFFFAB40),
  );

  /// 浅色主题 - 白色背景 + 黑色文字
  static const ThemeColors light = ThemeColors(
    primary: Color(0xFF0DA6F2),
    backgroundDark: Color(0xFFFFFFFF),
    surface: Color(0xFFF3F4F6),
    accentCyan: Color(0xFF00A0CC),
    accentRed: Color(0xFFDC2626),
    accentOrange: Color(0xFFF59E0B),
    accentGreen: Color(0xFF10B981),
    textPrimary: Color(0xFF000000),
    textSecondary: Color(0xFF4B5563),
    textMuted: Color(0xFF9CA3AF),
    accent: Color(0xFF0DA6F2),
  );

  /// 根据主题类型获取对应的 ThemeColors
  static ThemeColors getThemeColors(AppThemeType type) {
    switch (type) {
      case AppThemeType.cyberBlue:
        return cyberBlue;
      case AppThemeType.red:
        return red;
      case AppThemeType.orange:
        return orange;
      case AppThemeType.light:
        return light;
    }
  }
}
