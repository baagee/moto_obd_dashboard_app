import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/bluetooth_device.dart';
import '../providers/bluetooth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/bluetooth_device_list.dart';
import '../widgets/connected_device_card.dart';

/// 蓝牙设备扫描页面 - 嵌入模式
class BluetoothScanScreen extends StatefulWidget {
  const BluetoothScanScreen({super.key});

  @override
  State<BluetoothScanScreen> createState() => _BluetoothScanScreenState();
}

class _BluetoothScanScreenState extends State<BluetoothScanScreen> {
  @override
  void initState() {
    super.initState();
    // 页面加载后自动开始扫描
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BluetoothProvider>().startScan();
    });
  }

  void _handleConnect(BluetoothDeviceModel device) {
    context.read<BluetoothProvider>().connectToDevice(device);
  }

  void _handleDisconnect() {
    context.read<BluetoothProvider>().disconnectDevice();
  }

  void _handleRescan() {
    context.read<BluetoothProvider>().startScan();
  }

  void _handleClearLastDevice() {
    context.read<BluetoothProvider>().clearLastDevice();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.backgroundDark,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 左侧 - 设备扫描列表 (7列比例)
            Expanded(
              flex: 7,
              child: _buildDeviceListSection(),
            ),

            const SizedBox(width: 8),

            // 右侧 - 已连接设备详情 (5列比例)
            Expanded(
              flex: 5,
              child: _buildConnectedDeviceSection(),
            ),
          ],
        ),
      ),
    );
  }

  /// 设备列表区域
  Widget _buildDeviceListSection() {
    return Consumer<BluetoothProvider>(
      builder: (context, provider, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题和状态标签
            Row(
              children: [
                const Text(
                  'Device Scanner',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: 8),
                if (provider.isScanning)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.primary20,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 4,
                          height: 4,
                          decoration: const BoxDecoration(
                            color: AppTheme.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'SCANNING',
                          style: AppTheme.labelTiny.copyWith(
                            color: AppTheme.primary,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                const Spacer(),
                // 重新扫描按钮
                GestureDetector(
                  onTap: provider.isScanning ? null : _handleRescan,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      provider.isScanning ? Icons.sync : Icons.refresh,
                      color: provider.isScanning
                          ? AppTheme.textMuted
                          : AppTheme.primary,
                      size: 28,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Detecting nearby Bluetooth OBD-II adapters',
              style: TextStyle(
                fontSize: 10,
                color: AppTheme.textSecondary,
                height: 1.4,
              ),
            ),

            const SizedBox(height: 8),

            // 设备列表
            Expanded(
              child: BluetoothDeviceList(
                isScanning: provider.isScanning,
                devices: provider.scannedDevices,
                onConnect: _handleConnect,
              ),
            ),
          ],
        );
      },
    );
  }

  /// 已连接设备区域
  Widget _buildConnectedDeviceSection() {
    return Consumer<BluetoothProvider>(
      builder: (context, provider, _) {
        return ConnectedDeviceCard(
          connectedDevice: provider.connectedDevice,
          lastConnectedDevice: provider.lastConnectedDevice,
          onDisconnect: _handleDisconnect,
          onClear: _handleClearLastDevice,
        );
      },
    );
  }
}
