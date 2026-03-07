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
  int sentBytes;
  int receivedBytes;
  double connectionStability;

  BluetoothDeviceModel({
    required this.id,
    required this.name,
    required this.macAddress,
    required this.rssi,
    this.status = DeviceConnectionStatus.disconnected,
    this.sentBytes = 0,
    this.receivedBytes = 0,
    this.connectionStability = 0.0,
  });

  BluetoothDeviceModel copyWith({
    String? id,
    String? name,
    String? macAddress,
    int? rssi,
    DeviceConnectionStatus? status,
    int? sentBytes,
    int? receivedBytes,
    double? connectionStability,
  }) {
    return BluetoothDeviceModel(
      id: id ?? this.id,
      name: name ?? this.name,
      macAddress: macAddress ?? this.macAddress,
      rssi: rssi ?? this.rssi,
      status: status ?? this.status,
      sentBytes: sentBytes ?? this.sentBytes,
      receivedBytes: receivedBytes ?? this.receivedBytes,
      connectionStability: connectionStability ?? this.connectionStability,
    );
  }
}
