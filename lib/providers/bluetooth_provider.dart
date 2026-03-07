import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fb;
import '../constants/bluetooth_constants.dart';
import '../models/bluetooth_device.dart';
import '../models/obd_data.dart';
import '../services/bluetooth_service.dart' as app_bluetooth;
import '../services/device_storage_service.dart';
import '../services/obd_service.dart';
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
  // 从 BluetoothConstants 引用最大重连次数
  bool _isAutoReconnecting = false;

  // OBD 相关
  final OBDDataProvider _obdDataProvider;
  OBDService? _obdService;
  fb.BluetoothCharacteristic? _writeCharacteristic;
  fb.BluetoothCharacteristic? _notifyCharacteristic;
  StreamSubscription<List<int>>? _obdNotificationSubscription;

  StreamSubscription<fb.BluetoothAdapterState>? _adapterSubscription;
  StreamSubscription<List<fb.ScanResult>>? _scanSubscription;
  StreamSubscription<fb.BluetoothConnectionState>? _connectionSubscription;
  Timer? _scanTimer;

  // 用户是否正在主动断开连接（避免在 disconnectDevice 中重复触发清理）
  bool _isManuallyDisconnecting = false;

  // 日志回调 - 降低耦合度
  void Function(String source, LogType type, String message)? _logCallback;

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

  /// 构造函数 - 通过依赖注入接收 OBDDataProvider 和 LogProvider
  BluetoothProvider({
    required OBDDataProvider obdDataProvider,
    required LogProvider logProvider,
  })  : _obdDataProvider = obdDataProvider {
    // 初始化日志回调
    _logCallback = (source, type, message) => logProvider.addLog(source, type, message);

    // 初始化 OBDService
    _obdService = OBDService(
      obdDataProvider: obdDataProvider,
      logCallback: _logCallback,
    );
    _logCallback?.call('OBD', LogType.info, 'OBDDataProvider 已关联');
  }

  /// 初始化蓝牙状态检测
  Future<void> initialize() async {
    if (_isInitialized) return;

    // 输出初始化日志
    _logCallback?.call('Bluetooth', LogType.info, '蓝牙服务初始化中...');

    // 初始检测
    await _checkPermission();
    await _checkBluetoothStatus();

    // 先加载上次设备
    await _loadLastDevice();

    // 监听蓝牙状态变化（必须在自动重连之前设置，确保状态回调能触发）
    _adapterSubscription = fb.FlutterBluePlus.adapterState.listen((state) {
      final wasOn = _isBluetoothOn;
      _isBluetoothOn = state == fb.BluetoothAdapterState.on;

      // 蓝牙状态变化时输出日志
      if (_isBluetoothOn && !wasOn) {
        _logCallback?.call('Bluetooth', LogType.success, '蓝牙已开启');
        // 蓝牙开启后自动扫描
        if (!_hasScanned && !_isScanning) {
          startScan();
        }
      } else if (!_isBluetoothOn && wasOn) {
        _logCallback?.call('Bluetooth', LogType.warning, '蓝牙已关闭');
      }

      notifyListeners();
    });

    // 如果上次有连接的设备且当前未连接，尝试自动重连
    if (_lastConnectedDevice != null && !_isDeviceConnected && _isBluetoothOn) {
      _logCallback?.call('Bluetooth', LogType.info, '尝试自动连接上次设备: ${_lastConnectedDevice!.name}');
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
      _logCallback?.call('Bluetooth', LogType.info, '已加载上次设备: ${device.name}');
      notifyListeners();
    }
  }

  /// 自动重连上次设备
  Future<void> _autoReconnectLastDevice() async {
    if (_lastConnectedDevice == null || _isAutoReconnecting) return;

    _isAutoReconnecting = true;

    // 开始扫描查找上次设备
    await startScan();

    // 等待扫描结果
    await Future.delayed(BluetoothConstants.autoReconnectWait);

    // 检查是否在扫描结果中找到设备（优先 ID 匹配）
    var foundDevice = _scannedDevices.where((d) => d.id == _lastConnectedDevice!.id).toList();

    // 如果 ID 匹配失败，尝试使用名称匹配（某些设备使用随机 MAC 地址）
    if (foundDevice.isEmpty && _lastConnectedDevice!.name.isNotEmpty) {
      foundDevice = _scannedDevices.where((d) => d.name == _lastConnectedDevice!.name).toList();
      if (foundDevice.isNotEmpty) {
        _logCallback?.call('Bluetooth', LogType.info, '通过名称匹配到设备: ${foundDevice.first.name}');
      }
    }

    if (foundDevice.isEmpty) {
      _logCallback?.call('Bluetooth', LogType.warning, '未找到上次设备: ${_lastConnectedDevice!.name}，请手动重试');
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
    int reconnectAttempts = 0;

    while (reconnectAttempts < BluetoothConstants.maxReconnectAttempts && !_isDeviceConnected) {
      reconnectAttempts++;
      _logCallback?.call('Bluetooth', LogType.info, '自动重连尝试 $reconnectAttempts/$BluetoothConstants.maxReconnectAttempts');

      try {
        await connectToDevice(device);
        if (_isDeviceConnected) {
          _logCallback?.call('Bluetooth', LogType.success, '自动重连成功');
          break;
        }
      } catch (e) {
        _logCallback?.call('Bluetooth', LogType.error, '重连失败: $e');
      }

      if (reconnectAttempts < BluetoothConstants.maxReconnectAttempts && !_isDeviceConnected) {
        await Future.delayed(BluetoothConstants.reconnectRetryInterval);
      }
    }

    if (!_isDeviceConnected && reconnectAttempts >= BluetoothConstants.maxReconnectAttempts) {
      _logCallback?.call('Bluetooth', LogType.error, '自动重连失败，已达到最大重试次数');
      // 连接失败，清除保存的设备信息，让用户重新选择
      // await DeviceStorageService.clearLastDevice();
      _lastConnectedDevice = null;
      // _logCallback?.call('Bluetooth', LogType.info, '已清除上次设备信息');
    }
  }

  /// 检查权限状态
  Future<void> _checkPermission() async {
    _permissionStatus = await app_bluetooth.BluetoothService.checkBluetoothPermission();

    switch (_permissionStatus) {
      case app_bluetooth.BluetoothPermissionStatus.granted:
        _logCallback?.call('Bluetooth', LogType.success, '蓝牙权限已获取');
        break;
      case app_bluetooth.BluetoothPermissionStatus.denied:
        _logCallback?.call('Bluetooth', LogType.warning, '蓝牙权限被拒绝');
        break;
      case app_bluetooth.BluetoothPermissionStatus.permanentlyDenied:
        _logCallback?.call('Bluetooth', LogType.error, '蓝牙权限已永久拒绝，请前往设置授权');
        break;
      case app_bluetooth.BluetoothPermissionStatus.unknown:
        _logCallback?.call('Bluetooth', LogType.info, '正在检测蓝牙权限...');
        break;
    }

    notifyListeners();
  }

  /// 检查蓝牙是否开启
  Future<void> _checkBluetoothStatus() async {
    _isBluetoothOn = await app_bluetooth.BluetoothService.isBluetoothEnabled();

    if (_isBluetoothOn) {
      _logCallback?.call('Bluetooth', LogType.success, '蓝牙已开启');
    } else {
      _logCallback?.call('Bluetooth', LogType.warning, '蓝牙未开启，请开启蓝牙');
    }

    notifyListeners();
  }

  /// 请求蓝牙权限
  Future<bool> requestPermission() async {
    _logCallback?.call('Bluetooth', LogType.info, '正在请求蓝牙权限...');
    _permissionStatus = await app_bluetooth.BluetoothService.requestBluetoothPermission();

    if (_permissionStatus == app_bluetooth.BluetoothPermissionStatus.granted) {
      _logCallback?.call('Bluetooth', LogType.success, '蓝牙权限已获取');
    } else {
      _logCallback?.call('Bluetooth', LogType.warning, '蓝牙权限授权失败');
    }

    notifyListeners();
    return _permissionStatus == app_bluetooth.BluetoothPermissionStatus.granted;
  }

  /// 刷新蓝牙状态
  Future<void> refreshBluetoothStatus() async {
    _logCallback?.call('Bluetooth', LogType.info, '正在刷新蓝牙状态...');
    await _checkPermission();
    await _checkBluetoothStatus();
  }

  /// 打开系统设置
  Future<void> openSettings() async {
    _logCallback?.call('Bluetooth', LogType.info, '正在打开系统设置...');
    await app_bluetooth.BluetoothService.openBluetoothSettings();
  }

  /// 开始扫描设备（真实扫描）
  Future<void> startScan() async {
    if (_isScanning) return;

    _isScanning = true;
    _scannedDevices = [];
    notifyListeners();

    _logCallback?.call('Bluetooth', LogType.info, '开始扫描蓝牙设备...');

    // 设置6秒超时
    _scanTimer = Timer(BluetoothConstants.scanTimeout, () {
      stopScan();
    });

    // 监听扫描结果
    _scanSubscription = fb.FlutterBluePlus.scanResults.listen((results) {
      // 过滤弱信号设备并按信号强度排序
      final filteredDevices = results
          .where((r) => r.rssi >= minRssi)
          .map((r) => BluetoothDeviceModel.fromScanResult(r))
          .toList();

      // 按设备优先级排序，再按信号强度，最后按名称
      filteredDevices.sort((a, b) {
        int aPriority = _getDevicePriority(a.name);
        int bPriority = _getDevicePriority(b.name);
        if (aPriority != bPriority) return aPriority.compareTo(bPriority);
        if (a.rssi != b.rssi) return b.rssi.compareTo(a.rssi);
        return a.name.compareTo(b.name);
      });

      // // 输出扫描到的设备详情
      // for (final device in filteredDevices) {
      //   _logCallback?.call('Bluetooth', LogType.info, '扫描到设备: ${device.name} (${device.id}) RSSI: ${device.rssi}');
      // }

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
      await fb.FlutterBluePlus.startScan(
        timeout: BluetoothConstants.scanTimeout,
      );
    } catch (e) {
      _logCallback?.call('Bluetooth', LogType.error, '扫描失败: $e');
      await stopScan();
    }
  }

  /// 停止扫描
  Future<void> stopScan() async {
    _scanTimer?.cancel();
    _scanTimer = null;

    await fb.FlutterBluePlus.stopScan();
    _scanSubscription?.cancel();
    _scanSubscription = null;

    _isScanning = false;
    _logCallback?.call('Bluetooth', LogType.info, '扫描完成，找到 ${_scannedDevices.length} 个设备');
    notifyListeners();
  }

  /// 获取设备优先级（数字越小越优先）
  /// 优先级: 1=OBD设备, 2=ELM适配器, 3=诊断工具, 4=其他
  int _getDevicePriority(String deviceName) {
    String name = deviceName.toUpperCase();
    if (name.contains('OBD') || name.contains('OBDII') || name.contains('OBD2')) {
      return 1;
    }
    if (name.contains('ELM') || name.contains('ELM327') || name.contains('VAG') ||
        name.contains('VCDS') || name.contains('SCAN') || name.contains('CAR')) {
      return 2;
    }
    if (name.contains('DIAG') || name.contains('DIAGNOSTIC') || name.contains('TOOL') ||
        name.contains('PROTOCOL') || name.contains('ADAPTER')) {
      return 3;
    }
    return 4;
  }

  /// 连接设备（真实连接）
  Future<void> connectToDevice(BluetoothDeviceModel device) async {
    // 前置检查
    if (device.flutterDevice == null) {
      _logCallback?.call('Bluetooth', LogType.error, '设备对象无效');
      return;
    }

    _logCallback?.call('Bluetooth', LogType.info, '正在连接 ${device.name}...');

    // 断开旧设备
    if (_connectedDevice != null) {
      await _disconnectInternal();
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
      _logCallback?.call('Bluetooth', LogType.error, '设备对象无效，无法启动 OBD 会话');
      return;
    }

    try {
      // 发现服务并匹配特征
      final services = await device.flutterDevice!.discoverServices();
      await _discoverAndMatchCharacteristics(device, services);

      // 初始化 ELM327
      await _initializeElm327();

      // 启动 OBD 轮询
      _obdService?.startPolling();

      // 更新为已连接状态
      _updateDeviceConnectedStatus(device, deviceIndex);

    } catch (e) {
      _logCallback?.call('Bluetooth', LogType.error, '启动 OBD 会话失败: $e');
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
      timeout: BluetoothConstants.connectionTimeout,
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
    List<fb.BluetoothService> services,
  ) async {
    _logCallback?.call('Bluetooth', LogType.info, '开始发现服务...');
    _logCallback?.call('Bluetooth', LogType.info, '发现 ${services.length} 个服务');


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

    _logCallback?.call('Bluetooth', LogType.success, '已连接到 ${device.name}');
    notifyListeners();
  }

  /// 处理连接失败
  void _handleConnectionError(BluetoothDeviceModel device, int index, Object error) {
    _logCallback?.call('Bluetooth', LogType.error, '连接失败: $error');

    // 调用清理方法，确保资源完全释放
    // _cleanupConnection 内部会调用 notifyListeners()
    _cleanupConnection(shouldReconnect: false);
  }

  /// ========== ELM327 初始化（增加详细日志） ==========
  Future<void> _initializeElm327() async {
    _logCallback?.call('ELM327', LogType.info, '开始初始化 ELM327...');

    try {
      _logCallback?.call('ELM327', LogType.info, '发送 ATZ (复位)...');
      await _obdService?.sendCommand("ATZ");
      await Future.delayed(BluetoothConstants.elm327InitWait);

      _logCallback?.call('ELM327', LogType.info, '发送 ATE0 (关闭回显)...');
      await _obdService?.sendCommand("ATE0");
      await Future.delayed(BluetoothConstants.obdCommandInterval);

      _logCallback?.call('ELM327', LogType.info, '发送 ATL0 (关闭行尾)...');
      await _obdService?.sendCommand("ATL0");
      await Future.delayed(BluetoothConstants.obdCommandInterval);

      _logCallback?.call('ELM327', LogType.info, '发送 ATH0 (关闭头信息)...');
      await _obdService?.sendCommand("ATH0");
      await Future.delayed(BluetoothConstants.obdCommandInterval);

      _logCallback?.call('ELM327', LogType.info, '发送 ATSP0 (自动协议)...');
      await _obdService?.sendCommand("ATSP0");
      await Future.delayed(BluetoothConstants.obdCommandInterval);

      _logCallback?.call('ELM327', LogType.success, 'ELM327 初始化完成');
    } catch (e) {
      _logCallback?.call('ELM327', LogType.error, '初始化失败: $e');
      rethrow;
    }
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
      _notifyCharacteristic = notifyChar;
      // 设置 OBDService 的写入特征
      _obdService?.setWriteCharacteristic(writeChar);
      _logCallback?.call('Bluetooth', LogType.success, '匹配写入特征: ${_writeCharacteristic?.uuid.str}');

      // 订阅通知
      try {
        await notifyChar.setNotifyValue(true);
        _logCallback?.call('Bluetooth', LogType.info, '已订阅通知特征');
        _obdNotificationSubscription?.cancel();
        _obdNotificationSubscription = notifyChar.lastValueStream.listen(
          (value) => _obdService?.handleNotification(value),
          onError: (e) => _logCallback?.call('Bluetooth', LogType.error, '通知监听数据错误: $e'),
        );
      } catch (e) {
        _logCallback?.call('Bluetooth', LogType.error, '订阅通知失败: $e');
      }
      return;
    }
    _logCallback?.call('Bluetooth', LogType.error, '未匹配到写入&通知service');
  }

  /// 处理连接状态变化
  Future<void> _handleConnectionStateChanged(fb.BluetoothConnectionState state, BluetoothDeviceModel device) async {
    switch (state) {
      case fb.BluetoothConnectionState.connected:
        _logCallback?.call('Bluetooth', LogType.success, '设备已连接: ${device.name}，正在启动 OBD 会话...');

        // 查找设备在列表中的索引
        final index = _scannedDevices.indexWhere((d) => d.id == device.id || d.name == device.name);

        // 启动完整的 OBD 会话初始化流程
        await _startObdSession(device, index);
        break;
      case fb.BluetoothConnectionState.disconnected:
        _logCallback?.call('Bluetooth', LogType.warning, '设备已断开: ${device.name}');
        _handleDisconnection();
        break;
      default:
        break;
    }
  }

  /// 清理连接资源（供内部使用）
  ///
  /// [shouldReconnect] - 清理后是否尝试自动重连
  void _cleanupConnection({required bool shouldReconnect}) {
    final previousDevice = _connectedDevice;
    final wasConnected = _isDeviceConnected;

    // 停止 OBD 轮询
    _obdService?.stopPolling();

    // 取消通知监听
    _obdNotificationSubscription?.cancel();
    _obdNotificationSubscription = null;

    // 取消连接状态监听
    _connectionSubscription?.cancel();
    _connectionSubscription = null;

    // 取消通知订阅（静默失败）
    if (_notifyCharacteristic != null) {
      _notifyCharacteristic!.setNotifyValue(false).catchError((_) {});
      _notifyCharacteristic = null;
    }

    // 更新设备列表状态
    if (previousDevice != null) {
      final index = _scannedDevices.indexWhere((d) => d.id == previousDevice.id);
      if (index != -1) {
        _scannedDevices[index] = _scannedDevices[index].copyWith(
          status: DeviceConnectionStatus.disconnected,
        );
      }
    }

    // 重置状态
    _connectedDevice = null;
    _isDeviceConnected = false;
    _isManuallyDisconnecting = false;

    // 重置 OBD 数据
    _obdDataProvider.resetData();

    notifyListeners();

    // 如果是异常断开且不是自动重连中，尝试自动重连
    // 只有在非主动断开 且 之前已连接 且 有之前设备 时才重连
    if (shouldReconnect && wasConnected && previousDevice != null && !_isAutoReconnecting) {
      _logCallback?.call('Bluetooth', LogType.warning, '检测到异常断开，尝试自动重连...');
      _attemptReconnect(previousDevice);
    }
  }

  /// 处理断开连接（由蓝牙状态监听器触发）
  void _handleDisconnection() {
    // 如果是用户主动断开，这里不需要做任何事
    // 因为 disconnectDevice 已经处理完了
    if (_isManuallyDisconnecting) {
      return;
    }
    // 被动断开，尝试自动重连
    _cleanupConnection(shouldReconnect: true);
  }

  /// 内部断开连接（不设置用户主动断开标志）
  /// 用于在连接新设备前断开旧设备
  Future<void> _disconnectInternal() async {
    final deviceToDisconnect = _connectedDevice;
    final deviceName = deviceToDisconnect?.name ?? 'Unknown';

    _logCallback?.call('Bluetooth', LogType.info, '正在断开旧设备: $deviceName...');

    // 使用 shouldReconnect = false 进行清理
    _cleanupConnection(shouldReconnect: false);

    // 断开蓝牙设备
    if (deviceToDisconnect?.flutterDevice != null) {
      try {
        await deviceToDisconnect!.flutterDevice!.disconnect();
      } catch (e) {
        // 静默处理断开错误
      }
    }
  }

  /// 断开连接（由用户手动触发）
  Future<void> disconnectDevice() async {
    // 先保存设备引用（用于调用实际的 disconnect）
    final deviceToDisconnect = _connectedDevice;
    final deviceName = deviceToDisconnect?.name ?? 'Unknown';

    _logCallback?.call('Bluetooth', LogType.info, '开始断开连接...');

    // 设置标志，防止状态回调重复处理
    _isManuallyDisconnecting = true;

    // 清理所有资源（不自动重连）
    _cleanupConnection(shouldReconnect: false);

    // 主动断开蓝牙设备（此时状态已清理，即使触发回调也无害）
    if (deviceToDisconnect?.flutterDevice != null) {
      try {
        await deviceToDisconnect!.flutterDevice!.disconnect();
        _logCallback?.call('Bluetooth', LogType.warning, '已断开与 $deviceName 的连接');
      } catch (e) {
        _logCallback?.call('Bluetooth', LogType.error, '断开连接失败: $e');
      }
    }
  }

  /// 清除上次保存的设备信息
  Future<void> clearLastDevice() async {
    await DeviceStorageService.clearLastDevice();
    _lastConnectedDevice = null;
    _logCallback?.call('Bluetooth', LogType.info, '已清除上次设备信息');
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
    _obdService?.dispose();
    super.dispose();
  }
}
