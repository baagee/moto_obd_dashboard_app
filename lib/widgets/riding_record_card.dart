import 'package:flutter/material.dart';
import '../models/riding_record.dart';
import '../models/riding_event.dart';
import '../theme/app_theme.dart';
import 'mini_track_preview.dart';

/// 骑行记录卡片
class RidingRecordCard extends StatelessWidget {
  final RidingRecord record;
  final VoidCallback? onTap;

  const RidingRecordCard({
    super.key,
    required this.record,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: AppTheme.surfaceBorderDefault,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 顶部：日期时间
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDateTime(record.startTime),
                  style: AppTheme.titleMedium,
                ),
                if (record.trackPoints.isNotEmpty)
                  SizedBox(
                    width: 80,
                    height: 40,
                    child: MiniTrackPreview(
                      trackPoints: record.trackPoints,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // 中部：时长和里程
            Row(
              children: [
                _StatItem(
                  label: '时长',
                  value: _formatDuration(record.duration),
                ),
                const SizedBox(width: 24),
                _StatItem(
                  label: '里程',
                  value: '${record.distance.toStringAsFixed(2)} km',
                ),
                const SizedBox(width: 24),
                _StatItem(
                  label: '最高速度',
                  value: '${record.maxSpeed.toStringAsFixed(1)} km/h',
                ),
                const SizedBox(width: 24),
                _StatItem(
                  label: '平均速度',
                  value: '${record.avgSpeed.toStringAsFixed(1)} km/h',
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 底部：倾角和事件统计
            Row(
              children: [
                _LeanBadge(label: '左倾', value: '${record.maxLeanLeft}°'),
                const SizedBox(width: 8),
                _LeanBadge(label: '右倾', value: '${record.maxLeanRight}°'),
                const SizedBox(width: 16),
                if (record.eventCounts.isNotEmpty) ...[
                  _EventBadge(
                    type: RidingEventType.extremeLean,
                    count: record.eventCounts[RidingEventType.extremeLean] ?? 0,
                  ),
                  const SizedBox(width: 8),
                  _EventBadge(
                    type: RidingEventType.performanceBurst,
                    count: record.eventCounts[RidingEventType.performanceBurst] ?? 0,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h > 0) return '${h}h${m}m';
    return '${m}m';
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;

  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTheme.labelSmall),
        const SizedBox(height: 2),
        Text(value, style: AppTheme.valueMedium),
      ],
    );
  }
}

class _LeanBadge extends StatelessWidget {
  final String label;
  final String value;

  const _LeanBadge({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.primary20,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '$label $value',
        style: AppTheme.labelSmall.copyWith(color: AppTheme.primary),
      ),
    );
  }
}

class _EventBadge extends StatelessWidget {
  final RidingEventType type;
  final int count;

  const _EventBadge({required this.type, required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.accentOrange20,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '${_getEventName(type)} $count',
        style: AppTheme.labelSmall.copyWith(color: AppTheme.accentOrange),
      ),
    );
  }

  String _getEventName(RidingEventType type) {
    switch (type) {
      case RidingEventType.extremeLean:
        return '压弯';
      case RidingEventType.performanceBurst:
        return '爆发';
      default:
        return '事件';
    }
  }
}
