import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obd_dashboard/providers/obd_data_provider.dart';
import 'package:obd_dashboard/theme/app_theme.dart';
import 'package:obd_dashboard/widgets/side_stats_panel.dart';
import 'package:provider/provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget host(OBDDataProvider obd, {Size size = const Size(220, 420)}) {
    return Center(
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: ChangeNotifierProvider<OBDDataProvider>.value(
          value: obd,
          child: SizedBox(
            width: size.width,
            height: size.height,
            child: const SideStatsPanel(),
          ),
        ),
      ),
    );
  }

  testWidgets('三块仪表保留大读数和清晰单位', (tester) async {
    final obd = OBDDataProvider();
    obd.updateRealTimeData(throttle: 60, load: 30, pressure: 87);
    await tester.pumpWidget(host(obd));
    for (final label in ['车辆状态', '油门开度', '发动机负载', '进气歧管压力']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('60%'), findsOneWidget);
    expect(find.text('30%'), findsOneWidget);
    expect(find.text('87 kPa'), findsOneWidget);
    expect(find.byType(CustomPaint), findsOneWidget);
    final title = tester.widget<Text>(find.text('车辆状态'));
    final metric = tester.widget<Text>(find.text('油门开度'));
    expect(title.style!.fontSize, greaterThan(metric.style!.fontSize!));
    expect(title.style!.color, AppTheme.primary);
    expect(metric.style!.color, AppTheme.dashboardLabel);
    expect(tester.takeException(), isNull);
  });

  testWidgets('细进度条随数值变化且没有模糊阴影', (tester) async {
    final obd = OBDDataProvider();
    obd.updateRealTimeData(throttle: 60, load: 30, pressure: 87);
    await tester.pumpWidget(host(obd));
    List<FractionallySizedBox> fills() => tester
        .widgetList<FractionallySizedBox>(find.byType(FractionallySizedBox))
        .toList();
    expect(fills().length, 2);
    expect(fills()[0].widthFactor, closeTo(0.6, 1e-9));
    for (final fill in fills()) {
      final decoration =
          (fill.child! as Container).decoration! as BoxDecoration;
      expect(decoration.boxShadow, isNull);
      expect(decoration.gradient, isA<LinearGradient>());
    }
    obd.updateRealTimeData(throttle: 25);
    await tester.pump();
    expect(fills()[0].widthFactor, closeTo(0.25, 1e-9));
  });

  testWidgets('正常负载用青色，高负载改为琥珀', (tester) async {
    final obd = OBDDataProvider();
    obd.updateRealTimeData(load: 30, pressure: 87);
    await tester.pumpWidget(host(obd));
    Color loadColor() {
      final bars = tester
          .widgetList<FractionallySizedBox>(
            find.byType(FractionallySizedBox),
          )
          .toList();
      final decoration =
          (bars.last.child! as Container).decoration! as BoxDecoration;
      return (decoration.gradient! as LinearGradient).colors.last;
    }

    expect(loadColor(), AppTheme.gaugeNormal);
    obd.updateRealTimeData(load: 80);
    await tester.pump();
    expect(loadColor(), AppTheme.gaugeWarn);
  });

  testWidgets('油门和 RPM 变化不重建压力图；压力 PID 更新才重绘', (tester) async {
    final obd = OBDDataProvider();
    obd.updateRealTimeData(throttle: 20, pressure: 80);
    await tester.pumpWidget(host(obd));
    final before =
        tester.widget<CustomPaint>(find.byType(CustomPaint).first).painter;
    obd.updateRealTimeData(throttle: 40, rpm: 3500, speed: 60);
    await tester.pump();
    final after =
        tester.widget<CustomPaint>(find.byType(CustomPaint).first).painter;
    expect(identical(before, after), isTrue);
    obd.updateRealTimeData(pressure: 84);
    await tester.pump();
    final updated =
        tester.widget<CustomPaint>(find.byType(CustomPaint).first).painter;
    expect(identical(before, updated), isFalse);
    expect(obd.pressureHistoryVersion, 2);
  });

  testWidgets('多种横屏尺寸优先保留读数，不溢出', (tester) async {
    final obd = OBDDataProvider();
    obd.updateRealTimeData(throttle: 60, load: 30, pressure: 87);
    for (final size in [
      const Size(220, 420),
      const Size(160, 300),
      const Size(140, 240),
    ]) {
      await tester.pumpWidget(host(obd, size: size));
      expect(tester.getSize(find.byType(SideStatsPanel)), size);
      expect(find.text('87 kPa'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: '$size');
    }
  });

  test('PressureChartPainter 支持常规、单柱和空历史', () {
    const histories = <List<int>>[
      [0, 10, 40, 80, 150],
      [90],
      <int>[],
    ];
    for (final history in histories) {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, 200, 56));
      final painter = PressureChartPainter(
        pressureHistory: history,
        minPressure: 0,
        maxPressure: 150,
      );
      expect(() => painter.paint(canvas, const Size(200, 56)), returnsNormally);
      expect(recorder.endRecording(), isNotNull);
    }
  });

  test('side_stats_panel.dart 没有模糊绘制', () {
    final source = File('lib/widgets/side_stats_panel.dart').readAsStringSync();
    final codeLines =
        source.split('\n').where((line) => !line.trimLeft().startsWith('//'));
    expect(codeLines.any((line) => line.contains('MaskFilter')), isFalse);
    expect(codeLines.any((line) => line.contains('blurRadius')), isFalse);
  });
}
