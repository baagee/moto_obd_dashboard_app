import 'package:flutter/material.dart';
import '../models/riding_record.dart';
import '../theme/app_theme.dart';
import 'cyber_dialog.dart';

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
                  return _RecordEventItem(event: events[index]);
                },
              ),
      ),
    );
  }
}

/// 单条事件 item（与 Dashboard `_EventItem` 样式一致）
class _RecordEventItem extends StatelessWidget {
  final RidingRecordEvent event;

  const _RecordEventItem({required this.event});

  Color get _color {
    switch (event.type) {
      case 'RidingEventType.performanceBurst':
        return AppTheme.accentRed;
      case 'RidingEventType.efficientCruising':
        return AppTheme.accentGreen;
      case 'RidingEventType.engineOverheating':
        return AppTheme.accentRed;
      case 'RidingEventType.voltageAnomaly':
        return Colors.amber;
      case 'RidingEventType.longRiding':
        return AppTheme.primary;
      case 'RidingEventType.highEngineLoad':
        return Colors.orange;
      case 'RidingEventType.engineWarmup':
        return Colors.amber;
      case 'RidingEventType.coldEnvironmentRisk':
        return AppTheme.accentCyan;
      case 'RidingEventType.extremeLean':
        return Colors.purple;
      default:
        return AppTheme.textSecondary;
    }
  }

  IconData get _icon {
    switch (event.type) {
      case 'RidingEventType.performanceBurst':
        return Icons.speed;
      case 'RidingEventType.efficientCruising':
        return Icons.eco;
      case 'RidingEventType.engineOverheating':
        return Icons.whatshot;
      case 'RidingEventType.voltageAnomaly':
        return Icons.battery_alert;
      case 'RidingEventType.longRiding':
        return Icons.timer;
      case 'RidingEventType.highEngineLoad':
        return Icons.engineering;
      case 'RidingEventType.engineWarmup':
        return Icons.ac_unit;
      case 'RidingEventType.coldEnvironmentRisk':
        return Icons.severe_cold;
      case 'RidingEventType.extremeLean':
        return Icons.rotate_right;
      default:
        return Icons.info_outline;
    }
  }

  void _showDetail(BuildContext context) {
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
            _DetailRow(label: '事件类型', value: event.type),
            if (event.description != null)
              _DetailRow(label: '描述', value: event.description!),
            _DetailRow(
                label: '触发值', value: event.triggerValue.toStringAsFixed(1)),
            _DetailRow(label: '阈值', value: event.threshold.toStringAsFixed(1)),
            _DetailRow(label: '触发时间', value: event.formattedTime),
            if (event.additionalData != null &&
                event.additionalData!.isNotEmpty) ...[
              const Divider(color: AppTheme.textMuted),
              const Text('扩展信息',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
              const SizedBox(height: 4),
              ...event.additionalData!.entries.map(
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
      onTap: () => _showDetail(context),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: _color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
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
                    event.formattedTime,
                    style: AppTheme.valueSmall.copyWith(fontSize: 9),
                  ),
                ],
              ),
            ),
            // 可点击提示
            Icon(Icons.chevron_right, color: _color.withValues(alpha: 0.5), size: 14),
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
