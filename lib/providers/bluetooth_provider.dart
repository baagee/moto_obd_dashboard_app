import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../models/bluetooth_device.dart';
import '../models/obd_data.dart';
import '../services/bluetooth_service.dart' as app_bluetooth;
import '../services/device_storage_service.dart';
import 'log_provider.dart';

/// 蓝牙状态 Provider - 管理蓝牙权限和状态
class BluetoothProvider extends ChangeNotifier {
  app_bluetooth.BluetoothPermissionStatus _permissionStatus = app_bluetooth.BluetoothPermissionStatus.unknown;
  bool _isBluetoothOn = false;
  bool _isInitialized = false;
  bool _isDeviceConnected = false; // 是否有已连接的蓝牙设备

  // 扫描相关
  bool _isScanning = false;
  bool _hasScanned = false; // 记录是否已经扫描过
  List<BluetoothDeviceModel> _scannedDevices = [];
  BluetoothDeviceModel? _connectedDevice;
  BluetoothDeviceModel? _lastConnectedDevice;

  // 重连相关
  int _reconnectAttempts = 0;
  static const int maxReconnectAttempts = 2;
  bool _isAutoReconnecting = false;

  StreamSubscription<BluetoothAdapterState>? _adapterSubscription;
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
  Timer? _scanTimer;
  Timer? _connectionSimulationTimer;
  LogProvider? _logProvider;

  // 过滤阈值
  static const int minRssi = -90; // 过滤弱信号设备

  // Getter
  app_bluetooth.BluetoothPermissionStatus get permissionStatus => _permissionStatus;
  bool get isBluetoothOn => _isBluetoothOn;
  bool get isInitialized => _isInitialized;
  bool get hasPermission => _permissionStatus == app_bluetooth.BluetoothPermissionStatus.granted;
  bool get isDeviceConnected => _isDeviceConnected;
  bool get isScanning => _isScanning;
  bool get hasScanned => _hasScanned;
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
        // 蓝牙开启后自动扫描
        if (!_hasScanned && !_isScanning) {
          startScan();
        }
      } else if (!_isBluetoothOn && wasOn) {
        _logProvider?.addLog('Bluetooth', LogType.warning, '蓝牙已关闭');
      }

      notifyListeners();
    });

    // 加载上次设备
    await _loadLastDevice();

    // 如果上次有连接的设备且当前未连接，尝试自动重连
    if (_lastConnectedDevice != null && !_isDeviceConnected && _isBluetoothOn) {
      _logProvider?.addLog('Bluetooth', LogType.info, '尝试自动连接上次设备: ${_lastConnectedDevice!.name}');
      await _autoReconnectLastDevice();
    }

    _isInitialized = true;
    notifyListeners();
  }

  /// 加载上次连接的设备
  Future<void> _loadLastDevice() async {
    final device = await DeviceStorageService.loadLastDevice();
    if (device != null) {
      _lastConnectedDevice = device;
      _logProvider?.addLog('Bluetooth', LogType.info, '已加载上次设备: ${device.name}');
      notifyListeners();
    }
  }

  /// 自动重连上次设备
  Future<void> _autoReconnectLastDevice() async {
    if (_lastConnectedDevice == null || _isAutoReconnecting) return;

    _isAutoReconnecting = true;
    _reconnectAttempts = 0;

    // 开始扫描查找上次设备
    await startScan();

    // 等待扫描结果
    await Future.delayed(const Duration(seconds: 4));

    // 查找设备
    final device = _scannedDevices.firstWhere(
      (d) => d.id == _lastConnectedDevice!.id,
      orElse: () => _lastConnectedDevice!,
    );

    // 如果在列表中找到（信号强度足够）
    if (_scannedDevices.any((d) => d.id == _lastConnectedDevice!.id)) {
      await _attemptReconnect(device);
    } else {
      _logProvider?.addLog('Bluetooth', LogType.warning, '未找到上次设备: ${_lastConnectedDevice!.name}');
    }

    _isAutoReconnecting = false;
    notifyListeners();
  }

  /// 尝试重连
  Future<void> _attemptReconnect(BluetoothDeviceModel device) async {
    while (_reconnectAttempts < maxReconnectAttempts && !_isDeviceConnected) {
      _reconnectAttempts++;
      _logProvider?.addLog('Bluetooth', LogType.info, '自动重连尝试 $_reconnectAttempts/$maxReconnectAttempts');

      try {
        await connectToDevice(device);
        if (_isDeviceConnected) {
          _logProvider?.addLog('Bluetooth', LogType.success, '自动重连成功');
          break;
        }
      } catch (e) {
        _logProvider?.addLog('Bluetooth', LogType.error, '重连失败: $e');
      }

      if (_reconnectAttempts < maxReconnectAttempts && !_isDeviceConnected) {
        await Future.delayed(const Duration(seconds: 2));
      }
    }

    if (!_isDeviceConnected && _reconnectAttempts >= maxReconnectAttempts) {
      _logProvider?.addLog('Bluetooth', LogType.error, '自动重连失败，已达到最大重试次数');
    }
  }

  /// 检查权限状态
  Future<void> _checkPermission() async {
    _permissionStatus = await app_bluetooth.BluetoothService.checkBluetoothPermission();

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

  /// 开始扫描设备（真实扫描）
  Future<void> startScan() async {
    if (_isScanning) return;

    _isScanning = true;
    _scannedDevices = [];
    notifyListeners();

    _logProvider?.addLog('Bluetooth', LogType.info, '开始扫描蓝牙设备...');

    // 设置3秒超时
    _scanTimer = Timer(const Duration(seconds: 3), () {
      stopScan();
    });

    // 监听扫描结果
    _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      // 过滤弱信号设备并按信号强度排序
      final filteredDevices = results
          .where((r) => r.rssi >= minRssi)
          .map((r) => BluetoothDeviceModel.fromScanResult(r))
          .toList();

      // 按信号强度排序（从高到低）
      filteredDevices.sort((a, b) => b.rssi.compareTo(a.rssi));

      _scannedDevices = filteredDevices;
      _hasScanned = true;
      notifyListeners();
    });

    // 开始扫描
    try {
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 3),
      );
    } catch (e) {
      _logProvider?.addLog('Bluetooth', LogType.error, '扫描失败: $e');
      await stopScan();
    }
  }

  /// 停止扫描
  Future<void> stopScan() async {
    _scanTimer?.cancel();
    _scanTimer = null;

    await FlutterBluePlus.stopScan();
    _scanSubscription?.cancel();
    _scanSubscription = null;

    _isScanning = false;
    _logProvider?.addLog('Bluetooth', LogType.info, '扫描完成，找到 ${_scannedDevices.length} 个设备');
    notifyListeners();
  }

  /// 连接设备（真实连接）
  Future<void> connectToDevice(BluetoothDeviceModel device) async {
    if (device.flutterDevice == null) {
      _logProvider?.addLog('Bluetooth', LogType.error, '设备对象无效');
      return;
    }

    _logProvider?.addLog('Bluetooth', LogType.info, '正在连接 ${device.name}...');

    // 先断开之前已连接的设备
    if (_connectedDevice != null) {
      await disconnectDevice();
    }

    // 更新设备状态为连接中
    final index = _scannedDevices.indexWhere((d) => d.id == device.id);
    if (index != -1) {
      _scannedDevices[index] = _scannedDevices[index].copyWith(
        status: DeviceConnectionStatus.connecting,
      );
      notifyListeners();
    }

    try {
      // 连接设备
      await device.flutterDevice!.connect(
        timeout: const Duration(seconds: 10),
        autoConnect: false,
      );

      // 监听连接状态变化
      _connectionSubscription?.cancel();
      _connectionSubscription = device.flutterDevice!.connectionState.listen((state) {
        _handleConnectionStateChanged(state, device);
      });

      // 发现服务并获取 UUID
      await _discoverServices(device);

      // 更新为已连接状态
      if (index != -1) {
        _scannedDevices[index] = _scannedDevices[index].copyWith(
          status: DeviceConnectionStatus.connected,
          sentBytes: 0,
          receivedBytes: 0,
          connectionStability: 100.0,
        );
        _connectedDevice = _scannedDevices[index];
        _lastConnectedDevice = _scannedDevices[index];
        _isDeviceConnected = true;

        // 保存设备信息
        await DeviceStorageService.saveLastDevice(_connectedDevice!);
      }

      _logProvider?.addLog('Bluetooth', LogType.success, '已连接到 ${device.name}');
      notifyListeners();

    } catch (e) {
      _logProvider?.addLog('Bluetooth', LogType.error, '连接失败: $e');

      // 更新状态为断开
      if (index != -1) {
        _scannedDevices[index] = _scannedDevices[index].copyWith(
          status: DeviceConnectionStatus.disconnected,
        );
      }
      notifyListeners();
    }
  }

  /// 发现服务并获取 UUID
  /// 修正逻辑：先匹配服务 UUID，再查找特征
  Future<void> _discoverServices(BluetoothDeviceModel device) async {
    try {
      final services = await device.flutterDevice!.discoverServices();

      // 步骤1: 检查设备的服务 UUID 是否在预定义的 ELM327 UUID 列表中（服务级别匹配）
      for (final service in services) {
        final serviceUuid = service.uuid.str.toLowerCase();

        // 检查是否匹配默认 UUID
        if (serviceUuid == Elm327Uuids.notifyUuid.toLowerCase() ||
            serviceUuid == Elm327Uuids.writeUuid.toLowerCase()) {
          device.notifyUuid = Elm327Uuids.notifyUuid;
          device.writeUuid = Elm327Uuids.writeUuid;
          _logProvider?.addLog('Bluetooth', LogType.info, '匹配到默认 ELM327 UUID');
          return;
        }

        // 检查是否匹配 alternativeUuids
        for (final alt in Elm327Uuids.alternativeUuids) {
          if (serviceUuid == alt['notify']!.toLowerCase() ||
              serviceUuid == alt['write']!.toLowerCase()) {
            device.notifyUuid = alt['notify'];
            device.writeUuid = alt['write'];
            _logProvider?.addLog('Bluetooth', LogType.info, '匹配到 ELM327 备用 UUID: $alt');
            return;
          }
        }
      }

      // 步骤2: 如果没匹配，回退到从特征中查找
      for (final service in services) {
        for (final char in service.characteristics) {
          if (char.properties.notify && device.notifyUuid == null) {
            device.notifyUuid = char.uuid.str;
          }
          if ((char.properties.write || char.properties.writeWithoutResponse) &&
              device.writeUuid == null) {
            device.writeUuid = char.uuid.str;
          }
        }
      }

      // 默认值
      device.notifyUuid ??= Elm327Uuids.notifyUuid;
      device.writeUuid ??= Elm327Uuids.writeUuid;

      _logProvider?.addLog('Bluetooth', LogType.info, '服务 UUID - Notify: ${device.notifyUuid}, Write: ${device.writeUuid}');
    } catch (e) {
      _logProvider?.addLog('Bluetooth', LogType.warning, '发现服务失败，使用默认 UUID');
      device.notifyUuid = Elm327Uuids.notifyUuid;
      device.writeUuid = Elm327Uuids.writeUuid;
    }
  }

  /// 处理连接状态变化
  void _handleConnectionStateChanged(BluetoothConnectionState state, BluetoothDeviceModel device) {
    switch (state) {
      case BluetoothConnectionState.connected:
        _logProvider?.addLog('Bluetooth', LogType.success, '设备已连接: ${device.name}');
        break;
      case BluetoothConnectionState.disconnected:
        _logProvider?.addLog('Bluetooth', LogType.warning, '设备已断开: ${device.name}');
        _handleDisconnection();
        break;
      default:
        break;
    }
  }

  /// 处理断开连接
  void _handleDisconnection() {
    final wasConnected = _isDeviceConnected;
    final previousDevice = _connectedDevice;

    _connectedDevice = null;
    _isDeviceConnected = false;

    // 更新列表中的设备状态
    if (previousDevice != null) {
      final index = _scannedDevices.indexWhere((d) => d.id == previousDevice.id);
      if (index != -1) {
        _scannedDevices[index] = _scannedDevices[index].copyWith(
          status: DeviceConnectionStatus.disconnected,
        );
      }
    }

    notifyListeners();

    // 如果非手动断开，尝试自动重连
    if (wasConnected && previousDevice != null && !_isAutoReconnecting) {
      _logProvider?.addLog('Bluetooth', LogType.warning, '检测到异常断开，尝试自动重连...');
      _attemptReconnect(previousDevice);
    }
  }

  /// 断开连接
  Future<void> disconnectDevice() async {
    _connectionSubscription?.cancel();
    _connectionSubscription = null;

    if (_connectedDevice?.flutterDevice != null) {
      try {
        await _connectedDevice!.flutterDevice!.disconnect();
        _logProvider?.addLog('Bluetooth', LogType.warning, '已断开与 ${_connectedDevice!.name} 的连接');
      } catch (e) {
        _logProvider?.addLog('Bluetooth', LogType.error, '断开连接失败: $e');
      }
    }

    // 更新列表中的设备状态
    if (_connectedDevice != null) {
      final index = _scannedDevices.indexWhere((d) => d.id == _connectedDevice!.id);
      if (index != -1) {
        _scannedDevices[index] = _scannedDevices[index].copyWith(
          status: DeviceConnectionStatus.disconnected,
        );
      }
    }

    _connectedDevice = null;
    _isDeviceConnected = false;
    _reconnectAttempts = 0;
    notifyListeners();
  }

  /// 显示蓝牙未开启弹窗（供外部调用）
  bool get shouldShowBluetoothOffDialog {
    return _isInitialized && hasPermission && !_isBluetoothOn;
  }

  @override
  void dispose() {
    _adapterSubscription?.cancel();
    _scanSubscription?.cancel();
    _connectionSubscription?.cancel();
    _scanTimer?.cancel();
    _connectionSimulationTimer?.cancel();
    super.dispose();
  }
}
