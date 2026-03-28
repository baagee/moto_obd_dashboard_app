import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'cyber_dialog.dart';

/// 统一的骑行事件 Item 组件
/// 同时支持运行时 [RidingEvent]（通过 fromEvent 工厂）和数据库 [RidingRecordEvent]（通过 fromRecord 工厂）
class RidingEventItem extends StatelessWidget {
  final String type;
  final String title;
  final String? description;
  final double triggerValue;
  final double threshold;
  final String timeLabel;
  final Map<String, dynamic>? additionalData;

  const RidingEventItem({
    super.key,
    required this.type,
    required this.title,
    this.description,
    required this.triggerValue,
    required this.threshold,
    required this.timeLabel,
    this.additionalData,
  });

  // ──────────────────────────────────────────────
  // 颜色 / 图标映射（统一处理 enum.toString() 字符串）
  // ──────────────────────────────────────────────
  static Color colorFromType(String type) {
    switch (type) {
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

  static IconData iconFromType(String type) {
    switch (type) {
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
    final color = colorFromType(type);
    final icon = iconFromType(type);

    CyberDialog.show(
      context: context,
      title: title,
      icon: icon,
      accentColor: color,
      barrierDismissible: true,
      width: 420,
      actions: const [],
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _DetailRow(label: '事件类型', value: type),
            if (description != null && description!.isNotEmpty)
              _DetailRow(label: '描述', value: description!),
            _DetailRow(label: '触发值', value: triggerValue.toStringAsFixed(1)),
            _DetailRow(label: '阈值', value: threshold.toStringAsFixed(1)),
            _DetailRow(label: '触发时间', value: timeLabel),
            if (additionalData != null && additionalData!.isNotEmpty) ...[
              const Divider(color: AppTheme.textMuted),
              const Text('扩展信息',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
              const SizedBox(height: 4),
              ...additionalData!.entries.map(
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
    final color = colorFromType(type);
    final icon = iconFromType(type);

    return GestureDetector(
      onTap: () => _showDetail(context),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          border: Border(
            left: BorderSide(color: color, width: 3),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTheme.labelTiny.copyWith(color: color),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    timeLabel,
                    style: AppTheme.valueSmall.copyWith(fontSize: 9),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right,
                color: color.withValues(alpha: 0.5), size: 14),
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
