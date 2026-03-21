import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/riding_event.dart';
import '../providers/riding_stats_provider.dart';
import '../theme/app_theme.dart';
import 'cyber_dialog.dart';
import 'gear_display_panel.dart';

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
                                style: TextStyle(color: AppTheme.textMuted, fontSize: 10),
                              ),
                            )
                          : ListView.separated(
                              padding: EdgeInsets.zero,
                              itemCount: events.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 4),
                              itemBuilder: (context, index) {
                                final event = events[index];
                                return _EventItem(
                                  key: ValueKey(event.timestamp),
                                  event: event,
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

class _EventItem extends StatelessWidget {
  final RidingEvent event;

  const _EventItem({required this.event, super.key});

  Color get _color {
    switch (event.type) {
      case RidingEventType.performanceBurst:
        return AppTheme.accentRed;
      case RidingEventType.efficientCruising:
        return AppTheme.accentGreen;
      case RidingEventType.engineOverheating:
        return AppTheme.accentRed;
      case RidingEventType.voltageAnomaly:
        return Colors.amber;
      case RidingEventType.longRiding:
        return AppTheme.primary;
      case RidingEventType.highEngineLoad:
        return Colors.orange;
      case RidingEventType.engineWarmup:
        return Colors.amber;
      case RidingEventType.coldEnvironmentRisk:
        return AppTheme.accentCyan;
      case RidingEventType.extremeLean:
        return Colors.purple;
    }
  }

  IconData get _icon {
    switch (event.type) {
      case RidingEventType.performanceBurst:
        return Icons.speed;
      case RidingEventType.efficientCruising:
        return Icons.eco;
      case RidingEventType.engineOverheating:
        return Icons.whatshot;
      case RidingEventType.voltageAnomaly:
        return Icons.battery_alert;
      case RidingEventType.longRiding:
        return Icons.timer;
      case RidingEventType.highEngineLoad:
        return Icons.engineering;
      case RidingEventType.engineWarmup:
        return Icons.ac_unit;
      case RidingEventType.coldEnvironmentRisk:
        return Icons.severe_cold;
      case RidingEventType.extremeLean:
        return Icons.rotate_right;
    }
  }

  void _showDetailDialog(BuildContext context) {
    CyberDialog.show(
      context: context,
      title: event.title,
      icon: _icon,
      accentColor: _color,
      barrierDismissible: true,
      actions: const [],
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _DetailRow(label: '事件类型', value: event.type.toString()),
            _DetailRow(label: '描述', value: event.description),
            _DetailRow(label: '触发值', value: event.triggerValue.toStringAsFixed(1)),
            _DetailRow(label: '阈值', value: event.threshold.toStringAsFixed(1)),
            _DetailRow(
              label: '触发时间',
              value: '${event.timestamp.hour.toString().padLeft(2, '0')}:${event.timestamp.minute.toString().padLeft(2, '0')}:${event.timestamp.second.toString().padLeft(2, '0')}',
            ),
            if (event.additionalData.isNotEmpty) ...[
              const Divider(color: AppTheme.textMuted),
              const Text('扩展信息', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
              const SizedBox(height: 4),
              ...event.additionalData.entries.map(
                (e) => _DetailRow(label: e.key, value: e.value.toString()),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showDetailDialog(context),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: _color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6),
          border: Border(
            left: BorderSide(color: _color, width: 3),
          ),
        ),
        child: Row(
          children: [
            Icon(_icon, color: _color, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: AppTheme.labelTiny.copyWith(color: _color),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${event.timestamp.hour.toString().padLeft(2, '0')}:${event.timestamp.minute.toString().padLeft(2, '0')}',
                    style: AppTheme.valueSmall.copyWith(fontSize: 9),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
