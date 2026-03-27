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
import 'loggable.dart';
import 'obd_data_provider.dart';

/// 蓝牙状态 Provider - 管理蓝牙权限和状态
class BluetoothProvider extends ChangeNotifier {
  app_bluetooth.BluetoothPermissionStatus _permissionStatus =
      app_bluetooth.BluetoothPermissionStatus.unknown;
  bool _isBluetoothOn = false;
  bool _isInitialized = false;

  // 扫描相关
  bool _isScanning = false;
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
  Timer? _rssiMonitorTimer;

  // 日志回调
  late final void Function(String source, LogType type, String message)
      _logCallback;

  // 过滤阈值
  static const int minRssi = -90; // 过滤弱信号设备

  // Getter
  bool get isBluetoothOn => _isBluetoothOn;
  bool get hasPermission =>
      _permissionStatus == app_bluetooth.BluetoothPermissionStatus.granted;
  bool get isDeviceConnected => _connectedDevice != null;
  bool get isScanning => _isScanning;
  List<BluetoothDeviceModel> get scannedDevices => _scannedDevices;
  BluetoothDeviceModel? get connectedDevice => _connectedDevice;
  BluetoothDeviceModel? get lastConnectedDevice => _lastConnectedDevice;

  /// 构造函数 - 通过依赖注入接收 OBDDataProvider 和 LogProvider
  BluetoothProvider({
    required OBDDataProvider obdDataProvider,
    required LogProvider logProvider,
  }) : _obdDataProvider = obdDataProvider {
    // 初始化日志回调
    _logCallback = createLogger(logProvider);

    // 初始化 OBDService
    _obdService = OBDService(
      obdDataProvider: obdDataProvider,
      logCallback: _logCallback,
    );
  }

  /// 初始化蓝牙状态检测
  Future<void> initialize() async {
    if (_isInitialized) return;

    // 输出初始化日志
    _logCallback?.call('Bluetooth', LogType.info, '蓝牙服务初始化中...');

    // 先取消已存在的订阅，避免内存泄漏和重复监听
    await _adapterSubscription?.cancel();
    _adapterSubscription = null;

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
        if (!_isScanning) {
          startScan();
        }
      } else if (!_isBluetoothOn && wasOn) {
        _logCallback?.call('Bluetooth', LogType.warning, '蓝牙已关闭');
      }

      notifyListeners();
    });

    // 如果上次有连接的设备且当前未连接，尝试自动重连
    if (_lastConnectedDevice != null &&
        _connectedDevice == null &&
        _isBluetoothOn) {
      await _autoReconnectLastDevice();
    }

    _isInitialized = true;
    notifyListeners();
  }

  /// 加载上次连接的设备
  Future<void> _loadLastDevice() async {
    final device = await DeviceStorageService.loadLastDevice();
    _logCallback?.call('Bluetooth', LogType.info,
        '从文件加载上次连接的设备: ${device?.name} ${device?.id}');
    if (device != null) {
      _lastConnectedDevice = device;
      notifyListeners();
    }
  }

  /// 自动重连上次设备（事件驱动：发现目标设备即停止扫描并连接，不再盲等）
  Future<void> _autoReconnectLastDevice() async {
    if (_lastConnectedDevice == null ||
        _isAutoReconnecting ||
        !_isBluetoothOn) {
      _logCallback?.call('Bluetooth', LogType.warning, '当前状态无法自动重连');
      return;
    }
    _isAutoReconnecting = true;

    final completer = Completer<BluetoothDeviceModel?>();

    // 独立订阅扫描结果，不干扰 startScan() 内部对 _scannedDevices 的更新
    StreamSubscription<List<fb.ScanResult>>? autoConnectSub;
    autoConnectSub = fb.FlutterBluePlus.scanResults.listen((results) {
      if (completer.isCompleted) return;

      final candidates = results
          .where((r) =>
              r.rssi >= minRssi && r.advertisementData.advName.isNotEmpty)
          .map((r) => BluetoothDeviceModel.fromScanResult(r))
          .toList();

      // 优先 ID 匹配，备选名称匹配（兼容随机 MAC 地址设备）
      BluetoothDeviceModel? found =
          candidates.where((d) => d.id == _lastConnectedDevice!.id).firstOrNull;
      if (found == null && _lastConnectedDevice!.name.isNotEmpty) {
        found = candidates
            .where((d) => d.name == _lastConnectedDevice!.name)
            .firstOrNull;
        if (found != null) {
          _logCallback?.call(
              'Bluetooth', LogType.info, '通过名称匹配到设备: ${found.name}');
        }
      }

      if (found != null) {
        completer.complete(found);
      }
    });

    // 超时兜底（3s），防止目标设备不在范围内时永久等待
    Timer(BluetoothConstants.scanTimeout, () {
      if (!completer.isCompleted) completer.complete(null);
    });

    // 启动扫描
    await startScan();

    // 等待：发现目标设备 或 超时
    final foundDevice = await completer.future;

    // 清理独立订阅，停止扫描
    await autoConnectSub.cancel();
    await stopScan();

    if (foundDevice != null) {
      _logCallback?.call(
          'Bluetooth', LogType.info, '尝试自动连接上次设备: ${foundDevice.name}');
      await _attemptReconnect(foundDevice);
    } else {
      _logCallback?.call('Bluetooth', LogType.warning,
          '未找到上次设备: ${_lastConnectedDevice!.name}，请手动重试');
    }
    _isAutoReconnecting = false;
    notifyListeners();
  }

  /// 尝试重连（以 connectToDevice 返回值为准，不依赖 _connectedDevice 状态）
  Future<void> _attemptReconnect(BluetoothDeviceModel device) async {
    // 修复问题5：原循环条件用 _connectedDevice == null 判断，
    // 但问题4（index=-1）会导致连接成功后 _connectedDevice 仍为 null，造成重复连接。
    // 改为以 connectToDevice() 的返回值（bool）作为唯一成功判据。
    for (int attempt = 1;
        attempt <= BluetoothConstants.maxReconnectAttempts;
        attempt++) {
      _logCallback?.call('Bluetooth', LogType.info,
          '自动重连尝试 $attempt/${BluetoothConstants.maxReconnectAttempts}');

      try {
        final success = await connectToDevice(device);
        if (success) {
          _logCallback?.call('Bluetooth', LogType.success, '自动重连成功');
          return;
        }
      } catch (e) {
        _logCallback?.call('Bluetooth', LogType.error, '重连失败: $e');
      }

      if (attempt < BluetoothConstants.maxReconnectAttempts) {
        await Future.delayed(BluetoothConstants.reconnectRetryInterval);
      }
    }

    _logCallback?.call('Bluetooth', LogType.error, '已达到最大重试次数, 自动重连失败');
  }

  /// 检查权限状态
  Future<void> _checkPermission() async {
    _permissionStatus =
        await app_bluetooth.BluetoothService.checkBluetoothPermission();

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
    _permissionStatus =
        await app_bluetooth.BluetoothService.requestBluetoothPermission();

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

    // 先取消已存在的扫描订阅，避免重复监听
    await _scanSubscription?.cancel();
    _scanSubscription = null;

    _isScanning = true;
    _scannedDevices = [];
    notifyListeners();

    _logCallback?.call('Bluetooth', LogType.info, '开始扫描蓝牙设备...');

    _scanTimer?.cancel();
    _scanTimer = Timer(BluetoothConstants.scanTimeout, () {
      stopScan();
    });

    // 监听扫描结果
    _scanSubscription = fb.FlutterBluePlus.scanResults.listen((results) {
      // 过滤弱信号设备和名称为空的设备，并按信号强度排序
      // 使用 advertisementData.advName 过滤，与模型创建时使用的字段一致
      final filteredDevices = results
          .where((r) =>
              r.rssi >= minRssi && r.advertisementData.advName.isNotEmpty)
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

      _scannedDevices = filteredDevices;

      // 检查已连接设备是否在扫描列表中，如果在则更新状态
      if (_connectedDevice != null) {
        final connectedIndex = _scannedDevices.indexWhere(
          (d) =>
              d.id == _connectedDevice!.id || d.name == _connectedDevice!.name,
        );
        if (connectedIndex != -1) {
          _scannedDevices[connectedIndex] =
              _scannedDevices[connectedIndex].copyWith(
            status: DeviceConnectionStatus.connected,
          );
        }
      }

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
    _logCallback?.call(
        'Bluetooth', LogType.info, '扫描完成，找到 ${_scannedDevices.length} 个设备');
    notifyListeners();
  }

  /// 获取设备优先级（数字越小越优先）
  /// 优先级: 1=OBD设备, 2=ELM适配器, 3=诊断工具, 4=其他
  int _getDevicePriority(String deviceName) {
    String name = deviceName.toUpperCase();
    if (name.contains('OBD') ||
        name.contains('OBDII') ||
        name.contains('OBD2')) {
      return 1;
    }
    if (name.contains('ELM') ||
        name.contains('ELM327') ||
        name.contains('VAG') ||
        name.contains('VCDS') ||
        name.contains('SCAN') ||
        name.contains('CAR')) {
      return 2;
    }
    if (name.contains('DIAG') ||
        name.contains('DIAGNOSTIC') ||
        name.contains('TOOL') ||
        name.contains('PROTOCOL') ||
        name.contains('ADAPTER')) {
      return 3;
    }
    return 4;
  }

  /// 连接设备（真实连接）
  /// 返回 true 表示连接并完成 OBD 会话初始化成功，false 表示失败
  Future<bool> connectToDevice(BluetoothDeviceModel device) async {
    // 前置检查
    if (device.flutterDevice == null) {
      _logCallback?.call('Bluetooth', LogType.error, '设备对象无效');
      return false;
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
      // 连接蓝牙设备并等待 OBD 会话初始化完成
      return await _connectBluetoothDevice(device);
    } catch (e) {
      _handleConnectionError(device, index, e);
      return false;
    }
  }

  /// 启动 OBD 会话（连接成功后的完整初始化流程）
  /// 由 _connectBluetoothDevice 在连接成功时调用，返回是否初始化成功
  Future<bool> _startObdSession(
      BluetoothDeviceModel device, int deviceIndex) async {
    if (device.flutterDevice == null) {
      _logCallback?.call('Bluetooth', LogType.error, '设备对象无效，无法启动 OBD 会话');
      return false;
    }

    try {
      // 发现服务并匹配特征
      final services = await device.flutterDevice!.discoverServices();
      final ret = await _discoverAndMatchCharacteristics(device, services);
      if (!ret) {
        throw Exception('发现服务匹配特征失败');
      }
      // 初始化 ELM327（响应驱动，传入 notifyStream）
      await _obdService?.initialize(_notifyCharacteristic!.lastValueStream);

      // 启动 OBD 轮询
      _obdService?.startPolling();
      // 更新为已连接状态
      _updateDeviceConnectedStatus(device, deviceIndex);
      return true;
    } catch (e) {
      _logCallback?.call('Bluetooth', LogType.error, '启动 OBD 会话失败: $e');
      _handleConnectionError(device, deviceIndex, e);
      return false;
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

  /// 连接蓝牙设备，返回 OBD 会话是否初始化成功
  Future<bool> _connectBluetoothDevice(BluetoothDeviceModel device) async {
    _connectionSubscription?.cancel();
    _connectionSubscription = null;

    final connectCompleter = Completer<bool>();

    // 先注册连接状态监听，再发起连接，避免 connected 回调在 connect() 返回前触发而被错过
    _connectionSubscription =
        device.flutterDevice!.connectionState.listen((state) async {
      switch (state) {
        case fb.BluetoothConnectionState.connected:
          _logCallback?.call('Bluetooth', LogType.success,
              '设备已连接: ${device.name}，正在启动 OBD 会话...');
          final index = _scannedDevices
              .indexWhere((d) => d.id == device.id || d.name == device.name);
          final success = await _startObdSession(device, index);
          if (!connectCompleter.isCompleted) {
            connectCompleter.complete(success);
          }
          break;
        case fb.BluetoothConnectionState.disconnected:
          if (!connectCompleter.isCompleted) {
            // 修复问题1：connect() 超时抛异常时 disconnected 回调会触发，
            // 在这里 complete(false) 确保 connectCompleter 不会永久挂起
            connectCompleter.complete(false);
          } else if (isDeviceConnected) {
            _cleanupConnection(caller: '_connectBluetoothDevice.disconnected');
          }
          break;
        default:
          break;
      }
    });

    try {
      await device.flutterDevice!.connect(
        timeout: BluetoothConstants.connectionTimeout,
        autoConnect: false,
      );
    } catch (e) {
      // 修复问题1：connect() 超时或其它异常时，connectionState 回调不一定触发
      // 直接在此处 complete(false) 兜底，防止 connectCompleter.future 永久挂起
      if (!connectCompleter.isCompleted) {
        _logCallback?.call('Bluetooth', LogType.error, 'BLE connect() 异常: $e');
        connectCompleter.complete(false);
      }
    }

    return connectCompleter.future;
  }

  /// 发现服务并匹配特征
  Future<bool> _discoverAndMatchCharacteristics(
    BluetoothDeviceModel device,
    List<fb.BluetoothService> services,
  ) async {
    _logCallback?.call('Bluetooth', LogType.info, '发现 ${services.length} 个服务');
    final characteristics = services.expand((s) => s.characteristics).toList();
    return _trySmartMatching(characteristics);
  }

  /// 更新为已连接状态
  Future<void> _updateDeviceConnectedStatus(
      BluetoothDeviceModel device, int index) async {
    if (index != -1) {
      _scannedDevices[index] = _scannedDevices[index].copyWith(
        status: DeviceConnectionStatus.connected,
        connectionStability: 100.0,
      );
      _connectedDevice = _scannedDevices[index];
    } else {
      // 修复问题4：自动重连时设备可能不在 _scannedDevices 中（index == -1）
      // 此时直接用传入的 device 构建已连接状态，确保 _connectedDevice 被正确设置
      _connectedDevice = device.copyWith(
        status: DeviceConnectionStatus.connected,
        connectionStability: 100.0,
      );
    }
    _lastConnectedDevice = _connectedDevice;

    // 保存设备信息
    await DeviceStorageService.saveLastDevice(_connectedDevice!);

    _logCallback?.call('Bluetooth', LogType.success, '已连接到 ${device.name}');
    notifyListeners();

    // 启动 RSSI 监测
    _startRssiMonitoring();
  }

  /// 处理连接失败
  void _handleConnectionError(
      BluetoothDeviceModel device, int index, Object error) {
    _logCallback?.call(
        'Bluetooth', LogType.error, '_handleConnectionError: $error');

    // 连接失败时，重置设备状态为 disconnected
    if (index != -1) {
      _scannedDevices[index] = _scannedDevices[index].copyWith(
        status: DeviceConnectionStatus.disconnected,
      );
      notifyListeners();
    }

    // 调用清理方法，确保资源完全释放
    _cleanupConnection(caller: "_handleConnectionError");
  }

  Future<bool> _trySmartMatching(
      List<fb.BluetoothCharacteristic> characteristics) async {
    fb.BluetoothCharacteristic? notifyChar;
    fb.BluetoothCharacteristic? writeChar;

    for (final char in characteristics) {
      if (notifyChar == null && char.properties.notify) {
        notifyChar = char;
      } else if (writeChar == null &&
          (char.properties.write || char.properties.writeWithoutResponse)) {
        writeChar = char;
      }
    }

    if (notifyChar != null && writeChar != null) {
      _writeCharacteristic = writeChar;
      _notifyCharacteristic = notifyChar;
      // 设置 OBDService 的写入特征
      _obdService?.setWriteCharacteristic(writeChar);
      _logCallback?.call('Bluetooth', LogType.success,
          '匹配写入特征: ${_writeCharacteristic?.uuid.str}');

      // 订阅通知
      try {
        await notifyChar.setNotifyValue(true);
        _logCallback?.call('Bluetooth', LogType.info, '已订阅通知特征');
        _obdNotificationSubscription?.cancel();
        _obdNotificationSubscription = notifyChar.lastValueStream.listen(
          (value) => _obdService?.handleNotification(value),
          onError: (Object e) {
            _logCallback?.call('Bluetooth', LogType.error, '通知监听数据错误: $e');
          },
        );
        return true;
      } catch (e) {
        _logCallback?.call('Bluetooth', LogType.error, '订阅通知失败: $e');
      }
      return false;
    }
    _logCallback?.call('Bluetooth', LogType.error, '未匹配到写入&通知service');
    return false;
  }

  // _handleConnectionStateChanged 已内联到 _connectBluetoothDevice 的 listen 回调中

  /// 清理连接资源（供内部使用）
  ///
  /// [shouldReconnect] - 清理后是否尝试自动重连
  void _cleanupConnection({required String caller}) {
    // 停止 OBD 轮询
    _obdService?.stopPolling();

    // 停止 RSSI 监测
    _stopRssiMonitoring();

    // 取消通知监听
    _obdNotificationSubscription?.cancel();
    _obdNotificationSubscription = null;

    // 取消连接状态监听
    _connectionSubscription?.cancel();
    _connectionSubscription = null;

    // 取消通知订阅（静默失败）
    if (_notifyCharacteristic != null) {
      _notifyCharacteristic!.setNotifyValue(false).catchError((_) => false);
      _notifyCharacteristic = null;
    }
    // 兜底处理：确保所有设备都重置为 disconnected
    // 防止重连失败后设备状态仍显示"连接中"
    for (int i = 0; i < _scannedDevices.length; i++) {
      _scannedDevices[i] = _scannedDevices[i].copyWith(
        status: DeviceConnectionStatus.disconnected,
      );
    }
    _logCallback.call(
        'Bluetooth', LogType.warning, '_cleanupConnection caller:$caller');

    // 重置状态
    _connectedDevice = null;
    // _isManuallyDisconnecting = false;

    // 重置 OBD 数据
    _obdDataProvider.resetData();

    notifyListeners();
  }

  /// 内部断开连接（不设置用户主动断开标志）
  /// 用于在连接新设备前断开旧设备
  Future<void> _disconnectInternal() async {
    final deviceToDisconnect = _connectedDevice;
    final deviceName = deviceToDisconnect?.name ?? 'Unknown';

    _logCallback?.call('Bluetooth', LogType.info, '正在断开旧设备: $deviceName...');

    // 使用 shouldReconnect = false 进行清理
    _cleanupConnection(caller: "_disconnectInternal");

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
    // 先保存设备引用（清理后 _connectedDevice 会被置 null）
    final deviceToDisconnect = _connectedDevice;
    final deviceName = deviceToDisconnect?.name ?? 'Unknown';

    _logCallback?.call('Bluetooth', LogType.info, '开始断开连接...');

    // 先清理所有资源：停止轮询、取消订阅、重置状态
    // 必须在 BLE disconnect() 之前调用，避免依赖异步回调来释放资源
    _cleanupConnection(caller: "disconnectDevice");

    // 再调用 BLE 层断开
    if (deviceToDisconnect?.flutterDevice != null) {
      try {
        await deviceToDisconnect!.flutterDevice!.disconnect();
        _logCallback?.call(
            'Bluetooth', LogType.warning, '已断开与 $deviceName 的连接');
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

  /// RSSI 转稳定性百分比
  /// RSSI 范围: -50(强) ~ -90(弱)，映射到 100% ~ 50%
  double _rssiToStability(int rssi) {
    if (rssi >= -50) return 100.0;
    if (rssi < -90) return 50.0;
    // 线性插值: (-50 到 -90 区间，映射到 100% 到 50%)
    return 100.0 + ((rssi + 50) / 40) * 50;
  }

  /// 启动 RSSI 监测
  void _startRssiMonitoring() {
    _rssiMonitorTimer?.cancel();
    _rssiMonitorTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_rssiMonitorTimer == null) {
        _logCallback.call(
            'Bluetooth', LogType.warning, '_rssiMonitorTimer is null');
        return;
      }
      _updateRssiAndStability();
    });
    // 立即更新一次
    _updateRssiAndStability();
  }

  /// 停止 RSSI 监测
  void _stopRssiMonitoring() {
    _rssiMonitorTimer?.cancel();
    _rssiMonitorTimer = null;
  }

  /// 更新 RSSI 和稳定性
  void _updateRssiAndStability() async {
    if (_connectedDevice?.flutterDevice == null) return;
    try {
      final rssi = await _connectedDevice!.flutterDevice!.readRssi();
      final stability = _rssiToStability(rssi);
      _connectedDevice = _connectedDevice!.copyWith(
        rssi: rssi,
        connectionStability: stability,
      );

      // 同时更新扫描列表中的设备
      final index =
          _scannedDevices.indexWhere((d) => d.id == _connectedDevice!.id);
      if (index != -1) {
        _scannedDevices[index] = _connectedDevice!;
      }

      notifyListeners();
    } catch (e) {
      final errorMsg = e.toString();
      // RSSI 读取失败时静默处理
      if (errorMsg.contains('device is disconnected') ||
          errorMsg.contains('disconnected')) {
        _stopRssiMonitoring();
      }
    }
  }

  @override
  void dispose() {
    _adapterSubscription?.cancel();
    _scanSubscription?.cancel();
    _connectionSubscription?.cancel();
    _obdNotificationSubscription?.cancel();
    _scanTimer?.cancel();
    _rssiMonitorTimer?.cancel();
    _obdService?.dispose();
    super.dispose();
  }
}
