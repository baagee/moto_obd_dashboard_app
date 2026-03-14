import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/bluetooth_device.dart';
import '../models/theme_colors.dart';
import '../providers/theme_provider.dart';
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
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final colors = themeProvider.currentColors;

        if (connectedDevice != null) {
          return _ConnectedState(
            device: connectedDevice!,
            onDisconnect: onDisconnect,
            colors: colors,
          );
        } else if (lastConnectedDevice != null) {
          return _LastConnectedState(
            device: lastConnectedDevice!,
            onClear: onClear,
            colors: colors,
          );
        } else {
          return _EmptyState(colors: colors);
        }
      },
    );
  }
}

/// 已连接状态
class _ConnectedState extends StatelessWidget {
  final BluetoothDeviceModel device;
  final VoidCallback? onDisconnect;
  final ThemeColors colors;

  const _ConnectedState({
    required this.device,
    this.onDisconnect,
    required this.colors,
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
            colors.primary.withValues(alpha: 0.2),
            colors.primary.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colors.primary.withValues(alpha: 0.4),
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
                  Text(
                    'Connected Device',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: colors.textPrimary,
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
                          color: colors.accentGreen,
                          shape: BoxShape.circle,
                          boxShadow: AppTheme.glowShadow(colors.accentGreen, blur: 8),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'SYNC ESTABLISHED',
                        style: TextStyle(
                          color: colors.accentGreen,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              IconButton(
                onPressed: onDisconnect,
                icon: Icon(
                  Icons.link_off,
                  color: colors.textMuted,
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
              color: colors.backgroundDark.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: colors.primary.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: AppTheme.glowShadow(colors.primary, blur: 15, opacity: 0.3),
                  ),
                  child: Icon(
                    Icons.memory,
                    color: colors.primary,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Model',
                        style: TextStyle(
                          color: colors.textMuted,
                          fontSize: 10,
                        ),
                      ),
                      Text(
                        device.name,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: colors.textPrimary,
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
                  label: 'MAC Address',
                  value: device.macAddress,
                  isPrimary: true,
                  colors: colors,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _InfoBox(
                  label: 'Protocol',
                  value: 'ISO 15765-4 CAN',
                  isPrimary: true,
                  colors: colors,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // 连接稳定性
          _StabilityIndicator(stability: device.connectionStability, colors: colors),
        ],
      ),
    );
  }
}

/// 上次连接状态
class _LastConnectedState extends StatelessWidget {
  final BluetoothDeviceModel device;
  final VoidCallback? onClear;
  final ThemeColors colors;

  const _LastConnectedState({
    required this.device,
    this.onClear,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colors.primary.withValues(alpha: 0.2),
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
                  Text(
                    'Last Connected',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: colors.textPrimary,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap to reconnect',
                    style: TextStyle(
                      color: colors.textMuted,
                      fontSize: 10,
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
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          Icons.delete_outline,
                          color: colors.textMuted,
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
              color: colors.backgroundDark.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: colors.primary.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: colors.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Icon(
                    Icons.bluetooth_disabled,
                    color: colors.textMuted,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Model',
                        style: TextStyle(
                          color: colors.textMuted,
                          fontSize: 10,
                        ),
                      ),
                      Text(
                        device.name,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: colors.textPrimary,
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
            label: 'MAC Address',
            value: device.macAddress,
            isPrimary: false,
            colors: colors,
          ),
        ],
      ),
    );
  }
}

/// 空状态
class _EmptyState extends StatelessWidget {
  final ThemeColors colors;

  const _EmptyState({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colors.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bluetooth_searching,
            size: 48,
            color: colors.textMuted,
          ),
          const SizedBox(height: 6),
          Text(
            'No Device Connected',
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Scan and connect to an OBD device',
            style: TextStyle(
              color: colors.textMuted,
              fontSize: 10,
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
  final ThemeColors colors;

  const _InfoBox({
    required this.label,
    required this.value,
    required this.isPrimary,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.backgroundDark.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isPrimary ? colors.primary.withValues(alpha: 0.2) : colors.primary.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: colors.textMuted,
              fontSize: 10,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontFamily: 'monospace',
              color: isPrimary ? colors.primary : colors.textSecondary,
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
  final ThemeColors colors;

  const _StabilityIndicator({required this.stability, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.backgroundDark.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.primary.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'CONNECTION STABILITY',
                style: TextStyle(
                  color: colors.textMuted,
                  fontSize: 10,
                  letterSpacing: 1,
                ),
              ),
              Text(
                '${stability.toStringAsFixed(1)}% Reliable',
                style: TextStyle(
                  color: colors.primary,
                  fontSize: 10,
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
                      color: isActive ? colors.primary : colors.primary.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
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
