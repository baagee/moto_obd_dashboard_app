import 'package:flutter/material.dart';

/// 主题颜色数据类 - 包含所有主题颜色 token
/// 用于支持动态主题切换
class ThemeColors {
  /// 主色 - 主题的主要强调色
  final Color primary;

  /// 深色背景
  final Color backgroundDark;

  /// 卡片/表面颜色
  final Color surface;

  /// 青色强调色
  final Color accentCyan;

  /// 红色强调色
  final Color accentRed;

  /// 橙色强调色
  final Color accentOrange;

  /// 绿色强调色
  final Color accentGreen;

  /// 主要文字颜色
  final Color textPrimary;

  /// 次要文字颜色
  final Color textSecondary;

  /// 弱化文字颜色
  final Color textMuted;

  /// 当前主题的主要强调色
  final Color accent;

  const ThemeColors({
    required this.primary,
    required this.backgroundDark,
    required this.surface,
    required this.accentCyan,
    required this.accentRed,
    required this.accentOrange,
    required this.accentGreen,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.accent,
  });

  /// 使用 copyWith 方法创建新实例（遵循 CLAUDE.md 模型规范）
  ThemeColors copyWith({
    Color? primary,
    Color? backgroundDark,
    Color? surface,
    Color? accentCyan,
    Color? accentRed,
    Color? accentOrange,
    Color? accentGreen,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? accent,
  }) {
    return ThemeColors(
      primary: primary ?? this.primary,
      backgroundDark: backgroundDark ?? this.backgroundDark,
      surface: surface ?? this.surface,
      accentCyan: accentCyan ?? this.accentCyan,
      accentRed: accentRed ?? this.accentRed,
      accentOrange: accentOrange ?? this.accentOrange,
      accentGreen: accentGreen ?? this.accentGreen,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      accent: accent ?? this.accent,
    );
  }
}

/// 主题类型枚举
enum AppThemeType {
  /// 赛博蓝主题 - 深色背景 + 蓝色强调
  cyberBlue,

  /// 红色主题 - 深色背景 + 红色强调
  red,

  /// 橙色主题 - 深色背景 + 橙色强调
  orange,

  /// 浅色主题 - 白色背景
  light,
}
