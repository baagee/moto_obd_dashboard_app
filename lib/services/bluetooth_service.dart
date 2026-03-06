import 'package:flutter/material.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

/// 蓝牙权限状态
enum BluetoothPermissionStatus {
  granted,   // 已授权
  denied,    // 被拒绝（可再次请求）
  permanentlyDenied, // 永久拒绝（需要手动设置）
  unknown,   // 未知
}

/// 蓝牙服务 - 负责权限检测和蓝牙状态管理
class BluetoothService {
  /// 检查蓝牙权限状态
  static Future<BluetoothPermissionStatus> checkBluetoothPermission() async {
    // 检查蓝牙扫描权限 (Android 12+)
    final scanStatus = await Permission.bluetoothScan.status;
    // 检查蓝牙连接权限 (Android 12+)
    final connectStatus = await Permission.bluetoothConnect.status;
    // 检查位置权限（用于 BLE 扫描）
    final locationStatus = await Permission.locationWhenInUse.status;

    if (scanStatus.isGranted && connectStatus.isGranted) {
      return BluetoothPermissionStatus.granted;
    } else if (scanStatus.isPermanentlyDenied ||
        connectStatus.isPermanentlyDenied ||
        locationStatus.isPermanentlyDenied) {
      return BluetoothPermissionStatus.permanentlyDenied;
    } else if (scanStatus.isDenied || connectStatus.isDenied || locationStatus.isDenied) {
      return BluetoothPermissionStatus.denied;
    }

    return BluetoothPermissionStatus.unknown;
  }

  /// 请求蓝牙权限
  static Future<BluetoothPermissionStatus> requestBluetoothPermission() async {
    // 请求多个权限
    final results = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();

    // 检查是否全部授权
    final scanGranted = results[Permission.bluetoothScan]?.isGranted ?? false;
    final connectGranted = results[Permission.bluetoothConnect]?.isGranted ?? false;

    if (scanGranted && connectGranted) {
      return BluetoothPermissionStatus.granted;
    } else if (results[Permission.bluetoothScan]?.isPermanentlyDenied == true ||
        results[Permission.bluetoothConnect]?.isPermanentlyDenied == true ||
        results[Permission.locationWhenInUse]?.isPermanentlyDenied == true) {
      return BluetoothPermissionStatus.permanentlyDenied;
    }

    return BluetoothPermissionStatus.denied;
  }

  /// 检查蓝牙是否开启
  static Future<bool> isBluetoothEnabled() async {
    try {
      // 检查设备是否支持蓝牙
      if (await FlutterBluePlus.isSupported == false) {
        return false;
      }

      // 获取蓝牙适配器状态
      final state = await FlutterBluePlus.adapterState.first;
      return state == BluetoothAdapterState.on;
    } catch (e) {
      debugPrint('检查蓝牙状态失败: $e');
      return false;
    }
  }

  /// 打开系统蓝牙设置页面
  static Future<bool> openBluetoothSettings() async {
    try {
      // 方案1: 打开 Android 蓝牙设置页面
      const androidIntent = AndroidIntent(
        action: 'android.settings.BLUETOOTH_SETTINGS',
      );
      await androidIntent.launch();
      return true;
    } catch (e) {
      debugPrint('打开蓝牙设置失败: $e');
    }

    // 方案2: 尝试打开系统设置页面
    try {
      const androidIntent = AndroidIntent(
        action: 'android.settings.SETTINGS',
      );
      await androidIntent.launch();
      return true;
    } catch (e) {
      debugPrint('打开系统设置失败: $e');
    }

    // 方案3: 打开应用设置
    try {
      return await openAppSettings();
    } catch (_) {
      return false;
    }
  }

  /// 监听蓝牙适配器状态变化
  static Stream<BluetoothAdapterState> get adapterStateStream {
    return FlutterBluePlus.adapterState;
  }
}
