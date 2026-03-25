import 'package:flutter/material.dart';
import '../models/bluetooth_device.dart';
import '../theme/app_theme.dart';
import 'cyber_button.dart';

/// 蓝牙设备列表组件
class BluetoothDeviceList extends StatelessWidget {
  final bool isScanning;
  final List<BluetoothDeviceModel> devices;
  final Function(BluetoothDeviceModel) onConnect;

  const BluetoothDeviceList({
    super.key,
    required this.isScanning,
    required this.devices,
    required this.onConnect,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 扫描状态进度条
        _ScanProgressBar(isScanning: isScanning),

        const SizedBox(height: 16),

        // 设备列表或空状态
        Expanded(
          child: devices.isEmpty
              ? _EmptyState(isScanning: isScanning)
              : ListView.builder(
                  itemCount: devices.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: _DeviceListItem(
                        device: devices[index],
                        onConnect: () => onConnect(devices[index]),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// 扫描进度条
class _ScanProgressBar extends StatefulWidget {
  final bool isScanning;

  const _ScanProgressBar({required this.isScanning});

  @override
  State<_ScanProgressBar> createState() => _ScanProgressBarState();
}

class _ScanProgressBarState extends State<_ScanProgressBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    if (widget.isScanning) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(_ScanProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isScanning && !_controller.isAnimating) {
      // 重新开始扫描时，先重置控制器到起始状态
      _controller.reset();
      _controller.repeat(reverse: true);
    } else if (!widget.isScanning && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          height: 4,
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(2),
          ),
          child: AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return Stack(
                children: [
                  // 渐变进度条 - 跟随移动位置，居中显示
                  if (widget.isScanning)
                    Positioned(
                      left: constraints.maxWidth * _animation.value - constraints.maxWidth * 0.15,
                      top: 0,
                      bottom: 0,
                      child: Container(
                        width: constraints.maxWidth * 0.3,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              AppTheme.primary,
                              Colors.transparent,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(2),
                          boxShadow: AppTheme.glowShadow(AppTheme.primary, blur: 10),
                        ),
                      ),
                    ),
                  // 移动效果 - 使用父容器宽度，移动到最右边
                  if (widget.isScanning)
                    Positioned(
                      left: constraints.maxWidth * _animation.value,
                      top: 0,
                      bottom: 0,
                      child: Container(
                        width: 2,
                        decoration: BoxDecoration(
                          color: AppTheme.primary,
                          boxShadow: AppTheme.glowShadow(AppTheme.primary, blur: 8),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

/// 空状态
class _EmptyState extends StatelessWidget {
  final bool isScanning;

  const _EmptyState({required this.isScanning});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isScanning ? Icons.bluetooth_searching : Icons.bluetooth_disabled,
            size: 48,
            color: AppTheme.textMuted,
          ),
          const SizedBox(height: 16),
          Text(
            isScanning ? '正在扫描设备...' : '未找到蓝牙设备',
            style: AppTheme.labelMedium.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '请确保摩托车点火开关已打开',
            style: AppTheme.labelSmall.copyWith(
              color: AppTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

/// 设备列表项
class _DeviceListItem extends StatelessWidget {
  final BluetoothDeviceModel device;
  final VoidCallback onConnect;

  const _DeviceListItem({
    required this.device,
    required this.onConnect,
  });

  @override
  Widget build(BuildContext context) {
    final isConnected = device.status == DeviceConnectionStatus.connected;
    final isConnecting = device.status == DeviceConnectionStatus.connecting;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isConnected ? AppTheme.primary10 : AppTheme.surface40,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isConnected
              ? AppTheme.primary.withOpacity(0.6)
              : AppTheme.primary20,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // 设备图标
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isConnected ? AppTheme.primary : AppTheme.primary20,
              ),
            ),
            child: Icon(
              Icons.bluetooth,
              color: isConnected ? AppTheme.primary : AppTheme.textSecondary,
              size: 24,
            ),
          ),

          const SizedBox(width: 16),

          // 设备信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device.name,
                  style: AppTheme.titleMedium.copyWith(
                    color: isConnected ? AppTheme.primary : AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  device.macAddress,
                  style: AppTheme.labelSmall.copyWith(
                    color: AppTheme.textMuted,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),

          // 信号强度
          _SignalStrengthIndicator(rssi: device.rssi),

          const SizedBox(width: 16),

          // 连接按钮
          if (isConnecting)
            const SizedBox(
              width: 80,
              height: 32,
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
                  ),
                ),
              ),
            )
          else
            SizedBox(
              width: 80,
              height: 32,
              child: isConnected
                  ? CyberButton.success(
                      text: '已连接',
                      onPressed: null,
                      height: 32,
                      fontSize: 10,
                    )
                  : CyberButton.primary(
                      text: '连接',
                      onPressed: onConnect,
                      height: 32,
                      fontSize: 10,
                    ),
            ),
        ],
      ),
    );
  }
}

/// 信号强度指示器 (4格)
class _SignalStrengthIndicator extends StatelessWidget {
  final int rssi;

  const _SignalStrengthIndicator({required this.rssi});

  @override
  Widget build(BuildContext context) {
    // 将 rssi 转换为信号格数 (0-4)
    // -100 dBm 以下: 0 格
    // -100 ~ -75 dBm: 1-2 格
    // -75 ~ -50 dBm: 3 格
    // -50 dBm 以上: 4 格
    int bars;
    if (rssi >= -50) {
      bars = 4;
    } else if (rssi >= -65) {
      bars = 3;
    } else if (rssi >= -80) {
      bars = 2;
    } else {
      bars = 1;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(4, (index) {
            final isActive = index < bars;
            return Container(
              width: 4,
              height: 6 + (index * 3).toDouble(),
              margin: const EdgeInsets.only(left: 2),
              decoration: BoxDecoration(
                color: isActive ? AppTheme.primary : AppTheme.textMuted.withOpacity(0.3),
                borderRadius: BorderRadius.circular(1),
              ),
            );
          }),
        ),
        const SizedBox(height: 4),
        Text(
          '$rssi dBm',
          style: AppTheme.labelSmall.copyWith(
            color: AppTheme.textMuted,
            fontFamily: 'monospace',
            fontSize: 8,
          ),
        ),
      ],
    );
  }
}
