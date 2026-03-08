import 'dart:math';
import 'package:flutter/material.dart';
import '../models/bluetooth_device.dart';
import '../theme/app_theme.dart';
import 'cyber_button.dart';

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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.primary.withOpacity(0.4),
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
                    'Connected Device',
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
                          boxShadow: AppTheme.glowShadow(AppTheme.accentGreen, blur: 8),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'SYNC ESTABLISHED',
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
              color: AppTheme.backgroundDark.withOpacity(0.6),
              borderRadius: BorderRadius.circular(8),
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
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: AppTheme.glowShadow(AppTheme.primary, blur: 15, opacity: 0.3),
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
                        'Model',
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
                  label: 'MAC Address',
                  value: device.macAddress,
                  isPrimary: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _InfoBox(
                  label: 'Protocol',
                  value: 'ISO 15765-4 CAN',
                  isPrimary: true,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // 连接稳定性
          _StabilityIndicator(stability: device.connectionStability),

          const SizedBox(height: 6),

          // 数据传输统计
          _DataTransferStats(
            sentBytes: device.sentBytes,
            receivedBytes: device.receivedBytes,
          ),
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
        color: AppTheme.surface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
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
                    'Last Connected',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap to reconnect',
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
              color: AppTheme.backgroundDark.withOpacity(0.6),
              borderRadius: BorderRadius.circular(8),
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
                    borderRadius: BorderRadius.circular(8),
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
                        'Model',
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
            label: 'MAC Address',
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
        color: AppTheme.surface.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
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
            'No Device Connected',
            style: AppTheme.titleMedium.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Scan and connect to an OBD device',
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
        color: AppTheme.backgroundDark.withOpacity(0.6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isPrimary ? AppTheme.primary20 : AppTheme.primary10,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
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
        color: AppTheme.backgroundDark.withOpacity(0.6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.primary10),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'CONNECTION STABILITY',
                style: AppTheme.labelSmall.copyWith(
                  color: AppTheme.textMuted,
                  letterSpacing: 1,
                ),
              ),
              Text(
                '${stability.toStringAsFixed(1)}% Reliable',
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

/// 数据传输统计
class _DataTransferStats extends StatefulWidget {
  final int sentBytes;
  final int receivedBytes;

  const _DataTransferStats({
    required this.sentBytes,
    required this.receivedBytes,
  });

  @override
  State<_DataTransferStats> createState() => _DataTransferStatsState();
}

class _DataTransferStatsState extends State<_DataTransferStats> {
  late List<double> _dataPoints;

  @override
  void initState() {
    super.initState();
    _generateDataPoints();
  }

  @override
  void didUpdateWidget(_DataTransferStats oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.receivedBytes != widget.receivedBytes) {
      _generateDataPoints();
    }
  }

  void _generateDataPoints() {
    final random = Random();
    _dataPoints = List.generate(15, (_) => 0.3 + random.nextDouble() * 0.7);
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'PACKET LOSS: 0.02%',
              style: AppTheme.labelSmall.copyWith(
                color: AppTheme.textMuted,
                fontFamily: 'monospace',
              ),
            ),
            Text(
              'LATENCY: 14ms',
              style: AppTheme.labelSmall.copyWith(
                color: AppTheme.textMuted,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // 数据传输图表
        Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.backgroundDark.withOpacity(0.6),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: _dataPoints.map((height) {
              return Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.3 + height * 0.4),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(2),
                    ),
                  ),
                  height: height * 32,
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),
        // 发送/接收统计
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _DataStat(
              label: 'Sent',
              value: _formatBytes(widget.sentBytes),
              icon: Icons.arrow_upward,
              color: AppTheme.accentGreen,
            ),
            _DataStat(
              label: 'Received',
              value: _formatBytes(widget.receivedBytes),
              icon: Icons.arrow_downward,
              color: AppTheme.primary,
            ),
          ],
        ),
      ],
    );
  }
}

/// 数据统计项
class _DataStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _DataStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(
          '$label: ',
          style: AppTheme.labelSmall.copyWith(
            color: AppTheme.textMuted,
          ),
        ),
        Text(
          value,
          style: AppTheme.labelSmall.copyWith(
            color: color,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }
}
