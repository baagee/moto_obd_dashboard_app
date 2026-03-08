import 'dart:async';
import 'package:flutter/material.dart';
import '../models/riding_event.dart';
import '../theme/app_theme.dart';

/// 骑行事件通知弹窗
/// 带半透明背景、抖动动画、进度条显示
/// 样式参考 CyberDialog
class EventNotificationDialog extends StatefulWidget {
  /// 事件对象
  final RidingEvent event;

  /// 语音播放进度回调
  final void Function(double progress)? onProgressUpdate;

  /// 语音播放完成回调
  final VoidCallback? onComplete;

  const EventNotificationDialog({
    super.key,
    required this.event,
    this.onProgressUpdate,
    this.onComplete,
  });

  /// 显示弹窗的便捷方法
  static Future<void> show({
    required BuildContext context,
    required RidingEvent event,
    void Function(double progress)? onProgressUpdate,
    VoidCallback? onComplete,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (context) => EventNotificationDialog(
        event: event,
        onProgressUpdate: onProgressUpdate,
        onComplete: onComplete,
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

  /// 当前播放进度 (0.0 - 1.0)
  double _progress = 0.0;

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
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 100),
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
    // 快速抖动：每100ms切换一次方向
    _shakeTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (_shakeController.status == AnimationStatus.completed) {
        _shakeController.reverse();
      } else {
        _shakeController.forward();
      }
    });

    // 3秒后停止抖动
    Future.delayed(const Duration(seconds: 3), () {
      _shakeTimer?.cancel();
      _shakeController.stop();
      if (mounted) {
        setState(() {
          _shakeOffset = 0;
        });
      }
    });
  }

  @override
  void dispose() {
    _shakeTimer?.cancel();
    _shakeController.dispose();
    super.dispose();
  }

  /// 更新进度条
  void updateProgress(double progress) {
    if (mounted) {
      setState(() {
        _progress = progress.clamp(0.0, 1.0);
      });
      widget.onProgressUpdate?.call(_progress);
    }
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

  @override
  Widget build(BuildContext context) {
    final eventColor = _getEventColor();

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Transform.translate(
        offset: Offset(_shakeOffset, 0),
        child: Container(
          width: 320,
          padding: const EdgeInsets.all(20),
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
              // 顶部进度条
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                child: LinearProgressIndicator(
                  value: _progress,
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(eventColor),
                  minHeight: 3,
                ),
              ),

              const SizedBox(height: 16),

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
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.event.title,
                      style: TextStyle(
                        color: eventColor,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // 事件描述
              Text(
                widget.event.description,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                  height: 1.4,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 16),

              // 进度指示
              Row(
                children: [
                  Icon(
                    _progress >= 1.0 ? Icons.check_circle : Icons.volume_up,
                    color: eventColor.withOpacity(0.8),
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _progress >= 1.0 ? '播报完成' : '语音播报中...',
                    style: TextStyle(
                      color: eventColor.withOpacity(0.8),
                      fontSize: 10,
                      letterSpacing: 1,
                    ),
                  ),
                  const Spacer(),
                  // 进度百分比
                  Text(
                    '${(_progress * 100).toInt()}%',
                    style: TextStyle(
                      color: eventColor.withOpacity(0.6),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
