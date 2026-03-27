import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/riding_stats_provider.dart';
import '../theme/app_theme.dart';
import 'gear_display_panel.dart';
import 'riding_event_item.dart';

/// 骑行事件面板
class RidingEventsPanel extends StatelessWidget {
  const RidingEventsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // 左侧：档位竖向展示（无背景卡片）
        const Expanded(
          flex: 2,
          child: GearDisplayPanel(),
        ),

        const SizedBox(width: 8),

        // 右侧：骑行事件（独立卡片）
        Expanded(
          flex: 8,
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: AppTheme.surfaceBorder(),
            child: Consumer<RidingStatsProvider>(
              builder: (context, provider, child) {
                final events = provider.eventHistory;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 标题
                    const Text('骑行事件', style: AppTheme.labelMediumPrimary),

                    const SizedBox(height: 6),

                    // 事件列表
                    Expanded(
                      child: events.isEmpty
                          ? const Center(
                              child: Text(
                                '暂无事件',
                                style: TextStyle(
                                    color: AppTheme.textMuted, fontSize: 10),
                              ),
                            )
                          : ListView.separated(
                              padding: EdgeInsets.zero,
                              itemCount: events.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 4),
                              itemBuilder: (context, index) {
                                final event = events[index];
                                final ts = event.timestamp;
                                final timeLabel =
                                    '${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}';
                                return RidingEventItem(
                                  key: ValueKey(event.timestamp),
                                  type: event.type.toString(),
                                  title: event.title,
                                  description: event.description,
                                  triggerValue: event.triggerValue,
                                  threshold: event.threshold,
                                  timeLabel: timeLabel,
                                  additionalData: event.additionalData.isEmpty
                                      ? null
                                      : event.additionalData,
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
