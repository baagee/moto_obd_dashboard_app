import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/riding_record_provider.dart';
import '../models/riding_record.dart';
import '../theme/app_theme.dart';
import '../widgets/swipeable_record_card.dart';
import '../widgets/ride_event_list_modal.dart';
import '../widgets/cyber_dialog.dart';
import '../widgets/cyber_button.dart';
import '../services/database_service.dart';

/// 骑行记录页面
class RecordScreen extends StatefulWidget {
  const RecordScreen({super.key});

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> {
  int _selectedFilterIndex = 0; // 0=今天, 1=近7天, 2=近30天

  List<RidingRecord> _getFilteredRecords(RidingRecordProvider provider) {
    switch (_selectedFilterIndex) {
      case 1:
        return provider.weekRecords;
      case 2:
        return provider.monthRecords;
      default:
        return provider.todayRecords;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RidingRecordProvider>().initialize(force: true);
    });
  }

  AggregationStats _getCurrentStats(RidingRecordProvider provider) {
    switch (_selectedFilterIndex) {
      case 1:
        return provider.weekStats;
      case 2:
        return provider.monthStats;
      default:
        return provider.todayStats;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.backgroundDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 紧凑头部
          Consumer<RidingRecordProvider>(
            builder: (context, provider, child) {
              return _RecordCompactHeader(
                currentFilterIndex: _selectedFilterIndex,
                onFilterChanged: (index) =>
                    setState(() => _selectedFilterIndex = index),
                totalCount: _getFilteredRecords(provider).length,
                onClearAll: _confirmClearAll,
                onInsertMock: _insertMockData,
                todayCount: provider.todayStats.rideCount,
                weekCount: provider.weekStats.rideCount,
                monthCount: provider.monthStats.rideCount,
              );
            },
          ),
          // 内容区：左侧统计面板（20%）+ 右侧记录列表（80%）
          Expanded(
            child: Consumer<RidingRecordProvider>(
              builder: (context, provider, child) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 左侧约17%：5项聚合统计，固定不滚动
                    Expanded(
                      flex: 1,
                      child: _StatsPanel(stats: _getCurrentStats(provider)),
                    ),
                    // 右侧约83%：骑行记录列表，独立滚动
                    Expanded(
                      flex: 5,
                      child: _buildRecordsList(),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
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

        final records = _getFilteredRecords(provider);

        if (records.isEmpty) {
          return const _EmptyState();
        }

        return Container(
          margin: const EdgeInsets.fromLTRB(12, 4, 12, 12),
          clipBehavior: Clip.hardEdge,
          decoration: BoxDecoration(
            color: AppTheme.surface40,
            border: Border.all(color: AppTheme.primary10),
            borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          ),
          child: ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: records.length,
            itemBuilder: (context, index) {
              final record = records[index];
              return SwipeableRecordCard(
                record: record,
                onViewEvents: () => _showEventsModal(record),
                onDelete: () => context
                    .read<RidingRecordProvider>()
                    .deleteRecord(record.id!),
              );
            },
          ),
        );
      },
    );
  }

  void _showEventsModal(RidingRecord record) async {
    final provider = context.read<RidingRecordProvider>();
    final events = await provider.getEventsForRecord(record.id!);
    if (!mounted) return;
    RideEventListModal.show(context, events);
  }

  void _confirmClearAll() {
    CyberDialog.show(
      context: context,
      title: '清空所有骑行记录',
      icon: Icons.delete_sweep_outlined,
      accentColor: AppTheme.accentRed,
      content: Text(
        '此操作将永久删除全部骑行记录及统计数据，\n无法恢复，确定继续？',
        textAlign: TextAlign.center,
        style: AppTheme.labelMedium.copyWith(color: AppTheme.textSecondary),
      ),
      actions: [
        CyberButton.secondary(
          text: '取消',
          onPressed: () => Navigator.of(context).pop(),
          height: 32,
          fontSize: 12,
        ),
        const SizedBox(width: 10),
        CyberButton.danger(
          text: '确认清空',
          onPressed: () {
            Navigator.of(context).pop();
            context.read<RidingRecordProvider>().clearAllRecords();
          },
          height: 32,
          fontSize: 12,
        ),
      ],
    );
  }

  void _insertMockData() async {
    await DatabaseService.insertMockRidingRecords();
    if (!mounted) return;
    await context.read<RidingRecordProvider>().initialize(force: true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('✅ 已插入 5 条测试数据'),
        backgroundColor: AppTheme.accentGreen,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// 头部组件
// ─────────────────────────────────────────────

class _RecordCompactHeader extends StatelessWidget {
  final int currentFilterIndex;
  final ValueChanged<int> onFilterChanged;
  final int totalCount;
  final VoidCallback onClearAll;
  final VoidCallback onInsertMock;
  final int todayCount;
  final int weekCount;
  final int monthCount;

  const _RecordCompactHeader({
    required this.currentFilterIndex,
    required this.onFilterChanged,
    required this.totalCount,
    required this.onClearAll,
    required this.onInsertMock,
    required this.todayCount,
    required this.weekCount,
    required this.monthCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surface50,
        border: Border(
          bottom: BorderSide(color: AppTheme.primary20),
        ),
      ),
      child: Row(
        children: [
          // 左侧：标题
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'RIDING RECORDS',
                style: TextStyle(
                  color: AppTheme.primary60,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Total: $totalCount records',
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 9),
              ),
            ],
          ),

          const SizedBox(width: 16),

          // 中间：时间筛选 chips
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _TimeFilterChip(
                    label: '今天',
                    count: todayCount,
                    isActive: currentFilterIndex == 0,
                    onTap: () => onFilterChanged(0),
                  ),
                  const SizedBox(width: 8),
                  _TimeFilterChip(
                    label: '近一周',
                    count: weekCount,
                    isActive: currentFilterIndex == 1,
                    onTap: () => onFilterChanged(1),
                  ),
                  const SizedBox(width: 8),
                  _TimeFilterChip(
                    label: '近一月',
                    count: monthCount,
                    isActive: currentFilterIndex == 2,
                    onTap: () => onFilterChanged(2),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 12),

          // 右侧：操作按钮组
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 插入测试数据按钮（仅 debug 包可见）
              if (kDebugMode)
                ...([
                  GestureDetector(
                    onTap: onInsertMock,
                    child: Container(
                      height: 24,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusButton),
                        border: Border.all(color: AppTheme.accentGreen50),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_circle_outline,
                              color: AppTheme.accentGreen.withOpacity(0.7),
                              size: 12),
                          const SizedBox(width: 4),
                          Text(
                            '测试数据',
                            style: TextStyle(
                              color: AppTheme.accentGreen.withOpacity(0.7),
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ]),
              // 清空按钮
              GestureDetector(
                onTap: onClearAll,
                child: Container(
                  height: 24,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppTheme.radiusButton),
                    border: Border.all(color: AppTheme.accentRed50),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.delete_outline,
                          color: AppTheme.accentRed.withOpacity(0.7), size: 12),
                      const SizedBox(width: 4),
                      Text(
                        '清空',
                        style: TextStyle(
                          color: AppTheme.accentRed.withOpacity(0.7),
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// 空状态 - 科技感占位图
// ─────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 发光图标容器
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.surface,
              border: Border.all(color: AppTheme.primary30, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary15,
                  blurRadius: 20,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 外圈装饰弧
                Positioned.fill(
                  child: CircularProgressIndicator(
                    value: 0.75,
                    strokeWidth: 1,
                    color: AppTheme.primary20,
                    backgroundColor: Colors.transparent,
                  ),
                ),
                const Icon(
                  Icons.two_wheeler_outlined,
                  color: AppTheme.primary,
                  size: 32,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // 主标题
          Text(
            'NO RIDING RECORDS',
            style: TextStyle(
              color: AppTheme.primary70,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 6),
          // 副标题
          Text(
            '开始骑行后，记录将自动保存于此',
            style: TextStyle(
              color: AppTheme.textMuted.withOpacity(0.6),
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 20),
          // 分隔线装饰
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                  width: 30,
                  height: 1,
                  color: AppTheme.primary.withOpacity(0.2)),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  border: Border.all(
                      color: AppTheme.primary.withOpacity(0.2), width: 1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                ),
                child: Text(
                  'SIGNAL AWAITING',
                  style: TextStyle(
                    color: AppTheme.primary.withOpacity(0.35),
                    fontSize: 8,
                    letterSpacing: 2,
                  ),
                ),
              ),
              Container(
                  width: 30,
                  height: 1,
                  color: AppTheme.primary.withOpacity(0.2)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// 时间筛选芯片
// ─────────────────────────────────────────────

class _TimeFilterChip extends StatelessWidget {
  final String label;
  final int count;
  final bool isActive;
  final VoidCallback onTap;

  const _TimeFilterChip({
    required this.label,
    required this.count,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = AppTheme.primary;
    final mutedColor = AppTheme.textMuted;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      splashColor: activeColor.withOpacity(0.2),
      highlightColor: activeColor.withOpacity(0.1),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isActive ? activeColor.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          border: Border.all(
            color: isActive ? activeColor : mutedColor.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$count',
              style: TextStyle(
                color: isActive ? activeColor : mutedColor,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 3),
            Text(
              label,
              style: TextStyle(
                color: isActive ? activeColor : mutedColor,
                fontSize: 10,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// 统计面板（竖排，左侧20%区域）
// ─────────────────────────────────────────────

class _StatsPanel extends StatelessWidget {
  final AggregationStats stats;

  const _StatsPanel({required this.stats});

  String _getMaxLean() {
    final left = stats.maxLeftLean;
    final right = stats.maxRightLean;
    final maxLean = left > right ? left : right;
    final direction = left > right ? 'L' : 'R';
    return '${maxLean.toStringAsFixed(0)}°$direction';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 12),
      child: Column(
        children: [
          Expanded(
            child: _StatsCard(
              label: '距离',
              value: '${stats.distance.toStringAsFixed(1)} km',
              color: AppTheme.textPrimary,
              icon: Icons.route,
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: _StatsCard(
              label: '均速',
              value: '${stats.avgSpeed.toStringAsFixed(1)} km/h',
              color: AppTheme.accentCyan,
              icon: Icons.speed,
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: _StatsCard(
              label: '时长',
              value: stats.formattedDuration,
              color: AppTheme.accentGreen,
              icon: Icons.timer,
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: _StatsCard(
              label: '极速',
              value: '${stats.maxSpeed.toStringAsFixed(0)} km/h',
              color: AppTheme.accentOrange,
              icon: Icons.flash_on,
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: _StatsCard(
              label: '倾角',
              value: _getMaxLean(),
              color: AppTheme.accentPink,
              icon: Icons.rotate_right,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// 统计小卡片
// ─────────────────────────────────────────────

class _StatsCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _StatsCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
      decoration: BoxDecoration(
        color: AppTheme.surface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        border: Border.all(color: AppTheme.primary20),
      ),
      child: Stack(
        children: [
          // 背景图标（靠左居中，缩小到36）
          Positioned(
            left: -4,
            top: 0,
            bottom: 0,
            child: Icon(icon, size: 36, color: color.withOpacity(0.12)),
          ),
          // 前景文字：Positioned.fill 保证宽度有约束，不会溢出
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.only(left: 36),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                        color: AppTheme.textMuted, fontSize: 10),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    value,
                    style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
