import 'package:flutter_test/flutter_test.dart';
import 'package:obd_dashboard/data/amap/models.dart';
import 'package:obd_dashboard/data/amap/route_analyzer.dart';
import 'package:obd_dashboard/widgets/navi_turn_arrow.dart';

/// `main_action` 官方枚举 → 转向形状 / 文案 的映射回归
///
/// 依据 `docs/amap-share-api-reference.md` §2.11（高德官方
/// 「驾车动作列表」，区间闭合 / 几何转角 / 语义三重佐证）。
///
/// **本文件的存在意义是挡住"退回几何猜测"**：工程早期版本按几何反推，
/// 把 `3` 当直行、`5` 当左前方、`7` 当左后方、`9` 当左转、`10` 当直行 ——
/// 那一版已被官方枚举推翻（接口文档 §8 明确记在"失败过的断言"里），
/// 真机表现就是"高德说向左前方/靠左，本 app 画成直行或硬拐弯"。
///
/// 本工程离线样本的几何自检也与官方表一致：3 = −16°~−25°（浅左）、
/// 7 = −174°（调头）、9 = −8°（靠左）、10 = +27°（靠右）。
void main() {
  /// 官方枚举：`code -> (中文名, 箭头形状)`
  const official = <int, (String, NaviTurnType)>{
    1: ('左转', NaviTurnType.turnLeft),
    2: ('右转', NaviTurnType.turnRight),
    3: ('向左前方行驶', NaviTurnType.slightLeft),
    4: ('向右前方行驶', NaviTurnType.slightRight),
    5: ('向左后方行驶', NaviTurnType.sharpLeft),
    6: ('向右后方行驶', NaviTurnType.sharpRight),
    7: ('左转调头', NaviTurnType.uTurn),
    8: ('直行', NaviTurnType.straight),
    9: ('靠左', NaviTurnType.keepLeft),
    10: ('靠右', NaviTurnType.keepRight),
    11: ('进入环岛', NaviTurnType.roundaboutEnter),
    12: ('离开环岛', NaviTurnType.roundaboutExit),
    13: ('减速行驶', NaviTurnType.slowDown),
  };

  group('官方枚举逐条对拍', () {
    for (final e in official.entries) {
      test('code ${e.key} = ${e.value.$1} → ${e.value.$2.name}', () {
        expect(ActionCodes.of(e.key), e.value.$1);
        expect(naviTurnTypeOf(e.key), e.value.$2);
        expect(naviTurnLabel(e.key), e.value.$1);
      });
    }
  });

  group('不许退回几何猜测', () {
    test('3 是"向左前方"（不是直行）、9 是"靠左"（不是左转）、10 是"靠右"（不是直行）', () {
      expect(naviTurnTypeOf(3), NaviTurnType.slightLeft);
      expect(naviTurnTypeOf(3), isNot(NaviTurnType.straight));

      expect(naviTurnTypeOf(9), NaviTurnType.keepLeft);
      expect(naviTurnTypeOf(9), isNot(NaviTurnType.turnLeft));

      expect(naviTurnTypeOf(10), NaviTurnType.keepRight);
      expect(naviTurnTypeOf(10), isNot(NaviTurnType.straight));
    });

    test('7 是调头（不是"左后方"）、11 是进入环岛（不是调头）', () {
      expect(naviTurnTypeOf(7), NaviTurnType.uTurn);
      expect(naviTurnTypeOf(11), NaviTurnType.roundaboutEnter);
      expect(naviTurnTypeOf(12), NaviTurnType.roundaboutExit);
    });

    test('前后不能颠倒：5/6 是"后方"，3/4 是"前方"', () {
      expect(naviTurnTypeOf(5), NaviTurnType.sharpLeft);
      expect(naviTurnTypeOf(6), NaviTurnType.sharpRight);
      expect(naviTurnIsLeft(NaviTurnType.slightLeft), isTrue);
      expect(naviTurnIsLeft(NaviTurnType.slightRight), isFalse);
    });
  });

  group('0 码需要上下文：只有终点段才是"到达"', () {
    ActionPoint point(int code, {String? nextRoad}) => ActionPoint(
          segmentIndex: 0,
          actionCode: code,
          atDistance: 100,
          roadName: '测试路',
          nextRoadName: nextRoad,
          travelTime: 10,
        );

    test('终点段（nextRoadName == null）→ 到达', () {
      final end = point(0);
      expect(naviTurnTypeOfAction(end), NaviTurnType.arrive);
      expect(naviTurnLabelOfAction(end), '到达');
    });

    test('路段中间的 0 → 继续直行，且不给动作名（走路名兜底）', () {
      final mid = point(0, nextRoad: '下一条路');
      expect(naviTurnTypeOfAction(mid), NaviTurnType.straight);
      expect(naviTurnLabelOfAction(mid), isNull);
      expect(naviTurnLabel(0), isNull,
          reason: '官方 0 是"无基本导航动作"，不能当动作名显示');
    });

    test('非 0 码不受上下文影响', () {
      expect(naviTurnTypeOfAction(point(9)), NaviTurnType.keepLeft);
      expect(naviTurnLabelOfAction(point(9)), '靠左');
    });
  });

  group('未知码', () {
    test('越界码退化为通用箭头且不给动作名（界面走路名兜底）', () {
      for (final code in [14, 44, 99, -1]) {
        expect(naviTurnTypeOf(code), NaviTurnType.unknown);
        expect(naviTurnLabel(code), isNull);
      }
      expect(ActionCodes.of(99), contains('未知动作'));
      expect(ActionCodes.isInferred(99), isTrue);
      expect(ActionCodes.isInferred(9), isFalse);
    });
  });
}
