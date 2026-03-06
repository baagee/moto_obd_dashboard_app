import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../models/obd_data.dart';
import '../services/bluetooth_service.dart' as app_bluetooth;
import 'log_provider.dart';

/// 蓝牙状态 Provider - 管理蓝牙权限和状态
class BluetoothProvider extends ChangeNotifier {
  app_bluetooth.BluetoothPermissionStatus _permissionStatus = app_bluetooth.BluetoothPermissionStatus.unknown;
  bool _isBluetoothOn = false;
  bool _isInitialized = false;
  bool _isDeviceConnected = false; // 是否有已连接的蓝牙设备
  StreamSubscription<BluetoothAdapterState>? _adapterSubscription;
  LogProvider? _logProvider;

  // Getter
  app_bluetooth.BluetoothPermissionStatus get permissionStatus => _permissionStatus;
  bool get isBluetoothOn => _isBluetoothOn;
  bool get isInitialized => _isInitialized;
  bool get hasPermission => _permissionStatus == app_bluetooth.BluetoothPermissionStatus.granted;
  bool get isDeviceConnected => _isDeviceConnected;

  /// 设置日志 Provider
  void setLogProvider(LogProvider logProvider) {
    _logProvider = logProvider;
  }

  /// 初始化蓝牙状态检测
  Future<void> initialize() async {
    if (_isInitialized) return;

    // 输出初始化日志
    _logProvider?.addLog('Bluetooth', LogType.info, '蓝牙服务初始化中...');

    // 初始检测
    await _checkPermission();
    await _checkBluetoothStatus();

    // 监听蓝牙状态变化
    _adapterSubscription = FlutterBluePlus.adapterState.listen((state) {
      final wasOn = _isBluetoothOn;
      _isBluetoothOn = state == BluetoothAdapterState.on;

      // 蓝牙状态变化时输出日志
      if (_isBluetoothOn && !wasOn) {
        _logProvider?.addLog('Bluetooth', LogType.success, '蓝牙已开启');
      } else if (!_isBluetoothOn && wasOn) {
        _logProvider?.addLog('Bluetooth', LogType.warning, '蓝牙已关闭');
      }

      notifyListeners();
    });

    _isInitialized = true;
    notifyListeners();
  }

  /// 检查权限状态
  Future<void> _checkPermission() async {
    _permissionStatus = await app_bluetooth.BluetoothService.checkBluetoothPermission();

    // 根据权限状态输出日志
    switch (_permissionStatus) {
      case app_bluetooth.BluetoothPermissionStatus.granted:
        _logProvider?.addLog('Bluetooth', LogType.success, '蓝牙权限已获取');
        break;
      case app_bluetooth.BluetoothPermissionStatus.denied:
        _logProvider?.addLog('Bluetooth', LogType.warning, '蓝牙权限被拒绝');
        break;
      case app_bluetooth.BluetoothPermissionStatus.permanentlyDenied:
        _logProvider?.addLog('Bluetooth', LogType.error, '蓝牙权限已永久拒绝，请前往设置授权');
        break;
      case app_bluetooth.BluetoothPermissionStatus.unknown:
        _logProvider?.addLog('Bluetooth', LogType.info, '正在检测蓝牙权限...');
        break;
    }

    notifyListeners();
  }

  /// 检查蓝牙是否开启
  Future<void> _checkBluetoothStatus() async {
    _isBluetoothOn = await app_bluetooth.BluetoothService.isBluetoothEnabled();

    // 根据蓝牙状态输出日志
    if (_isBluetoothOn) {
      _logProvider?.addLog('Bluetooth', LogType.success, '蓝牙已开启');
    } else {
      _logProvider?.addLog('Bluetooth', LogType.warning, '蓝牙未开启，请开启蓝牙');
    }

    notifyListeners();
  }

  /// 请求蓝牙权限
  Future<bool> requestPermission() async {
    _logProvider?.addLog('Bluetooth', LogType.info, '正在请求蓝牙权限...');
    _permissionStatus = await app_bluetooth.BluetoothService.requestBluetoothPermission();

    // 根据请求结果输出日志
    if (_permissionStatus == app_bluetooth.BluetoothPermissionStatus.granted) {
      _logProvider?.addLog('Bluetooth', LogType.success, '蓝牙权限已获取');
    } else {
      _logProvider?.addLog('Bluetooth', LogType.warning, '蓝牙权限授权失败');
    }

    notifyListeners();
    return _permissionStatus == app_bluetooth.BluetoothPermissionStatus.granted;
  }

  /// 刷新蓝牙状态
  Future<void> refreshBluetoothStatus() async {
    _logProvider?.addLog('Bluetooth', LogType.info, '正在刷新蓝牙状态...');
    await _checkPermission();
    await _checkBluetoothStatus();
  }

  /// 打开系统设置
  Future<void> openSettings() async {
    _logProvider?.addLog('Bluetooth', LogType.info, '正在打开系统设置...');
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
