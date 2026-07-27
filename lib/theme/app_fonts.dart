import 'package:flutter/material.dart';

/// 科技感字体集中管理
///
/// 双字体策略（仅应用于拉丁字母/数字，中文走系统回退链）：
/// - [display] Orbitron：仪表盘大数字、标题
/// - [mono] Roboto Mono：刻度数字、数据值（等宽防跳字）
///
/// 字体文件打包在 assets/fonts/，pubspec.yaml 中已注册，
/// 不依赖 google_fonts 运行时下载（车机离线场景可用）。
class AppFonts {
  AppFonts._();

  /// 大数字/标题字体族名
  static const String display = 'Orbitron';

  /// 等宽数据字体族名
  static const String mono = 'RobotoMono';

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
}
