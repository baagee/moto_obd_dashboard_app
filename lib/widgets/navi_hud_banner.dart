import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/amap/route_analyzer.dart';
import '../providers/navi_provider.dart';
import '../theme/app_fonts.dart';
import '../theme/app_theme.dart';
import 'navi_turn_arrow.dart';

/// 临近路口通栏（方案 §2.3 + §2.4 + §2.8）
///
/// 出现/消失绑定**动作队列**而不是单个动作：只要队列中还有 `eta < 8s` 的动作
/// 就保持展开，只更新内容 —— 连续转弯（实测 153m/31m/51m 三个动作）期间
/// 不出现"展开→收回→展开"的抖动。
///
/// **作为悬浮覆盖层**叠加在仪表盘顶部：`dashboard_screen.dart` 里挂在
/// `Positioned(top:0, left:0, right:0)` 上，**不参与三栏 Column 的布局**，
/// 因此不会把下方的仪表压缩变形（这是本轮的既有实现；早期文档曾写成"Column
/// 占位 + 三栏压缩"，已按实现更正）。为在覆盖时不被底层仪表透出干扰读数，底色
/// 近乎不透明；未展开时高度为零，非导航态完全零占位。
class NaviHudBanner extends StatelessWidget {
  const NaviHudBanner({super.key});

  /// 通栏展开高度（方案 §2.3：72px）
  static const double expandedHeight = 72;

  static const Duration _animDuration = Duration(milliseconds: 300);

  @override
  Widget build(BuildContext context) {
    // 仅 select 展开状态：内容切换由 body 内部的 Consumer 负责，
    // 保证"通栏仅在 _bannerExpanded 翻转时重建外壳"（方案 §4 重绘）
    final expanded = context.select<NaviProvider, bool>((p) => p.bannerExpanded);
    final visible = context.select<NaviProvider, bool>(
      (p) => p.state == NaviState.navigating || p.state == NaviState.stale,
    );

    return AnimatedSize(
      duration: _animDuration,
      curve: Curves.easeInOut,
      alignment: Alignment.topCenter,
      child: (expanded && visible)
          ? const _BannerBody(key: ValueKey('navi-banner'))
          : const SizedBox(width: double.infinity, height: 0),
    );
  }
}

class _BannerBody extends StatelessWidget {
  const _BannerBody({super.key});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: NaviHudBanner._animDuration,
      curve: Curves.easeInOut,
      builder: (context, t, child) => Opacity(opacity: t, child: child),
      child: SizedBox(
        height: NaviHudBanner.expandedHeight,
        width: double.infinity,
        child: Consumer<NaviProvider>(
          builder: (context, navi, _) {
            final current = navi.nextAction;
            // 用动作点（而不是只取动作码）：0 码需要上下文才能区分"无动作"与终点段"到达"
            final action = navi.displayAction;
            if (action == null) return const SizedBox.shrink();
            final turn = naviTurnTypeOfAction(action);
            final ahead = navi.distanceToNextAction;
            final imminent = ahead != null && ahead < 50;
            final accent = imminent ? AppTheme.gaugeWarn : AppTheme.textPrimary;

            // 内容切换 300ms 淡入淡出（方案 §2.4 ③）。
            // key 只取"当前动作的身份"，不含距离 —— 距离是实时倒计时，
            // 若把距离写进 key 会每 1 米就触发一次交叉淡入，反而变成持续闪烁。
            return AnimatedSwitcher(
              duration: NaviHudBanner._animDuration,
              child: _BreathingBanner(
                key: ValueKey(
                    'act_${current?.segmentIndex ?? -1}_${action.actionCode}'),
                turn: turn,
                distanceLabel: ahead == null ? '--' : '${ahead.round()}',
                distanceColor: accent,
                actionLabel: naviTurnLabelOfAction(action) ??
                    (navi.currentRoad ?? '继续前行'),
                roadLabel: _roadLabel(navi),
                subsequents: navi.upcomingActions.skip(1).toList(),
                speedLimit: navi.speedLimitKmh,
                speeding: navi.isSpeeding,
              ),
            );
          },
        ),
      ),
    );
  }

  static String _roadLabel(NaviProvider navi) {
    final from = navi.currentRoad;
    final to = navi.nextAction?.nextRoadName;
    if (from == null || from.isEmpty) return to ?? '';
    if (to == null || to.isEmpty) return '$from → 终点';
    return '$from → $to';
  }
}

/// 带呼吸发光边框 + 边缘侧光的通栏主体
class _BreathingBanner extends StatefulWidget {
  const _BreathingBanner({
    super.key,
    required this.turn,
    required this.distanceLabel,
    required this.distanceColor,
    required this.actionLabel,
    required this.roadLabel,
    required this.subsequents,
    required this.speedLimit,
    required this.speeding,
  });

  final NaviTurnType turn;
  final String distanceLabel;
  final Color distanceColor;
  final String actionLabel;
  final String roadLabel;
  final List<ActionPoint> subsequents;
  final int? speedLimit;
  final bool speeding;

  @override
  State<_BreathingBanner> createState() => _BreathingBannerState();
}

class _BreathingBannerState extends State<_BreathingBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    // 复用 DangerPulseOverlay 的动画范式：700ms 呼吸
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
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
        final opacity = 0.30 + 0.45 * _c.value;
        return Container(
          decoration: BoxDecoration(
            // 近乎不透明：悬浮在仪表盘上方时避免底层仪表透出来干扰读数；
            // 呼吸效果由边框与发光承载（见下），不靠底色透明。
            color: AppTheme.surface.withValues(alpha: 0.92),
            // 呼吸边框用 gaugeNormal 青（不用琥珀/红：红色已被 RPM/速度超限占用）
            border: Border.all(
              color: AppTheme.gaugeNormal.withValues(alpha: opacity),
              width: 1.5,
            ),
            boxShadow: AppTheme.glowShadow(
              AppTheme.gaugeNormal,
              blur: 10 + 8 * _c.value,
              opacity: 0.10 + 0.18 * _c.value,
            ),
          ),
          child: Row(
            children: [
              // 左侧宽边竖条：与 CyberToast / 导航卡动作条保持一致的"左宽边"样式，
              // 固定在最左端，不随转向方向左右跳动
              _sideLight(),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: NaviTurnArrow(
                  type: widget.turn,
                  size: 56,
                  color: AppTheme.gaugeNormal,
                ),
              ),
              const SizedBox(width: 12),

              // 剩余距离：42px Orbitron；< 50m 转琥珀
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    widget.distanceLabel,
                    style: AppFonts.displayStyle(
                      fontSize: 42,
                      color: widget.distanceColor,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Text('米',
                        style: TextStyle(
                            color: widget.distanceColor, fontSize: 14)),
                  ),
                ],
              ),
              const SizedBox(width: 14),

              // 动作名 + 路线：横屏空间充足，合并一行；动作名加大到 20px
              Expanded(
                child: RichText(
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: widget.actionLabel,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (widget.roadLabel.isNotEmpty) ...[
                        const TextSpan(
                          text: '  ',
                          style: TextStyle(fontSize: 20),
                        ),
                        TextSpan(
                          text: widget.roadLabel,
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 16,
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // 后续动作序列：只用图标 + 距离，不抢当前动作的注意力
              if (widget.subsequents.isNotEmpty) ...[
                const SizedBox(width: 8),
                _SubsequentSequence(actions: widget.subsequents),
              ],

              const SizedBox(width: 12),
              if (widget.speedLimit != null)
                _SpeedLimitSign(
                  limit: widget.speedLimit!,
                  speeding: widget.speeding,
                  phase: _c.value,
                ),
              const SizedBox(width: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _sideLight() => Container(width: 4, color: AppTheme.gaugeNormal);
}

/// 后续动作序列（`然后 ⬅ 65m ↗ 116m`）
class _SubsequentSequence extends StatelessWidget {
  const _SubsequentSequence({required this.actions});

  final List<ActionPoint> actions;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('然后',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
        const SizedBox(width: 6),
        for (final a in actions) ...[
          NaviTurnArrow(
            type: naviTurnTypeOfAction(a),
            size: 18,
            color: AppTheme.textSecondary,
            glow: false,
          ),
          const SizedBox(width: 2),
          Text(
            '${a.atDistance.round()}m',
            style: AppFonts.monoStyle(
              fontSize: 12,
              color: AppTheme.textMuted,
            ),
          ),
          const SizedBox(width: 10),
        ],
      ],
    );
  }
}

/// 限速牌：36px 圆，白底黑字红圈；超速时红圈闪烁
class _SpeedLimitSign extends StatelessWidget {
  const _SpeedLimitSign({
    required this.limit,
    required this.speeding,
    required this.phase,
  });

  final int limit;
  final bool speeding;
  final double phase;

  @override
  Widget build(BuildContext context) {
    final ringOpacity = speeding ? (0.35 + 0.65 * phase) : 1.0;
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(
          color: AppTheme.gaugeDanger.withValues(alpha: ringOpacity),
          width: 3,
        ),
        boxShadow: speeding
            ? AppTheme.glowShadow(AppTheme.gaugeDanger,
                blur: 14, opacity: 0.5 * ringOpacity)
            : null,
      ),
      child: Text(
        '$limit',
        style: const TextStyle(
          color: Colors.black,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
