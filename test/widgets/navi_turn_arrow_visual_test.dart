import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obd_dashboard/widgets/navi_turn_arrow.dart';

/// 全量动作箭头**视觉对照表**（人工目视审查用，不参与断言）
///
/// 覆盖：官方 `main_action` 枚举 §2.11 的 14 项（0~13）+ 3 个自绘特例
/// （到达 / 收费站门架 / 未知码兜底）。
///
/// 重新生成：
/// ```bash
/// flutter test --update-goldens test/widgets/navi_turn_arrow_visual_test.dart
/// ```
/// 产物：`test/widgets/navi_turn_arrows.png`（2220×1480，画布按 2x 设计）
///
/// 断言侧的映射正确性由 `navi_turn_arrow_mapping_test.dart`（逐条对拍 + 反退回）
/// 与 `navi_turn_arrow_paint_test.dart`（读像素几何）负责；本文件只管"画出来长什么样"。
void main() {
  testWidgets('全量动作箭头对照表', (tester) async {
    // 固定画布：2220×1480、dpr=1.0 ⇒ golden 直接落成 2220×1480 的清晰图
    tester.view.physicalSize = const Size(2220, 1480);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    /// 官方枚举码
    const official = <(int, String, NaviTurnType)>[
      (0, '无动作（路段中→直行）', NaviTurnType.straight),
      (1, '左转', NaviTurnType.turnLeft),
      (2, '右转', NaviTurnType.turnRight),
      (3, '向左前方行驶', NaviTurnType.slightLeft),
      (4, '向右前方行驶', NaviTurnType.slightRight),
      (5, '向左后方行驶', NaviTurnType.sharpLeft),
      (6, '向右后方行驶', NaviTurnType.sharpRight),
      (7, '左转调头', NaviTurnType.uTurn),
      (8, '直行', NaviTurnType.straight),
      (9, '靠左', NaviTurnType.keepLeft),
      (10, '靠右', NaviTurnType.keepRight),
      (11, '进入环岛', NaviTurnType.roundaboutEnter),
      (12, '离开环岛', NaviTurnType.roundaboutExit),
      (13, '减速行驶', NaviTurnType.slowDown),
    ];

    /// 自绘特例（不在 main_action 枚举里）
    const special = <(String, String, NaviTurnType)>[
      ('—', '到达（0 码 + 终点段）', NaviTurnType.arrive),
      ('—', '收费站门架（预留）', NaviTurnType.tollGate),
      ('—', '未知码兜底', NaviTurnType.unknown),
    ];

    Widget tile({
      required String code,
      required String cn,
      required NaviTurnType type,
      required bool isOfficial,
    }) {
      return SizedBox(
        width: 336,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 264,
              height: 264,
              decoration: BoxDecoration(
                color: const Color(0xFF12171D),
                border: Border.all(color: Colors.white24, width: 2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: NaviTurnArrow(type: type, size: 208, glow: true),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              code,
              style: TextStyle(
                color: isOfficial
                    ? const Color(0xFF4DD8E6)
                    : const Color(0xFF8A93A3),
                fontSize: 26,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              cn,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 24),
            ),
            Text(
              type.name,
              style: const TextStyle(color: Colors.white38, fontSize: 18),
            ),
          ],
        ),
      );
    }

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: const Color(0xFF0B0E12),
          body: Padding(
            padding: const EdgeInsets.fromLTRB(60, 44, 60, 44),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '导航动作箭头对照表',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 42,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'main_action 官方枚举 §2.11（amap-share-api-reference.md）·  '
                  'NaviTurnArrow 自绘 · 色值 AppTheme.gaugeNormal',
                  style: TextStyle(color: Colors.white54, fontSize: 22),
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: 2100,
                  child: Wrap(
                    spacing: 16,
                    runSpacing: 34,
                    children: [
                      for (final e in official)
                        tile(
                          code: '码 ${e.$1}',
                          cn: e.$2,
                          type: e.$3,
                          isOfficial: true,
                        ),
                      for (final e in special)
                        tile(
                          code: e.$1,
                          cn: e.$2,
                          type: e.$3,
                          isOfficial: false,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('navi_turn_arrows.png'),
    );
  });
}
