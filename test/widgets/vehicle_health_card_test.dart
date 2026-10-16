import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obd_dashboard/providers/obd_data_provider.dart';
import 'package:obd_dashboard/theme/app_theme.dart';
import 'package:obd_dashboard/widgets/vehicle_health_card.dart';
import 'package:provider/provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget host(OBDDataProvider obd, {Size size = const Size(520, 120)}) {
    return Center(
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: ChangeNotifierProvider<OBDDataProvider>.value(
          value: obd,
          child: SizedBox(
              width: size.width,
              height: size.height,
              child: const VehicleHealthCard()),
        ),
      ),
    );
  }

  testWidgets('标题字阶高于内部指标，正常与窄卡保持层级', (tester) async {
    final obd = OBDDataProvider();
    obd.setDeviceConnected(true);
    obd.updateRealTimeData(coolantTemp: -20, intakeTemp: -12, voltage: 12.4);
    for (final size in [const Size(520, 120), const Size(260, 84)]) {
      await tester.pumpWidget(host(obd, size: size));
      final title = tester.widget<Text>(find.text('车辆健康'));
      final metric = tester.widget<Text>(find.text('冷却水温'));
      expect(title.style!.fontSize, greaterThan(metric.style!.fontSize!));
      expect(title.style!.color, AppTheme.primary);
      expect(metric.style!.color, AppTheme.dashboardLabel);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('支持北京冬季负温，不把负温误判为无数据', (tester) async {
    final obd = OBDDataProvider();
    obd.setDeviceConnected(true);
    obd.updateRealTimeData(coolantTemp: -20, intakeTemp: -12, voltage: 12.4);

    await tester.pumpWidget(host(obd));

    expect(find.text('-20°C'), findsOneWidget);
    expect(find.text('-12°C'), findsOneWidget);
    expect(find.text('COLD'), findsNWidgets(3));
    expect(find.text('NO DATA'), findsNothing);
  });

  testWidgets('未连接时显示 NO DATA，而不是零值', (tester) async {
    final obd = OBDDataProvider();
    await tester.pumpWidget(host(obd));

    expect(find.text('--'), findsNWidgets(3));
    expect(find.text('NO DATA'), findsNWidgets(4));
    expect(find.text('0°C'), findsNothing);
    expect(find.text('0.0V'), findsNothing);
  });

  testWidgets('温度与电压告警状态可读', (tester) async {
    final obd = OBDDataProvider();
    obd.setDeviceConnected(true);
    obd.updateRealTimeData(coolantTemp: 103, intakeTemp: 55, voltage: 11.8);

    await tester.pumpWidget(host(obd));

    expect(find.text('103°C'), findsOneWidget);
    expect(find.text('55°C'), findsOneWidget);
    expect(find.text('WARM'), findsNWidgets(2));
    expect(find.text('11.8V'), findsOneWidget);
    expect(find.text('LOW'), findsOneWidget);
  });

  testWidgets('窄横屏不溢出且保持横向指标', (tester) async {
    final obd = OBDDataProvider();
    obd.setDeviceConnected(true);
    obd.updateRealTimeData(coolantTemp: 86, intakeTemp: 42, voltage: 13.8);

    await tester.pumpWidget(host(obd, size: const Size(400, 120)));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('86°C'), findsOneWidget);
    expect(find.text('42°C'), findsOneWidget);
    expect(find.text('13.8V'), findsOneWidget);
  });

  testWidgets('已连接但低频 PID 尚未响应时不展示假 0°C', (tester) async {
    final obd = OBDDataProvider();
    obd.setDeviceConnected(true);
    obd.updateRealTimeData(rpm: 1200, speed: 0);
    await tester.pumpWidget(host(obd));

    expect(find.text('--'), findsNWidgets(3));
    expect(find.text('0°C'), findsNothing);
    expect(find.text('NO DATA'), findsNWidgets(4));

    obd.updateRealTimeData(coolantTemp: 0, intakeTemp: -20, voltage: 13.4);
    await tester.pump();
    expect(find.text('0°C'), findsOneWidget);
    expect(find.text('-20°C'), findsOneWidget);
    expect(find.text('13.4V'), findsOneWidget);
    expect(find.text('NO DATA'), findsNothing);
  });

  testWidgets('断开重连后清除上次温度与电压有效性', (tester) async {
    final obd = OBDDataProvider();
    obd.setDeviceConnected(true);
    obd.updateRealTimeData(coolantTemp: -20, intakeTemp: -12, voltage: 12.4);
    await tester.pumpWidget(host(obd));
    expect(find.text('-20°C'), findsOneWidget);

    obd.setDeviceConnected(false);
    obd.setDeviceConnected(true);
    await tester.pump();
    expect(find.text('--'), findsNWidgets(3));
    expect(find.text('-20°C'), findsNothing);
  });

  testWidgets('不同横向尺寸不溢出', (tester) async {
    final obd = OBDDataProvider();
    obd.setDeviceConnected(true);
    obd.updateRealTimeData(coolantTemp: -20, intakeTemp: -12, voltage: 12.4);
    for (final size in [
      const Size(520, 120),
      const Size(400, 120),
      const Size(320, 100),
      const Size(260, 84)
    ]) {
      await tester.pumpWidget(host(obd, size: size));
      expect(tester.getSize(find.byType(VehicleHealthCard)), size);
      expect(tester.takeException(), isNull, reason: '尺寸 $size');
    }
  });

  test('车辆健康卡不引入模糊或持续动画', () {
    final source =
        File('lib/widgets/vehicle_health_card.dart').readAsStringSync();
    for (final forbidden in [
      'MaskFilter',
      'blurRadius',
      'BackdropFilter',
      'AnimationController',
      'Timer.periodic',
    ]) {
      expect(source.contains(forbidden), isFalse, reason: '不应出现 $forbidden');
    }
  });

  testWidgets('100px 高横卡仍显示水温趋势，极矮时保留读数', (tester) async {
    final obd = OBDDataProvider();
    obd.setDeviceConnected(true);
    obd.updateRealTimeData(coolantTemp: -20, intakeTemp: -12, voltage: 12.4);

    await tester.pumpWidget(host(obd, size: const Size(400, 100)));
    expect(find.byType(CustomPaint), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(host(obd, size: const Size(260, 84)));
    expect(find.text('-20°C'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('水温微趋势来自真实 PID 历史且随断开清空', (tester) async {
    final obd = OBDDataProvider();
    obd.setDeviceConnected(true);
    for (final temp in [-20, -18, -15, 0, 60, 86]) {
      obd.updateRealTimeData(coolantTemp: temp);
    }
    await tester.pumpWidget(host(obd, size: const Size(520, 120)));
    expect(obd.coolantTempHistory, [-20, -18, -15, 0, 60, 86]);
    final chart = tester.widget<CustomPaint>(find.byType(CustomPaint).first);
    expect(chart.painter, isA<CoolantTrendPainter>());
    expect(find.text('近16次'), findsOneWidget);

    obd.setDeviceConnected(false);
    await tester.pump();
    expect(obd.coolantTempHistory, isEmpty);
    expect(find.byType(CustomPaint), findsNothing);
  });

  testWidgets('RPM 变化不重建健康卡内的温度曲线', (tester) async {
    final obd = OBDDataProvider();
    obd.setDeviceConnected(true);
    obd.updateRealTimeData(coolantTemp: 30, intakeTemp: -5, voltage: 12.8);
    await tester.pumpWidget(host(obd, size: const Size(520, 120)));
    final before =
        tester.widget<CustomPaint>(find.byType(CustomPaint).first).painter;
    obd.updateRealTimeData(rpm: 2500, speed: 50);
    await tester.pump();
    final after =
        tester.widget<CustomPaint>(find.byType(CustomPaint).first).painter;
    expect(identical(before, after), isTrue);
  });

  test('温度范围映射支持负温和上限', () {
    expect(coolantTemperatureRatio(-40), 0);
    expect(coolantTemperatureRatio(-20), closeTo(0.125, 1e-9));
    expect(coolantTemperatureRatio(0), closeTo(0.25, 1e-9));
    expect(coolantTemperatureRatio(120), 1);
    expect(coolantTemperatureStatus(-20), 'COLD');
    expect(coolantTemperatureStatus(86), 'NORMAL');
    expect(coolantTemperatureStatus(103), 'WARM');
    expect(coolantTemperatureStatus(115), 'OVERHEAT');
  });
}
