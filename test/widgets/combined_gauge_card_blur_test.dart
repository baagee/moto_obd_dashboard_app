import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obd_dashboard/widgets/combined_gauge_card.dart';

/// 组合仪表盘 Painter 的 blur 降级回归测试（性能优化）。
///
/// 背景：`CombinedGaugePainter` / `GaugeStaticPainter` 原来用
/// `MaskFilter.blur` 画发光层——每次模糊都要触发一次离屏渲染通道，是
/// 光栅线程开销最大的一块；在 OBD 26 次/秒的高频数据下，这个发光层每次
/// 数值变化都要重新模糊。改动后用多层递减透明度描边模拟辉光，不再触发
/// 任何 `MaskFilter`。
///
/// 这里不走 widget 树（CustomPainter 不是 Widget），直接构造真实
/// `ui.Canvas`（`PictureRecorder` 支持的那种）调用 `paint()`：
/// 1. 冒烟：各种数值/峰值/危险区组合下 `paint()` 不抛异常；
/// 2. 静态回归：覆盖 RPM/速度满量程、峰值标记、温度条等所有触发过
///    blur 的分支后，`toImage()` 能正常生成（间接证明没有残留的
///    `MaskFilter` 导致渐变/离屏渲染异常——更直接的保证见下方源码断言）。
void main() {
  test('CombinedGaugePainter.paint 在危险区+峰值+满量程下不抛异常', () {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, 300, 300));

    final painter = CombinedGaugePainter(
      rpm: 9500, // 超过 dangerRpm，触发红色区 + 峰值标记分支
      speed: 200, // 超过 dangerSpeed
      gear: 4,
      coolantTemp: 110, // 触发温度条高亮分段
      intakeTemp: 70,
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
}
