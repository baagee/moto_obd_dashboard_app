import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obd_dashboard/widgets/navi_turn_arrow.dart';

/// 箭头头部的几何回归：三角头必须**从尖端向尾部逐渐变宽**。
///
/// 历史故障：线茎被一路描到 tip，而三角头在距尖端约 1×头长 的范围内
/// 比线茎还窄，于是上半段被整块盖住，顶部呈现"等宽平头矩形 + 两侧斜肩"，
/// 看上去根本不是三角形（`glow` 模糊只是让它更显眼，不是根因）。
///
/// 这里**直接读像素**，并且从 ink 包围盒取极点（不依赖归一化坐标解析值），
/// 断言"极点处极窄、往里迅速变宽"这一形状特征。
void main() {
  /// 渲染并返回 [宽, 高, RGBA 字节]。
  Future<(int, int, Uint8List)> render(
    WidgetTester tester,
    NaviTurnType type,
  ) async {
    const size = 128.0;
    await tester.pumpWidget(
      Center(
        child: NaviTurnArrow(
          type: type,
          size: size,
          color: const Color(0xFFFFFFFF),
          glow: false, // 关闭辉光：只量形状，不量模糊
        ),
      ),
    );
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byType(RepaintBoundary).first,
    );
    final image = await tester.runAsync(() => boundary.toImage());
    final data = await tester.runAsync(
      () => image!.toByteData(format: ui.ImageByteFormat.rawRgba),
    );
    return (image!.width, image.height, data!.buffer.asUint8List());
  }

  bool ink(Uint8List bytes, int w, int x, int y) =>
      bytes[(y * w + x) * 4 + 3] > 32; // 忽略抗锯齿边缘

  /// 沿 [vertical] 轴逐行/逐列统计 ink 宽度（[from, to) 限定扫描范围）。
  List<int> profile(
    Uint8List bytes,
    int w,
    int h, {
    required bool vertical,
    int? from,
    int? to,
  }) {
    final out = <int>[];
    final outer = vertical ? h : w;
    final lo = from ?? 0;
    final hi = to ?? (vertical ? w : h);
    for (var o = 0; o < outer; o++) {
      var count = 0;
      for (var i = lo; i < hi; i++) {
        if (vertical ? ink(bytes, w, i, o) : ink(bytes, w, o, i)) count++;
      }
      out.add(count);
    }
    return out;
  }

  Future<void> expectTaperedHead(
    WidgetTester tester,
    NaviTurnType type, {
    required bool vertical,
    required bool tipAtStart,
    int? from,
    int? to,
  }) async {
    final (w, h, bytes) = await render(tester, type);
    final widths = profile(bytes, w, h, vertical: vertical, from: from, to: to);

    // ink 包围盒内的极点（箭头尖端一定落在端点一侧）
    final inked = <int>[
      for (var i = 0; i < widths.length; i++)
        if (widths[i] > 0) i,
    ];
    expect(inked, isNotEmpty, reason: '$type 应当画出了东西');
    final tip = tipAtStart ? inked.first : inked.last;

    // 从尖端往里扫描，取"开始收窄"之前的最宽处作为三角头底边
    var base = 0;
    final dir = tipAtStart ? 1 : -1;
    for (var k = 0; k < 60; k++) {
      final idx = tip + dir * k;
      if (idx < 0 || idx >= widths.length) break;
      final cw = widths[idx];
      if (cw > base) base = cw;
      if (k > 2 && cw < base * 0.75) break; // 已过底边、进入线茎
    }

    final tipWidth = widths[tip + dir * 2];
    expect(tipWidth, lessThanOrEqualTo(10),
        reason: '$type: 距尖端 2px 处应当很窄（是尖角，不是平头），实测 $tipWidth px');
    expect(base, greaterThanOrEqualTo(18),
        reason: '$type: 三角头底边应当明显宽于线茎（线宽约 14px），实测 $base px');
    expect(tipWidth * 2, lessThan(base),
        reason: '$type: 尖端必须显著窄于底边（是三角形，不是等宽矩形）'
            '（尖端 $tipWidth px vs 底边 $base px）');
  }

  testWidgets('直行：顶部是尖角三角形，不是平头矩形', (tester) async {
    await expectTaperedHead(tester, NaviTurnType.straight,
        vertical: true, tipAtStart: true);
  });

  testWidgets('未知动作（退化为通用箭头）同样是尖角', (tester) async {
    await expectTaperedHead(tester, NaviTurnType.unknown,
        vertical: true, tipAtStart: true);
  });

  testWidgets('左前方：斜向箭头的尖角不被线茎盖住', (tester) async {
    await expectTaperedHead(tester, NaviTurnType.slightLeft,
        vertical: true, tipAtStart: true);
  });

  testWidgets('调头：末段被 clamp 到 70% 后仍收出尖角（尖端朝下）', (tester) async {
    // 箭头画在左侧短腿上，右侧长竖杆会拉低 ink 包围盒，故限定左半区
    // （pad=12.8、长竖杆在 x≈0.66 → 80 附近，取 [0,64) 可排除）
    await expectTaperedHead(tester, NaviTurnType.uTurn,
        vertical: true, tipAtStart: false, to: 64);
  });

  testWidgets('左转：横向指向的三角头也是尖的（尖端朝左）', (tester) async {
    await expectTaperedHead(tester, NaviTurnType.turnLeft,
        vertical: false, tipAtStart: true);
  });

  testWidgets('左后方：斜向指向的三角头也是尖的（尖端朝左上）', (tester) async {
    await expectTaperedHead(tester, NaviTurnType.sharpLeft,
        vertical: false, tipAtStart: true);
  });
}
