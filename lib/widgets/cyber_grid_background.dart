import 'package:flutter/material.dart';
import 'dart:math' as math;

import '../theme/app_theme.dart';

/// 全局赛博风格背景：深蓝黑渐变 + 不规则电路走线纹理 + 流动光点
class CyberGridBackground extends StatefulWidget {
  final Widget child;
  const CyberGridBackground({super.key, required this.child});

  @override
  State<CyberGridBackground> createState() => _CyberGridBackgroundState();
}

class _CyberGridBackgroundState extends State<CyberGridBackground>
    with SingleTickerProviderStateMixin {
  /// 光点流动动画：5s 线性循环
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

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
        // ② 电路走线纹理（静态层）
        Positioned.fill(
          child: CustomPaint(painter: _CircuitPainter()),
        ),
        // ③ 流动光点（动态层，独立图层不波及静态层）
        Positioned.fill(
          child: RepaintBoundary(
            child: CustomPaint(painter: _PulsePainter(_pulseController)),
          ),
        ),
        // ④ 内容层
        widget.child,
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
// 走线数据共享缓存（静态层与光点层复用同一份数据）
// ─────────────────────────────────────────────
class _CircuitCache {
  // App 启动时生成一次种子，保证同一次运行内图案稳定，但每次启动不同
  static final int _seed = DateTime.now().millisecondsSinceEpoch;

  static List<_CircuitTrace>? traces;
  static List<Offset>? vias;
  static Size? size;

  /// 首次或尺寸变化时重新生成
  static void ensure(Size s) {
    if (traces == null || size != s) {
      final rng = math.Random(_seed);
      traces = _generateTraces(s, rng);
      vias = _generateVias(s, rng);
      size = s;
    }
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
}
// ─────────────────────────────────────────────
// CustomPainter 实现（静态层）
// ─────────────────────────────────────────────
class _CircuitPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    _CircuitCache.ensure(size);
    final traces = _CircuitCache.traces!;
    final vias = _CircuitCache.vias!;

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

  @override
  bool shouldRepaint(_CircuitPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────
// 流动光点 Painter（动态层）
// ─────────────────────────────────────────────
/// 沿发光走线流动的光点：3 个光点错峰循环，带 60px 渐隐拖尾
class _PulsePainter extends CustomPainter {
  /// 光点数量
  static const int _pulseCount = 3;

  /// 拖尾长度（px）
  static const double _trailLength = 60;

  /// 拖尾分段数
  static const int _trailSegments = 8;

  final Animation<double> progress;

  _PulsePainter(this.progress) : super(repaint: progress);

  @override
  void paint(Canvas canvas, Size size) {
    _CircuitCache.ensure(size);
    final glowTraces = _CircuitCache.traces!
        .where((t) => t.isGlow)
        .take(_pulseCount)
        .toList();

    for (int k = 0; k < glowTraces.length; k++) {
      final pts = glowTraces[k].points;
      final totalLen = _polylineLength(pts);
      if (totalLen <= 0) continue;

      // 错峰相位：3 个光点均匀分布在循环周期上
      final t = (progress.value + k / _pulseCount) % 1.0;
      final headDist = t * totalLen;
      final head = _pointAt(pts, headDist);

      // 拖尾：从头部反向采样，透明度渐隐
      for (int i = 0; i < _trailSegments; i++) {
        final d1 = headDist - _trailLength * i / _trailSegments;
        final d2 = headDist - _trailLength * (i + 1) / _trailSegments;
        if (d2 < 0 && d1 <= 0) break;
        final p1 = _pointAt(pts, d1.clamp(0.0, totalLen));
        final p2 = _pointAt(pts, d2.clamp(0.0, totalLen));
        final alpha = 0.35 * (1 - i / _trailSegments);
        canvas.drawLine(
          p1,
          p2,
          Paint()
            ..color = AppTheme.gaugeNormal.withValues(alpha: alpha)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..strokeCap = StrokeCap.round,
        );
      }

      // 头部光点：外发光 + 白芯
      canvas.drawCircle(
        head,
        3,
        Paint()
          ..color = AppTheme.gaugeNormal.withValues(alpha: 0.8)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      canvas.drawCircle(
        head,
        1.2,
        Paint()..color = Colors.white.withValues(alpha: 0.9),
      );
    }
  }

  /// 折线总长度
  double _polylineLength(List<Offset> pts) {
    double len = 0;
    for (int i = 1; i < pts.length; i++) {
      len += (pts[i] - pts[i - 1]).distance;
    }
    return len;
  }

  /// 折线上距起点 dist 处的点
  Offset _pointAt(List<Offset> pts, double dist) {
    double remaining = dist;
    for (int i = 1; i < pts.length; i++) {
      final segLen = (pts[i] - pts[i - 1]).distance;
      if (remaining <= segLen) {
        final t = segLen == 0 ? 0.0 : remaining / segLen;
        return Offset.lerp(pts[i - 1], pts[i], t)!;
      }
      remaining -= segLen;
    }
    return pts.last;
  }

  // 逐帧重绘由构造函数 super(repaint: progress) 驱动，字段不可变故返回 false
  @override
  bool shouldRepaint(_PulsePainter oldDelegate) => false;
}
