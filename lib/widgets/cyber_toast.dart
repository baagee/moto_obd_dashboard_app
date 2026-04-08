import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Toast 类型
enum CyberToastType { success, warning, error }

/// 赛博朋克风格底部提示
///
/// 使用方式：
/// ```dart
/// CyberToast.show(context, '保存成功');
/// CyberToast.show(context, '连接失败', type: CyberToastType.error);
/// ```
class CyberToast {
  static void show(
    BuildContext context,
    String message, {
    CyberToastType type = CyberToastType.success,
    Duration duration = const Duration(seconds: 2),
  }) {
    final Color color;
    final IconData icon;
    switch (type) {
      case CyberToastType.success:
        color = AppTheme.accentGreen;
        icon = Icons.check_circle_outline;
      case CyberToastType.warning:
        color = AppTheme.accentOrange;
        icon = Icons.warning_amber_outlined;
      case CyberToastType.error:
        color = AppTheme.accentRed;
        icon = Icons.error_outline;
    }

    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          duration: duration,
          backgroundColor: AppTheme.surface,
          elevation: 4,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          shape: RoundedRectangleBorder(
            side: BorderSide(color: color.withValues(alpha: 0.4)),
          ),
          content: Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }
}
