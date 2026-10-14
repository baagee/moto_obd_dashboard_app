import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obd_dashboard/providers/obd_data_provider.dart';
import 'package:obd_dashboard/widgets/side_stats_panel.dart';
import 'package:provider/provider.dart';

/// 侧边统计面板的"无模糊"回归测试（性能优化）。
///
/// 背景：面板里两处高亮原本都靠模糊实现，而模糊在 Flutter 里最终都会落到
/// `MaskFilter.blur` 上——包括 `BoxShadow`：`BoxShadow.toPaint()` 内部就是
/// `..maskFilter = MaskFilter.blur(blurStyle, blurSigma)`
/// （flutter/lib/src/painting/box_shadow.dart）。每次命中都要一次离屏模糊通道。
///
/// 1. 油门开度 / 发动机负载进度条：`BoxShadow(blurRadius: 8)` 改成顶部亮色
///    竖向渐变——OBD 每个数据 tick 这两条都会重建，是仪表盘上频率最高的一处；
/// 2. 进气歧管压力柱状图最新一根柱子：删掉 `glowPaint`，改为纯色亮柱 + 顶部
///    1.5px 亮边，保留"最新一根更亮"的高亮语义但不再模糊。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('油门/负载进度条高亮不再使用 boxShadow', (tester) async {
    final obd = OBDDataProvider();
    obd.updateRealTimeData(throttle: 60, load: 30);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: ChangeNotifierProvider<OBDDataProvider>.value(
          value: obd,
          child: const SizedBox(
            width: 220,
            height: 420,
            child: SideStatsPanel(),
          ),
        ),
      ),
    );

    List<FractionallySizedBox> fills() => tester
        .widgetList<FractionallySizedBox>(find.byType(FractionallySizedBox))
        .toList();

    expect(fills().length, 2, reason: '油门开度 / 发动机负载 两条进度条');

    for (final fill in fills()) {
      final deco = (fill.child! as Container).decoration! as BoxDecoration;
      expect(
        deco.boxShadow,
        isNull,
        reason: 'BoxShadow 内部会构造 MaskFilter.blur，等于每次重建一次离屏模糊',
      );
      expect(
        deco.gradient,
        isA<LinearGradient>(),
        reason: '高亮改由渐变承担，不能只是把发光整条删掉',
      );
    }

    expect(fills()[0].widthFactor, closeTo(0.6, 1e-9));

    // 数据更新后宽度跟随，且仍然不含 boxShadow
    obd.updateRealTimeData(throttle: 25, load: 30);
    await tester.pump();

    final updated = fills()[0];
    expect(updated.widthFactor, closeTo(0.25, 1e-9));
    final updatedDeco =
        (updated.child! as Container).decoration! as BoxDecoration;
    expect(updatedDeco.boxShadow, isNull);
  });

  test('PressureChartPainter.paint 不抛异常（含只有一根柱子的边界）', () {
    const histories = <List<int>>[
      [0, 10, 40, 80, 150], // 常规：最后一根柱子走高亮分支
      [90], // 边界：唯一一根柱子就是"最新"
      <int>[], // 空历史：直接 return
    ];

    for (final history in histories) {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, 200, 56));
      final painter = PressureChartPainter(
        pressureHistory: history,
        minPressure: 0,
        maxPressure: 150,
      );

      expect(
        () => painter.paint(canvas, const Size(200, 56)),
        returnsNormally,
        reason: 'history=$history',
      );
      expect(recorder.endRecording(), isNotNull);
    }
  });

  test('side_stats_panel.dart 源码内不再出现 MaskFilter / blurRadius', () {
    final source = File('lib/widgets/side_stats_panel.dart').readAsStringSync();

    // 注释里仍会提到 MaskFilter / BoxShadow（说明改动缘由），只断言真实调用不存在
    final codeLines = source
        .split('\n')
        .where((line) => !line.trimLeft().startsWith('//'));

    expect(
      codeLines.any((line) => line.contains('MaskFilter')),
      isFalse,
      reason: '不得残留 MaskFilter（离屏模糊通道）',
    );
    expect(
      codeLines.any((line) => line.contains('blurRadius')),
      isFalse,
      reason: 'BoxShadow/Shadow 的 blurRadius 同样会转成 MaskFilter.blur',
    );
  });
}
