import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/bluetooth_provider.dart';
import '../services/location_service.dart';
import '../theme/app_theme.dart';

/// 蓝牙状态图标组件 - 根据蓝牙状态显示不同图标
class BluetoothStatusIcon extends StatefulWidget {
  final double size;
  final VoidCallback? onTap;

  const BluetoothStatusIcon({
    super.key,
    this.size = 12,
    this.onTap,
  });

  @override
  State<BluetoothStatusIcon> createState() => _BluetoothStatusIconState();
}

class _BluetoothStatusIconState extends State<BluetoothStatusIcon>
    with WidgetsBindingObserver {
  /// 定位权限及服务状态：true=已授权且服务开启，false=其他
  bool _locationGranted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshLocationStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// 监听 APP 生命周期变化
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // 当 APP 从后台恢复到前台时，刷新定位状态
    if (state == AppLifecycleState.resumed) {
      _refreshLocationStatus();
    }
  }

  Future<void> _refreshLocationStatus() async {
    final serviceEnabled = await LocationService.isLocationServiceEnabled();
    final permissionGranted = await LocationService.checkPermission();
    if (mounted) {
      setState(() {
        _locationGranted = serviceEnabled && permissionGranted;
      });
    }
  }

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

        // 定位图标颜色：已授权且服务开启=绿色，否则=橙色警告
        final locationIconColor =
            _locationGranted ? AppTheme.accentGreen : AppTheme.accentOrange;
        final locationIcon =
            _locationGranted ? Icons.location_on : Icons.location_off;

        return GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              border: Border.all(
                color: AppTheme.primary10,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  bluetoothIcon,
                  color: bluetoothIconColor,
                  size: widget.size,
                ),
                const SizedBox(width: 6),
                Icon(
                  signalIcon,
                  color: signalIconColor,
                  size: widget.size,
                ),
                const SizedBox(width: 6),
                Icon(
                  locationIcon,
                  color: locationIconColor,
                  size: widget.size,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
