import 'package:flutter/material.dart';
import '../models/riding_record.dart';
import '../theme/app_theme.dart';
import 'cyber_dialog.dart';
import 'riding_event_item.dart';

/// 骑行事件列表弹窗（样式与 Dashboard 骑行事件面板一致）
class RideEventListModal {
  static Future<void> show(
      BuildContext context, List<RidingRecordEvent> events) {
    return CyberDialog.show(
      context: context,
      title: '骑行事件列表 · 共${events.length}个事件',
      icon: Icons.flag_outlined,
      accentColor: AppTheme.primary,
      barrierDismissible: true,
      actions: [],
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        child: events.isEmpty
            ? const Center(
                child: Text(
                  '暂无事件',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                ),
              )
            : ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: events.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (context, index) {
                  final event = events[index];
                  return RidingEventItem(
                    type: event.type,
                    title: event.title,
                    description: event.description,
                    triggerValue: event.triggerValue,
                    threshold: event.threshold,
                    timeLabel: event.formattedTime,
                    additionalData: event.additionalData,
                  );
                },
              ),
      ),
    );
  }
}
