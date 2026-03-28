import 'package:flutter/material.dart';
import '../models/riding_record.dart';
import '../theme/app_theme.dart';

/// 轨迹页底部统计摘要卡片（距离 / 时长 / 极速 / 均速）
class TrackStatsCard extends StatelessWidget {
  final RidingRecord record;

  const TrackStatsCard({super.key, required this.record});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.backgroundDark.withOpacity(0.9),
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: AppTheme.primary20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatItem(
            icon: Icons.route,
            label: '距离',
            value: '${record.distance.toStringAsFixed(1)}',
            unit: 'km',
            color: AppTheme.textPrimary,
          ),
          _Divider(),
          _StatItem(
            icon: Icons.timer_outlined,
            label: '时长',
            value: record.formattedDuration,
            unit: '',
            color: AppTheme.accentGreen,
          ),
          _Divider(),
          _StatItem(
            icon: Icons.flash_on,
            label: '极速',
            value: '${record.maxSpeed.toStringAsFixed(0)}',
            unit: 'km/h',
            color: AppTheme.accentOrange,
          ),
          _Divider(),
          _StatItem(
            icon: Icons.speed,
            label: '均速',
            value: '${record.avgSpeed.toStringAsFixed(0)}',
            unit: 'km/h',
            color: AppTheme.accentCyan,
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      width: 1,
      color: AppTheme.primary20,
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final Color color;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color.withOpacity(0.6), size: 18),
        const SizedBox(height: 4),
        Text(label,
            style: const TextStyle(
                color: AppTheme.textMuted, fontSize: 10, letterSpacing: 0.5)),
        const SizedBox(height: 2),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: value,
                style: TextStyle(
                  color: color,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (unit.isNotEmpty)
                TextSpan(
                  text: ' $unit',
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 10,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
