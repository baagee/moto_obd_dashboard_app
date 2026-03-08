import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'cyber_button.dart';

/// 赛博朋克风格通用弹窗组件
class CyberDialog extends StatelessWidget {
  /// 弹窗标题
  final String title;

  /// 标题图标
  final IconData? icon;

  /// 边框和发光的主色调（默认使用 primary）
  final Color accentColor;

  /// 弹窗内容
  final Widget content;

  /// 自定义按钮组（可选，默认提供关闭按钮）
  final List<Widget>? actions;

  /// 弹窗宽度（默认 320px）
  final double width;

  const CyberDialog({
    super.key,
    required this.title,
    this.icon,
    this.accentColor = AppTheme.primary,
    required this.content,
    this.actions,
    this.width = 320,
  });

  /// 显示弹窗的便捷方法
  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    IconData? icon,
    Color accentColor = AppTheme.primary,
    required Widget content,
    List<Widget>? actions,
    double width = 320,
    bool barrierDismissible = true,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (context) => CyberDialog(
        title: title,
        icon: icon,
        accentColor: accentColor,
        content: content,
        actions: actions,
        width: width,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: width,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: accentColor.withOpacity(0.5),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: accentColor.withOpacity(0.2),
              blurRadius: 20,
              spreadRadius: 0,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题行
            Row(
              children: [
                if (icon != null) ...[
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      icon,
                      color: accentColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: accentColor,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 内容区域
            content,

            // 按钮区域
            if (actions != null && actions!.isNotEmpty) ...[
              const SizedBox(height: 20),
              _buildActions(context),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    if (actions != null && actions!.isNotEmpty) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: actions!,
      );
    }

    // 默认关闭按钮
    return Align(
      alignment: Alignment.centerRight,
      child: CyberButton.secondary(
        text: '关闭',
        onPressed: () => Navigator.of(context).pop(),
        height: 32,
        fontSize: 12,
      ),
    );
  }
}
