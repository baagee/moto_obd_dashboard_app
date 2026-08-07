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

  /// 当前平滑后的朝向角（弧度，0 = 北，顺时针为正）
  double _smoothedHeading = 0.0;

  /// 平滑系数：约 0.3s 收敛（60fps × k ≈ 1）
  static const double _smoothK = 0.10;

  /// 低速冻结阈值（km/h）：低于此速度时不更新朝向
  static const double _minSpeedKmh = 5.0;

  /// 有效方位角累计距离下限（米）：段长不足时不更新朝向
  static const double _minBearingDistM = 15.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
    // 用 addListener 每帧更新朝向，不调用 setState（AnimatedBuilder 已覆盖重建）
    _controller.addListener(_updateHeading);
  }

  @override
  void dispose() {
    _controller.removeListener(_updateHeading);
    _controller.dispose();
    super.dispose();
  }

  /// 每帧计算目标方位角并做最短弧平滑 lerp
  void _updateHeading() {
    final statsProvider = context.read<RidingStatsProvider>();
    final track = statsProvider.recentTrack;
    if (track.isEmpty) return;

    // 低速冻结：末点速度 < 阈值则保持
    if (track.last.speedKmh < _minSpeedKmh) return;

    // 从末端往回找累计距离 >= _minBearingDistM 的"头部"点
    // 跳过 gapBefore 段（GPS 失联段不参与）
    final metersPerLng =
        111320.0 * cos(track.last.latitude * pi / 180);
    const metersPerLat = 110540.0;

    double accDist = 0.0;
    int headIdx = track.length - 1;
    for (int i = track.length - 1; i > 0; i--) {
      if (track[i].gapBefore) break; // 遇到失联断点停止往前追溯
      final dx =
          (track[i].longitude - track[i - 1].longitude) * metersPerLng;
      final dy =
          (track[i].latitude - track[i - 1].latitude) * metersPerLat;
      accDist += sqrt(dx * dx + dy * dy);
      headIdx = i - 1;
      if (accDist >= _minBearingDistM) break;
    }

    // 段长不足（静止 / 刚起步）则保持
    if (accDist < _minBearingDistM) return;

    // 平面近似：atan2(dx, dy) → 0=北，顺时针正，与地理方位角一致
    final tailPoint = track.last;
    final headPoint = track[headIdx];
    final dx = (tailPoint.longitude - headPoint.longitude) * metersPerLng;
    final dy = (tailPoint.latitude - headPoint.latitude) * metersPerLat;
    final targetHeading = atan2(dx, dy);

    // 最短弧 lerp
    var delta = ((targetHeading - _smoothedHeading + pi) % (2 * pi)) - pi;
    _smoothedHeading += delta * _smoothK;
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
                        smoothedHeading: _smoothedHeading,
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

/// 雷达静态网格层：同心圆 + 十字线 + 刻度 + 角标
/// 内容不随时间变化，配合外层 RepaintBoundary 只绘制一次
/// 注意：罗盘方向标识（N/E/S/W）在动态层绘制（随 heading-up 旋转实现指北针效果）
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

  /// Heading-up：当前平滑后的行驶方向（弧度，0=北，顺时针为正）
  /// 轨迹 canvas 绕中心旋转 -smoothedHeading，使行驶方向恒朝正上方
  final double smoothedHeading;

  /// 最多绘制的轨迹段数（超出则抽稀）
  /// 双层绘制（辉光+实芯）每段画 2 次，段数取 320 控制 60fps 开销
  static const int _maxSegments = 320;

  /// 轨迹四周留白

  _TrackRadarDynamicPainter({
    required this.track,
    required this.markers,
    required this.phase,
    required this.now,
    required this.warnSpeed,
    required this.dangerSpeed,
    required this.smoothedHeading,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final maxR = min(size.width, size.height) / 2 - 2;

    // 雷达扫描装饰：不随轨迹旋转（纯装饰）
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
    // 径向适配：遍历保留点，求各点到包围盒中心的最大距离（米）
    // 用半径而非包围盒边长做适配，保证任意轨迹形状在任意旋转角度下均不超出圆环
    double maxDist = 0;
    for (final p in pts) {
      final dx = (p.longitude - lngC) * metersPerLng;
      final dy = (p.latitude - latC) * metersPerLat;
      maxDist = max(maxDist, sqrt(dx * dx + dy * dy));
    }
    // 下限 50m（近似等价原 100m 最小跨度，实际视野略大）
    maxDist = max(maxDist, 50.0);
    // 12px 余量：覆盖末点装饰物延伸（脉冲环 10px / 箭头尖端 8px），保证不出圆环
    final scale = (maxR - 12) / maxDist;

    Offset toScreen(double lat, double lng) {
      return Offset(
        center.dx + (lng - lngC) * metersPerLng * scale,
        center.dy - (lat - latC) * metersPerLat * scale,
      );
    }

    // ── 旋转变换：轨迹/徽章/当前位置随行驶方向旋转 ──────────────────
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-smoothedHeading);
    canvas.translate(-center.dx, -center.dy);

    _drawTrack(canvas, pts, toScreen);
    _drawMarkers(canvas, size, toScreen);
    _drawCurrentPosition(canvas, pts, toScreen);

    canvas.restore();
    // ────────────────────────────────────────────────────────────────

    // 罗盘方向标识（N/E/S/W）：圆环上对应角位置，不随轨迹旋转（天然指北针）
    _drawCompassIndicators(canvas, center, maxR);
    // 比例尺：始终水平显示（视野实际直径 = maxDist × 2）
    _drawScaleLabel(canvas, size, maxDist * 2);
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

    // 脉冲光环（随相位扩散淡出），max 半径 10px，与 scale 的 12px 余量匹配
    canvas.drawCircle(
      last,
      3 + phase * 7,
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
        // 箭头整体约 8×6px（原 11×8 缩小 ~30%），尖端延伸不超过 scale 余量
        final arrow = Path()
          ..moveTo(last.dx + unit.dx * 8, last.dy + unit.dy * 8)
          ..lineTo(
            last.dx + unit.dx * 2 + perp.dx * 3,
            last.dy + unit.dy * 2 + perp.dy * 3,
          )
          ..lineTo(
            last.dx + unit.dx * 2 - perp.dx * 3,
            last.dy + unit.dy * 2 - perp.dy * 3,
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

  /// 罗盘四方向标识（N/E/S/W）：绘制在圆环上，随 heading-up 反向旋转。
  /// 世界方位角 b 在旋转后出现在 center + r·(sin(b−h), −cos(b−h))：
  /// heading=0（朝北）→ N 顶中、E 右、S 底、W 左；heading=π/2（朝东）→ N 左 ✓
  /// N 高亮（primary60）作为锚点，E/S/W 弱化（primary30），符合真实罗盘层级惯例。
  /// TextPainter 静态缓存，每帧仅改 paint offset，避免 60fps 重复 layout。
  void _drawCompassIndicators(Canvas canvas, Offset center, double maxR) {
    for (final dir in _compassDirections) {
      final a = dir.bearing - smoothedHeading;
      final tp = dir.painter;
      tp.paint(
        canvas,
        Offset(
          center.dx + maxR * sin(a) - tp.width / 2,
          center.dy - maxR * cos(a) - tp.height / 2,
        ),
      );
    }
  }

  /// 罗盘四方向定义（世界方位角 + 缓存的 TextPainter）
  static final List<({double bearing, TextPainter painter})>
      _compassDirections = [
    (bearing: 0.0, painter: _buildCompassPainter('N', AppTheme.primary60)),
    (bearing: pi / 2, painter: _buildCompassPainter('E', AppTheme.primary30)),
    (bearing: pi, painter: _buildCompassPainter('S', AppTheme.primary30)),
    (
      bearing: 3 * pi / 2,
      painter: _buildCompassPainter('W', AppTheme.primary30),
    ),
  ];

  static TextPainter _buildCompassPainter(String label, Color color) {
    return TextPainter(
      text: TextSpan(
        text: label,
        style: AppFonts.monoStyle(fontSize: 9, color: color),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
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
