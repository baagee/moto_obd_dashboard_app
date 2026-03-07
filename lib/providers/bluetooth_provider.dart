import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../models/bluetooth_device.dart';
import '../models/obd_data.dart';
import '../services/bluetooth_service.dart' as app_bluetooth;
import 'log_provider.dart';

/// 蓝牙状态 Provider - 管理蓝牙权限和状态
class BluetoothProvider extends ChangeNotifier {
  app_bluetooth.BluetoothPermissionStatus _permissionStatus = app_bluetooth.BluetoothPermissionStatus.unknown;
  bool _isBluetoothOn = false;
  bool _isInitialized = false;
  bool _isDeviceConnected = false; // 是否有已连接的蓝牙设备

  // 扫描相关
  bool _isScanning = false;
  List<BluetoothDeviceModel> _scannedDevices = [];
  BluetoothDeviceModel? _connectedDevice;
  BluetoothDeviceModel? _lastConnectedDevice;

  StreamSubscription<BluetoothAdapterState>? _adapterSubscription;
  Timer? _scanTimer;
  Timer? _connectionSimulationTimer;
  LogProvider? _logProvider;

  // Getter
  app_bluetooth.BluetoothPermissionStatus get permissionStatus => _permissionStatus;
  bool get isBluetoothOn => _isBluetoothOn;
  bool get isInitialized => _isInitialized;
  bool get hasPermission => _permissionStatus == app_bluetooth.BluetoothPermissionStatus.granted;
  bool get isDeviceConnected => _isDeviceConnected;
  bool get isScanning => _isScanning;
  List<BluetoothDeviceModel> get scannedDevices => _scannedDevices;
  BluetoothDeviceModel? get connectedDevice => _connectedDevice;
  BluetoothDeviceModel? get lastConnectedDevice => _lastConnectedDevice;

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

  /// 开始扫描设备（Mock）
  Future<void> startScan() async {
    if (_isScanning) return;

    _isScanning = true;
    _scannedDevices = [];
    notifyListeners();

    _logProvider?.addLog('Bluetooth', LogType.info, '开始扫描蓝牙设备...');

    // Mock 模拟扫描结果 - 延迟添加设备
    final random = Random();
    final mockDeviceNames = ['OBDLink MX+', 'Vgate iCar Pro', 'Generic OBD-II', 'UniCarScan UCSI-2000', 'OBD-II Bluetooth'];

    _scanTimer = Timer.periodic(const Duration(milliseconds: 800), (timer) {
      if (_scannedDevices.length >= mockDeviceNames.length) {
        stopScan();
        return;
      }

      final index = _scannedDevices.length;
      final device = BluetoothDeviceModel(
        id: '${index + 1}',
        name: mockDeviceNames[index],
        macAddress: _generateRandomMac(random),
        rssi: random.nextInt(40) - 95, // -95 到 -55 dBm
        status: DeviceConnectionStatus.disconnected,
      );

      _scannedDevices = [..._scannedDevices, device];
      notifyListeners();
    });
  }

  /// 停止扫描
  Future<void> stopScan() async {
    _scanTimer?.cancel();
    _scanTimer = null;
    _isScanning = false;
    _logProvider?.addLog('Bluetooth', LogType.info, '扫描完成，找到 ${_scannedDevices.length} 个设备');
    notifyListeners();
  }

  /// 连接设备（Mock）
  Future<void> connectToDevice(BluetoothDeviceModel device) async {
    _logProvider?.addLog('Bluetooth', LogType.info, '正在连接 ${device.name}...');

    // 先断开之前已连接的设备
    if (_connectedDevice != null) {
      final prevIndex = _scannedDevices.indexWhere((d) => d.id == _connectedDevice!.id);
      if (prevIndex != -1) {
        _scannedDevices[prevIndex] = _scannedDevices[prevIndex].copyWith(
          status: DeviceConnectionStatus.disconnected,
        );
      }
      _connectedDevice = null;
      _isDeviceConnected = false;
      _connectionSimulationTimer?.cancel();
      notifyListeners();
    }

    // 更新设备状态为连接中
    final index = _scannedDevices.indexWhere((d) => d.id == device.id);
    if (index != -1) {
      _scannedDevices[index] = _scannedDevices[index].copyWith(
        status: DeviceConnectionStatus.connecting,
      );
      notifyListeners();
    }

    // Mock 模拟连接过程 - 2秒后连接成功
    await Future.delayed(const Duration(seconds: 2));

    // 更新为已连接状态
    if (index != -1) {
      _scannedDevices[index] = _scannedDevices[index].copyWith(
        status: DeviceConnectionStatus.connected,
        sentBytes: 0,
        receivedBytes: 0,
        connectionStability: 99.8,
      );
      _connectedDevice = _scannedDevices[index];
      _lastConnectedDevice = _scannedDevices[index];
      _isDeviceConnected = true;
      notifyListeners();
    }

    _logProvider?.addLog('Bluetooth', LogType.success, '已连接到 ${device.name}');

    // 启动模拟数据更新
    _startConnectionSimulation();
  }

  /// 断开连接
  Future<void> disconnectDevice() async {
    _connectionSimulationTimer?.cancel();
    _connectionSimulationTimer = null;

    if (_connectedDevice != null) {
      _logProvider?.addLog('Bluetooth', LogType.warning, '已断开与 ${_connectedDevice!.name} 的连接');

      // 更新列表中的设备状态
      final index = _scannedDevices.indexWhere((d) => d.id == _connectedDevice!.id);
      if (index != -1) {
        _scannedDevices[index] = _scannedDevices[index].copyWith(
          status: DeviceConnectionStatus.disconnected,
        );
      }

      _connectedDevice = null;
      _isDeviceConnected = false;
      notifyListeners();
    }
  }

  /// 生成随机 MAC 地址
  String _generateRandomMac(Random random) {
    final bytes = List.generate(6, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(':');
  }

  /// 启动连接后的数据模拟
  void _startConnectionSimulation() {
    _connectionSimulationTimer?.cancel();
    _connectionSimulationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_connectedDevice != null) {
        final random = Random();
        _connectedDevice = _connectedDevice!.copyWith(
          sentBytes: _connectedDevice!.sentBytes + random.nextInt(500),
          receivedBytes: _connectedDevice!.receivedBytes + random.nextInt(800),
          connectionStability: 95.0 + random.nextDouble() * 4.9,
        );

        // 同时更新列表中的设备
        final index = _scannedDevices.indexWhere((d) => d.id == _connectedDevice!.id);
        if (index != -1) {
          _scannedDevices[index] = _connectedDevice!;
        }

        notifyListeners();
      }
    });
  }

  /// 显示蓝牙未开启弹窗（供外部调用）
  bool get shouldShowBluetoothOffDialog {
    return _isInitialized && hasPermission && !_isBluetoothOn;
  }

  @override
  void dispose() {
    _adapterSubscription?.cancel();
    _scanTimer?.cancel();
    _connectionSimulationTimer?.cancel();
    super.dispose();
  }
}
