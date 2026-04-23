import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/obd_data_provider.dart';
import '../theme/app_theme.dart';

/// 档位显示面板
/// 所有档位共享一个容器，档位之间用细分割线隔开，激活档用发光方框高亮
class GearDisplayPanel extends StatelessWidget {
  const GearDisplayPanel({super.key});

  static const List<int> _gears = [6, 5, 4, 3, 2, 0, 1]; // 0 = N

  @override
  Widget build(BuildContext context) {
    // 精确订阅 gear 单字段，其他字段变化（倾角66Hz等）不触发重建
    final gear = context.select<OBDDataProvider, int>((p) => p.data.gear);
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: AppTheme.surfaceBorder(),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // 顶部标签
          const Text('档位', style: AppTheme.labelMediumPrimary12),
          const SizedBox(height: 4),
          // 档位列表区域
          Expanded(
            child: _GearList(gears: _gears, currentGear: gear),
          ),
        ],
      ),
    );
  }
}

/// 档位列表：用细分割线隔开各档位，激活档用发光方框高亮
class _GearList extends StatelessWidget {
  final List<int> gears;
  final int currentGear;

  const _GearList({required this.gears, required this.currentGear});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalHeight = constraints.maxHeight;
        final dividerCount = gears.length - 1; // 分割线数量
        const dividerH = 1.0;
        const dividerSpacing = 0.0;
        // 每个档位行高（均分，扣除分割线占用）
        final rowHeight =
            (totalHeight - dividerCount * (dividerH + dividerSpacing * 2)) /
                gears.length;

        return Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            for (int i = 0; i < gears.length; i++) ...[
              _GearRow(
                gear: gears[i],
                currentGear: currentGear,
                height: rowHeight,
              ),
              if (i < gears.length - 1)
                Container(
                  height: dividerH,
                  color: AppTheme.primary20,
                ),
            ],
          ],
        );
      },
    );
  }
}

/// 单个档位行 - 带激活时发光方框动画
class _GearRow extends StatefulWidget {
  final int gear;
  final int currentGear;
  final double height;

  const _GearRow({
    required this.gear,
    required this.currentGear,
    required this.height,
  });

  @override
  State<_GearRow> createState() => _GearRowState();
}

class _GearRowState extends State<_GearRow>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _glowAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _glowAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    if (widget.gear == widget.currentGear) _ctrl.value = 1.0;
  }

  @override
  void didUpdateWidget(_GearRow old) {
    super.didUpdateWidget(old);
    if (widget.gear == widget.currentGear) {
      _ctrl.forward();
    } else {
      _ctrl.reverse();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isNeutral = widget.gear == 0;
    final displayText = isNeutral ? 'N' : '${widget.gear}';
    final activeColor = isNeutral ? AppTheme.accentOrange : AppTheme.accentCyan;

    // 文字透明度：按距激活档的距离衰减，营造景深感
    final distance = (widget.gear - widget.currentGear).abs();
    final isActive = distance == 0;
    // 未激活统一用相同透明度的主题蓝色，保持颜色一致
    final textOpacity =
        isActive ? 1.0 : (1.0 - distance * 0.15).clamp(0.35, 0.75);

    return AnimatedBuilder(
      animation: _glowAnim,
      builder: (context, _) {
        final t = _glowAnim.value;
        return SizedBox(
          height: widget.height,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 背景文字（始终可见）
              Center(
                child: Text(
                  displayText,
                  style: TextStyle(
                    color: isActive ? activeColor : AppTheme.accentCyan,
                    fontSize: 15 + t * 3, // 激活时字号从 15 → 18
                    fontWeight: isActive ? FontWeight.bold : FontWeight.w400,
                  ),
                ),
              ),
              // 激活发光方框（透明度跟随动画）
              if (t > 0)
                Positioned.fill(
                  child: Container(
                    margin: const EdgeInsets.symmetric(
                        vertical: 1.0, horizontal: 0),
                    decoration: BoxDecoration(
                      // 半透明渐变填充
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          activeColor.withValues(alpha: 0.22 * t),
                          activeColor.withValues(alpha: 0.08 * t),
                        ],
                      ),
                      border: Border.all(
                        color: activeColor.withValues(alpha: 0.9 * t),
                        width: 1.5,
                      ),
                      // 双层发光
                      boxShadow: [
                        BoxShadow(
                          color: activeColor.withValues(alpha: 0.55 * t),
                          blurRadius: 6,
                          spreadRadius: -1,
                        ),
                        BoxShadow(
                          color: activeColor.withValues(alpha: 0.20 * t),
                          blurRadius: 14,
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
