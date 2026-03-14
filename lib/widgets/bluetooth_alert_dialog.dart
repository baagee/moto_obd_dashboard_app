import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import 'cyber_button.dart';

/// 赛博朋克风格蓝牙提示弹窗
class BluetoothAlertDialog extends StatelessWidget {
  final String title;
  final String message;
  final String buttonText;
  final VoidCallback? onButtonPressed;

  const BluetoothAlertDialog({
    super.key,
    required this.title,
    required this.message,
    required this.buttonText,
    this.onButtonPressed,
  });

  /// 显示蓝牙未开启弹窗
  static Future<void> showBluetoothOffDialog(
    BuildContext context, {
    required VoidCallback onOpenSettings,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => BluetoothAlertDialog(
        title: '蓝牙未开启',
        message: '为了连接 OBD 设备，请开启蓝牙功能',
        buttonText: '打开设置',
        onButtonPressed: onOpenSettings,
      ),
    );
  }

  /// 显示权限被拒绝弹窗
  static Future<void> showPermissionDeniedDialog(
    BuildContext context, {
    required VoidCallback onOpenSettings,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => BluetoothAlertDialog(
        title: '权限不足',
        message: '需要蓝牙和位置权限才能扫描 OBD 设备',
        buttonText: '去设置',
        onButtonPressed: onOpenSettings,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final colors = themeProvider.currentColors;

        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: 280,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: colors.primary.withValues(alpha: 0.5),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: colors.primary.withValues(alpha: 0.2),
                  blurRadius: 20,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 标题
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colors.accentOrange.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.bluetooth_disabled,
                        color: colors.accentOrange,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 消息
                Text(
                  message,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 24),

                // 按钮
                CyberButton.danger(
                  text: buttonText,
                  width: double.infinity,
                  onPressed: () {
                    Navigator.of(context).pop();
                    onButtonPressed?.call();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
