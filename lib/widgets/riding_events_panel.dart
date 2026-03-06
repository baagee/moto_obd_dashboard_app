import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/obd_data.dart';
import '../providers/obd_data_provider.dart';
import '../theme/app_theme.dart';

/// 骑行事件面板
class RidingEventsPanel extends StatelessWidget {
  const RidingEventsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<OBDDataProvider>(
      builder: (context, provider, child) {
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: AppTheme.surfaceBorder(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题
              const Text('骑行事件', style: AppTheme.labelTinyPrimary),

              const SizedBox(height: 6),

              // 事件列表
              Expanded(
                child: ListView.separated(
                  padding: EdgeInsets.zero,
                  itemCount: provider.events.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 4),
                  itemBuilder: (context, index) {
                    final event = provider.events[index];
                    return _EventItem(
                      key: ValueKey(event.timestamp),
                      event: event,
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _EventItem extends StatelessWidget {
  final RidingEvent event;

  const _EventItem({required this.event, super.key});

  Color get _color {
    switch (event.type) {
      case EventType.warning:
        return AppTheme.accentRed;
      case EventType.success:
        return AppTheme.accentGreen;
      case EventType.info:
        return AppTheme.primary;
    }
  }

  IconData get _icon {
    switch (event.type) {
      case EventType.warning:
        return Icons.warning;
      case EventType.success:
        return Icons.check_circle;
      case EventType.info:
        return Icons.sports_motorsports;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.08),
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
                  event.title.toUpperCase(),
                  style: AppTheme.labelTiny.copyWith(color: _color),
                ),
                const SizedBox(height: 2),
                Text(event.message, style: AppTheme.valueSmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}