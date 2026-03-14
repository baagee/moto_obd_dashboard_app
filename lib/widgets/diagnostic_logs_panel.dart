import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/obd_data.dart';
import '../models/theme_colors.dart';
import '../providers/log_provider.dart';
import '../providers/theme_provider.dart';

/// 诊断日志面板
class DiagnosticLogsPanel extends StatelessWidget {
  const DiagnosticLogsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final colors = themeProvider.currentColors;

        return Consumer<LogProvider>(
          builder: (context, provider, child) {
            return Container(
              decoration: BoxDecoration(
                color: colors.surface,
                border: Border.all(
                  color: colors.primary.withValues(alpha: 0.2),
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  // 头部
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: 0.05),
                      border: Border(
                        bottom: BorderSide(
                          color: colors.primary.withValues(alpha: 0.1),
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'DIAGNOSTIC LOGS',
                          style: TextStyle(
                            color: colors.primary.withValues(alpha: 0.6),
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                        ),
                        TextButton(
                          onPressed: () {},
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: Size.zero,
                          ),
                          child: Text(
                            'EXPORT',
                            style: TextStyle(
                              color: colors.primary,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 日志列表
                  Expanded(
                    child: Container(
                      color: colors.backgroundDark.withValues(alpha: 0.3),
                      child: ListView.separated(
                        padding: const EdgeInsets.all(8),
                        itemCount: provider.logs.length > 5 ? 5 : provider.logs.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 4),
                        itemBuilder: (context, index) {
                          return _LogItem(log: provider.logs[index], colors: colors);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _LogItem extends StatelessWidget {
  final DiagnosticLog log;
  final ThemeColors colors;

  const _LogItem({required this.log, required this.colors});

  Color get _color {
    switch (log.type) {
      case LogType.success:
        return colors.accentGreen;
      case LogType.warning:
        return colors.accentOrange;
      case LogType.error:
        return colors.accentRed;
      case LogType.info:
        return colors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWarning = log.type == LogType.warning || log.type == LogType.error;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 时间
          SizedBox(
            width: 70,
            child: Text(
              log.formattedTime,
              style: TextStyle(
                color: colors.textMuted,
                fontSize: 10,
                fontFamily: 'monospace',
              ),
            ),
          ),

          // 状态点
          Container(
            margin: const EdgeInsets.only(top: 4),
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: _color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _color,
                  blurRadius: 4,
                  spreadRadius: -1,
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // 消息
          Expanded(
            child: Text(
              log.message,
              style: TextStyle(
                color: isWarning ? _color : colors.textSecondary,
                fontSize: 10,
                fontWeight: log.type == LogType.error ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
