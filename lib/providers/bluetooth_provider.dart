import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fb;
import '../models/bluetooth_device.dart';
import '../models/obd_data.dart';
import '../services/bluetooth_service.dart' as app_bluetooth;
import '../services/device_storage_service.dart';
import 'log_provider.dart';
import 'obd_data_provider.dart';

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

  // OBD 相关
  OBDDataProvider? _obdDataProvider;
  BluetoothCharacteristic? _writeCharacteristic;
  BluetoothCharacteristic? _notifyCharacteristic;
  StreamSubscription<List<int>>? _obdNotificationSubscription;
  Timer? _obdPollingTimer;
  static const int obdCommandInterval = 200;

  // OBD PID 列表（查询模式 01）
  static const List<String> obdPids = [
    '010C', // 发动机转速 RPM
    '010D', // 车速 VSS
    '0105', // 冷却液温度
    '0111', // 节气门位置 TP
    '010F', // 进气温度 IAT
    '010B', // 进气歧管压力 MAP
    '0104', // 引擎负荷
    '0145', // 绝对节气门位置
    '0142', // 控制模块电压
  ];

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

  /// 设置 OBDDataProvider 引用
  void setOBDDataProvider(OBDDataProvider provider) {
    _obdDataProvider = provider;
    _logProvider?.addLog('OBD', LogType.info, 'OBDDataProvider 已关联');
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
    await Future.delayed(const Duration(seconds: 5));

    // 检查是否在扫描结果中找到设备（优先 ID 匹配）
    var foundDevice = _scannedDevices.where((d) => d.id == _lastConnectedDevice!.id).toList();

    // 如果 ID 匹配失败，尝试使用名称匹配（某些设备使用随机 MAC 地址）
    if (foundDevice.isEmpty && _lastConnectedDevice!.name.isNotEmpty) {
      foundDevice = _scannedDevices.where((d) => d.name == _lastConnectedDevice!.name).toList();
      if (foundDevice.isNotEmpty) {
        _logProvider?.addLog('Bluetooth', LogType.info, '通过名称匹配到设备: ${foundDevice.first.name}');
      }
    }

    if (foundDevice.isEmpty) {
      _logProvider?.addLog('Bluetooth', LogType.warning, '未找到上次设备: ${_lastConnectedDevice!.name}，请手动重试');
      // 保留设备信息，让用户可以手动点击重连
      _isAutoReconnecting = false;
      notifyListeners();
      return;
    }

    // 使用扫描到的设备（有 flutterDevice 引用）
    final device = foundDevice.first;
    await _attemptReconnect(device);

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
      // 连接失败，清除保存的设备信息，让用户重新选择
      await DeviceStorageService.clearLastDevice();
      _lastConnectedDevice = null;
      _logProvider?.addLog('Bluetooth', LogType.info, '已清除上次设备信息');
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

    // 设置6秒超时
    _scanTimer = Timer(const Duration(seconds: 6), () {
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

      // 输出扫描到的设备详情
      for (final device in filteredDevices) {
        _logProvider?.addLog('Bluetooth', LogType.info, '扫描到设备: ${device.name} (${device.id}) RSSI: ${device.rssi}');
      }

      _scannedDevices = filteredDevices;

      // 检查已连接设备是否在扫描列表中，如果在则更新状态
      if (_connectedDevice != null) {
        final connectedIndex = _scannedDevices.indexWhere(
          (d) => d.id == _connectedDevice!.id || d.name == _connectedDevice!.name,
        );
        if (connectedIndex != -1) {
          _scannedDevices[connectedIndex] = _scannedDevices[connectedIndex].copyWith(
            status: DeviceConnectionStatus.connected,
          );
        }
      }

      _hasScanned = true;
      notifyListeners();
    });

    // 开始扫描
    try {
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 6),
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
    // 前置检查
    if (device.flutterDevice == null) {
      _logProvider?.addLog('Bluetooth', LogType.error, '设备对象无效');
      return;
    }

    _logProvider?.addLog('Bluetooth', LogType.info, '正在连接 ${device.name}...');

    // 断开旧设备
    if (_connectedDevice != null) {
      await disconnectDevice();
    }

    // 更新状态为连接中
    final index = _scannedDevices.indexWhere((d) => d.id == device.id);
    _updateDeviceConnectingStatus(device, index);

    try {
      // 连接蓝牙设备并监听状态变化
      await _connectBluetoothDevice(device);

      // 注意：连接成功后的初始化逻辑在 _handleConnectionStateChanged 中统一处理
      // 这样可以确保任何连接成功（包括自动重连）都会执行完整的初始化流程

    } catch (e) {
      _handleConnectionError(device, index, e);
    }
  }

  /// 启动 OBD 会话（连接成功后的完整初始化流程）
  /// 由 _handleConnectionStateChanged 在连接成功时调用
  Future<void> _startObdSession(BluetoothDeviceModel device, int deviceIndex) async {
    if (device.flutterDevice == null) {
      _logProvider?.addLog('Bluetooth', LogType.error, '设备对象无效，无法启动 OBD 会话');
      return;
    }

    try {
      // 发现服务并匹配特征
      final services = await device.flutterDevice!.discoverServices();
      await _discoverAndMatchCharacteristics(device, services);

      // 初始化 ELM327
      await _initializeElm327();

      // 启动 OBD 轮询
      _startObdPolling();

      // 更新为已连接状态
      _updateDeviceConnectedStatus(device, deviceIndex);

    } catch (e) {
      _logProvider?.addLog('Bluetooth', LogType.error, '启动 OBD 会话失败: $e');
      _handleConnectionError(device, deviceIndex, e);
    }
  }

  /// 更新设备状态为连接中
  void _updateDeviceConnectingStatus(BluetoothDeviceModel device, int index) {
    if (index != -1) {
      _scannedDevices[index] = _scannedDevices[index].copyWith(
        status: DeviceConnectionStatus.connecting,
      );
      notifyListeners();
    }
  }

  /// 连接蓝牙设备
  Future<void> _connectBluetoothDevice(BluetoothDeviceModel device) async {
    await device.flutterDevice!.connect(
      timeout: const Duration(seconds: 6),
      autoConnect: true,
    );

    // 监听连接状态变化
    _connectionSubscription?.cancel();
    _connectionSubscription = device.flutterDevice!.connectionState.listen((state) {
      _handleConnectionStateChanged(state, device);
    });
  }

  /// 发现服务并匹配特征
  Future<void> _discoverAndMatchCharacteristics(
    BluetoothDeviceModel device,
    List<BluetoothService> services,
  ) async {
    _logProvider?.addLog('Bluetooth', LogType.info, '开始发现服务...');
    _logProvider?.addLog('Bluetooth', LogType.info, '发现 ${services.length} 个服务');


    final characteristics = services.expand((s) => s.characteristics).toList();
    _trySmartMatching(characteristics);
  }

  /// 更新为已连接状态
  Future<void> _updateDeviceConnectedStatus(BluetoothDeviceModel device, int index) async {
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
    _logProvider?.addLog('OBD', LogType.success, 'OBD 数据流已启动');
    notifyListeners();
  }

  /// 处理连接失败
  void _handleConnectionError(BluetoothDeviceModel device, int index, Object error) {
    _logProvider?.addLog('Bluetooth', LogType.error, '连接失败: $error');

    // 更新状态为断开
    if (index != -1) {
      _scannedDevices[index] = _scannedDevices[index].copyWith(
        status: DeviceConnectionStatus.disconnected,
      );
    }
    notifyListeners();
  }

  /// ========== ELM327 初始化（增加详细日志） ==========
  Future<void> _initializeElm327() async {
    _logProvider?.addLog('ELM327', LogType.info, '开始初始化 ELM327...');

    try {
      _logProvider?.addLog('ELM327', LogType.info, '发送 ATZ (复位)...');
      await _sendObdCommand("ATZ");
      await Future.delayed(const Duration(milliseconds: 1000));

      _logProvider?.addLog('ELM327', LogType.info, '发送 ATE0 (关闭回显)...');
      await _sendObdCommand("ATE0");
      await Future.delayed(const Duration(milliseconds: obdCommandInterval));

      _logProvider?.addLog('ELM327', LogType.info, '发送 ATL0 (关闭行尾)...');
      await _sendObdCommand("ATL0");
      await Future.delayed(const Duration(milliseconds: obdCommandInterval));

      _logProvider?.addLog('ELM327', LogType.info, '发送 ATH0 (关闭头信息)...');
      await _sendObdCommand("ATH0");
      await Future.delayed(const Duration(milliseconds: obdCommandInterval));

      _logProvider?.addLog('ELM327', LogType.info, '发送 ATSP0 (自动协议)...');
      await _sendObdCommand("ATSP0");
      await Future.delayed(const Duration(milliseconds: obdCommandInterval));

      _logProvider?.addLog('ELM327', LogType.success, 'ELM327 初始化完成');
    } catch (e) {
      _logProvider?.addLog('ELM327', LogType.error, '初始化失败: $e');
      rethrow;
    }
  }

  /// ========== 发送 OBD 命令（增加日志） ==========
  Future<void> _sendObdCommand(String command) async {
    if (_writeCharacteristic == null) {
      _logProvider?.addLog('OBD', LogType.warning, '写入特征为空，跳过命令: $command');
      return;
    }

    try {
      final bytes = utf8.encode("$command\r");
      await _writeCharacteristic!.write(bytes, withoutResponse: false);
      _logProvider?.addLog('OBD', LogType.info, '发送命令: $command');
    } catch (e) {
      _logProvider?.addLog('OBD', LogType.error, '发送命令失败: $command, 错误: $e');
    }
  }

  /// ========== 处理 OBD 通知（增加详细日志） ==========
  void _handleObdNotification(List<int> value) {
    if (value.isEmpty) {
      _logProvider?.addLog('OBD', LogType.warning, '收到空数据');
      return;
    }

    try {
      final response = utf8.decode(value, allowMalformed: true).trim();
      _logProvider?.addLog('OBD', LogType.info, '收到原始数据: $response');
      _processObdResponse(response);
    } catch (e) {
      _logProvider?.addLog('OBD', LogType.error, '解析数据失败: $e, 原始数据: $value');
    }
  }

  /// ========== 解析 OBD 响应（增加详细日志） ==========
  void _processObdResponse(String response) {
    // 过滤 ELM327 提示符
    if (response.startsWith(">")) {
      _logProvider?.addLog('OBD', LogType.info, '跳过 ELM327 提示符');
      return;
    }

    if (response.isEmpty) {
      _logProvider?.addLog('OBD', LogType.info, '跳过空响应');
      return;
    }

    // 非标准 OBD 响应（非 41 xx yy 格式）
    if (!response.startsWith("41")) {
      _logProvider?.addLog('OBD', LogType.warning, '非标准 OBD 响应: $response');
      return;
    }

    final parts = response.split(" ").where((s) => s.isNotEmpty).toList();
    if (parts.length < 3) {
      _logProvider?.addLog('OBD', LogType.warning, 'OBD 数据长度不足: $response');
      return;
    }

    final pid = parts[1];
    _logProvider?.addLog('OBD', LogType.info, '解析 PID: $pid, 原始数据: $response');

    switch (pid) {
      case "0C": // RPM = ((A*256)+B)/4
        if (parts.length >= 4) {
          final a = int.tryParse(parts[2], radix: 16) ?? 0;
          final b = int.tryParse(parts[3], radix: 16) ?? 0;
          final rpm = ((a * 256) + b) ~/ 4;
          _logProvider?.addLog('OBD', LogType.info, 'RPM: $rpm');
          _obdDataProvider?.updateRealTimeData(rpm: rpm);
        }
        break;
      case "0D": // 车速
        if (parts.length >= 3) {
          final speed = int.tryParse(parts[2], radix: 16) ?? 0;
          _logProvider?.addLog('OBD', LogType.info, '车速: $speed km/h');
          _obdDataProvider?.updateRealTimeData(speed: speed);
        }
        break;
      case "05": // 冷却液温度 = A-40
        if (parts.length >= 3) {
          final temp = int.tryParse(parts[2], radix: 16) ?? 0;
          final celsius = temp - 40;
          _logProvider?.addLog('OBD', LogType.info, '冷却液温度: $celsius°C');
          _obdDataProvider?.updateRealTimeData(coolantTemp: celsius);
        }
        break;
      case "11": // 节气门位置 = A*100/255
        if (parts.length >= 3) {
          final position = int.tryParse(parts[2], radix: 16) ?? 0;
          final percent = (position * 100) ~/ 255;
          _logProvider?.addLog('OBD', LogType.info, '节气门位置: $percent%');
          _obdDataProvider?.updateRealTimeData(throttle: percent);
        }
        break;
      case "0F": // 进气温度 = A-40
        if (parts.length >= 3) {
          final temp = int.tryParse(parts[2], radix: 16) ?? 0;
          final celsius = temp - 40;
          _logProvider?.addLog('OBD', LogType.info, '进气温度: $celsius°C');
          _obdDataProvider?.updateRealTimeData(intakeTemp: celsius);
        }
        break;
      case "0B": // 进气歧管压力
        if (parts.length >= 3) {
          final pressure = int.tryParse(parts[2], radix: 16) ?? 0;
          _logProvider?.addLog('OBD', LogType.info, '进气歧管压力: $pressure kPa');
          _obdDataProvider?.updateRealTimeData(pressure: pressure);
        }
        break;
      case "04": // 引擎负荷 = A*100/255
        if (parts.length >= 3) {
          final load = int.tryParse(parts[2], radix: 16) ?? 0;
          final percent = (load * 100) ~/ 255;
          _logProvider?.addLog('OBD', LogType.info, '引擎负荷: $percent%');
          _obdDataProvider?.updateRealTimeData(load: percent);
        }
        break;
      case "45": // 绝对节气门位置 = A*100/255
        if (parts.length >= 3) {
          final position = int.tryParse(parts[2], radix: 16) ?? 0;
          final percent = (position * 100) ~/ 255;
          _logProvider?.addLog('OBD', LogType.info, '绝对节气门位置: $percent%');
          _obdDataProvider?.updateRealTimeData(throttle: percent);
        }
        break;
      case "42": // 控制模块电压 = ((A*256)+B)/1000
        if (parts.length >= 4) {
          final a = int.tryParse(parts[2], radix: 16) ?? 0;
          final b = int.tryParse(parts[3], radix: 16) ?? 0;
          final voltage = ((a * 256) + b) / 1000.0;
          _logProvider?.addLog('OBD', LogType.info, '电压: ${voltage.toStringAsFixed(2)}V');
          _obdDataProvider?.updateRealTimeData(voltage: voltage);
        }
        break;
      default:
        _logProvider?.addLog('OBD', LogType.info, '未知的 PID: $pid');
    }
  }

  /// ========== OBD 轮询（增加日志） ==========
  void _startObdPolling() {
    _logProvider?.addLog('OBD', LogType.info, '启动 OBD 轮询...');

    _obdPollingTimer?.cancel();
    int currentPidIndex = 0;

    _obdPollingTimer = Timer.periodic(
      Duration(milliseconds: obdCommandInterval),
      (_) async {
        if (!_isDeviceConnected) {
          _logProvider?.addLog('OBD', LogType.warning, '设备已断开，停止轮询');
          _stopObdPolling();
          return;
        }

        if (_writeCharacteristic == null) {
          _logProvider?.addLog('OBD', LogType.warning, '写入特征为空');
          return;
        }

        final command = obdPids[currentPidIndex];
        await _sendObdCommand(command);
        currentPidIndex = (currentPidIndex + 1) % obdPids.length;
      },
    );

    _logProvider?.addLog('OBD', LogType.success, 'OBD 轮询已启动');
  }

  void _stopObdPolling() {
    _obdPollingTimer?.cancel();
    _obdPollingTimer = null;
    _logProvider?.addLog('OBD', LogType.info, 'OBD 轮询已停止');
  }


  Future<void> _trySmartMatching(List<fb.BluetoothCharacteristic> characteristics) async {
    fb.BluetoothCharacteristic? notifyChar;
    fb.BluetoothCharacteristic? writeChar;

    for (final char in characteristics) {
      if (notifyChar == null && char.properties.notify) {
        notifyChar = char;
      } else if (writeChar == null && (char.properties.write || char.properties.writeWithoutResponse)) {
        writeChar = char;
      }
    }

    if (notifyChar != null && writeChar != null) {
      _writeCharacteristic = writeChar;
      _logProvider?.addLog('Bluetooth', LogType.success, '匹配写入特征: ${_writeCharacteristic?.uuid.str}');

      _logProvider?.addLog('Bluetooth', LogType.success, '智能匹配通知特征: ${notifyChar.uuid.str}');

      // 订阅通知
      try {
        await notifyChar.setNotifyValue(true);
        _logProvider?.addLog('Bluetooth', LogType.info, '已订阅通知特征');
        _obdNotificationSubscription?.cancel();
        _obdNotificationSubscription = notifyChar.lastValueStream.listen(
          _handleObdNotification,
          onError: (e) => _logProvider?.addLog('Bluetooth', LogType.error, '通知监听数据错误: $e'),
        );
      } catch (e) {
        _logProvider?.addLog('Bluetooth', LogType.error, '订阅通知失败: $e');
      }
      return;
    }
    _logProvider?.addLog('Bluetooth', LogType.error, '未匹配到写入&通知service');
  }

  /// 处理连接状态变化
  Future<void> _handleConnectionStateChanged(BluetoothConnectionState state, BluetoothDeviceModel device) async {
    switch (state) {
      case BluetoothConnectionState.connected:
        _logProvider?.addLog('Bluetooth', LogType.success, '设备已连接: ${device.name}，正在启动 OBD 会话...');

        // 查找设备在列表中的索引
        final index = _scannedDevices.indexWhere((d) => d.id == device.id || d.name == device.name);

        // 启动完整的 OBD 会话初始化流程
        await _startObdSession(device, index);
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

    // 停止 OBD 轮询
    _stopObdPolling();
    _logProvider?.addLog('OBD', LogType.warning, 'OBD 轮询已停止（异常断开）');

    // 重置数据
    _obdDataProvider?.resetData();
    _logProvider?.addLog('OBD', LogType.warning, 'OBD 数据已重置（异常断开）');

    // 如果非手动断开，尝试自动重连
    if (wasConnected && previousDevice != null && !_isAutoReconnecting) {
      _logProvider?.addLog('Bluetooth', LogType.warning, '检测到异常断开，尝试自动重连...');
      _attemptReconnect(previousDevice);
    }
  }

  /// 断开连接
  Future<void> disconnectDevice() async {
    _logProvider?.addLog('Bluetooth', LogType.info, '开始断开连接...');

    // 停止 OBD 轮询
    _stopObdPolling();
    _logProvider?.addLog('OBD', LogType.info, 'OBD 轮询已停止');

    // 取消通知监听
    _obdNotificationSubscription?.cancel();
    _obdNotificationSubscription = null;

    // 取消通知订阅
    if (_notifyCharacteristic != null) {
      try {
        await _notifyCharacteristic!.setNotifyValue(false);
        _logProvider?.addLog('Bluetooth', LogType.info, '已取消通知订阅');
      } catch (e) {
        _logProvider?.addLog('Bluetooth', LogType.warning, '取消通知订阅失败: $e');
      }
    }

    // 通知 OBDDataProvider 重置数据为默认值
    _obdDataProvider?.resetData();
    _logProvider?.addLog('OBD', LogType.info, 'OBD 数据已重置');

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
    _obdNotificationSubscription?.cancel();
    _scanTimer?.cancel();
    _connectionSimulationTimer?.cancel();
    _obdPollingTimer?.cancel();
    super.dispose();
  }
}
