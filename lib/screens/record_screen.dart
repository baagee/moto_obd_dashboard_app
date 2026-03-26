import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/riding_record_provider.dart';
import '../models/riding_record.dart';
import '../theme/app_theme.dart';
import '../widgets/stats_summary_card.dart';
import '../widgets/swipeable_record_card.dart';
import '../widgets/ride_event_list_modal.dart';
import '../widgets/delete_confirm_dialog.dart';

/// 骑行记录页面
class RecordScreen extends StatefulWidget {
  const RecordScreen({super.key});

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> {
  int _selectedTabIndex = 0;  // 0=今天, 1=近7天, 2=近30天

  @override
  void initState() {
    super.initState();
    // 初始化加载数据
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RidingRecordProvider>().initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.backgroundDark,
      child: SafeArea(
        child: Column(
          children: [
            // Tab 切换
            _buildTabBar(),
            // 聚合统计
            _buildStatsSummary(),
            // 骑行历史列表
            Expanded(child: _buildRecordsList()),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _buildTabButton('今天', 0),
          const SizedBox(width: 8),
          _buildTabButton('近一周', 1),
          const SizedBox(width: 8),
          _buildTabButton('近一月', 2),
        ],
      ),
    );
  }

  Widget _buildTabButton(String label, int index) {
    final isSelected = _selectedTabIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTabIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : AppTheme.slateGray,
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.primary20,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : AppTheme.textSecondary,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildStatsSummary() {
    return Consumer<RidingRecordProvider>(
      builder: (context, provider, _) {
        AggregationStats stats;
        switch (_selectedTabIndex) {
          case 1:
            stats = provider.weekStats;
            break;
          case 2:
            stats = provider.monthStats;
            break;
          default:
            stats = provider.todayStats;
        }
        return StatsSummaryCard(stats: stats);
      },
    );
  }

  Widget _buildRecordsList() {
    return Consumer<RidingRecordProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.primary),
          );
        }

        if (provider.records.isEmpty) {
          return Center(
            child: Text(
              '暂无骑行记录',
              style: AppTheme.labelMedium.copyWith(
                color: AppTheme.textMuted,
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: provider.records.length,
          itemBuilder: (context, index) {
            final record = provider.records[index];
            return SwipeableRecordCard(
              record: record,
              onViewEvents: () => _showEventsModal(record),
              onDelete: () => _confirmDelete(record),
            );
          },
        );
      },
    );
  }

  void _showEventsModal(RidingRecord record) async {
    final provider = context.read<RidingRecordProvider>();
    final events = await provider.getEventsForRecord(record.id!);
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => RideEventListModal(events: events),
    );
  }

  void _confirmDelete(RidingRecord record) {
    showDialog(
      context: context,
      builder: (context) => DeleteConfirmDialog(
        onConfirm: () {
          context.read<RidingRecordProvider>().deleteRecord(record.id!);
        },
      ),
    );
  }
}
