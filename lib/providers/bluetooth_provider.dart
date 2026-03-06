import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../services/bluetooth_service.dart' as app_bluetooth;

/// 蓝牙状态 Provider - 管理蓝牙权限和状态
class BluetoothProvider extends ChangeNotifier {
  app_bluetooth.BluetoothPermissionStatus _permissionStatus = app_bluetooth.BluetoothPermissionStatus.unknown;
  bool _isBluetoothOn = false;
  bool _isInitialized = false;
  bool _isDeviceConnected = false; // 是否有已连接的蓝牙设备
  StreamSubscription<BluetoothAdapterState>? _adapterSubscription;

  // Getter
  app_bluetooth.BluetoothPermissionStatus get permissionStatus => _permissionStatus;
  bool get isBluetoothOn => _isBluetoothOn;
  bool get isInitialized => _isInitialized;
  bool get hasPermission => _permissionStatus == app_bluetooth.BluetoothPermissionStatus.granted;
  bool get isDeviceConnected => _isDeviceConnected;

  /// 初始化蓝牙状态检测
  Future<void> initialize() async {
    if (_isInitialized) return;

    // 初始检测
    await _checkPermission();
    await _checkBluetoothStatus();

    // 监听蓝牙状态变化
    _adapterSubscription = FlutterBluePlus.adapterState.listen((state) {
      _isBluetoothOn = state == BluetoothAdapterState.on;
      notifyListeners();
    });

    _isInitialized = true;
    notifyListeners();
  }

  /// 检查权限状态
  Future<void> _checkPermission() async {
    _permissionStatus = await app_bluetooth.BluetoothService.checkBluetoothPermission();
    notifyListeners();
  }

  /// 检查蓝牙是否开启
  Future<void> _checkBluetoothStatus() async {
    _isBluetoothOn = await app_bluetooth.BluetoothService.isBluetoothEnabled();
    notifyListeners();
  }

  /// 请求蓝牙权限
  Future<bool> requestPermission() async {
    _permissionStatus = await app_bluetooth.BluetoothService.requestBluetoothPermission();
    notifyListeners();
    return _permissionStatus == app_bluetooth.BluetoothPermissionStatus.granted;
  }

  /// 刷新蓝牙状态
  Future<void> refreshBluetoothStatus() async {
    await _checkPermission();
    await _checkBluetoothStatus();
  }

  /// 打开系统设置
  Future<void> openSettings() async {
    await app_bluetooth.BluetoothService.openBluetoothSettings();
  }

  /// 显示蓝牙未开启弹窗（供外部调用）
  bool get shouldShowBluetoothOffDialog {
    return _isInitialized && hasPermission && !_isBluetoothOn;
  }

  @override
  void dispose() {
    _adapterSubscription?.cancel();
    super.dispose();
  }
}
