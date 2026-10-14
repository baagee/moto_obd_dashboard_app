import 'package:flutter/material.dart';

/// 科技感字体集中管理
///
/// 三字体策略（仅应用于拉丁字母/数字，中文走系统回退链）：
/// - [display] Orbitron：仪表盘大数字、标题
/// - [mono] Roboto Mono：刻度数字、数据值（等宽防跳字）
/// - [ui] Space Grotesk：界面文案（= `ThemeData.fontFamily`）
///
/// 字体文件打包在 assets/fonts/，pubspec.yaml 中已注册，
/// 不依赖运行时下载（车机离线场景可用）。
///
/// ## ⚠️ CustomPainter 里必须显式指定字体族
///
/// `AppTheme.labelXxx` / `valueXxx` 这类样式**不含 fontFamily**，设计上靠
/// `DefaultTextStyle` 从主题继承。但 `TextPainter` 在 `CustomPainter` 内部，
/// 没有 `BuildContext`，继承链是断的——同一个样式放进 `Text` 是 Space Grotesk，
/// 放进 painter 就会**静默退化成系统默认字体**，两者观感完全不同。
///
/// 因此 painter 里的文字一律用 [displayStyle] / [monoStyle] / [uiStyle]
/// 之一显式指定字体族，不要在 `TextSpan` 里直接塞 `AppTheme.labelXxx`。
class AppFonts {
  AppFonts._();

  /// 大数字/标题字体族名
  static const String display = 'Orbitron';

  /// 等宽数据字体族名
  static const String mono = 'RobotoMono';

  /// 界面文案字体族名（与 pubspec.yaml 中声明的 family 一致）
  static const String ui = 'SpaceGrotesk';

  /// 仪表盘大数字样式（Orbitron）
  static TextStyle displayStyle({
    required double fontSize,
    Color color = Colors.white,
    double? letterSpacing,
  }) {
    return TextStyle(
      fontFamily: display,
      fontSize: fontSize,
      fontWeight: FontWeight.bold,
      color: color,
      letterSpacing: letterSpacing,
      height: 1,
    );
  }

  /// 等宽数据样式（Roboto Mono）
  static TextStyle monoStyle({
    required double fontSize,
    Color color = Colors.white,
  }) {
    return TextStyle(
      fontFamily: mono,
      fontSize: fontSize,
      fontWeight: FontWeight.bold,
      color: color,
    );
  }

  /// 界面文案样式（Space Grotesk）——供 CustomPainter 使用
  ///
  /// 只在 painter 里用它。widget 树里的文字直接用 `AppTheme.labelXxx`
  /// 就行（会正常继承主题字体），不需要也不应该绕到这儿。
  static TextStyle uiStyle({
    required double fontSize,
    Color color = Colors.white,
    FontWeight fontWeight = FontWeight.w500,
    double? letterSpacing,
  }) {
    return TextStyle(
      fontFamily: ui,
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
    );
  }
}
