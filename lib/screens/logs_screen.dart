import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/obd_data_provider.dart';
import '../theme/app_theme.dart';
import '../models/obd_data.dart';

/// 日志页面
class LogsScreen extends StatelessWidget {
  const LogsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0A1114),
      ),
      child: Column(
        children: [
          // 顶部区域
          Container(
            padding: const EdgeInsets.all(16),
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                      const SizedBox(height: 4),
                      Consumer<OBDDataProvider>(
                        builder: (context, provider, child) {
                          return Text(
                            'Total: ${provider.logs.length} entries',
                            style: const TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 9,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                // 筛选按钮
                _FilterButton(),
                const SizedBox(width: 8),

                // 导出按钮
                Container(
                  height: 28,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: AppTheme.glowShadow(AppTheme.primary),
                  ),
                  child: const Center(
                    child: Row(
                      children: [
                        Icon(Icons.download, color: Colors.white, size: 14),
                        SizedBox(width: 6),
                        Text(
                          'EXPORT',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
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
          ),

          // 日志列表
          Expanded(
            child: Consumer<OBDDataProvider>(
              builder: (context, provider, child) {
                return Container(
                  margin: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.surface.withOpacity(0.3),
                    border: Border.all(
                      color: AppTheme.primary.withOpacity(0.1),
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(8),
                    itemCount: provider.logs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 4),
                    itemBuilder: (context, index) {
                      return _LogItem(log: provider.logs[index]);
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

class _FilterButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: AppTheme.primary.withOpacity(0.2),
        ),
      ),
      child: const Center(
        child: Row(
          children: [
            Icon(Icons.filter_list, color: AppTheme.primary, size: 14),
            SizedBox(width: 6),
            Text(
              'FILTER',
              style: TextStyle(
                color: AppTheme.primary,
                fontSize: 9,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(color: _color, width: 3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 图标
          Container(
            margin: const EdgeInsets.only(right: 12),
            child: Icon(
              _icon,
              color: _color,
              size: 18,
            ),
          ),

          // 时间
          SizedBox(
            width: 70,
            child: Text(
              log.formattedTime,
              style: const TextStyle(
                color: AppTheme.textMuted,
                fontSize: 10,
                fontFamily: 'monospace',
              ),
            ),
          ),

          const SizedBox(width: 8),

          // 消息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  log.type.name.toUpperCase(),
                  style: TextStyle(
                    color: _color,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  log.message,
                  style: TextStyle(
                    color: isWarning ? _color : AppTheme.textSecondary,
                    fontSize: 11,
                    fontWeight: log.type == LogType.error ? FontWeight.bold : FontWeight.normal,
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