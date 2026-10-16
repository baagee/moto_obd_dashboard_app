import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/amap/models.dart';
import '../data/amap/route_analyzer.dart';
import '../providers/navi_provider.dart';
import '../services/location_service.dart';
import '../theme/app_fonts.dart';
import '../theme/app_theme.dart';
import 'cyber_button.dart';
import 'cyber_dialog.dart';
import 'cyber_toast.dart';
import 'navi_turn_arrow.dart';

/// 右下角导航卡 v2（方案：导航卡 v2 重设计）
///
/// 信息主次（自上而下）：
/// 1. **真实路线底图为主角**：只截取"后方 40m + 前方 N m"这一段真实路线，
///    heading-up（车辆前进方向恒朝上，朝向取**路线切线**而非 GPS 朝向 ——
///    低速时 GPS 朝向会冻结），亮青实线 + 辉光，并在线上画当前位置与前进方向。
/// 2. **下一个转向动作是独立元素**：地图下方的动作条，不参与地图绘制。
/// 3. 底部是**固定列宽的多列指标条**（剩余里程 / 剩余时间 / 红绿灯 / 限速），
///    每列 `FittedBox(scaleDown)` 兜底，从结构上消除旧版"单行拼接 + ellipsis"的截断。
///
/// 三个异常态（E1 定位中 / E2 偏离 / stale 弱信号）都在**同一张活跃卡**里可见、不静默消失；
/// `off` 状态由父级不挂载，本组件亦返回空组件（零残留）。
///
/// **没有"导航已结束"终态卡**：分享失效 / 高德那边停了都由 `NaviProvider`
/// 静默收尾回 `off`，第三列直接恢复默认的轨迹雷达卡（用户要求"直接恢复原来的样子"）。
class NaviCard extends StatelessWidget {
  const NaviCard({super.key});

  /// 卡片设计基准高度（244），用于等比缩放
  static const double baseHeight = 244;

  /// 底图区域 key（供测试断言压缩后仍保留可读高度）
  static const Key mapKey = Key('navi-map');

  /// 标题行高度
  static const double _titleHeight = 18;

  /// 下一个动作条设计高度
  static const double _actionStripHeight = 60;

  /// 指标条设计高度
  static const double _metricsHeight = 36;

  /// 区块之间的竖向留白（底图是主角，留白压到最小）
  static const double _gap = 2;

  @override
  Widget build(BuildContext context) {
    return Consumer<NaviProvider>(
      builder: (context, navi, _) {
        if (navi.state == NaviState.off) return const SizedBox.shrink();

        final card = RepaintBoundary(
          child: Container(
            padding: const EdgeInsets.all(5),
            decoration: AppTheme.surfaceBorder(
              borderColor: _borderColor(navi.state),
              opacity: navi.state == NaviState.navigating ? 0.2 : 0.45,
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                // 通栏展开时第三列被压缩（244 → 196），内容随高度等比缩小
                final factor =
                    (constraints.maxHeight / baseHeight).clamp(0.55, 1.0);
                // 没有终态卡：分享失效 / 高德那边停了都静默收尾回 NaviState.off
                // （在上一行就被 `SizedBox.shrink()` 拦下了），这里只剩活跃态。
                return _buildActive(context, navi, factor);
              },
            ),
          ),
        );

        // 偏离且已确认拿不到新路线：整卡可点重贴短链。
        // 这是唯一可能脱困的出口（高德分享链接是快照，我们无法真的重新规划）。
        if (navi.replanFailed) {
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => showNaviPasteDialog(context),
            child: card,
          );
        }
        // 缺权限 / 系统定位未开：整卡可点直达系统设置（别再让用户干等）
        if (navi.gpsNeedsSettings) {
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => LocationService.openSettings(),
            child: card,
          );
        }
        return card;
      },
    );
  }

  static Color _borderColor(NaviState state) => switch (state) {
        NaviState.deviated => AppTheme.gaugeWarn,
        NaviState.stale => AppTheme.gaugeWarn,
        _ => AppTheme.gaugeNormal,
      };

  // ==========================================================================
  // 导航中 / 定位中 / 偏离 / stale
  // ==========================================================================

  Widget _buildActive(BuildContext context, NaviProvider navi, double factor) {
    final locating = navi.state == NaviState.locating;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题行与地图区都用 **const + 自 select** 的子组件：
        // 本方法在 NaviProvider 每次通知（里程平滑 5Hz）时都会重跑，若把这两块
        // 写成 inline，地图的 CustomPaint（含 LayoutBuilder/包围盒/标记）会跟着
        // 5Hz 重建。做成 const 子组件后，只有它们**自己 select 的值**变化时才重建
        // ——地图约 2.5Hz（里程每前移一个锚点步才重算切片）、标题行更少。
        const SizedBox(height: _titleHeight, child: _NaviTitleRow()),
        const SizedBox(height: _gap),

        // ② 地图区：真实路线为主体（弹性，吃掉所有剩余高度）
        const Expanded(child: _NaviMap()),

        const SizedBox(height: _gap),

        // ③ 下一个动作（独立元素；距离/剩余量每帧都在变，本就在这里重建）
        SizedBox(
          height: (_actionStripHeight * factor).clamp(40.0, _actionStripHeight),
          child: _buildActionStrip(context, navi, factor, locating: locating),
        ),

        const SizedBox(height: _gap),

        // ④ 指标条（高度略收，把空间让给底图）
        SizedBox(
          height: (_metricsHeight * factor).clamp(30.0, _metricsHeight),
          child: _buildMetricsBar(navi),
        ),
      ],
    );
  }

  /// ③ 下一个动作条：地图下方的独立一行（不再用左侧竖线分隔——
  /// 与地图隔着 `_gap` 已是不同区域，竖线冗余）
  Widget _buildActionStrip(
    BuildContext context,
    NaviProvider navi,
    double factor, {
    required bool locating,
  }) {
    final action = navi.displayAction;
    final turn =
        action == null ? NaviTurnType.unknown : naviTurnTypeOfAction(action);
    final ahead = navi.distanceToNextAction;
    final actionLabel = action == null
        ? '继续前行'
        : (naviTurnLabelOfAction(action) ?? navi.currentRoad ?? '继续前行');
    final roadLabel = _roadLabel(navi);

    // < 50m 转琥珀（方案 §2.8）
    final distanceColor = (ahead != null && ahead < 50)
        ? AppTheme.gaugeWarn
        : AppTheme.dashboardValue;
    final distanceText = locating || ahead == null
        ? '--'
        : (ahead < 10 ? '现在' : '${ahead.round()}');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        NaviTurnArrow(
          type: turn,
          size: 44 * factor,
          color: AppTheme.gaugeNormal,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    distanceText,
                    style: AppFonts.displayStyle(
                      fontSize: 34 * factor,
                      color: distanceColor,
                    ),
                  ),
                  if (!locating && ahead != null && ahead >= 10) ...[
                    const SizedBox(width: 3),
                    Text('米',
                        style: TextStyle(
                            color: distanceColor, fontSize: 13 * factor)),
                  ],
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      actionLabel,
                      style: const TextStyle(
                        color: AppTheme.dashboardValue,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (roadLabel.isNotEmpty) ...[
                const SizedBox(height: 1),
                Text(
                  roadLabel,
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  static String _roadLabel(NaviProvider navi) {
    final from = navi.currentRoad;
    final to = navi.nextAction?.nextRoadName;
    if (from == null || from.isEmpty) return to ?? '';
    if (to == null || to.isEmpty) return '';
    return '$from → $to';
  }

  /// ④ 指标条：四列**等分（flex）独立渲染** + `FittedBox(scaleDown)` 兜底，
  /// 任何情况都不会被 ellipsis 吃掉（"列宽"是比例而非像素——比硬编码固定宽度
  /// 更抗窄卡片溢出，且同样满足"不拼接成单行字符串"这条不变量）。
  Widget _buildMetricsBar(NaviProvider navi) {
    final remaining = navi.remaining;
    final km = remaining == null
        ? '--'
        : '${(remaining.meters / 1000).toStringAsFixed(1)} km';
    final total = navi.totalDistance;
    final totalKm =
        total == null ? '--' : '${(total / 1000).toStringAsFixed(1)} km';

    return Row(
      children: [
        _metricCell('剩余里程', km, AppTheme.dashboardValue, 11),
        _metricCell('剩余时间', _etaText(navi), AppTheme.dashboardValue, 11),
        _metricCell(
          '红绿灯',
          remaining == null ? '--' : '${remaining.lights}',
          AppTheme.dashboardValue,
          8,
        ),
        _metricCell('总里程', totalKm, AppTheme.dashboardValue, 11),
      ],
    );
  }

  /// 剩余时间：按设置显示"预计到达时刻"或"剩余时长"
  static String _etaText(NaviProvider navi) {
    final remaining = navi.remaining;
    if (remaining == null) return '--';
    if (navi.etaAsClock) {
      final at =
          DateTime.now().add(Duration(seconds: remaining.seconds.round()));
      final h = at.hour.toString().padLeft(2, '0');
      final m = at.minute.toString().padLeft(2, '0');
      return '$h:$m';
    }
    final minutes = (remaining.seconds / 60).round();
    if (minutes >= 60) return '${minutes ~/ 60}时${minutes % 60}分';
    return '$minutes 分钟';
  }

  Widget _metricCell(
    String label,
    String value,
    Color color,
    int flex,
  ) {
    return Expanded(
      flex: flex,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: AppTheme.dashboardMetricLabelCompact,
              maxLines: 1,
            ),
          ),
          const SizedBox(height: 1),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: AppFonts.monoStyle(
                fontSize: 14,
                color: color,
              ),
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // 小组件
  // ==========================================================================
}

// ===========================================================================
// 自 select 的卡片子块
//
// 把标题行与地图区从 `NaviCard.build` 里拆出来，是为了**把 5Hz 的里程平滑通知
// 挡在门外**：它们用 `context.select` 只订阅自己关心的字段，值不变就不重建。
// 外层因此可以每次通知都照常重跑（动作条/指标条本来就要跟着距离与剩余量刷新），
// 成本只剩几何布局，不再包含 CustomPaint 的路径 / 包围盒 / 标记重算。
// ===========================================================================

/// 标题行（状态文案 + 信号徽标 + 关闭按钮）
class _NaviTitleRow extends StatelessWidget {
  const _NaviTitleRow();

  @override
  Widget build(BuildContext context) {
    // offsetMeters 取整后再进 select：偏离态下它每秒都在抖，取整避免无意义重建
    final (
      state,
      offM,
      replanFailed,
      gpsIssue,
      currentRoad,
      extrapolating,
      stopped
    ) =
        context
            .select<NaviProvider,
                    (NaviState, int?, bool, NaviGpsIssue, String?, bool, bool)>(
                (p) => (
                      p.state,
                      p.offsetMeters?.round(),
                      p.replanFailed,
                      p.gpsIssue,
                      p.currentRoad,
                      p.extrapolating,
                      p.shareStoppedHint,
                    ));

    final String title;
    final Color dotColor;
    switch (state) {
      case NaviState.deviated:
        final offText = offM == null ? '' : ' ${offM}m';
        // 分享链接是快照：拿不到新路线时必须说实话，并给出唯一可行的出口
        title = replanFailed ? '已偏离$offText · 点此重新粘贴短链' : '已偏离路线 · 重新规划中…';
        dotColor = AppTheme.gaugeWarn;
      case NaviState.locating:
        title = switch (gpsIssue) {
          NaviGpsIssue.denied ||
          NaviGpsIssue.deniedForever =>
            '导航中 · 没有定位权限（点此去设置）',
          NaviGpsIssue.serviceDisabled => '导航中 · 系统定位未开启（点此去设置）',
          NaviGpsIssue.streamError => '导航中 · 定位异常，检查权限与信号',
          NaviGpsIssue.noFixYet => '导航中 · 等不到定位（信号弱或室内）',
          NaviGpsIssue.none => '导航中 · 定位中…',
        };
        dotColor = gpsIssue == NaviGpsIssue.none
            ? AppTheme.textMuted
            : AppTheme.gaugeWarn;
      case _:
        title = '导航中 · ${currentRoad ?? '未知道路'}';
        // 用导航主色青：与卡片边框/路线同色系，避免 8px 圆点下绿色与青色难分辨；
        // 绿色留给地图红绿灯标记
        dotColor = AppTheme.gaugeNormal;
    }
    final live = state == NaviState.navigating;

    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: AppTheme.dashboardNaviTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (state == NaviState.stale)
          const Padding(
            padding: EdgeInsets.only(right: 4),
            child: Text('信号弱',
                style: TextStyle(color: AppTheme.gaugeWarn, fontSize: 10)),
          ),
        if (extrapolating)
          const Padding(
            padding: EdgeInsets.only(right: 4),
            child: Text('推算中',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 10)),
          ),
        // 已探到"高德那边停了"但用户选择继续导航（naviStopOnShareEnd=false）：
        // 必须让他知道指引已不再来自高德，而不是静默继续
        if (stopped)
          const Padding(
            padding: EdgeInsets.only(right: 4),
            child: Text('已停止',
                style: TextStyle(color: AppTheme.gaugeWarn, fontSize: 10)),
          ),
        _naviDot(dotColor, breathe: live),
        const SizedBox(width: 4),
        Text(
          switch (state) {
            NaviState.locating =>
              gpsIssue == NaviGpsIssue.none ? 'WAIT' : 'NO GPS',
            NaviState.deviated => replanFailed ? 'OFF' : 'REROUTE',
            NaviState.stale => 'WEAK',
            _ => 'LIVE',
          },
          style: AppTheme.dashboardStatus.copyWith(color: dotColor),
        ),
        GestureDetector(
          onTap: () => context.read<NaviProvider>().stop(),
          behavior: HitTestBehavior.opaque,
          child: const Padding(
            padding: EdgeInsets.only(left: 6),
            child: Icon(Icons.close, size: 13, color: AppTheme.textMuted),
          ),
        ),
      ],
    );
  }
}

/// 地图区（真实路线底图 + 红绿灯/限速标记 + 车标）
class _NaviMap extends StatelessWidget {
  const _NaviMap();

  @override
  Widget build(BuildContext context) {
    final (slice, markers, hasFix, deviated, trafficColor) = context.select<
            NaviProvider, (RouteSlice, List<RouteMarker>, bool, bool, bool)>(
        (p) => (
              p.routeSlice,
              p.routeMarkers,
              p.projection != null,
              p.state == NaviState.deviated,
              p.routeTrafficColor,
            ));

    return RepaintBoundary(
      child: CustomPaint(
        key: NaviCard.mapKey,
        size: Size.infinite,
        painter: _RouteMapPainter(
          slice: slice,
          markers: markers,
          hasFix: hasFix,
          deviated: deviated,
          trafficColor: trafficColor,
          lineColor: AppTheme.gaugeNormal,
        ),
      ),
    );
  }
}

/// 状态圆点（8px；[breathe] 为 true 时呼吸）
Widget _naviDot(Color color, {bool breathe = false}) {
  if (!breathe) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: AppTheme.glowShadow(color, blur: 6),
      ),
    );
  }
  return _BreathingDot(color: color);
}

/// 呼吸状态点（8px，1.2s 周期）
class _BreathingDot extends StatefulWidget {
  const _BreathingDot({required this.color});
  final Color color;

  @override
  State<_BreathingDot> createState() => _BreathingDotState();
}

class _BreathingDotState extends State<_BreathingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final a = 0.35 + 0.65 * _c.value;
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color.withValues(alpha: a),
            boxShadow: AppTheme.glowShadow(widget.color,
                blur: 6 + 4 * _c.value, opacity: 0.5 * a),
          ),
        );
      },
    );
  }
}

// ===========================================================================
// 地图区绘制：六层（网格 / 已行驶残影 / 前方真实路线 / 红绿灯 / 限速 / 车标）
// ===========================================================================

/// 真实路线底图（heading-up）
///
/// 关键决策：朝向取**路线切线**（`RouteSlice.bearing`）而不是 GPS 朝向 ——
/// 低速/静止时 GPS 朝向会冻结或抖动，而路线切线在同一路段内平滑、稳定，
/// 且与"这条路接下来往哪走"的语义一致（见 phase4 方案 §7 风险 6）。
class _RouteMapPainter extends CustomPainter {
  _RouteMapPainter({
    required this.slice,
    required this.markers,
    required this.hasFix,
    required this.deviated,
    required this.trafficColor,
    required this.lineColor,
  });

  final RouteSlice slice;
  final List<RouteMarker> markers;

  /// 是否有有效定位（E1 无定位时车标退化为空心点、不画朝向）
  final bool hasFix;

  /// 偏离路线（车标转琥珀 + 外圈）
  final bool deviated;

  /// 是否给路线叠加路况着色（默认关）
  final bool trafficColor;

  final Color lineColor;

  /// 画布内边距
  static const double _pad = 8;

  /// fit-to-content 的下限：极短弯(净位移很小)时不把一小段路线无限放大
  /// 糊成一团，视窗最小按此米数处理（居中显示，四周均匀留白）。
  static const double _minVisibleMeters = 80;

  @override
  void paint(Canvas canvas, Size size) {
    _drawBackdrop(canvas, size);
    if (slice.isEmpty || size.isEmpty) return;

    final anchorPoint = slice.points[slice.vehicleIndex];
    final metersPerLon = 111320.0 * math.cos(anchorPoint.lat * math.pi / 180);
    const metersPerLat = 110540.0;
    final b = slice.bearing;
    final cb = math.cos(b);
    final sb = math.sin(b);

    // 局部平面（米，x=东 y=北）→ 绕车辆点旋转 -bearing，使前进方向朝上。
    // 车辆点恒为原点 (0,0)，前方点 y<0（屏幕上方），后方点 y>0。
    Offset rotate(LonLat p) {
      final east = (p.lon - anchorPoint.lon) * metersPerLon;
      final north = (p.lat - anchorPoint.lat) * metersPerLat;
      final x = east, y = -north; // 屏幕 y 向下
      return Offset(x * cb + y * sb, -x * sb + y * cb);
    }

    // 旋转后内容包围盒（米）——已含车辆点(0,0)，故车标必在盒内
    final rotated = [for (final p in slice.points) rotate(p)];
    var minX = double.infinity, maxX = -double.infinity;
    var minY = double.infinity, maxY = -double.infinity;
    for (final o in rotated) {
      minX = math.min(minX, o.dx);
      maxX = math.max(maxX, o.dx);
      minY = math.min(minY, o.dy);
      maxY = math.max(maxY, o.dy);
    }
    final contentW = math.max(maxX - minX, 1e-6);
    final contentH = math.max(maxY - minY, 1e-6);

    // fit-to-viewport：让真实路线的包围盒撑满画布（四周仅留 _pad），
    // 不再按固定前视里程预算高度 —— 那会在弯路/短路段留出大片空白。
    // 构图副作用天然符合直觉：直路时后方 40m + 前方 N m 使盒子很“高”，
    // 车标自然落到偏下位置；弯路时盒子小，路线撑满、车标居中。
    final availW = math.max(size.width - _pad * 2, 1.0);
    final availH = math.max(size.height - _pad * 2, 1.0);
    var scale = math.min(availW / contentW, availH / contentH);
    final maxScale = math.min(availW, availH) / _minVisibleMeters;
    scale = scale.clamp(0.01, maxScale);

    // 车辆点(局部原点)的屏幕位置：令包围盒中心对齐画布中心
    final bboxCx = (minX + maxX) / 2;
    final bboxCy = (minY + maxY) / 2;
    final anchor = Offset(
      size.width / 2 - bboxCx * scale,
      size.height / 2 - bboxCy * scale,
    );
    Offset toScreen(LonLat p) {
      final r = rotate(p);
      return anchor + Offset(r.dx * scale, r.dy * scale);
    }

    final screen = [for (final p in slice.points) toScreen(p)];
    final vi = slice.vehicleIndex.clamp(0, screen.length - 1);

    _drawTravelledTrace(canvas, screen, vi);
    _drawRouteAhead(canvas, screen, vi);
    _drawMarkers(canvas, size, toScreen);
    _drawVehicle(canvas, anchor);
    _drawScaleBar(canvas, size, scale);
  }

  /// L1 底纹：稀疏网格 + 四角角标（沿用轨迹雷达卡的视觉语言）
  void _drawBackdrop(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = AppTheme.primary10
      ..strokeWidth = 1;
    for (var i = 1; i < 4; i++) {
      final x = size.width * i / 4;
      final y = size.height * i / 4;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final bracket = Paint()
      ..color = AppTheme.primary30
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    const len = 8.0;
    const inset = 1.0;
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
      canvas.drawPath(path, bracket);
    }
  }

  /// L2 已行驶残影：给出"刚从哪来"的方向感，低对比度不抢主体
  void _drawTravelledTrace(Canvas canvas, List<Offset> screen, int vi) {
    if (vi < 1) return;
    final path = _smoothPath(screen.sublist(0, vi + 1));
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = lineColor.withValues(alpha: 0.22),
    );
  }

  /// L3 前方真实路线：本次重设计的重点 —— 从"18% 蓝 2px 垫底"改为
  /// "100% 青 3px + 辉光"，让底图真正看得清
  void _drawRouteAhead(Canvas canvas, List<Offset> screen, int vi) {
    if (vi >= screen.length - 1) return;
    final path = _smoothPath(screen.sublist(vi));

    // 辉光层
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = lineColor.withValues(alpha: 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    // 实芯线
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = lineColor,
    );

    // 可选路况叠加：只在缓行/拥堵段加细彩带，主线的导航语义色保持不变
    if (!trafficColor) return;
    for (var i = vi; i < screen.length - 1; i++) {
      final state =
          i + 1 < slice.trafficStates.length ? slice.trafficStates[i + 1] : 0;
      final color = switch (state) {
        2 => AppTheme.gaugeWarn,
        3 || 4 => AppTheme.gaugeDanger,
        _ => null,
      };
      if (color == null) continue;
      canvas.drawLine(
        screen[i],
        screen[i + 1],
        Paint()
          ..strokeWidth = 1.2
          ..strokeCap = StrokeCap.round
          ..color = color.withValues(alpha: 0.9),
      );
    }
  }

  /// L4 红绿灯点 / L5 限速点
  void _drawMarkers(
    Canvas canvas,
    Size size,
    Offset Function(LonLat) toScreen,
  ) {
    for (final m in markers) {
      final o = toScreen(m.coord);
      if (o.dx < -12 ||
          o.dx > size.width + 12 ||
          o.dy < -12 ||
          o.dy > size.height + 12) {
        continue;
      }
      switch (m.kind) {
        case RouteMarkerKind.trafficLight:
          // 绿色点 + 绿色淡环：与青色路线(同系)、白色车标、红圈限速牌三方区分
          canvas.drawCircle(o, 3, Paint()..color = AppTheme.accentGreen);
          canvas.drawCircle(
            o,
            4.5,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1
              ..color = AppTheme.accentGreen.withValues(alpha: 0.45),
          );
        case RouteMarkerKind.speedLimit:
          // 12px 迷你限速牌：白底 + 红圈 + 黑字（与通栏大牌同形制）
          canvas.drawCircle(o, 6, Paint()..color = Colors.white);
          canvas.drawCircle(
            o,
            6,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.6
              ..color = AppTheme.gaugeDanger,
          );
          _drawText(
            canvas,
            '${m.value ?? ''}',
            o,
            // 走等宽数据字体：painter 里没有 BuildContext，不显式指定会
            // 掉到系统默认字体，和地图其它数字不一致
            AppFonts.monoStyle(fontSize: 6.5, color: Colors.black),
            center: true,
          );
      }
    }
  }

  /// L6 车标 + 前进方向（heading-up 下恒朝正上）
  void _drawVehicle(Canvas canvas, Offset anchor) {
    if (!hasFix) {
      // E1：无定位，画空心点表示"位置未知"
      canvas.drawCircle(
        anchor,
        4,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = AppTheme.textMuted,
      );
      return;
    }

    final color = deviated ? AppTheme.gaugeWarn : lineColor;

    // 外发光
    canvas.drawCircle(
      anchor,
      13,
      Paint()
        ..color = color.withValues(alpha: 0.28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    // 三角箭头（尖端朝上 = 前进方向）
    const tipY = -8.0;
    const backY = 6.0;
    const halfW = 5.5;
    final arrow = Path()
      ..moveTo(anchor.dx, anchor.dy + tipY)
      ..lineTo(anchor.dx - halfW, anchor.dy + backY)
      ..lineTo(anchor.dx, anchor.dy + backY * 0.45)
      ..lineTo(anchor.dx + halfW, anchor.dy + backY)
      ..close();
    canvas.drawPath(arrow, Paint()..color = color);
    // 内芯提亮，确保在地图与路线上都清晰
    canvas.drawCircle(
        anchor.translate(0, 1.5), 1.8, Paint()..color = Colors.white);

    if (deviated) {
      canvas.drawCircle(
        anchor,
        10,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = AppTheme.gaugeWarn,
      );
    }
  }

  /// 比例尺：取"当前缩放下的整数值里程"，画在右下角
  void _drawScaleBar(Canvas canvas, Size size, double scale) {
    const candidates = [50, 100, 200, 500, 1000, 2000];
    var meters = candidates.first;
    for (final c in candidates) {
      if (c * scale <= 64) meters = c;
    }
    final length = meters * scale;
    final y = size.height - 7;
    final x0 = size.width - 6 - length;

    final paint = Paint()
      ..strokeWidth = 1
      ..color = AppTheme.textMuted;
    canvas.drawLine(Offset(x0, y), Offset(x0 + length, y), paint);
    canvas.drawLine(Offset(x0, y - 3), Offset(x0, y + 3), paint);
    canvas.drawLine(
        Offset(x0 + length, y - 3), Offset(x0 + length, y + 3), paint);

    _drawText(
      canvas,
      meters >= 1000 ? '${meters ~/ 1000} km' : '$meters m',
      Offset(size.width - 6, y - 5),
      AppFonts.monoStyle(fontSize: 8, color: AppTheme.textMuted),
      alignRight: true,
      above: true,
    );
  }

  /// 中点二次贝塞尔平滑：几何点平均间距约 50m，直接连折线会有明显折角；
  /// 平滑仅用于显示（偏差远小于 200px 画布上的 1px），不参与任何里程计算。
  Path _smoothPath(List<Offset> pts) {
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    if (pts.length == 2) {
      path.lineTo(pts[1].dx, pts[1].dy);
      return path;
    }
    for (var i = 1; i < pts.length - 1; i++) {
      final mid = Offset(
        (pts[i].dx + pts[i + 1].dx) / 2,
        (pts[i].dy + pts[i + 1].dy) / 2,
      );
      path.quadraticBezierTo(pts[i].dx, pts[i].dy, mid.dx, mid.dy);
    }
    path.lineTo(pts.last.dx, pts.last.dy);
    return path;
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset at,
    TextStyle style, {
    bool center = false,
    bool alignRight = false,
    bool above = false,
  }) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    var dx = at.dx;
    var dy = at.dy;
    if (center) {
      dx -= tp.width / 2;
      dy -= tp.height / 2;
    }
    if (alignRight) dx -= tp.width;
    if (above) dy -= tp.height;
    tp.paint(canvas, Offset(dx, dy));
  }

  @override
  bool shouldRepaint(covariant _RouteMapPainter old) =>
      old.slice != slice ||
      old.markers != markers ||
      old.hasFix != hasFix ||
      old.deviated != deviated ||
      old.trafficColor != trafficColor ||
      old.lineColor != lineColor;
}

/// 短链粘贴弹窗（方案 §2.7 永久兜底；入口在「设置 → 第三方服务 → 导航 HUD」，
/// 以及偏离且重规划失败时整卡可点）
Future<void> showNaviPasteDialog(BuildContext context) async {
  final navi = context.read<NaviProvider>();
  final controller = TextEditingController();

  // 打开时先尝试读一次剪贴板，命中即预填（Android 10+ 仅前台可读，此处恰在前台）
  final clipboard = await Clipboard.getData(Clipboard.kTextPlain);
  final pasted = clipboard?.text?.trim() ?? '';
  if (pasted.contains('surl.amap.com')) controller.text = pasted;

  if (!context.mounted) {
    controller.dispose();
    return;
  }

  final confirmed = await CyberDialog.show<bool>(
    context: context,
    title: '粘贴高德分享短链',
    icon: Icons.alt_route,
    accentColor: AppTheme.gaugeNormal,
    width: 420,
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '在高德地图中「分享行程」后复制短链，粘贴到此处。\n'
          '形如 https://surl.amap.com/xxxxxxx',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 12),
        Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: AppTheme.surface40,
            border: Border.all(color: AppTheme.primary20),
          ),
          child: TextField(
            controller: controller,
            autofocus: true,
            style:
                AppFonts.monoStyle(fontSize: 12, color: AppTheme.textPrimary),
            decoration: const InputDecoration(
              isDense: true,
              border: InputBorder.none,
              hintText: 'https://surl.amap.com/xxxxxxxxx',
              hintStyle: TextStyle(color: AppTheme.textMuted, fontSize: 12),
            ),
          ),
        ),
      ],
    ),
    actions: [
      CyberButton.secondary(
        text: '取消',
        height: 32,
        fontSize: 11,
        onPressed: () => Navigator.of(context).pop(false),
      ),
      const SizedBox(width: 8),
      CyberButton.primary(
        text: '开始导航',
        height: 32,
        fontSize: 11,
        icon: Icons.navigation_outlined,
        onPressed: () => Navigator.of(context).pop(true),
      ),
    ],
  );

  final url = controller.text.trim();
  controller.dispose();

  if (confirmed != true || url.isEmpty || !context.mounted) return;
  final ok = await navi.start(url);
  if (!context.mounted) return;
  // 行前自检拦下（分享本来就没在导航）≠ 解析失败：卡片没被拉起，只给一条
  // warning，措辞说清"什么都没发生"，别让用户以为是自己粘错了。
  final endedShare = !ok && navi.lastStartEndedShare;
  CyberToast.show(
    context,
    ok ? '导航已同步，指引已上线' : (navi.errorMessage ?? '解析失败：未知错误'),
    type: ok
        ? CyberToastType.success
        : (endedShare ? CyberToastType.warning : CyberToastType.error),
  );
}
