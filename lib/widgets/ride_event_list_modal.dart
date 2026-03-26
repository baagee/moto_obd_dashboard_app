import 'package:flutter/material.dart';
import '../models/riding_record.dart';
import '../theme/app_theme.dart';

/// 骑行事件列表弹窗
class RideEventListModal extends StatelessWidget {
  final List<RidingRecordEvent> events;

  const RideEventListModal({super.key, required this.events});

  static Future<void> show(BuildContext context, List<RidingRecordEvent> events) {
    return showDialog(
      context: context,
      builder: (ctx) => RideEventListModal(events: events),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          border: Border.all(color: AppTheme.primary40),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题
            Text(
              '骑行事件列表 · 共${events.length}个事件',
              style: AppTheme.labelMediumPrimary12.copyWith(color: AppTheme.primary),
            ),
            const SizedBox(height: 12),
            // 事件列表
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: events.length,
                itemBuilder: (context, index) {
                  return _buildEventItem(events[index]);
                },
              ),
            ),
            const SizedBox(height: 12),
            // 关闭按钮
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(AppTheme.radiusButton),
                ),
                child: Center(
                  child: Text(
                    '关闭',
                    style: AppTheme.labelMedium.copyWith(color: Colors.black),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventItem(RidingRecordEvent event) {
    final color = _getEventColor(event.type);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.slateGray,
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        border: Border(
          left: BorderSide(color: color, width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                event.title,
                style: AppTheme.labelMedium.copyWith(color: color, fontWeight: FontWeight.bold),
              ),
              Text(
                event.formattedTime,
                style: AppTheme.labelSmall.copyWith(color: AppTheme.textMuted),
              ),
            ],
          ),
          if (event.description != null) ...[
            const SizedBox(height: 4),
            Text(
              event.description!,
              style: AppTheme.labelMedium.copyWith(color: AppTheme.textSecondary),
            ),
          ],
        ],
      ),
    );
  }

  Color _getEventColor(String type) {
    switch (type) {
      case 'RidingEventType.extremeLean':
        return AppTheme.accentPink;
      case 'RidingEventType.efficientCruising':
        return AppTheme.accentOrange;
      case 'RidingEventType.performanceBurst':
        return AppTheme.primary;
      case 'RidingEventType.engineOverheating':
        return AppTheme.accentRed;
      case 'RidingEventType.highEngineLoad':
        return AppTheme.accentOrange;
      default:
        return AppTheme.textSecondary;
    }
  }
}
