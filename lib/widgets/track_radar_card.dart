import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/riding_stats_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_fonts.dart';
import '../theme/app_theme.dart';
import 'riding_event_item.dart';

/// 轨迹雷达卡片
/// 雷达风迷你地图：展示最近 15 分钟实时 GPS 轨迹（速度着色 + 时间拖尾），
/// 骑行事件以浮动徽章形式叠加在轨迹对应位置上。
/// 无轨迹时显示"等待 GPS 信号"的雷达待机动画。
class TrackRadarCard extends StatefulWidget {
  const TrackRadarCard({super.key});

  @override
  State<TrackRadarCard> createState() => _TrackRadarCardState();
}

class _TrackRadarCardState extends State<TrackRadarCard>
    with SingleTickerProviderStateMixin {
  /// 雷达扫描/脉冲动画（4s 一圈，匀速循环）
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 列表引用稳定（Provider 内部只做原地增删），
    // 动态 Painter 每帧读取最新内容，无需 Consumer
    final statsProvider = context.read<RidingStatsProvider>();
    final isRiding =
        context.select<RidingStatsProvider, bool>((p) => p.isRiding);
    // 速度着色阈值与仪表盘共用，用户在设置页调整后轨迹雷达同步生效
    final warnSpeed =
        context.select<SettingsProvider, int>((s) => s.warnSpeed);
    final dangerSpeed =
        context.select<SettingsProvider, int>((s) => s.dangerSpeed);

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: AppTheme.surfaceBorder(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题行：左侧标题，右侧 LIVE 状态 + 时间窗标识
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('轨迹雷达', style: AppTheme.labelMediumPrimary),
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color:
                          isRiding ? AppTheme.accentGreen : AppTheme.textMuted,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isRiding ? 'LIVE' : 'STANDBY',
                    style: AppTheme.labelTiny.copyWith(
                      color:
                          isRiding ? AppTheme.accentGreen : AppTheme.textMuted,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text('15MIN', style: AppTheme.labelTiny),
                ],
              ),
            ],
          ),

          const SizedBox(height: 6),

          // 雷达图区域：静态网格层（RepaintBoundary 隔离）+ 动态数据层
          Expanded(
            child: RepaintBoundary(
              child: CustomPaint(
                size: Size.infinite,
                painter: const _RadarGridPainter(),
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) {
                    final now = DateTime.now();
                    final track = statsProvider.recentTrack;
                    final cutoff =
                        now.subtract(RidingStatsProvider.trackWindow);
                    final hasTrack =
                        track.any((p) => p.timestamp.isAfter(cutoff));

                    return CustomPaint(
                      size: Size.infinite,
                      painter: _TrackRadarDynamicPainter(
                        track: track,
                        markers: statsProvider.eventMarkers,
                        phase: _controller.value,
                        now: now,
                        warnSpeed: warnSpeed.toDouble(),
                        dangerSpeed: dangerSpeed.toDouble(),
                      ),
                      child: hasTrack
                          ? null
                          : _StandbyHint(phase: _controller.value),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// GPS 待机提示：呼吸光点 + 双语标签（叠加在雷达扫描动画上）
class _StandbyHint extends StatelessWidget {
  final double phase;

  const _StandbyHint({required this.phase});

  @override
  Widget build(BuildContext context) {
    // 每秒两次呼吸
    final pulse = 0.5 + 0.5 * sin(phase * 2 * pi * 2);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color:
                  AppTheme.gaugeNormal.withValues(alpha: 0.3 + 0.7 * pulse),
              boxShadow: AppTheme.glowShadow(
                AppTheme.gaugeNormal,
                blur: 10,
                opacity: 0.3 + 0.4 * pulse,
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Text('等待 GPS 信号', style: AppTheme.labelMedium),
          const SizedBox(height: 2),
          const Text('AWAITING GPS SIGNAL', style: AppTheme.labelTiny),
        ],
      ),
    );
  }
}

/// 雷达静态网格层：同心圆 + 十字线 + 刻度 + 角标 + 北向标识
/// 内容不随时间变化，配合外层 RepaintBoundary 只绘制一次
class _RadarGridPainter extends CustomPainter {
  const _RadarGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final maxR = min(size.width, size.height) / 2 - 2;

    // 同心圆
    final ringPaint = Paint()
      ..color = AppTheme.primary10
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final r in [maxR / 3, maxR * 2 / 3, maxR]) {
      canvas.drawCircle(center, r, ringPaint);
    }

    // 十字线
    canvas.drawLine(
      Offset(center.dx - maxR, center.dy),
      Offset(center.dx + maxR, center.dy),
      ringPaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - maxR),
      Offset(center.dx, center.dy + maxR),
      ringPaint,
    );

    // 外圈刻度（每 30° 一个小 tick）
    final tickPaint = Paint()
      ..color = AppTheme.primary20
      ..strokeWidth = 1;
    for (int i = 0; i < 12; i++) {
      final angle = i * pi / 6;
      final cosA = cos(angle);
      final sinA = sin(angle);
      canvas.drawLine(
        Offset(center.dx + cosA * (maxR - 4), center.dy + sinA * (maxR - 4)),
        Offset(center.dx + cosA * maxR, center.dy + sinA * maxR),
        tickPaint,
      );
    }

    // 四角 HUD 角标
    final bracketPaint = Paint()
      ..color = AppTheme.primary30
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    const len = 8.0;
    const inset = 2.0;
    final corners = [
      (const Offset(inset, inset), const Offset(1, 1)),
      (Offset(size.width - inset, inset), const Offset(-1, 1)),
      (Offset(inset, size.height - inset), const Offset(1, -1)),
      (Offset(size.width - inset, size.height - inset), const Offset(-1, -1)),
    ];
    for (final (origin, dir) in corners) {
      final path = Path()
        ..moveTo(origin.dx + dir.dx * len, origin.dy)
        ..lineTo(origin.dx, origin.dy)
        ..lineTo(origin.dx, origin.dy + dir.dy * len);
      canvas.drawPath(path, bracketPaint);
    }

    // 北向标识（顶部居中）
    final nPainter = TextPainter(
      text: TextSpan(
        text: 'N',
        style: AppFonts.monoStyle(fontSize: 9, color: AppTheme.primary60),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    nPainter.paint(canvas, Offset(center.dx - nPainter.width / 2, 4));
  }

  @override
  bool shouldRepaint(covariant _RadarGridPainter oldDelegate) => false;
}

/// 雷达动态数据层：扫描拖尾 + 轨迹线 + 事件徽章 + 当前位置脉冲
/// 由 AnimationController 驱动逐帧重绘
class _TrackRadarDynamicPainter extends CustomPainter {
  final List<LiveTrackPoint> track;
  final List<TrackEventMarker> markers;

  /// 动画相位 0..1（4s 一圈）
  final double phase;

  /// 本次绘制的基准时间（用于时间拖尾计算）
  final DateTime now;

  /// 速度着色阈值（与仪表盘共用，从 SettingsProvider 注入）
  final double warnSpeed;
  final double dangerSpeed;

  /// 最多绘制的轨迹段数（超出则抽稀）
  /// 双层绘制（辉光+实芯）每段画 2 次，段数取 320 控制 60fps 开销
  static const int _maxSegments = 320;

  /// 轨迹四周留白
  static const double _padding = 16.0;

  _TrackRadarDynamicPainter({
    required this.track,
    required this.markers,
    required this.phase,
    required this.now,
    required this.warnSpeed,
    required this.dangerSpeed,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final maxR = min(size.width, size.height) / 2 - 2;

    _drawSweep(canvas, center, maxR);

    final cutoff = now.subtract(RidingStatsProvider.trackWindow);
    var pts = track.where((p) => p.timestamp.isAfter(cutoff)).toList();
    if (pts.isEmpty) return;

    // 抽稀：段数过多时按步长抽样（始终保留最后一点）
    if (pts.length - 1 > _maxSegments) {
      final stride = ((pts.length - 1) / _maxSegments).ceil();
      pts = [
        for (int i = 0; i < pts.length - 1; i += stride) pts[i],
        pts.last,
      ];
    }

    // 等距圆柱近似：以包围盒中心为原点，经纬度差转米
    double minLat = pts.first.latitude, maxLat = pts.first.latitude;
    double minLng = pts.first.longitude, maxLng = pts.first.longitude;
    for (final p in pts) {
      minLat = min(minLat, p.latitude);
      maxLat = max(maxLat, p.latitude);
      minLng = min(minLng, p.longitude);
      maxLng = max(maxLng, p.longitude);
    }
    final latC = (minLat + maxLat) / 2;
    final lngC = (minLng + maxLng) / 2;
    final metersPerLng = 111320.0 * cos(latC * pi / 180);
    const metersPerLat = 110540.0;
    // 最小跨度 100m，防止短轨迹被过度放大
    final spanX = max((maxLng - minLng) * metersPerLng, 100.0);
    final spanY = max((maxLat - minLat) * metersPerLat, 100.0);
    final scale = min(
      (size.width - _padding * 2) / spanX,
      (size.height - _padding * 2) / spanY,
    );

    Offset toScreen(double lat, double lng) {
      return Offset(
        center.dx + (lng - lngC) * metersPerLng * scale,
        center.dy - (lat - latC) * metersPerLat * scale,
      );
    }

    _drawTrack(canvas, pts, toScreen);
    _drawMarkers(canvas, size, toScreen);
    _drawCurrentPosition(canvas, pts, toScreen);
    _drawScaleLabel(canvas, size, max(spanX, spanY));
  }

  /// 雷达扫描拖尾：从相位角出发的扇形渐变尾迹 + 前沿亮线
  void _drawSweep(Canvas canvas, Offset center, double maxR) {
    final leading = phase * 2 * pi;
    const trailAngle = 1.1; // 尾迹弧度
    const slices = 22;
    final rect = Rect.fromCircle(center: center, radius: maxR);
    final paint = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < slices; i++) {
      final t = i / slices; // 越接近前沿越亮
      paint.color = AppTheme.gaugeNormal.withValues(alpha: 0.10 * t);
      canvas.drawArc(
        rect,
        leading - trailAngle + i * trailAngle / slices,
        trailAngle / slices,
        true,
        paint,
      );
    }
    // 前沿亮线
    final edgePaint = Paint()
      ..color = AppTheme.gaugeNormal.withValues(alpha: 0.6)
      ..strokeWidth = 1.5;
    canvas.drawLine(
      center,
      Offset(
        center.dx + cos(leading) * maxR,
        center.dy + sin(leading) * maxR,
      ),
      edgePaint,
    );
  }

  /// 轨迹线：速度着色（青→琥珀→红）+ 时间拖尾（越旧越透明）
  /// 双层绘制：底层粗线低透明度形成霓虹辉光，上层细线实色线芯
  void _drawTrack(
    Canvas canvas,
    List<LiveTrackPoint> pts,
    Offset Function(double lat, double lng) toScreen,
  ) {
    if (pts.length < 2) return;
    final windowSec = RidingStatsProvider.trackWindow.inSeconds.toDouble();
    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    final corePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    for (int i = 1; i < pts.length; i++) {
      if (pts[i].gapBefore) continue; // GPS 失联段断开不画
      final ageSec = now.difference(pts[i].timestamp).inSeconds.toDouble();
      final fade = (1 - ageSec / windowSec).clamp(0.18, 1.0);
      final color = _speedColor(pts[i].speedKmh);
      final a = toScreen(pts[i - 1].latitude, pts[i - 1].longitude);
      final b = toScreen(pts[i].latitude, pts[i].longitude);

      // 底层：霓虹辉光
      glowPaint.color = color.withValues(alpha: fade * 0.22);
      canvas.drawLine(a, b, glowPaint);
      // 上层：实色线芯
      corePaint.color = color.withValues(alpha: fade);
      canvas.drawLine(a, b, corePaint);
    }

    // 起点：空心圆标记
    final start = toScreen(pts.first.latitude, pts.first.longitude);
    canvas.drawCircle(
      start,
      3,
      Paint()
        ..color = AppTheme.gaugeNormal.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  /// 事件徽章：彩色菱形叠加在轨迹对应位置，新事件带扩散涟漪
  void _drawMarkers(
    Canvas canvas,
    Size size,
    Offset Function(double lat, double lng) toScreen,
  ) {
    final cutoff = now.subtract(RidingStatsProvider.trackWindow);
    final windowSec = RidingStatsProvider.trackWindow.inSeconds.toDouble();

    for (final m in markers) {
      if (m.timestamp.isBefore(cutoff)) continue;
      final o = toScreen(m.latitude, m.longitude);
      // 超出当前轨迹视野的徽章不画
      if (o.dx < -8 || o.dx > size.width + 8 || o.dy < -8 ||
          o.dy > size.height + 8) {
        continue;
      }

      final color = RidingEventItem.colorFromType(m.type.toString());
      final ageSec = now.difference(m.timestamp).inSeconds.toDouble();
      final fade = (1 - ageSec / windowSec).clamp(0.25, 1.0);

      // 新事件（6 秒内）画扩散涟漪
      if (ageSec < 6) {
        canvas.drawCircle(
          o,
          6 + phase * 10,
          Paint()
            ..color = color.withValues(alpha: (1 - phase) * 0.6)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      }

      // 菱形徽章
      const r = 4.5;
      final diamond = Path()
        ..moveTo(o.dx, o.dy - r)
        ..lineTo(o.dx + r, o.dy)
        ..lineTo(o.dx, o.dy + r)
        ..lineTo(o.dx - r, o.dy)
        ..close();
      canvas.drawShadow(diamond, color, 4, false);
      canvas.drawPath(diamond, Paint()..color = color.withValues(alpha: fade));
    }
  }

  /// 当前位置：脉冲光环 + 核心亮点 + 朝向箭头
  void _drawCurrentPosition(
    Canvas canvas,
    List<LiveTrackPoint> pts,
    Offset Function(double lat, double lng) toScreen,
  ) {
    final last = toScreen(pts.last.latitude, pts.last.longitude);

    // 脉冲光环（随相位扩散淡出）
    canvas.drawCircle(
      last,
      4 + phase * 12,
      Paint()
        ..color = AppTheme.gaugeNormal.withValues(alpha: (1 - phase) * 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // 朝向箭头（由最后一段轨迹方向推导）
    if (pts.length >= 2 && !pts.last.gapBefore) {
      final prev = toScreen(
        pts[pts.length - 2].latitude,
        pts[pts.length - 2].longitude,
      );
      final dir = last - prev;
      final dist = dir.distance;
      if (dist > 2) {
        final unit = dir / dist;
        final perp = Offset(-unit.dy, unit.dx);
        final arrow = Path()
          ..moveTo(last.dx + unit.dx * 11, last.dy + unit.dy * 11)
          ..lineTo(
            last.dx + unit.dx * 3 + perp.dx * 4,
            last.dy + unit.dy * 3 + perp.dy * 4,
          )
          ..lineTo(
            last.dx + unit.dx * 3 - perp.dx * 4,
            last.dy + unit.dy * 3 - perp.dy * 4,
          )
          ..close();
        canvas.drawPath(
          arrow,
          Paint()..color = AppTheme.gaugeNormal.withValues(alpha: 0.9),
        );
      }
    }

    // 核心亮点
    canvas.drawCircle(last, 3.5, Paint()..color = AppTheme.gaugeNormal);
    canvas.drawCircle(last, 1.5, Paint()..color = AppTheme.textPrimary);
  }

  /// 左下角比例尺标签（当前视野的实际跨度）
  void _drawScaleLabel(Canvas canvas, Size size, double spanMeters) {
    final label = spanMeters >= 1000
        ? '${(spanMeters / 1000).toStringAsFixed(1)} KM'
        : '${spanMeters.toInt()} M';
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: AppFonts.monoStyle(fontSize: 9, color: AppTheme.textMuted)
            .copyWith(letterSpacing: 1),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(6, size.height - tp.height - 4));
  }

  /// 速度着色：与仪表盘共用 warn/danger 阈值
  /// ≤ warnSpeed：青→琥珀渐变；> warnSpeed 且 ≤ dangerSpeed：琥珀→红渐变；> dangerSpeed：全红
  Color _speedColor(double kmh) {
    if (kmh <= warnSpeed) {
      return Color.lerp(
        AppTheme.gaugeNormal,
        AppTheme.gaugeWarn,
        warnSpeed > 0 ? (kmh / warnSpeed).clamp(0.0, 1.0) : 0.0,
      )!;
    }
    return Color.lerp(
      AppTheme.gaugeWarn,
      AppTheme.gaugeDanger,
      dangerSpeed > warnSpeed
          ? ((kmh - warnSpeed) / (dangerSpeed - warnSpeed)).clamp(0.0, 1.0)
          : 1.0,
    )!;
  }

  @override
  bool shouldRepaint(covariant _TrackRadarDynamicPainter oldDelegate) {
    // 由 AnimationController 驱动逐帧重建，直接重绘
    return true;
  }
}
