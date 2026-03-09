import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// 蓝牙设备连接状态
enum DeviceConnectionStatus {
  disconnected, // 未连接
  connecting,   // 连接中
  connected,    // 已连接
}

/// 蓝牙设备模型
class BluetoothDeviceModel {
  final String id;
  final String name;
  final String macAddress;
  final int rssi;
  DeviceConnectionStatus status;
  double connectionStability;

  // flutter_blue_plus 设备引用
  BluetoothDevice? flutterDevice;

  BluetoothDeviceModel({
    required this.id,
    required this.name,
    required this.macAddress,
    required this.rssi,
    this.status = DeviceConnectionStatus.disconnected,
    this.connectionStability = 0.0,
    this.flutterDevice,
  });

  /// 从 ScanResult 创建设备模型
  factory BluetoothDeviceModel.fromScanResult(ScanResult result) {
    final device = result.device;
    final advertisementData = result.advertisementData;

    String deviceName = advertisementData.advName.isNotEmpty
        ? advertisementData.advName
        : 'Unknown Device';

    return BluetoothDeviceModel(
      id: device.remoteId.str,
      name: deviceName,
      macAddress: device.remoteId.str,
      rssi: result.rssi,
      status: DeviceConnectionStatus.disconnected,
      flutterDevice: device,
    );
  }

  BluetoothDeviceModel copyWith({
    String? id,
    String? name,
    String? macAddress,
    int? rssi,
    DeviceConnectionStatus? status,
    double? connectionStability,
    BluetoothDevice? flutterDevice,
  }) {
    return BluetoothDeviceModel(
      id: id ?? this.id,
      name: name ?? this.name,
      macAddress: macAddress ?? this.macAddress,
      rssi: rssi ?? this.rssi,
      status: status ?? this.status,
      connectionStability: connectionStability ?? this.connectionStability,
      flutterDevice: flutterDevice ?? this.flutterDevice,
    );
  }
}
