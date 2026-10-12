import 'package:flutter/material.dart';

import '../data/amap/models.dart';
import '../data/amap/route_analyzer.dart';
import '../theme/app_theme.dart';

/// 转向类型（方案 §3.6：按 `main_action` 官方枚举映射）
enum NaviTurnType {
  straight, // 直行
  turnLeft,
  turnRight,
  slightLeft, // 向左前方行驶（浅斜）
  slightRight, // 向右前方行驶
  sharpLeft, // 向左后方行驶（回折）
  sharpRight, // 向右后方行驶
  uTurn, // 左转调头
  keepLeft, // 靠左
  keepRight, // 靠右
  roundaboutEnter, // 进入环岛
  roundaboutExit, // 离开环岛
  slowDown, // 减速行驶
  tollGate, // 收费站门架（官方 main_action 里没有"收费站"，保留给将来接 assist_action=26）
  arrive, // 到达（只用于终点段，见 [naviTurnTypeOfAction]）
  unknown,
}

/// 动作码 → 转向类型（**官方枚举**，14 项 0~13）
///
/// 依据 `amap_test01/docs/amap-share-api-reference.md` §2.11（高德官方
/// 「驾车动作列表」，区间/几何/语义三重佐证）。**注意与本工程早期版本的差异**：
/// 旧表把 `3` 当直行、`9` 当左转、`10` 当直行 —— 那版是几何猜测，已被官方枚举
/// 推翻，表现就是"高德说向左前方/靠左，本 app 画成直行或硬拐弯"。
NaviTurnType naviTurnTypeOf(int actionCode) {
  switch (actionCode) {
    case 1:
      return NaviTurnType.turnLeft;
    case 2:
      return NaviTurnType.turnRight;
    case 3:
      return NaviTurnType.slightLeft; // 向左前方行驶
    case 4:
      return NaviTurnType.slightRight; // 向右前方行驶
    case 5:
      return NaviTurnType.sharpLeft; // 向左后方行驶
    case 6:
      return NaviTurnType.sharpRight; // 向右后方行驶
    case 7:
      return NaviTurnType.uTurn; // 左转调头
    case 9:
      return NaviTurnType.keepLeft; // 靠左
    case 10:
      return NaviTurnType.keepRight; // 靠右
    case 11:
      return NaviTurnType.roundaboutEnter; // 进入环岛
    case 12:
      return NaviTurnType.roundaboutExit; // 离开环岛
    case 13:
      return NaviTurnType.slowDown; // 减速行驶（实测只出现在收费站路段）
    case 0: // 官方"无基本导航动作"：按继续直行画，终点段由下面升级为"到达"
    case 8:
      return NaviTurnType.straight;
    default:
      return NaviTurnType.unknown;
  }
}

/// 动作点 → 转向类型（用上下文消歧 `0` 码）。
///
/// 官方 `0` 是"无基本导航动作"，实测它只出现在**路线终点段**；所以只有
/// **终点段**（`nextRoadName == null`，见 `RouteAnalyzer._build`）上的 0 才画成
/// "到达"，路段中间的 0 老老实实画直行 —— 否则会对着一条普通路段喊"到达"。
NaviTurnType naviTurnTypeOfAction(ActionPoint action) =>
    action.actionCode == 0 && action.nextRoadName == null
        ? NaviTurnType.arrive
        : naviTurnTypeOf(action.actionCode);

/// 动作中文标签；未知码返回 null（由调用方改用路名，不显示"未知动作(N)"）
///
/// `0` 码返回 null：官方语义是"无动作"，中间路段不该显示任何动作名；
/// 终点段的"到达"请用 [naviTurnLabelOfAction]。
String? naviTurnLabel(int actionCode) {
  if (actionCode == 0) return null;
  if (actionCode >= 0 && actionCode <= 13) return ActionCodes.of(actionCode);
  return null;
}

/// 动作点 → 中文标签（同 [naviTurnTypeOfAction]：0 码只在终点段显示"到达"）
String? naviTurnLabelOfAction(ActionPoint action) =>
    action.actionCode == 0 && action.nextRoadName == null
        ? '到达'
        : naviTurnLabel(action.actionCode);

/// 该转向是否"向左"（决定通栏侧光方向，方案 §2.3）
bool naviTurnIsLeft(NaviTurnType t) => switch (t) {
      NaviTurnType.turnLeft ||
      NaviTurnType.slightLeft ||
      NaviTurnType.sharpLeft ||
      NaviTurnType.uTurn ||
      NaviTurnType.keepLeft =>
        true,
      _ => false,
    };

/// 转向箭头（自绘，非字体图标 —— 文字箭头在不同 ROM 下字形不一致）
///
/// 几何在归一化 1×1 空间定义，绘制时按 [size] 缩放；
/// [glow] 为 true 时叠加一层模糊描边形成霓虹外发光。
class NaviTurnArrow extends StatelessWidget {
  const NaviTurnArrow({
    super.key,
    required this.type,
    required this.size,
    this.color = AppTheme.gaugeNormal,
    this.glow = true,
  });

  final NaviTurnType type;
  final double size;
  final Color color;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _TurnArrowPainter(type: type, color: color, glow: glow),
        ),
      ),
    );
  }
}

class _TurnArrowPainter extends CustomPainter {
  _TurnArrowPainter({
    required this.type,
    required this.color,
    required this.glow,
  });

  final NaviTurnType type;
  final Color color;
  final bool glow;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final stroke = (s * 0.13).clamp(1.5, 14.0);
    final pad = s * 0.10;
    final box = Rect.fromLTWH(pad, pad, s - pad * 2, s - pad * 2);

    Offset p(double x, double y) =>
        Offset(box.left + x * box.width, box.top + y * box.height);

    final spec = _specFor(type);

    // ── 环岛类：圆 + 进出支线 ──
    if (type == NaviTurnType.roundaboutEnter ||
        type == NaviTurnType.roundaboutExit) {
      _paintRoundabout(
          canvas, box, stroke, type == NaviTurnType.roundaboutEnter);
      return;
    }

    // ── 收费站：门架 ──
    if (type == NaviTurnType.tollGate) {
      _paintTollGate(canvas, box, stroke);
      return;
    }

    // ── 到达：旗杆 + 旗面 ──
    if (type == NaviTurnType.arrive) {
      _paintArrive(canvas, box, stroke);
      return;
    }

    // ── 通用：折线 + 箭头 ──
    final pts = spec.points.map((e) => p(e.$1, e.$2)).toList();
    if (pts.length < 2) return;

    // 箭头指向最后一段的方向
    final tip = pts.last;
    final prev = pts[pts.length - 2];
    final dir = tip - prev;
    if (dir.distance < 1e-6) return;
    final unit = dir / dir.distance;
    final head = _headGeometry(stroke, dir.distance);

    // 线茎在三角头**底边**处收笔，不能一路画到 tip ——
    // 三角形越靠近尖端越窄，在距尖端 head.len 内其半宽小于线茎半宽，
    // 若线茎画到 tip，它会把三角头的上半段整块盖掉，
    // 顶部于是呈现"平头矩形 + 两侧斜肩"，完全读不出三角形。
    final shaft = List<Offset>.of(pts)..[pts.length - 1] = tip - unit * head.len;

    final path = Path()..moveTo(shaft.first.dx, shaft.first.dy);
    for (var i = 1; i < shaft.length; i++) {
      path.lineTo(shaft[i].dx, shaft[i].dy);
    }

    _stroke(canvas, path, stroke);

    // 支线（靠左/靠右的分叉短线）
    for (final branch in spec.branches) {
      final from = p(branch.fromX, branch.fromY);
      final to = p(branch.toX, branch.toY);
      final b = Path()
        ..moveTo(from.dx, from.dy)
        ..lineTo(to.dx, to.dy);
      _stroke(canvas, b, stroke * 0.75, alphaBoost: 0.55);
    }

    _drawHead(canvas, tip, unit, head);
  }

  /// 三角头的几何：轴线高度 [len] 与底边半宽 [half]。
  ///
  /// 两条约束：
  /// - 底边必须明显宽于线茎（约 2.6 倍线宽），否则读不出"箭头"；
  /// - 头长最多占末段的 70%，否则线茎被吃光、只剩一枚孤立的三角，
  ///   （环岛进/出支线这类短段尤其明显）。
  ({double len, double half}) _headGeometry(double stroke, double segmentLength) {
    var len = stroke * 2.8;
    final cap = segmentLength * 0.7;
    if (len > cap) len = cap;
    return (len: len, half: len * 0.44);
  }

  /// 描边（发光层 + 实芯层）
  ///
  /// 折角用 [StrokeJoin.miter]（尖角）——`round` 会把 90° 拐角画成圆弧，
  /// 在大箭头时代看着柔和，缩到动作条的 44px 就变成"不是箭头"了。
  /// 辉光半径跟随线宽（而非固定像素），否则小尺寸下 1 倍线宽的模糊会把尖端糊成圆点。
  void _stroke(Canvas canvas, Path path, double stroke, {double alphaBoost = 1}) {
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt
      ..strokeJoin = StrokeJoin.miter;

    if (glow) {
      canvas.drawPath(
        path,
        base
          ..color = color.withValues(alpha: 0.30 * alphaBoost)
          ..strokeWidth = stroke * 2.0
          ..maskFilter = MaskFilter.blur(
            BlurStyle.normal,
            (stroke * 0.55).clamp(1.0, 6.0),
          ),
      );
    }
    canvas.drawPath(
      path,
      base
        ..color = color.withValues(alpha: alphaBoost)
        ..strokeWidth = stroke
        ..maskFilter = null,
    );
  }

  /// 画三角头。[head] 与线茎收笔用的是同一份几何（见 [_headGeometry]），
  /// 否则线茎会伸进三角头内部、把它的尖梢盖掉。
  void _drawHead(
    Canvas canvas,
    Offset tip,
    Offset dir,
    ({double len, double half}) head,
  ) {
    if (dir.distance < 1e-6 || head.len <= 0) return;
    final u = dir / dir.distance;
    final n = Offset(-u.dy, u.dx);
    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(tip.dx - u.dx * head.len + n.dx * head.half,
          tip.dy - u.dy * head.len + n.dy * head.half)
      ..lineTo(tip.dx - u.dx * head.len - n.dx * head.half,
          tip.dy - u.dy * head.len - n.dy * head.half)
      ..close();
    if (glow) {
      canvas.drawPath(
        path,
        Paint()
          ..color = color.withValues(alpha: 0.30)
          ..maskFilter = MaskFilter.blur(
            BlurStyle.normal,
            (head.len * 0.5).clamp(1.0, 6.0),
          ),
      );
    }
    canvas.drawPath(path, Paint()..color = color);
  }

  void _paintRoundabout(Canvas canvas, Rect box, double stroke, bool incoming) {
    final center = box.center;
    final r = box.width * 0.30;
    final ring = Path()
      ..addArc(
        Rect.fromCircle(center: center, radius: r),
        incoming ? -1.35 : 0.55,
        incoming ? 4.6 : 4.4,
      );
    _stroke(canvas, ring, stroke * 0.9);

    // 入口从下方接进环岛，出口从环岛向上离开
    final tip = incoming
        ? Offset(center.dx, center.dy + r * 0.9)
        : Offset(center.dx + r * 0.2, box.top + box.height * 0.06);
    final prev = incoming
        ? Offset(center.dx, box.bottom)
        : Offset(center.dx + r * 0.85, box.top + box.height * 0.06);
    final dir = tip - prev;
    final head = _headGeometry(stroke * 0.85, dir.distance);
    // 支线在三角头底边处收笔，否则线茎会把尖梢盖成"平头矩形"（短段尤其明显）
    final shaftEnd =
        dir.distance > 1e-6 ? tip - dir / dir.distance * head.len : tip;

    final stem = Path();
    if (incoming) {
      stem
        ..moveTo(center.dx, box.bottom)
        ..lineTo(shaftEnd.dx, shaftEnd.dy);
    } else {
      stem
        ..moveTo(center.dx + r * 0.85, center.dy - r * 0.52)
        ..lineTo(center.dx + r * 0.85, box.top + box.height * 0.06)
        ..lineTo(shaftEnd.dx, shaftEnd.dy);
    }
    _stroke(canvas, stem, stroke * 0.85);

    _drawHead(canvas, tip, dir, head);
  }

  void _paintTollGate(Canvas canvas, Rect box, double stroke) {
    final left = box.left + box.width * 0.12;
    final right = box.right - box.width * 0.12;
    final top = box.top + box.height * 0.30;
    final bottom = box.bottom - box.height * 0.08;
    final gate = Path()
      ..moveTo(left, bottom)
      ..lineTo(left, top)
      ..lineTo(right, top)
      ..lineTo(right, bottom);
    _stroke(canvas, gate, stroke * 0.9);
    // 中间抬起的栏杆
    final bar = Path()
      ..moveTo(box.left + box.width * 0.30, bottom)
      ..lineTo(box.left + box.width * 0.72, box.top + box.height * 0.52);
    _stroke(canvas, bar, stroke * 0.6, alphaBoost: 0.65);
  }

  void _paintArrive(Canvas canvas, Rect box, double stroke) {
    final pole = Path()
      ..moveTo(box.left + box.width * 0.28, box.bottom)
      ..lineTo(box.left + box.width * 0.28, box.top + box.height * 0.08);
    _stroke(canvas, pole, stroke * 0.85);
    final flag = Path()
      ..moveTo(box.left + box.width * 0.28, box.top + box.height * 0.08)
      ..lineTo(box.right - box.width * 0.10, box.top + box.height * 0.26)
      ..lineTo(box.left + box.width * 0.28, box.top + box.height * 0.46)
      ..close();
    if (glow) {
      canvas.drawPath(
        flag,
        Paint()
          ..color = color.withValues(alpha: 0.30)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }
    canvas.drawPath(flag, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _TurnArrowPainter old) =>
      old.type != type || old.color != color || old.glow != glow;
}

/// 归一化折线定义（方案 §3.6 的箭头形状表）
class _Branch {
  const _Branch(this.fromX, this.fromY, this.toX, this.toY);
  final double fromX;
  final double fromY;
  final double toX;
  final double toY;
}

class _ArrowSpec {
  const _ArrowSpec(this.points, {this.branches = const []});
  final List<(double, double)> points;
  final List<_Branch> branches;
}

_ArrowSpec _specFor(NaviTurnType t) {
  switch (t) {
    case NaviTurnType.straight:
    case NaviTurnType.unknown:
      return const _ArrowSpec([(0.5, 0.94), (0.5, 0.12)]);
    case NaviTurnType.turnLeft:
      return const _ArrowSpec([(0.62, 0.94), (0.62, 0.40), (0.16, 0.40)]);
    case NaviTurnType.turnRight:
      return const _ArrowSpec([(0.38, 0.94), (0.38, 0.40), (0.84, 0.40)]);
    case NaviTurnType.slightLeft:
      return const _ArrowSpec([(0.66, 0.94), (0.38, 0.16)]);
    case NaviTurnType.slightRight:
      return const _ArrowSpec([(0.34, 0.94), (0.62, 0.16)]);
    case NaviTurnType.sharpLeft:
      return const _ArrowSpec([(0.68, 0.90), (0.68, 0.34), (0.18, 0.60)]);
    case NaviTurnType.sharpRight:
      return const _ArrowSpec([(0.32, 0.90), (0.32, 0.34), (0.82, 0.60)]);
    case NaviTurnType.uTurn:
      return const _ArrowSpec([
        (0.66, 0.94),
        (0.66, 0.30),
        (0.34, 0.30),
        (0.34, 0.62),
      ]);
    case NaviTurnType.keepLeft:
      return const _ArrowSpec(
        [(0.54, 0.94), (0.54, 0.52), (0.24, 0.18)],
        branches: [
          _Branch(0.54, 0.52, 0.80, 0.30),
        ],
      );
    case NaviTurnType.keepRight:
      return const _ArrowSpec(
        [(0.46, 0.94), (0.46, 0.52), (0.76, 0.18)],
        branches: [
          _Branch(0.46, 0.52, 0.20, 0.30),
        ],
      );
    case NaviTurnType.slowDown:
      return const _ArrowSpec([(0.5, 0.10), (0.5, 0.90)]);
    case NaviTurnType.roundaboutEnter:
    case NaviTurnType.roundaboutExit:
      return const _ArrowSpec([]);
    case NaviTurnType.tollGate:
    case NaviTurnType.arrive:
      return const _ArrowSpec([(0.5, 0.94), (0.5, 0.12)]);
  }
}
