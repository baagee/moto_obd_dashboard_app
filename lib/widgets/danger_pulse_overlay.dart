import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// 危险状态呼吸闪烁覆盖层（Shift-Light）
///
/// [danger] 为 true 时，容器边缘红色发光边框以 700ms 周期呼吸；
/// 为 false 时停止动画并返回空组件，零帧开销。
/// 通过 [IgnorePointer] 保证不拦截手势（含长按切换仪表盘风格）。
class DangerPulseOverlay extends StatefulWidget {
  final bool danger;

  const DangerPulseOverlay({super.key, required this.danger});

  @override
  State<DangerPulseOverlay> createState() => _DangerPulseOverlayState();
}

class _DangerPulseOverlayState extends State<DangerPulseOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _opacity = Tween<double>(begin: 0.15, end: 0.75).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    if (widget.danger) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(DangerPulseOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.danger && !oldWidget.danger) {
      _controller.repeat(reverse: true);
    } else if (!widget.danger && oldWidget.danger) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.danger) return const SizedBox.shrink();

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _opacity,
        builder: (context, _) {
          return Opacity(
            opacity: _opacity.value,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.gaugeDanger, width: 2),
                borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.gaugeDanger.withValues(alpha: 0.6),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
