import 'package:flutter/material.dart';
import '../models/bluetooth_device.dart';
import '../theme/app_theme.dart';

/// 已连接设备详情卡片
class ConnectedDeviceCard extends StatelessWidget {
  final BluetoothDeviceModel? connectedDevice;
  final BluetoothDeviceModel? lastConnectedDevice;
  final VoidCallback? onDisconnect;
  final VoidCallback? onClear;

  const ConnectedDeviceCard({
    super.key,
    this.connectedDevice,
    this.lastConnectedDevice,
    this.onDisconnect,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    if (connectedDevice != null) {
      return _ConnectedState(
        device: connectedDevice!,
        onDisconnect: onDisconnect,
      );
    } else if (lastConnectedDevice != null) {
      return _LastConnectedState(
        device: lastConnectedDevice!,
        onClear: onClear,
      );
    } else {
      return const _EmptyState();
    }
  }
}

/// 已连接状态
class _ConnectedState extends StatelessWidget {
  final BluetoothDeviceModel device;
  final VoidCallback? onDisconnect;

  const _ConnectedState({
    required this.device,
    this.onDisconnect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primary20,
            AppTheme.primary10,
          ],
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(
          color: AppTheme.primary40,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题栏
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '已连接设备',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: AppTheme.accentGreen,
                          shape: BoxShape.circle,
                          boxShadow: AppTheme.glowShadow(AppTheme.accentGreen,
                              blur: 8),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '已建立同步',
                        style: AppTheme.labelTinyPrimary.copyWith(
                          color: AppTheme.accentGreen,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              IconButton(
                onPressed: onDisconnect,
                icon: const Icon(
                  Icons.link_off,
                  color: AppTheme.textMuted,
                ),
                tooltip: '断开连接',
              ),
            ],
          ),

          const SizedBox(height: 8),

          // 设备信息
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.backgroundDark50,
              borderRadius: BorderRadius.circular(AppTheme.radiusButton),
              border: Border.all(
                color: AppTheme.primary20,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppTheme.primary20,
                    borderRadius: BorderRadius.circular(AppTheme.radiusButton),
                    boxShadow: AppTheme.glowShadow(AppTheme.primary,
                        blur: 15, opacity: 0.3),
                  ),
                  child: const Icon(
                    Icons.memory,
                    color: AppTheme.primary,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '型号',
                        style: AppTheme.labelSmall.copyWith(
                          color: AppTheme.textMuted,
                        ),
                      ),
                      Text(
                        device.name,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 6),

          // MAC 地址和协议
          Row(
            children: [
              Expanded(
                child: _InfoBox(
                  label: 'MAC 地址',
                  value: device.macAddress,
                  isPrimary: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _InfoBox(
                  label: '协议',
                  value: 'ISO 15765-4 CAN',
                  isPrimary: true,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // 连接稳定性
          _StabilityIndicator(stability: device.connectionStability),
        ],
      ),
    );
  }
}

/// 上次连接状态
class _LastConnectedState extends StatelessWidget {
  final BluetoothDeviceModel device;
  final VoidCallback? onClear;

  const _LastConnectedState({
    required this.device,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface40,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(
          color: AppTheme.primary20,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题栏
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '上次连接',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '点击重新连接',
                    style: AppTheme.labelSmall.copyWith(
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (onClear != null)
                    GestureDetector(
                      onTap: onClear,
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(
                          Icons.delete_outline,
                          color: AppTheme.textMuted,
                          size: 22,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 8),

          // 设备信息
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.backgroundDark50,
              borderRadius: BorderRadius.circular(AppTheme.radiusButton),
              border: Border.all(
                color: AppTheme.primary20,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(AppTheme.radiusButton),
                    border: Border.all(
                      color: AppTheme.primary20,
                    ),
                  ),
                  child: const Icon(
                    Icons.bluetooth_disabled,
                    color: AppTheme.textMuted,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '型号',
                        style: AppTheme.labelSmall.copyWith(
                          color: AppTheme.textMuted,
                        ),
                      ),
                      Text(
                        device.name,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 6),

          // MAC 地址
          _InfoBox(
            label: 'MAC 地址',
            value: device.macAddress,
            isPrimary: false,
          ),
        ],
      ),
    );
  }
}

/// 空状态
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface40,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(
          color: AppTheme.primary20,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.bluetooth_searching,
            size: 48,
            color: AppTheme.textMuted,
          ),
          const SizedBox(height: 6),
          Text(
            '未连接设备',
            style: AppTheme.titleMedium.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '扫描并连接 OBD 设备',
            style: AppTheme.labelSmall.copyWith(
              color: AppTheme.textMuted,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// 信息框
class _InfoBox extends StatelessWidget {
  final String label;
  final String value;
  final bool isPrimary;

  const _InfoBox({
    required this.label,
    required this.value,
    required this.isPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.backgroundDark50,
        borderRadius: BorderRadius.circular(AppTheme.radiusButton),
        border: Border.all(
          color: isPrimary ? AppTheme.primary20 : AppTheme.primary10,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTheme.labelSmall.copyWith(
              color: AppTheme.textMuted,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontFamily: 'monospace',
              color: isPrimary ? AppTheme.primary : AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// 连接稳定性指示器
class _StabilityIndicator extends StatelessWidget {
  final double stability;

  const _StabilityIndicator({required this.stability});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.backgroundDark50,
        borderRadius: BorderRadius.circular(AppTheme.radiusButton),
        border: Border.all(color: AppTheme.primary10),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '连接稳定性',
                style: AppTheme.labelSmall.copyWith(
                  color: AppTheme.textMuted,
                  letterSpacing: 1,
                ),
              ),
              Text(
                '稳定性 ${stability.toStringAsFixed(1)}%',
                style: AppTheme.labelSmall.copyWith(
                  color: AppTheme.primary,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 稳定性条形图
          SizedBox(
            height: 6,
            child: Row(
              children: List.generate(7, (index) {
                final isActive = index < (stability / 15).round();
                return Expanded(
                  child: Container(
                    margin: EdgeInsets.only(right: index < 6 ? 2 : 0),
                    decoration: BoxDecoration(
                      color: isActive ? AppTheme.primary : AppTheme.primary30,
                      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
