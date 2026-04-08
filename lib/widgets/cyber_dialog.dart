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
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: AppTheme.surface,
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
            // ── 顶部彩色高亮横条 ──
            Container(height: 3, color: accentColor),
            // ── 标题行 ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  if (icon != null) ...[
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: accentColor.withOpacity(0.2),
                      ),
                      child: Icon(icon, color: accentColor, size: 24),
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
                color: accentColor.withOpacity(0.3),
              ),
            ),
            // ── 内容区域 ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.5,
                ),
                child: content,
              ),
            ),
            // ── 按钮区域（actions==null 时显示默认关闭按钮；[] 时隐藏）──
            if (actions == null || actions!.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                child: _buildActions(context),
              ),
            ] else
              const SizedBox(height: 16),
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

    if (actions != null && actions!.isEmpty) {
      return const SizedBox.shrink();
    }

    // 默认关闭按钮（actions == null 时）
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
