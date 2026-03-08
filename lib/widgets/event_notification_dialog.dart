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
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  /// 动画抖动偏移量
  double _shakeOffset = 0.0;

  Timer? _shakeTimer;

  @override
  void initState() {
    super.initState();
    _initShakeAnimation();
    _startShakeAnimation();
  }

  void _initShakeAnimation() {
    // 抖动更快(60ms)，幅度更大(6px)
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 60),
      vsync: this,
    );

    _shakeAnimation = Tween<double>(begin: -3.0, end: 3.0).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut),
    );

    _shakeAnimation.addListener(() {
      setState(() {
        _shakeOffset = _shakeAnimation.value;
      });
    });
  }

  void _startShakeAnimation() {
    // 快速抖动：每60ms切换一次方向
    _shakeTimer = Timer.periodic(const Duration(milliseconds: 60), (_) {
      if (_shakeController.status == AnimationStatus.completed) {
        _shakeController.reverse();
      } else {
        _shakeController.forward();
      }
    });

    // 3秒后停止抖动并自动关闭弹窗
    Future.delayed(const Duration(seconds: 3), () {
      _shakeTimer?.cancel();
      _shakeController.stop();
      if (mounted) {
        setState(() {
          _shakeOffset = 0;
        });
        // 自动关闭弹窗
        Navigator.of(context).pop();
      }
    });
  }

  @override
  void dispose() {
    _shakeTimer?.cancel();
    _shakeController.dispose();
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
      child: Transform.translate(
        offset: Offset(_shakeOffset, 0),
        child: Container(
          width: 320,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: eventColor.withOpacity(0.5),
              width: 1,
            ),
            boxShadow: AppTheme.glowShadow(eventColor, blur: 20, opacity: 0.3),
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
      ),
    );
  }
}
