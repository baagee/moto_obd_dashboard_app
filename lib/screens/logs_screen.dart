import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/log_provider.dart';
import '../theme/app_theme.dart';
import '../models/obd_data.dart';
import '../widgets/cyber_button.dart';
import '../widgets/cyber_dialog.dart';

/// 日志页面
class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  /// 显示清空日志确认对话框
  void _showClearConfirmDialog(BuildContext context, LogProvider provider) {
    CyberDialog.show(
      context: context,
      title: 'Clear Logs',
      icon: Icons.warning_amber_rounded,
      accentColor: AppTheme.accentOrange,
      content: const Text(
        'Are you sure you want to clear all logs? This action cannot be undone.',
        style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
      ),
      actions: [
        CyberButton.secondary(
          text: '取消',
          onPressed: () => Navigator.pop(context),
          height: 32,
          fontSize: 10,
        ),
        const SizedBox(width: 8),
        CyberButton.danger(
          text: '确认',
          onPressed: () {
            provider.clearLogs();
            Navigator.pop(context);
          },
          height: 32,
          fontSize: 10,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.backgroundDark,
      ),
      child: Column(
        children: [
          // 合并后的顶部区域
          Consumer<LogProvider>(
            builder: (context, provider, child) {
              return _CompactHeader(
                counts: provider.filterCounts,
                currentFilter: provider.currentFilter,
                onFilterChanged: (filter) => provider.setFilter(filter),
                onExport: () => provider.shareLogs(),
                onClear: () => _showClearConfirmDialog(context, provider),
              );
            },
          ),

          // 日志列表
          Expanded(
            child: Consumer<LogProvider>(
              builder: (context, provider, child) {
                final filteredLogs = provider.filteredLogs;

                if (filteredLogs.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inbox_outlined,
                          color: AppTheme.textMuted,
                          size: 48,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'No logs match the current filter',
                          style: TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return Container(
                  margin: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.surface.withOpacity(0.3),
                    border: Border.all(
                      color: AppTheme.primary.withOpacity(0.1),
                    ),
                    borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                  ),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(8),
                    itemCount: filteredLogs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 4),
                    itemBuilder: (context, index) {
                      return _LogItem(log: filteredLogs[index]);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// 合并后的紧凑顶部区域
class _CompactHeader extends StatelessWidget {
  final Map<LogFilterType, int> counts;
  final LogFilterType currentFilter;
  final ValueChanged<LogFilterType> onFilterChanged;
  final VoidCallback onExport;
  final VoidCallback onClear;

  const _CompactHeader({
    required this.counts,
    required this.currentFilter,
    required this.onFilterChanged,
    required this.onExport,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
          // 左侧：标题
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'DIAGNOSTIC LOGS',
                style: TextStyle(
                  color: AppTheme.primary.withOpacity(0.6),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Total: ${counts[LogFilterType.all]} entries',
                style: const TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 9,
                ),
              ),
            ],
          ),

          const SizedBox(width: 16),

          // 中间：筛选标签
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _CompactFilterChip(
                    filterType: LogFilterType.all,
                    count: counts[LogFilterType.all] ?? 0,
                    isActive: currentFilter == LogFilterType.all,
                    onTap: () => onFilterChanged(LogFilterType.all),
                  ),
                  const SizedBox(width: 8),
                  _CompactFilterChip(
                    filterType: LogFilterType.success,
                    count: counts[LogFilterType.success] ?? 0,
                    isActive: currentFilter == LogFilterType.success,
                    onTap: () => onFilterChanged(LogFilterType.success),
                  ),
                  const SizedBox(width: 8),
                  _CompactFilterChip(
                    filterType: LogFilterType.warning,
                    count: counts[LogFilterType.warning] ?? 0,
                    isActive: currentFilter == LogFilterType.warning,
                    onTap: () => onFilterChanged(LogFilterType.warning),
                  ),
                  const SizedBox(width: 8),
                  _CompactFilterChip(
                    filterType: LogFilterType.error,
                    count: counts[LogFilterType.error] ?? 0,
                    isActive: currentFilter == LogFilterType.error,
                    onTap: () => onFilterChanged(LogFilterType.error),
                  ),
                  const SizedBox(width: 8),
                  _CompactFilterChip(
                    filterType: LogFilterType.info,
                    count: counts[LogFilterType.info] ?? 0,
                    isActive: currentFilter == LogFilterType.info,
                    onTap: () => onFilterChanged(LogFilterType.info),
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
              // 清空按钮
              GestureDetector(
                onTap: onClear,
                child: Container(
                  height: 24,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(AppTheme.radiusButton),
                    border: Border.all(
                      color: AppTheme.accentRed.withOpacity(0.5),
                    ),
                  ),
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.delete_outline,
                            color: AppTheme.accentRed.withOpacity(0.7),
                            size: 12),
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
              ),
              // 导出按钮
              GestureDetector(
                onTap: onExport,
                child: Container(
                  height: 24,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(AppTheme.radiusButton),
                    boxShadow: AppTheme.glowShadow(AppTheme.primary),
                  ),
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.download, color: Colors.white, size: 12),
                        SizedBox(width: 4),
                        Text(
                          '导出分享',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
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

/// 紧凑型筛选标签
class _CompactFilterChip extends StatelessWidget {
  final LogFilterType filterType;
  final int count;
  final bool isActive;
  final VoidCallback onTap;

  const _CompactFilterChip({
    required this.filterType,
    required this.count,
    required this.isActive,
    required this.onTap,
  });

  Color get _color {
    switch (filterType) {
      case LogFilterType.all:
        return AppTheme.textPrimary;
      case LogFilterType.success:
        return AppTheme.accentGreen;
      case LogFilterType.warning:
        return AppTheme.accentOrange;
      case LogFilterType.error:
        return AppTheme.accentRed;
      case LogFilterType.info:
        return AppTheme.primary;
    }
  }

  IconData get _icon {
    switch (filterType) {
      case LogFilterType.all:
        return Icons.list_alt;
      case LogFilterType.success:
        return Icons.check_circle;
      case LogFilterType.warning:
        return Icons.warning;
      case LogFilterType.error:
        return Icons.error;
      case LogFilterType.info:
        return Icons.info;
    }
  }

  String get _label {
    switch (filterType) {
      case LogFilterType.all:
        return 'ALL';
      case LogFilterType.success:
        return 'SUCCESS';
      case LogFilterType.warning:
        return 'WARNING';
      case LogFilterType.error:
        return 'ERROR';
      case LogFilterType.info:
        return 'INFO';
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      splashColor: _color.withOpacity(0.2),
      highlightColor: _color.withOpacity(0.1),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isActive ? _color.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          border: Border.all(
            color: isActive ? _color : AppTheme.textMuted.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _icon,
              color: isActive ? _color : AppTheme.textMuted,
              size: 12,
            ),
            const SizedBox(width: 4),
            Text(
              '$count',
              style: TextStyle(
                color: isActive ? _color : AppTheme.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 3),
            Text(
              _label,
              style: TextStyle(
                color: isActive ? _color : AppTheme.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LogItem extends StatelessWidget {
  final DiagnosticLog log;

  const _LogItem({required this.log});

  Color get _color {
    switch (log.type) {
      case LogType.success:
        return AppTheme.accentGreen;
      case LogType.warning:
        return AppTheme.accentOrange;
      case LogType.error:
        return AppTheme.accentRed;
      case LogType.info:
        return AppTheme.primary;
    }
  }

  IconData get _icon {
    switch (log.type) {
      case LogType.success:
        return Icons.check_circle;
      case LogType.warning:
        return Icons.warning;
      case LogType.error:
        return Icons.error;
      case LogType.info:
        return Icons.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWarning = log.type == LogType.warning || log.type == LogType.error;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        border: Border(
          left: BorderSide(color: _color, width: 3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 图标
          Container(
            margin: const EdgeInsets.only(right: 10),
            child: Icon(
              _icon,
              color: _color,
              size: 16,
            ),
          ),

          // 时间
          SizedBox(
            width: 60,
            child: Text(
              log.formattedTime,
              style: const TextStyle(
                color: AppTheme.textMuted,
                fontSize: 10,
                fontFamily: 'monospace',
              ),
            ),
          ),

          const SizedBox(width: 6),

          // 消息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  log.type.name.toUpperCase(),
                  style: TextStyle(
                    color: _color,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  log.message,
                  style: TextStyle(
                    color: isWarning ? _color : AppTheme.textSecondary,
                    fontSize: 10,
                    fontWeight: log.type == LogType.error
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
