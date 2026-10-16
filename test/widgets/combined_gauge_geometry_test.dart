import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obd_dashboard/providers/obd_data_provider.dart';
import 'package:obd_dashboard/providers/settings_provider.dart';
import 'package:obd_dashboard/widgets/combined_gauge_card.dart';
import 'package:obd_dashboard/widgets/self_check_overlay.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 中央组合仪表**分层顺序**回归。
///
/// 背景：进度环原来在最外层、刻度线与刻度数字被挤在环**内侧**；本方案把顺序反转成
/// 「中心数值 → 指针 → **进度环** → 刻度线 → 刻度数字（最外）」，代价是整体缩径
/// 约 28%（环外预算 ≈ 54px，见 `GaugeGeometry.of`）。
///
/// 跟进：**环半径与刻度数字字号已彻底解耦**——环位置只由画布尺寸算（冻结定义），
/// 数字字号由"环外剩余带宽 + 最外 3 字符标签不出画布"反解。这条由「环位置只由画布
/// 尺寸决定」与「刻度数字吃满环外空间」两条用例守住，改字号不得再带动环。
///
/// 这里锁两件事：
/// 1. **几何关系**（`GaugeGeometry`，两个 painter 的唯一半径来源）：半径链严格有序、
///    刻度数字不出画布、中心大字号由**环内缘**定标（不随环径等比例变小）；
/// 2. **像素事实**（直接读画布）：静态层里所有刻度墨水（线 + 数字）都落在**环带内缘
///    之外**；动态层的进度环仍在 `ringRadius` 上，环带内侧已无刻度墨水。
///
/// 注意：`flutter test` 环境不加载 pubspec 里的自定义字体，文字走的是**回退字体**
/// （每字符约 1em，比打包的 Roboto Mono 0.6em 宽 1.67 倍），所以像素断言刻意避开
/// "文字宽度是否刚好放得下"这类字体敏感项——那由几何断言（按 0.6em/字符换算）负责。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // 像素类断言必须在**真实打包字体**下做：`flutter test` 默认不加载 pubspec 字体，
  // 回退字体每字符 ≈1em（Roboto Mono 是 0.6em），字宽会差 1.67 倍，
  // "数字与刻度线的缝"这种字墨级判断用回退字体会得出完全相反的结论。
  setUpAll(() async {
    for (final (family, path) in const [
      ('RobotoMono', 'assets/fonts/RobotoMono-Bold.ttf'),
      ('Orbitron', 'assets/fonts/Orbitron-Bold.ttf'),
    ]) {
      final loader = FontLoader(family)
        ..addFont(
            Future.value(File(path).readAsBytesSync().buffer.asByteData()));
      await loader.load();
    }
  });

  /// 画布尺寸（= `CombinedGaugeCard` 内 `Container(padding: 8)` 之后的 LayoutBuilder 尺寸）：
  /// - 主仪表盘 ≈ 325×328（800×360 横屏、flex 4/9，卡内再让 8px）；
  /// - 启动自检浮层 ≈ 309×312（左右又各让 8px）；
  /// - 另外覆盖宽扁的 800×300（高为短边）与几个更小/更大的画布。
  const sizes = <Size>[
    Size(200, 200),
    Size(300, 300),
    Size(800, 300),
    Size(309, 312),
    Size(325, 328),
    Size(341, 344),
    Size(441, 736),
  ];

  group('GaugeGeometry 分层不变量', () {
    test('半径链严格有序：环带 < 刻度线 < 数字 < 画布半宽', () {
      for (final size in sizes) {
        final g = GaugeGeometry.of(size);
        final tag = '${size.width.toInt()}x${size.height.toInt()}';

        expect(g.ringInner, greaterThan(0), reason: '$tag: 环内缘必须为正');
        expect(g.ringOuter, greaterThan(g.ringInner),
            reason: '$tag: 环带外缘必须大于内缘');
        // 刻度线整体在环带外
        expect(g.tickOuter - g.tickMajorLen, greaterThanOrEqualTo(g.ringOuter),
            reason: '$tag: 粗刻度内端不得压进环带');
        // 细刻度更短，但与粗刻度**外端对齐**
        expect(g.tickMinorLen, lessThan(g.tickMajorLen),
            reason: '$tag: 细刻度必须比粗刻度短');
        // 数字在刻度线外侧
        expect(g.labelRadius, greaterThan(g.tickOuter),
            reason: '$tag: 数字必须在刻度线外侧');
        // 数字不出画布：最宽标签 3 字符（12k / 210），Roboto Mono 每字符
        // ≈0.6em，故半宽 ≈0.9×字号；这里按 0.95 留小额余量
        // （画布边缘的留白由 `outerPad` 单独负责，见"吃满环外空间"用例）
        expect(g.labelRadius + g.labelFontSize * 0.95, lessThanOrEqualTo(g.half),
            reason: '$tag: 刻度数字会超出画布');
        expect(g.backgroundRadius, greaterThanOrEqualTo(g.half),
            reason: '$tag: 背景盘应铺满卡片');
      }
    });

    test('所有半径有限且环径随画布半宽单调不减', () {
      double? last;
      for (final size in sizes) {
        final g = GaugeGeometry.of(size);
        for (final v in [
          g.half,
          g.ringRadius,
          g.ringWidth,
          g.tickOuter,
          g.labelRadius,
          g.labelFontSize,
          g.backgroundRadius,
          g.pointerTipRadius,
          g.hubRadius,
          g.centerValueFontSize,
        ]) {
          expect(v.isFinite, isTrue, reason: '$size 出现非有限半径');
        }
        expect(g.ringInner, greaterThan(0), reason: '$size: 兜底分支失效');
        if (last != null) {
          expect(g.ringRadius, greaterThanOrEqualTo(last),
              reason: '$size: 画布更大时环径不得反而变小');
        }
        last = g.ringRadius;
      }
    });

    test('指针尖端落在环带内侧，不与进度环重叠', () {
      for (final size in sizes) {
        final g = GaugeGeometry.of(size);
        expect(g.pointerTipRadius, lessThan(g.ringInner), reason: '$size');
        expect(g.pointerTipRadius, greaterThan(g.hubRadius * 2),
            reason: '$size: 指针不能退化成一个点');
      }
    });

    test('中心大字号由环内缘定标：明显大于旧的 0.24×环半径', () {
      for (final size in sizes) {
        final g = GaugeGeometry.of(size);
        // 旧实现是 fontSize = 0.24 × radius；缩径后沿用会让主读数变小，
        // 故改为 ringInner × 0.34，这里锁住"不再按环半径等比例缩小"。
        expect(g.centerValueFontSize, greaterThan(0.24 * g.ringRadius * 1.05),
            reason: '$size: 中心读数被环径缩水带小了');
      }
    });

    test('环位置只由画布尺寸决定：调刻度数字不会带着环一起动', () {
      // 锁死这条线。环半径的历史定义（= 画布半宽 − 54 一类的外圈预算）已冻结；
      // 刻度数字字号改由"环外剩余带宽"反解，但**不得**反过来影响环。
      for (final (size, expected) in const [
        (Size(325, 328), 109.3), // 主仪表盘
        (Size(341, 344), 116.4),
        (Size(441, 736), 166.4),
      ]) {
        expect(GaugeGeometry.of(size).ringRadius, closeTo(expected, 0.15),
            reason: '$size 的环半径被刻度数字字号带偏了（环不该随字号变化）');
      }
    });

    test('刻度数字锚在刻度线一侧：墨迹内沿让出固定缝，外沿不出画布', () {
      for (final size in sizes) {
        final g = GaugeGeometry.of(size);
        // 3 字符（12k / 210）实测：墨迹内沿 ≈0.92×字号、外沿 ≈0.86×字号
        // （行框外沿为 0.9×字号）。实现里用 0.95 作为内沿深度（含余量）。
        final inkInner = g.labelRadius - 0.95 * g.labelFontSize;
        final boxOuter = g.labelRadius + 0.9 * g.labelFontSize;
        // ① 间距锚点：墨迹内沿距刻度线外端恒为 labelGap = 4px
        expect(inkInner - g.tickOuter, closeTo(4.0, 0.51),
            reason: '$size: 数字与刻度线的缝是 ${inkInner - g.tickOuter} px（期望 4）');
        // ② 外沿不越界：距画布边至少 outerPad = 3（labelFill<1 时会更宽，不会更窄）
        expect(boxOuter, lessThanOrEqualTo(g.half - 2.99),
            reason: '$size: 刻度数字外沿被推出了画布（余量 ${g.half - boxOuter}）');
        expect(g.half - boxOuter, lessThan(12.0),
            reason: '$size: 数字离画布边太远（余量 ${g.half - boxOuter}），环外空间浪费了');
      }
    });

    test('缩径代价符合设计：环半径约画布半宽的 70%', () {
      final g = GaugeGeometry.of(const Size(341, 344));
      expect(g.ringRadius / g.half, inInclusiveRange(0.62, 0.78),
          reason: '参考尺寸下 ringRadius/half 应为 ~0.68（缩径约 28%）');
      expect(g.half - g.ringOuter, greaterThan(30),
          reason: '环带外应有 ~40px 的刻度+数字带宽');
    });
  });

  group('像素：刻度墨水全在环外', () {
    /// 渲染 painter 并返回 [宽, 高, 预乘 RGBA]。
    Future<(int, int, Uint8List)> rasterize(
      WidgetTester tester,
      CustomPainter painter,
      Size size,
    ) async {
      final image = await tester.runAsync(() async {
        final recorder = ui.PictureRecorder();
        painter.paint(Canvas(recorder), size);
        return recorder.endRecording().toImage(
              size.width.round(),
              size.height.round(),
            );
      });
      final data = await tester.runAsync(
        () => image!.toByteData(format: ui.ImageByteFormat.rawRgba),
      );
      return (image!.width, image.height, data!.buffer.asUint8List());
    }

    /// 刻度墨水分辨：背景盘/环带暗格是暗色（预乘后任一通道都 ≤ 59），
    /// 而刻度线与数字（青 00F0FF / 琥珀 FFB84D / 红 FF3B3B，含 0.6~0.8 透明）
    /// 混合后至少有一个通道 > 90。
    bool ink(Uint8List b, int w, int x, int y) {
      final i = (y * w + x) * 4;
      return b[i] > 90 || b[i + 1] > 90 || b[i + 2] > 90;
    }

    GaugeStaticPainter staticPainter() => GaugeStaticPainter(
          maxRpm: 12000,
          warnRpm: 7000,
          dangerRpm: 9000,
          maxSpeed: 240,
          warnSpeed: 120,
          dangerSpeed: 180,
        );

    testWidgets('刻度线与刻度数字之间必须有真实空档（字墨级，不是行框级）',
        (tester) async {
      // 真机反馈的"位数多了就和刻度线重叠"就发生在这一层：数字行框（1.2×字号）
      // 与字墨的径向深度不同（实测墨迹内沿 ≈0.92×字号 vs 行框 0.6×字号半高），
      // 所以只有量**真实渲染出来的字墨**才算数。
      for (final size in [const Size(325, 328), const Size(341, 344)]) {
        final g = GaugeGeometry.of(size);
        final (w, h, bytes) = await rasterize(tester, staticPainter(), size);

        var tickEnd = 0.0;
        var inkInner = double.infinity;
        for (var y = 0; y < h; y++) {
          for (var x = 0; x < w; x++) {
            if (!ink(bytes, w, x, y)) continue;
            final dx = x - g.center.dx;
            final dy = y - g.center.dy;
            final r = math.sqrt(dx * dx + dy * dy);
            if (r <= g.tickOuter + 1.5) {
              if (r > tickEnd) tickEnd = r;
            } else if (r < inkInner) {
              inkInner = r;
            }
          }
        }

        expect(inkInner - tickEnd, greaterThanOrEqualTo(2.5),
            reason: '$size: 刻度线与数字之间只剩 ${inkInner - tickEnd} px 空档'
                '（刻度线外端 $tickEnd / 数字墨迹内沿 $inkInner）');
      }
    });

    testWidgets('静态层：刻度线与数字全在环带内缘之外', (tester) async {
      for (final size in [const Size(341, 344), const Size(800, 300)]) {
        final g = GaugeGeometry.of(size);
        final tag = '${size.width.toInt()}x${size.height.toInt()}';
        final (w, h, bytes) = await rasterize(tester, staticPainter(), size);

        var count = 0;
        var minR = double.infinity;
        var maxR = 0.0;
        for (var y = 0; y < h; y++) {
          for (var x = 0; x < w; x++) {
            if (!ink(bytes, w, x, y)) continue;
            final dx = x - g.center.dx;
            final dy = y - g.center.dy;
            final r = math.sqrt(dx * dx + dy * dy);
            count++;
            if (r < minR) minR = r;
            if (r > maxR) maxR = r;
          }
        }

        expect(count, greaterThan(200), reason: '$tag: 刻度/数字应当画出来了');
        // 核心不变量：环带内缘以内不得再有任何刻度墨水
        expect(minR, greaterThanOrEqualTo(g.ringInner - 1),
            reason: '$tag: 仍有刻度墨水落在环带内'
                '（最小半径 $minR < 环内缘 ${g.ringInner}）');
        // 刻度线确实伸到了环带外
        expect(maxR, greaterThan(g.ringOuter + 6),
            reason: '$tag: 刻度线没伸到环外（最大半径 $maxR）');
        // 数字画在最外层（label 环）附近，而不是留在环内
        expect(maxR, greaterThanOrEqualTo(g.labelRadius - g.labelFontSize),
            reason: '$tag: 刻度数字没有画到最外层（最大半径 $maxR）');
      }
    });

    testWidgets('动态层：进度环仍画在 ringRadius 上，环带内侧是空的',
        (tester) async {
      const size = Size(341, 344);
      final g = GaugeGeometry.of(size);
      final (w, h, bytes) = await rasterize(
        tester,
        CombinedGaugePainter(
          rpm: 12000, // 上半圆整条点亮，正上方射线必定落在环带上
          speed: 0, // 速度弧/指针不绘制
          gear: 0,
          peakRpm: 0,
          peakSpeed: 0,
          maxRpm: 12000,
          warnRpm: 7000,
          dangerRpm: 9000,
          maxSpeed: 240,
          warnSpeed: 120,
          dangerSpeed: 180,
        ),
        size,
      );

      // 正上方射线（角度 3π/2）：此时 RPM 指针指向右侧、速度指针不画，
      // 射线只穿过进度环，不穿过任何中心数值/指针。
      bool rayInk(double r) {
        final x = g.center.dx.round();
        final y = (g.center.dy - r).round();
        expect(y, inInclusiveRange(0, h - 1));
        expect(x, inInclusiveRange(0, w - 1));
        return ink(bytes, w, x, y);
      }

      expect(rayInk(g.ringRadius), isTrue,
          reason: '进度环必须还画在 ringRadius(${g.ringRadius}) 上');
      expect(rayInk(g.ringOuter + 6), isFalse,
          reason: '环外不应再有进度弧（刻度由静态层画在更外侧）');
      expect(rayInk(g.ringInner - 4), isFalse,
          reason: '环带内侧不应再有墨水（刻度已移到环外）');
    });
  });

  group('卡片布局：画布＝卡盒（仪表整体大小的主杠杆）', () {
    testWidgets('CombinedGaugeCard 不再内缩 8px：画布尺寸＝卡片盒子', (tester) async {
      // 画布每小一圈，环半径（= 半宽 − 冻结预算）、刻度、数字会**一起**变小，
      // 所以"整体显小"的第一杠杆是卡盒尺寸本身，不是环外带宽。
      // 曾经的 8px 内边距让画布只有 325×328（卡盒 341×344），白丢 ~5% 直径。
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsProvider();
      await settings.init();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<OBDDataProvider>.value(
              value: OBDDataProvider(),
            ),
            ChangeNotifierProvider<SettingsProvider>.value(value: settings),
          ],
          child: const Directionality(
            textDirection: TextDirection.ltr,
            child: Center(
              child: SizedBox(
                width: 341,
                height: 344,
                child: CombinedGaugeCard(),
              ),
            ),
          ),
        ),
      );

      final staticPaint = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is GaugeStaticPainter,
      );
      expect(tester.getSize(staticPaint), const Size(341, 344),
          reason: '卡片又内缩了：画布应当等于卡盒（不要再套内边距）');
      expect(tester.takeException(), isNull);
    });
  });

  group('启动自检浮层（复用同一套 painter，画布更小）', () {
    testWidgets('800×360 下整段动画跑完不抛异常、不溢出', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 360,
              child: SelfCheckOverlay(
                onComplete: () {},
                maxRpm: 12000,
                warnRpm: 7000,
                dangerRpm: 9000,
                maxSpeed: 240,
                warnSpeed: 120,
                dangerSpeed: 180,
              ),
            ),
          ),
        ),
      );

      // 扫完 2s 动画（含 rise/fall/opacity 三段）
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 200));
        expect(tester.takeException(), isNull,
            reason: '第 $i 帧自检浮层抛异常（几何在该尺寸下不成立）');
      }

      // 该浮层左右各再 Padding(8)：几何必须靠比例 clamp 自适应到更小的画布
      final inner = GaugeGeometry.of(const Size(309, 312));
      expect(inner.ringInner, greaterThan(0));
      expect(inner.ringRadius, lessThan(GaugeGeometry.of(const Size(325, 328)).ringRadius));
    });
  });
}
