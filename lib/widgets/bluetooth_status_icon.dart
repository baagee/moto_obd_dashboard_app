import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/bluetooth_provider.dart';
import '../theme/app_theme.dart';

/// 蓝牙状态图标组件 - 根据蓝牙状态显示不同图标
class BluetoothStatusIcon extends StatelessWidget {
  final double size;
  final VoidCallback? onTap;

  const BluetoothStatusIcon({
    super.key,
    this.size = 12,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<BluetoothProvider>(
      builder: (context, bluetoothProvider, child) {
        final isOn = bluetoothProvider.isBluetoothOn;
        final hasPermission = bluetoothProvider.hasPermission;
        final isConnected = bluetoothProvider.isDeviceConnected;

        Color bluetoothIconColor;
        IconData bluetoothIcon;
        Color signalIconColor;
        IconData signalIcon;

        if (!hasPermission) {
          // 权限未授权 - 蓝牙图标显示警告，信号无连接
          bluetoothIconColor = AppTheme.accentOrange;
          bluetoothIcon = Icons.bluetooth_disabled;
          signalIconColor = AppTheme.textMuted;
          signalIcon = Icons.signal_cellular_off;
        } else if (isOn) {
          if (isConnected) {
            // 蓝牙开启且已连接设备
            bluetoothIconColor = AppTheme.accentGreen;
            bluetoothIcon = Icons.bluetooth_connected;
            // 已连接显示满格信号
            signalIconColor = AppTheme.accentGreen;
            signalIcon = Icons.signal_cellular_alt;
          } else {
            // 蓝牙开启但未连接设备
            bluetoothIconColor = AppTheme.primary;
            bluetoothIcon = Icons.bluetooth;
            // 未连接显示无信号
            signalIconColor = AppTheme.textMuted;
            signalIcon = Icons.signal_cellular_off;
          }
        } else {
          // 蓝牙关闭 - 显示关闭图标，信号无连接
          bluetoothIconColor = AppTheme.textMuted;
          bluetoothIcon = Icons.bluetooth_disabled;
          signalIconColor = AppTheme.textMuted;
          signalIcon = Icons.signal_cellular_off;
        }

        return GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(
                color: AppTheme.primary.withOpacity(0.1),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  bluetoothIcon,
                  color: bluetoothIconColor,
                  size: size,
                ),
                const SizedBox(width: 6),
                Icon(
                  signalIcon,
                  color: signalIconColor,
                  size: size,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
