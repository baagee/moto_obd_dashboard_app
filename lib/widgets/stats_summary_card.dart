import 'package:flutter/material.dart';
import '../models/riding_record.dart';
import '../theme/app_theme.dart';

/// 聚合统计卡片组件
class StatsSummaryCard extends StatelessWidget {
  final AggregationStats stats;

  const StatsSummaryCard({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: AppTheme.surfaceBorderDefault,
      child: Row(
        children: [
          Expanded(child: _buildStatItem('骑行距离', '${stats.distance.toStringAsFixed(1)} km', AppTheme.textPrimary)),
          Expanded(child: _buildStatItem('平均速度', '${stats.avgSpeed.toStringAsFixed(1)} km/h', AppTheme.accentCyan)),
          Expanded(child: _buildStatItem('骑行时间', stats.formattedDuration, AppTheme.accentGreen)),
          Expanded(child: _buildStatItem('最快速度', '${stats.maxSpeed.toStringAsFixed(0)} km/h', AppTheme.accentOrange)),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color valueColor) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: AppTheme.labelSmall.copyWith(color: AppTheme.textMuted),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppTheme.valueMedium.copyWith(color: valueColor),
        ),
      ],
    );
  }
}
