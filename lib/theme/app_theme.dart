import 'package:flutter/material.dart';

/// 应用主题配置
class AppTheme {
  // ========== 基础颜色 ==========
  static const Color primary = Color(0xFF0DA6F2);
  static const Color backgroundDark = Color(0xFF0A1114);
  static const Color surface = Color(0xFF162229);
  static const Color accentCyan = Color(0xFF00F2FF);
  static const Color accentRed = Color(0xFFFF4D4D);
  static const Color accentOrange = Color(0xFFFFAB40);
  static const Color accentGreen = Color(0xFF00E676);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF9CA3AF);
  static const Color textMuted = Color(0xFF6B7280);

  // ========== 预定义透明度颜色 (避免 withOpacity 重复调用) ==========
  static const Color primary60 = Color(0x990DA6F2); // 0.6 opacity
  static const Color primary30 = Color(0x4D0DA6F2); // 0.3 opacity
  static const Color primary20 = Color(0x330DA6F2); // 0.2 opacity
  static const Color primary10 = Color(0x1A0DA6F2); // 0.1 opacity

  static const Color accentCyan20 = Color(0x3300F2FF);
  static const Color accentOrange20 = Color(0x33FFAB40);

  static const Color surface40 = Color(0x66162229);

  static const Color backgroundDark30 = Color(0x4D0A1114);
  static const Color backgroundDark50 = Color(0x800A1114);

  // ========== 预定义 TextStyle (const 优化) ==========
  /// 标签样式 - 小号 (fontSize: 9)
  static const TextStyle labelTiny = TextStyle(
    fontSize: 9,
    fontWeight: FontWeight.bold,
    letterSpacing: 2,
    color: textMuted,
  );

  /// 标签样式 - 带主色透明
  static const TextStyle labelTinyPrimary = TextStyle(
    fontSize: 9,
    fontWeight: FontWeight.bold,
    letterSpacing: 2,
    color: primary60,
  );

  /// 标签样式 - 小号 (fontSize: 10)
  static const TextStyle labelSmall = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.bold,
    letterSpacing: 1,
    color: textMuted,
  );

  /// 标签样式 - 中号 (fontSize: 11)
  static const TextStyle labelMedium = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: textSecondary,
  );

  /// 数值样式 - 小号 (fontSize: 11)
  static const TextStyle valueSmall = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.bold,
    color: textPrimary,
  );

  /// 数值样式 - 中号 (fontSize: 14)
  static const TextStyle valueMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.bold,
    color: textPrimary,
  );

  /// 大标题样式
  static const TextStyle headingLarge = TextStyle(
    fontSize: 120,
    fontWeight: FontWeight.bold,
    color: textPrimary,
    letterSpacing: -2,
    height: 1,
  );

  /// 标题样式 - 中号
  static const TextStyle titleMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.bold,
    color: textPrimary,
  );

  // ========== 边框样式 ==========
  static BoxDecoration surfaceBorder({
    Color borderColor = primary,
    double opacity = 0.2,
  }) {
    return BoxDecoration(
      color: surface.withOpacity(0.5),
      border: Border.all(
        color: borderColor.withOpacity(opacity),
        width: 1,
      ),
      borderRadius: BorderRadius.circular(12),
    );
  }

  // 预定义边框样式
  static const BoxDecoration surfaceBorderDefault = BoxDecoration(
    color: surface,
    border: Border(
      top: BorderSide(color: primary20, width: 1),
      left: BorderSide(color: primary20, width: 1),
      right: BorderSide(color: primary20, width: 1),
      bottom: BorderSide(color: primary20, width: 1),
    ),
    borderRadius: BorderRadius.all(Radius.circular(12)),
  );

  // ========== 发光效果 ==========
  static List<BoxShadow> glowShadow(Color color, {double blur = 15, double opacity = 0.2}) {
    return [
      BoxShadow(
        color: color.withOpacity(opacity),
        blurRadius: blur,
        spreadRadius: 0,
      ),
    ];
  }
}