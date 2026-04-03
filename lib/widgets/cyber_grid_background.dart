import 'package:flutter/material.dart';
import 'dart:math' as math;

/// 全局赛博风格背景：深蓝黑渐变 + 不规则电路走线纹理
class CyberGridBackground extends StatelessWidget {
  final Widget child;
  const CyberGridBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // ① 底色渐变
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF060A14), // 深蓝黑（左上角）
                  Color(0xFF080E22), // 中心深蓝（稍暗）
                  // Color(0xFF280D48), // 深紫黑（右下角，稍亮）
                  Color(0xFF1E0F38), // 深紫色 略亮一点，整体仍很暗
                ],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
          ),
        ),
        // ② 电路走线纹理
        Positioned.fill(
          child: CustomPaint(painter: _CircuitPainter()),
        ),
        // ③ 内容层
        child,
      ],
    );
  }
}

// ─────────────────────────────────────────────
// 电路走线数据模型
// ─────────────────────────────────────────────
class _CircuitTrace {
  final List<Offset> points;
  final bool isGlow;

  const _CircuitTrace(this.points, {this.isGlow = false});
}

// ─────────────────────────────────────────────
// CustomPainter 实现
// ─────────────────────────────────────────────
class _CircuitPainter extends CustomPainter {
  // App 启动时生成一次种子，保证同一次运行内图案稳定，但每次启动不同
  static final int _seed = DateTime.now().millisecondsSinceEpoch;

  // 预生成走线数据（静态缓存，只算一次）
  static List<_CircuitTrace>? _cachedTraces;
  static List<Offset>? _cachedVias;
  static Size? _cachedSize;

  @override
  void paint(Canvas canvas, Size size) {
    // 首次或尺寸变化时重新生成
    if (_cachedTraces == null || _cachedSize != size) {
      final rng = math.Random(_seed);
      _cachedTraces = _generateTraces(size, rng);
      _cachedVias = _generateVias(size, rng);
      _cachedSize = size;
    }

    final traces = _cachedTraces!;
    final vias = _cachedVias!;

    // --- 暗走线 ---
    final dimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6
      ..strokeCap = StrokeCap.square
      ..color = const Color(0xFF1A4A7A).withValues(alpha: 0.12);

    for (final trace in traces) {
      if (!trace.isGlow) {
        _drawTracePath(canvas, trace.points, dimPaint);
      }
    }

    // --- 发光走线（光晕层）---
    final glowHaloPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF00BFFF).withValues(alpha: 0.05);

    // --- 发光走线（主线层）---
    final glowCorePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7
      ..strokeCap = StrokeCap.square
      ..color = const Color(0xFF29B6F6).withValues(alpha: 0.20);

    for (final trace in traces) {
      if (trace.isGlow) {
        _drawTracePath(canvas, trace.points, glowHaloPaint);
        _drawTracePath(canvas, trace.points, glowCorePaint);
      }
    }

    // --- 走线折点节点圆圈 ---
    final nodePaint = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF1565C0).withValues(alpha: 0.18);

    final glowNodePaint = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF42A5F5).withValues(alpha: 0.35);

    for (final trace in traces) {
      // 只在中间折点（不含首尾端点）画节点
      for (int i = 1; i < trace.points.length - 1; i++) {
        final p = trace.points[i];
        if (trace.isGlow) {
          // 发光走线节点：外环+内芯
          canvas.drawCircle(
              p,
              2.5,
              Paint()
                ..style = PaintingStyle.fill
                ..color = const Color(0xFF00BFFF).withValues(alpha: 0.08));
          canvas.drawCircle(p, 1.2, glowNodePaint);
        } else {
          canvas.drawCircle(p, 1.0, nodePaint);
        }
      }
    }

    // --- Via 焊盘（双环）---
    final viaOuterPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = const Color(0xFF1976D2).withValues(alpha: 0.22);
    final viaInnerPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF0D47A1).withValues(alpha: 0.18);

    for (final via in vias) {
      canvas.drawCircle(via, 3.5, viaOuterPaint);
      canvas.drawCircle(via, 1.5, viaInnerPaint);
    }
  }

  /// 绘制一条折线路径（只走水平/垂直，自动连折点）
  void _drawTracePath(Canvas canvas, List<Offset> points, Paint paint) {
    if (points.length < 2) return;
    final path = Path()..moveTo(points[0].dx, points[0].dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(path, paint);
  }

  /// 生成所有走线
  static List<_CircuitTrace> _generateTraces(Size size, math.Random rng) {
    const int dimCount = 100; // 暗走线数量
    const int glowCount = 14; // 发光走线数量

    final traces = <_CircuitTrace>[];

    for (int i = 0; i < dimCount; i++) {
      final pts = _generateTracePath(size, rng);
      if (pts.length >= 2) traces.add(_CircuitTrace(pts));
    }

    for (int i = 0; i < glowCount; i++) {
      final pts = _generateTracePath(size, rng, minSegments: 2, maxSegments: 5);
      if (pts.length >= 2) traces.add(_CircuitTrace(pts, isGlow: true));
    }

    return traces;
  }

  /// 生成一条 PCB 风格折线路径（只走 0°/90°）
  static List<Offset> _generateTracePath(
    Size size,
    math.Random rng, {
    int minSegments = 2,
    int maxSegments = 6,
  }) {
    final points = <Offset>[];

    // 随机起点（允许稍微超出边缘，增加自然感）
    double x = rng.nextDouble() * size.width;
    double y = rng.nextDouble() * size.height;
    points.add(Offset(x, y));

    // 随机初始方向：true = 水平，false = 垂直
    bool horizontal = rng.nextBool();

    final segCount = minSegments + rng.nextInt(maxSegments - minSegments + 1);

    for (int i = 0; i < segCount; i++) {
      // 线段长度：20~160px，主要集中在 40~100px
      final len = 20.0 + rng.nextDouble() * 140.0;
      // 正负方向
      final sign = rng.nextBool() ? 1.0 : -1.0;

      if (horizontal) {
        x = (x + sign * len).clamp(-20, size.width + 20);
      } else {
        y = (y + sign * len).clamp(-20, size.height + 20);
      }

      points.add(Offset(x, y));

      // 下一段切换水平/垂直，偶尔（20%概率）连续同方向
      if (rng.nextDouble() > 0.2) {
        horizontal = !horizontal;
      }
    }

    return points;
  }

  /// 生成随机 Via 焊盘位置
  static List<Offset> _generateVias(Size size, math.Random rng) {
    const int count = 25;
    return List.generate(count, (_) {
      return Offset(
        rng.nextDouble() * size.width,
        rng.nextDouble() * size.height,
      );
    });
  }

  @override
  bool shouldRepaint(_CircuitPainter oldDelegate) => false;
}
