import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obd_dashboard/widgets/combined_gauge_card.dart';

/// 组合仪表盘 Painter 的"无模糊"回归测试（性能优化）。
///
/// 背景：`CombinedGaugePainter` / `GaugeStaticPainter` 原来用
/// `MaskFilter.blur` 画发光层——每次模糊都要触发一次离屏渲染通道，是
/// 光栅线程开销最大的一块；在 OBD 26 次/秒的高频数据下，这个发光层每次
/// 数值变化都要重新模糊。改动后辉光层被**整体删除**（中途那版多层递减
/// 描边观感偏脏，已弃用），文件内不再有任何 `MaskFilter` 调用。
///
/// 这里不走 widget 树（CustomPainter 不是 Widget），直接构造真实
/// `ui.Canvas`（`PictureRecorder` 支持的那种）调用 `paint()`：
/// 1. 冒烟：各种数值/峰值/危险区组合下 `paint()` 不抛异常；
/// 2. 源码断言：`combined_gauge_card.dart` 内不得再出现 `MaskFilter`。
void main() {
  test('CombinedGaugePainter.paint 在危险区+峰值+满量程下不抛异常', () {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, 300, 300));

    final painter = CombinedGaugePainter(
      rpm: 9500, // 超过 dangerRpm，触发红色区 + 峰值标记分支
      speed: 200, // 超过 dangerSpeed
      gear: 4,
      peakRpm: 9800,
      peakSpeed: 210,
      maxRpm: 12000,
      warnRpm: 7000,
      dangerRpm: 9000,
      maxSpeed: 240,
      warnSpeed: 120,
      dangerSpeed: 180,
    );

    expect(
      () => painter.paint(canvas, const Size(300, 300)),
      returnsNormally,
    );

    final picture = recorder.endRecording();
    expect(picture, isNotNull);
  });

  test('GaugeStaticPainter.paint 不抛异常', () {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, 300, 300));

    final painter = GaugeStaticPainter(
      maxRpm: 12000,
      warnRpm: 7000,
      dangerRpm: 9000,
      maxSpeed: 240,
      warnSpeed: 120,
      dangerSpeed: 180,
    );

    expect(
      () => painter.paint(canvas, const Size(300, 300)),
      returnsNormally,
    );
  });

  test('combined_gauge_card.dart 源码内不再出现 MaskFilter 调用', () {
    final source =
        File('lib/widgets/combined_gauge_card.dart').readAsStringSync();

    // 注释里仍会提到 MaskFilter（用来说明改动缘由），只断言真实 API 调用不存在
    final codeLines =
        source.split('\n').where((line) => !line.trimLeft().startsWith('//'));

    expect(
      codeLines.any((line) => line.contains('MaskFilter')),
      isFalse,
      reason: '辉光层应已整体删除，不得残留 MaskFilter（离屏模糊通道）',
    );
  });
}
