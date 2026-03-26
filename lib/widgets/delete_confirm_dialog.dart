import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// 删除确认弹窗
class DeleteConfirmDialog extends StatelessWidget {
  final VoidCallback onConfirm;

  const DeleteConfirmDialog({super.key, required this.onConfirm});

  static Future<void> show(BuildContext context, {required VoidCallback onConfirm}) {
    return showDialog(
      context: context,
      builder: (ctx) => DeleteConfirmDialog(onConfirm: onConfirm),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          border: Border.all(color: AppTheme.accentRed.withOpacity(0.5)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '确认删除',
              style: AppTheme.titleMedium.copyWith(color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 12),
            Text(
              '确定要删除这条骑行记录吗？\n删除后无法恢复。',
              textAlign: TextAlign.center,
              style: AppTheme.labelMedium.copyWith(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.slateGray,
                        borderRadius: BorderRadius.circular(AppTheme.radiusButton),
                      ),
                      child: Center(
                        child: Text(
                          '取消',
                          style: AppTheme.labelMedium.copyWith(color: AppTheme.textSecondary),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.of(context).pop();
                      onConfirm();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.accentRed,
                        borderRadius: BorderRadius.circular(AppTheme.radiusButton),
                      ),
                      child: Center(
                        child: Text(
                          '删除',
                          style: AppTheme.labelMedium.copyWith(color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
