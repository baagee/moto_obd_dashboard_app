import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/riding_record_provider.dart';
import '../models/riding_record.dart';
import '../models/riding_event.dart';
import '../theme/app_theme.dart';
import '../widgets/riding_record_card.dart';
import '../widgets/cyber_dialog.dart';
import '../widgets/cyber_button.dart';
import '../widgets/mini_track_preview.dart';

/// 骑行历史记录页面
class RidingHistoryScreen extends StatelessWidget {
  const RidingHistoryScreen({super.key});

  /// 显示骑行记录详情弹窗
  void _showRecordDetailDialog(BuildContext context, RidingRecord record) {
    CyberDialog.show(
      context: context,
      title: '骑行详情',
      icon: Icons.route,
      accentColor: AppTheme.primary,
      content: _RecordDetailContent(record: record),
      actions: [
        CyberButton.secondary(
          text: '关闭',
          onPressed: () => Navigator.pop(context),
          height: 32,
          fontSize: 12,
        ),
      ],
      width: 360,
    );
  }

  /// 显示删除确认弹窗
  void _showDeleteConfirmDialog(
    BuildContext context,
    RidingRecordProvider provider,
    RidingRecord record,
  ) {
    CyberDialog.show(
      context: context,
      title: '删除记录',
      icon: Icons.warning_amber_rounded,
      accentColor: AppTheme.accentRed,
      content: const Text(
        '确定要删除这条骑行记录吗？此操作无法撤销。',
        style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
      ),
      actions: [
        CyberButton.secondary(
          text: '取消',
          onPressed: () => Navigator.pop(context),
          height: 32,
          fontSize: 12,
        ),
        const SizedBox(width: 8),
        CyberButton.danger(
          text: '删除',
          onPressed: () {
            provider.deleteRecord(record.id);
            Navigator.pop(context);
          },
          height: 32,
          fontSize: 12,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0A1114),
      ),
      child: Column(
        children: [
          // 顶部区域
          _buildHeader(context),

          // 历史记录列表
          Expanded(
            child: Consumer<RidingRecordProvider>(
              builder: (context, provider, child) {
                final records = provider.records;

                if (records.isEmpty) {
                  return _buildEmptyState();
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: records.length,
                  itemBuilder: (context, index) {
                    final record = records[index];
                    return Dismissible(
                      key: Key(record.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 24),
                        color: AppTheme.accentRed.withOpacity(0.2),
                        child: const Icon(
                          Icons.delete_outline,
                          color: AppTheme.accentRed,
                        ),
                      ),
                      confirmDismiss: (direction) async {
                        _showDeleteConfirmDialog(context, provider, record);
                        return false; // 阻止自动删除，由弹窗确认
                      },
                      child: RidingRecordCard(
                        record: record,
                        onTap: () => _showRecordDetailDialog(context, record),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface.withOpacity(0.5),
        border: Border(
          bottom: BorderSide(
            color: AppTheme.primary.withOpacity(0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'RIDING HISTORY',
                style: TextStyle(
                  color: AppTheme.primary.withOpacity(0.6),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 2),
              Consumer<RidingRecordProvider>(
                builder: (context, provider, _) {
                  final count = provider.records.length;
                  final totalDistance = provider.records.fold<double>(
                    0,
                    (sum, record) => sum + record.distance,
                  );
                  return Text(
                    '$count 条记录 | 总里程 ${totalDistance.toStringAsFixed(1)} km',
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 9,
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.route_outlined,
            color: AppTheme.textMuted,
            size: 48,
          ),
          SizedBox(height: 12),
          Text(
            '暂无骑行记录',
            style: TextStyle(
              color: AppTheme.textMuted,
              fontSize: 12,
            ),
          ),
          SizedBox(height: 4),
          Text(
            '连接设备开始骑行后，记录将显示在这里',
            style: TextStyle(
              color: AppTheme.textMuted,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

/// 骑行记录详情内容
class _RecordDetailContent extends StatelessWidget {
  final RidingRecord record;

  const _RecordDetailContent({required this.record});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 日期时间
          _DetailRow(
            label: '日期时间',
            value: _formatDateTime(record.startTime),
          ),
          const SizedBox(height: 8),

          // 时长
          _DetailRow(
            label: '骑行时长',
            value: _formatDuration(record.duration),
          ),
          const SizedBox(height: 8),

          // 里程
          _DetailRow(
            label: '总里程',
            value: '${record.distance.toStringAsFixed(2)} km',
          ),
          const SizedBox(height: 8),

          // 速度信息
          Row(
            children: [
              Expanded(
                child: _DetailRow(
                  label: '最高速度',
                  value: '${record.maxSpeed.toStringAsFixed(1)} km/h',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _DetailRow(
                  label: '平均速度',
                  value: '${record.avgSpeed.toStringAsFixed(1)} km/h',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // 倾角信息
          Row(
            children: [
              Expanded(
                child: _DetailRow(
                  label: '左倾最大角度',
                  value: '${record.maxLeanLeft}°',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _DetailRow(
                  label: '右倾最大角度',
                  value: '${record.maxLeanRight}°',
                ),
              ),
            ],
          ),

          // 事件统计
          if (record.eventCounts.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(color: AppTheme.primary20),
            const SizedBox(height: 8),
            Text(
              '事件统计',
              style: AppTheme.labelSmall.copyWith(
                color: AppTheme.primary,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: record.eventCounts.entries.map((entry) {
                return _EventCountBadge(
                  type: entry.key,
                  count: entry.value,
                );
              }).toList(),
            ),
          ],

          // 轨迹预览
          if (record.trackPoints.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(color: AppTheme.primary20),
            const SizedBox(height: 8),
            Text(
              '轨迹预览',
              style: AppTheme.labelSmall.copyWith(
                color: AppTheme.primary,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              height: 120,
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.primary20),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: MiniTrackPreview(
                  trackPoints: record.trackPoints,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return '${h}h ${m}m ${s}s';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }
}

/// 详情行
class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.textMuted,
            fontSize: 11,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

/// 事件计数徽章
class _EventCountBadge extends StatelessWidget {
  final RidingEventType type;
  final int count;

  const _EventCountBadge({
    required this.type,
    required this.count,
  });

  String get _eventName {
    switch (type) {
      case RidingEventType.extremeLean:
        return '极限压弯';
      case RidingEventType.performanceBurst:
        return '性能爆发';
      case RidingEventType.efficientCruising:
        return '高效巡航';
      case RidingEventType.engineOverheating:
        return '引擎过热';
      case RidingEventType.voltageAnomaly:
        return '电压异常';
      case RidingEventType.longRiding:
        return '长途骑行';
      case RidingEventType.highEngineLoad:
        return '高负荷';
      case RidingEventType.engineWarmup:
        return '引擎预热';
      case RidingEventType.coldEnvironmentRisk:
        return '低温风险';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.accentOrange20,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '$_eventName x$count',
        style: const TextStyle(
          color: AppTheme.accentOrange,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
