import 'dart:async';
import 'package:flutter/material.dart';
import '../models/riding_event.dart';
import '../theme/app_theme.dart';

/// 骑行事件通知弹窗
/// 带抖动动画显示
/// 样式参考 CyberDialog
class EventNotificationDialog extends StatefulWidget {
  /// 事件对象
  final RidingEvent event;

  const EventNotificationDialog({
    super.key,
    required this.event,
  });

  /// 显示弹窗的便捷方法
  static Future<void> show({
    required BuildContext context,
    required RidingEvent event,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (context) => EventNotificationDialog(
        event: event,
      ),
    );
  }

  @override
  State<EventNotificationDialog> createState() =>
      _EventNotificationDialogState();
}

class _EventNotificationDialogState extends State<EventNotificationDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _neonAnimation;

  Timer? _blinkTimer;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _startAnimations();
  }

  void _initAnimations() {
    // 使用单个动画控制器（加快到40ms，闪烁更快）
    _animController = AnimationController(
      duration: const Duration(milliseconds: 40),
      vsync: this,
    );

    // 霓虹闪烁动画：透明度 0.2 到 1.0（更明显）
    _neonAnimation = Tween<double>(begin: 0.2, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  void _startAnimations() {
    // 快速闪烁：每40ms切换一次方向
    _blinkTimer = Timer.periodic(const Duration(milliseconds: 40), (_) {
      if (_animController.status == AnimationStatus.completed) {
        _animController.reverse();
      } else {
        _animController.forward();
      }
    });

    // 3秒后停止动画并自动关闭弹窗
    Future.delayed(const Duration(seconds: 3), () {
      _blinkTimer?.cancel();
      _animController.stop();
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  /// 获取事件对应的颜色
  Color _getEventColor() {
    switch (widget.event.type) {
      case RidingEventType.performanceBurst:
        return AppTheme.accentOrange;
      case RidingEventType.efficientCruising:
        return AppTheme.accentGreen;
      case RidingEventType.engineOverheating:
        return AppTheme.accentRed;
      case RidingEventType.voltageAnomaly:
        return AppTheme.accentOrange;
      case RidingEventType.longRiding:
        return AppTheme.primary;
      case RidingEventType.highEngineLoad:
        return AppTheme.accentOrange;
      case RidingEventType.engineWarmup:
        return AppTheme.accentCyan;
      case RidingEventType.coldEnvironmentRisk:
        return AppTheme.accentCyan;
      case RidingEventType.extremeLean:
        return AppTheme.accentRed;
      case RidingEventType.gearShiftUp:
        return AppTheme.accentGreen;
      case RidingEventType.gearShiftDown:
        return AppTheme.accentOrange;
    }
  }

  /// 获取事件图标
  IconData _getEventIcon() {
    switch (widget.event.type) {
      case RidingEventType.performanceBurst:
        return Icons.speed;
      case RidingEventType.efficientCruising:
        return Icons.eco;
      case RidingEventType.engineOverheating:
        return Icons.warning_amber;
      case RidingEventType.voltageAnomaly:
        return Icons.battery_alert;
      case RidingEventType.longRiding:
        return Icons.timer;
      case RidingEventType.highEngineLoad:
        return Icons.engineering;
      case RidingEventType.engineWarmup:
        return Icons.thermostat;
      case RidingEventType.coldEnvironmentRisk:
        return Icons.ac_unit;
      case RidingEventType.extremeLean:
        return Icons.sports_motorsports;
      case RidingEventType.gearShiftUp:
        return Icons.arrow_circle_up;
      case RidingEventType.gearShiftDown:
        return Icons.arrow_circle_down;
    }
  }

  /// 构建扩展信息显示 - 直接展示 additionalData 所有字段
  Widget _buildAdditionalInfo(Color eventColor) {
    final data = widget.event.additionalData;
    if (data.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: data.entries.map((entry) {
        String value = entry.value?.toString() ?? '';
        // 格式化数值
        if (entry.value is double) {
          value = (entry.value as double).toStringAsFixed(1);
        } else if (entry.value is int) {
          value = entry.value.toString();
        }
        return Text(
          '${entry.key}: $value',
          style: TextStyle(
            color: eventColor.withOpacity(0.8),
            fontSize: 14,
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final eventColor = _getEventColor();

    return Dialog(
      backgroundColor: Colors.transparent,
      child: AnimatedBuilder(
        animation: _animController,
        builder: (context, child) {
          // 霓虹闪烁：边框颜色在 0.3-1.0 透明度之间变化
          final neonOpacity = _neonAnimation.value;
          final neonColor = eventColor.withOpacity(neonOpacity);

          return Container(
            width: 420,
            clipBehavior: Clip.hardEdge,
            decoration: BoxDecoration(
              color: AppTheme.surface,
              border: Border.all(
                color: neonColor,
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: eventColor.withOpacity(neonOpacity * 0.7),
                  blurRadius: 30 * neonOpacity,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── 顶部彩色高亮横条 ──
                Container(height: 3, color: eventColor),
                // ── 标题行 ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: eventColor.withOpacity(0.2),
                        ),
                        child: Icon(
                          _getEventIcon(),
                          color: eventColor,
                          size: 36,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          widget.event.title,
                          style: TextStyle(
                            color: eventColor,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // ── 分隔线 ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                  child: Divider(
                    height: 1,
                    thickness: 1,
                    color: eventColor.withOpacity(0.3),
                  ),
                ),
                // ── 事件描述 ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                  child: Text(
                    widget.event.description,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 16,
                      height: 1.4,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // ── 扩展信息 ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
                  child: _buildAdditionalInfo(eventColor),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
