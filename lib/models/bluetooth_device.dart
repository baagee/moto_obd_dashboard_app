import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// 蓝牙设备连接状态
enum DeviceConnectionStatus {
  disconnected, // 未连接
  connecting,   // 连接中
  connected,    // 已连接
}

/// ELM327 UUID 配置
class Elm327Uuids {
  static const String notifyUuid = "0000fff1-0000-1000-8000-00805f9b34fb";
  static const String writeUuid = "0000fff2-0000-1000-8000-00805f9b34fb";

  static const List<Map<String, String>> alternativeUuids = [
    {'notify': "0000ffe1-0000-1000-8000-00805f9b34fb", 'write': "0000ffe2-0000-1000-8000-00805f9b34fb"},
    {'notify': "0000fff0-0000-1000-8000-00805f9b34fb", 'write': "0000fff1-0000-1000-8000-00805f9b34fb"},
    {'notify': "6e400003-b5a3-f393-e0a9-e50e24dcca9e", 'write': "6e400002-b5a3-f393-e0a9-e50e24dcca9e"},
  ];

  /// 获取默认 UUID 对
  static Map<String, String> get defaultUuids => {
    'notify': notifyUuid,
    'write': writeUuid,
  };
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

  // flutter_blue_plus 设备引用
  BluetoothDevice? flutterDevice;

  // ELM327 服务 UUID
  String? notifyUuid;
  String? writeUuid;

  BluetoothDeviceModel({
    required this.id,
    required this.name,
    required this.macAddress,
    required this.rssi,
    this.status = DeviceConnectionStatus.disconnected,
    this.sentBytes = 0,
    this.receivedBytes = 0,
    this.connectionStability = 0.0,
    this.flutterDevice,
    this.notifyUuid,
    this.writeUuid,
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
      notifyUuid: Elm327Uuids.notifyUuid,
      writeUuid: Elm327Uuids.writeUuid,
    );
  }

  BluetoothDeviceModel copyWith({
    String? id,
    String? name,
    String? macAddress,
    int? rssi,
    DeviceConnectionStatus? status,
    int? sentBytes,
    int? receivedBytes,
    double? connectionStability,
    BluetoothDevice? flutterDevice,
    String? notifyUuid,
    String? writeUuid,
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
      flutterDevice: flutterDevice ?? this.flutterDevice,
      notifyUuid: notifyUuid ?? this.notifyUuid,
      writeUuid: writeUuid ?? this.writeUuid,
    );
  }
}
