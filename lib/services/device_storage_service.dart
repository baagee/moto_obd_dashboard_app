import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/bluetooth_device.dart';

/// 设备存储服务 - 负责保存和读取上次连接的设备信息
class DeviceStorageService {
  static const String _fileName = 'last_device.json';
  static String? _cachedFilePath;

  /// 获取设备文件路径
  static Future<String> getDeviceFilePath() async {
    if (_cachedFilePath != null) return _cachedFilePath!;
    final directory = await getApplicationDocumentsDirectory();
    _cachedFilePath = '${directory.path}/$_fileName';
    return _cachedFilePath!;
  }

  /// 保存上次连接的设备信息
  static Future<void> saveLastDevice(BluetoothDeviceModel device) async {
    try {
      final filePath = await getDeviceFilePath();
      final file = File(filePath);

      final deviceData = {
        'id': device.id,
        'name': device.name,
        'macAddress': device.macAddress,
        'rssi': device.rssi,
        'notifyUuid': device.notifyUuid,
        'writeUuid': device.writeUuid,
        'savedAt': DateTime.now().toIso8601String(),
      };

      await file.writeAsString(jsonEncode(deviceData), encoding: utf8);
    } catch (e) {
      // 保存失败静默处理
    }
  }

  /// 读取上次连接的设备信息
  static Future<BluetoothDeviceModel?> loadLastDevice() async {
    try {
      final filePath = await getDeviceFilePath();
      final file = File(filePath);

      if (!await file.exists()) {
        return null;
      }

      final content = await file.readAsString(encoding: utf8);
      if (content.isEmpty) {
        return null;
      }

      final data = jsonDecode(content) as Map<String, dynamic>;

      return BluetoothDeviceModel(
        id: data['id'] as String,
        name: data['name'] as String? ?? 'Unknown Device',
        macAddress: data['macAddress'] as String,
        rssi: data['rssi'] as int? ?? -100,
        status: DeviceConnectionStatus.disconnected,
        notifyUuid: data['notifyUuid'] as String?,
        writeUuid: data['writeUuid'] as String?,
      );
    } catch (e) {
      // 读取失败返回 null
      return null;
    }
  }

  /// 清除保存的设备信息
  static Future<void> clearLastDevice() async {
    try {
      final filePath = await getDeviceFilePath();
      final file = File(filePath);

      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      // 清除失败静默处理
    }
  }
}
