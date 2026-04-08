import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'cyber_button.dart';

/// 赛博朋克风格定位权限提示弹窗（样式与 BluetoothAlertDialog 保持一致）
class LocationAlertDialog extends StatelessWidget {
  final String title;
  final String message;
  final String primaryButtonText;
  final VoidCallback? onPrimaryPressed;

  /// 可选的"忽略"按钮，不传则只显示主按钮
  final String? dismissButtonText;

  const LocationAlertDialog({
    super.key,
    required this.title,
    required this.message,
    required this.primaryButtonText,
    this.onPrimaryPressed,
    this.dismissButtonText,
  });

  /// 系统定位服务未开启弹窗
  static Future<void> showServiceDisabledDialog(
    BuildContext context, {
    required VoidCallback onOpenSettings,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => LocationAlertDialog(
        title: '定位服务未开启',
        message: '骑行记录需要 GPS 定位来记录起终点和轨迹，请在系统设置中开启定位服务',
        primaryButtonText: '打开设置',
        onPrimaryPressed: onOpenSettings,
        dismissButtonText: '暂不开启',
      ),
    );
  }

  /// 定位权限被永久拒绝弹窗（需引导去设置页手动授权）
  static Future<void> showPermissionDeniedForeverDialog(
    BuildContext context, {
    required VoidCallback onOpenSettings,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => LocationAlertDialog(
        title: '定位权限不足',
        message: '骑行记录需要定位权限，请在系统设置中手动授予"使用期间允许"或"始终允许"',
        primaryButtonText: '去设置',
        onPrimaryPressed: onOpenSettings,
        dismissButtonText: '暂不授权',
      ),
    );
  }

  /// 定位权限被拒绝弹窗（用户点了拒绝，仅提示说明）
  static Future<void> showPermissionDeniedDialog(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => LocationAlertDialog(
        title: '定位权限未授予',
        message: '骑行记录依赖定位权限记录起终点和轨迹。如需此功能，可在系统设置中手动开启',
        primaryButtonText: '知道了',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 280,
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: AppTheme.surface,
          border: Border.all(
            color: AppTheme.accentCyan.withValues(alpha: 0.5),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.accentCyan.withValues(alpha: 0.2),
              blurRadius: 20,
              spreadRadius: 0,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 顶部青色高亮横条 ──
            Container(height: 3, color: AppTheme.accentCyan),
            // ── 标题行 ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.accentCyan.withValues(alpha: 0.15),
                    ),
                    child: const Icon(
                      Icons.location_on_outlined,
                      color: AppTheme.accentCyan,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: AppTheme.accentCyan,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // ── 分隔线 ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Divider(
                height: 1,
                thickness: 1,
                color: AppTheme.accentCyan.withValues(alpha: 0.3),
              ),
            ),
            // ── 消息 ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Text(
                message,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                ),
              ),
            ),
            // ── 按钮 ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              child: dismissButtonText != null
                  ? Row(
                      children: [
                        Expanded(
                          child: CyberButton.secondary(
                            text: dismissButtonText!,
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: CyberButton.primary(
                            text: primaryButtonText,
                            onPressed: () {
                              Navigator.of(context).pop();
                              onPrimaryPressed?.call();
                            },
                          ),
                        ),
                      ],
                    )
                  : CyberButton.primary(
                      text: primaryButtonText,
                      width: double.infinity,
                      onPressed: () {
                        Navigator.of(context).pop();
                        onPrimaryPressed?.call();
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
