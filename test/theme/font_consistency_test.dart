import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obd_dashboard/theme/app_fonts.dart';

/// 字体一致性回归测试（方案 B 的"治本"部分）
///
/// 背景：`TextPainter` 在 `CustomPainter` 内部没有 `BuildContext`，
/// `DefaultTextStyle` 继承链是断的——`AppTheme.labelXxx` / `valueXxx`
/// 这类**不含 fontFamily** 的样式放进 painter 会静默退化成系统默认字体。
/// 这几条断言锁住"三字体策略 + painter 显式指定字体族"不被改回去。
void main() {
  group('字体资产已打包（离线车机可用）', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();

    test('pubspec 声明三种字体族', () {
      expect(pubspec.contains('family: Orbitron'), isTrue);
      expect(pubspec.contains('family: RobotoMono'), isTrue);
      expect(pubspec.contains('family: SpaceGrotesk'), isTrue);
    });

    test('声明的字体文件都真实存在', () {
      for (final p in const [
        'assets/fonts/Orbitron-Bold.ttf',
        'assets/fonts/RobotoMono-Bold.ttf',
        'assets/fonts/SpaceGrotesk-Regular.ttf',
        'assets/fonts/SpaceGrotesk-Medium.ttf',
        'assets/fonts/SpaceGrotesk-Bold.ttf',
      ]) {
        expect(File(p).existsSync(), isTrue, reason: '缺少字体文件 $p');
        expect(File(p).lengthSync() > 1000, isTrue, reason: '$p 大小异常');
      }
    });

    test('Space Grotesk 族名与 pubspec 声明的 family 一致', () {
      // 主题用的是打包族名，写错就整体掉回系统字体
      expect(AppFonts.ui, 'SpaceGrotesk');
      expect(pubspec.contains('family: SpaceGrotesk'), isTrue);
    });

    test('主题字体指向打包族名，不再走 google_fonts 运行时下载', () {
      final mainSrc = File('lib/main.dart').readAsStringSync();
      expect(mainSrc.contains('fontFamily: AppFonts.ui'), isTrue);
      // 只查代码行，注释里提到 GoogleFonts 不算（说明为什么不用它）
      final codeLines = mainSrc
          .split('\n')
          .where((l) => !l.trimLeft().startsWith('//'));
      final offenders = codeLines
          .where((l) => l.contains('GoogleFonts.') || l.contains('google_fonts'))
          .toList();
      expect(offenders, isEmpty,
          reason: '主题仍依赖 google_fonts 运行时加载字体：$offenders');
      expect(pubspec.contains('google_fonts:'), isFalse,
          reason: 'google_fonts 已无用，应移除依赖');
    });
  });

  group('painter 安全的样式工厂', () {
    test('三个工厂都显式带上了字体族', () {
      expect(
        AppFonts.displayStyle(fontSize: 12).fontFamily,
        AppFonts.display,
      );
      expect(AppFonts.monoStyle(fontSize: 12).fontFamily, AppFonts.mono);
      expect(AppFonts.uiStyle(fontSize: 12).fontFamily, AppFonts.ui);
    });

    test('uiStyle 默认字重 w500，可覆盖字号/颜色/字距', () {
      final s = AppFonts.uiStyle(
        fontSize: 12,
        color: const Color(0xFF00FF00),
        letterSpacing: 1.5,
      );
      expect(s.fontWeight, FontWeight.w500);
      expect(s.fontSize, 12);
      expect(s.color, const Color(0xFF00FF00));
      expect(s.letterSpacing, 1.5);
    });
  });

  group('painter 内不再引用无语义字体族的主题样式', () {
    /// 只排查"painter 里画字"的文件：这些文件里的 `AppTheme.labelXxx` /
    /// `AppTheme.valueXxx` 一旦进了 `TextSpan` 就会丢字体族。
    const painterFiles = [
      'lib/widgets/combined_gauge_card.dart',
      'lib/widgets/navi_card.dart',
      'lib/widgets/gauges/classic_gauge_widget.dart',
      'lib/widgets/track_radar_card.dart',
      'lib/widgets/side_stats_panel.dart',
    ];

    test('painter 文件里没有把 AppTheme.label*/value* 塞进 TextSpan', () {
      final offenders = <String>[];
      for (final path in painterFiles) {
        final src = File(path).readAsStringSync();
        // TextSpan( ... style: AppTheme.labelMediumPrimary12 ) 形式
        final re = RegExp(
          r'TextSpan\([^)]*AppTheme\.(label|value)\w*',
          multiLine: true,
          dotAll: true,
        );
        if (re.hasMatch(src)) offenders.add(path);
      }
      expect(offenders, isEmpty,
          reason: '这些文件的 TextSpan 里直接用了 AppTheme.label/value：$offenders');
    });

    test('暴露给 painter 的 _drawGaugeText 调用都必须传 fontFamily', () {
      final lines = File('lib/widgets/gauges/classic_gauge_widget.dart')
          .readAsStringSync()
          .split('\n');
      // 调用点：以 `_drawGaugeText(` 开头的行（排除 `void _drawGaugeText(` 定义）
      final callLines = lines
          .where((l) => l.trimLeft().startsWith('_drawGaugeText('))
          .length;
      // 函数体内给 TextStyle 传 fontFamily 的实参 + 每个调用点各 1 次
      final familyLines =
          lines.where((l) => l.contains('fontFamily:')).length;
      expect(callLines, greaterThan(0), reason: '没找到调用点，正则可能失效');
      expect(familyLines - 1, callLines,
          reason: '有 $callLines 处调用，但只有 ${familyLines - 1} 处传了 fontFamily');
    });
  });

  group('RichText 已换成会继承主题字体的 Text.rich', () {
    test('顶部导航栏与导航通栏不再裸用 RichText', () {
      for (final p in const [
        'lib/widgets/top_navigation_bar.dart',
        'lib/widgets/navi_hud_banner.dart',
      ]) {
        final src = File(p).readAsStringSync();
        // 允许注释里提到 RichText，只要没有实际构造
        final hasBare = src
            .split('\n')
            .any((l) => l.contains('RichText(') && !l.trimLeft().startsWith('//'));
        expect(hasBare, isFalse, reason: '$p 里仍有裸 RichText（不继承主题字体）');
      }
    });
  });
}
