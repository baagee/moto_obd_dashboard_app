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
  State<EventNotificationDialog> createState() => _EventNotificationDialogState();
}

class _EventNotificationDialogState extends State<EventNotificationDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _shakeAnimation;
  late Animation<double> _neonAnimation;

  /// 动画抖动偏移量
  double _shakeOffset = 0.0;

  Timer? _shakeTimer;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _startAnimations();
  }

  void _initAnimations() {
    // 使用单个动画控制器
    _animController = AnimationController(
      duration: const Duration(milliseconds: 60),
      vsync: this,
    );

    // 抖动动画：从 -6 到 6
    _shakeAnimation = Tween<double>(begin: -6.0, end: 6.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );

    // 霓虹闪烁动画：透明度 0.5 到 1.0
    _neonAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );

    _animController.addListener(_onAnimationUpdate);
  }

  void _onAnimationUpdate() {
    setState(() {
      _shakeOffset = _shakeAnimation.value;
    });
  }

  void _startAnimations() {
    // 快速抖动：每60ms切换一次方向
    _shakeTimer = Timer.periodic(const Duration(milliseconds: 60), (_) {
      if (_animController.status == AnimationStatus.completed) {
        _animController.reverse();
      } else {
        _animController.forward();
      }
    });

    // 3秒后停止动画并自动关闭弹窗
    Future.delayed(const Duration(seconds: 3), () {
      _shakeTimer?.cancel();
      _animController.stop();
      if (mounted) {
        setState(() {
          _shakeOffset = 0;
        });
        Navigator.of(context).pop();
      }
    });
  }

  @override
  void dispose() {
    _shakeTimer?.cancel();
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
    }
  }

  /// 构建扩展信息显示 - 直接展示 additionalData 所有字段
  Widget _buildAdditionalInfo(Color eventColor) {
    final data = widget.event.additionalData;
    if (data.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 8,
      runSpacing: 4,
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
            fontSize: 10,
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
          // 霓虹闪烁：边框颜色在 0.5-1.0 透明度之间变化
          final neonOpacity = _neonAnimation.value;
          final neonColor = eventColor.withOpacity(neonOpacity);

          return Transform.translate(
            offset: Offset(_shakeOffset, 0),
            child: Container(
              width: 320,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: neonColor,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: eventColor.withOpacity(neonOpacity * 0.5),
                    blurRadius: 20 * neonOpacity,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 标题行
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: eventColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          _getEventIcon(),
                          color: eventColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          widget.event.title,
                          style: TextStyle(
                            color: eventColor,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // 事件描述
                  Text(
                    widget.event.description,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),
                  // 扩展信息显示
                  _buildAdditionalInfo(eventColor),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
