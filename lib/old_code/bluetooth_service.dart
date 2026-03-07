import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fb;
import 'package:motoagent/services/common_service.dart';
import 'package:motoagent/services/test_ai_analysis_service.dart';
import 'package:motoagent/services/weather_service.dart';
import 'package:permission_handler/permission_handler.dart';
import '../configs/mock_config.dart';
import '../models/obd_data.dart';
import '../models/bluetooth_state.dart';
import 'ai_analysis_service.dart';
import 'bluetooth_state_machine.dart';
import 'device_storage_service.dart';
import 'foreground_service.dart';
import 'gear_calculation_service.dart';
import 'geolocator_service.dart';
import 'settings_service.dart';
import 'audio_service.dart';
import 'obd_sampling_service.dart';

class BluetoothService extends CommonService {
  static const String notifyUuid = "0000fff1-0000-1000-8000-00805f9b34fb";
  static const String writeUuid = "0000fff2-0000-1000-8000-00805f9b34fb";
  static const List<Map<String, String>> alternativeUuids = [
    {'notify': "0000ffe1-0000-1000-8000-00805f9b34fb", 'write': "0000ffe2-0000-1000-8000-00805f9b34fb"},
    {'notify': "0000fff0-0000-1000-8000-00805f9b34fb", 'write': "0000fff1-0000-1000-8000-00805f9b34fb"},
    {'notify': "6e400003-b5a3-f393-e0a9-e50e24dcca9e", 'write': "6e400002-b5a3-f393-e0a9-e50e24dcca9e"},
  ];

  // ========== 状态机 ==========
  final BluetoothStateMachine _stateMachine = BluetoothStateMachine();

  final DeviceStorageService _deviceStorage = DeviceStorageService();
  final SettingsService _settingsService = SettingsService();
  final AudioService _audioService = AudioService();
  final ObdSamplingService _samplingService = ObdSamplingService();
  final AIAnalysisService _aiAnalysisService = AIAnalysisService();
  final GeolocatorService _geolocatorService = GeolocatorService();
  final WeatherService _weatherService = WeatherService();
  final GearCalculationService _gearCalculationService = GearCalculationService();

  fb.BluetoothAdapterState _bluetoothState = fb.BluetoothAdapterState.unknown;
  fb.BluetoothDevice? _connectedDevice;
  fb.BluetoothCharacteristic? _writeCharacteristic;

  List<fb.ScanResult> _scanResults = [];
  bool _isPolling = false;
  Timer? _pollingTimer;
  ObdData _currentObdData = ObdData();

  // Stream controllers
  final StreamController<fb.BluetoothAdapterState> _bluetoothStateController =
      StreamController<fb.BluetoothAdapterState>.broadcast();
  final StreamController<List<fb.ScanResult>> _scanResultsController =
      StreamController<List<fb.ScanResult>>.broadcast();
  // 用于页面展示的数据流
  final StreamController<ObdData> _obdDataController =
      StreamController<ObdData>.broadcast();

  // 单例模式
  static final BluetoothService _instance = BluetoothService._internal();
  factory BluetoothService() => _instance;
  BluetoothService._internal();

  // ========== Getters ==========

  // 统一状态流（新增）
  Stream<BluetoothState> get stateStream => _stateMachine.stream;
  BluetoothState get bluetoothStateModel => _stateMachine.current;

  // 兼容旧接口
  // fb.BluetoothAdapterState get bluetoothState => _bluetoothState;
  fb.BluetoothDevice? get connectedDevice => _connectedDevice;
  // List<fb.ScanResult> get scanResults => _scanResults;
  Stream<List<fb.ScanResult>> get scanResultsController => _scanResultsController.stream;
  Stream<ObdData> get obdDataController => _obdDataController.stream;


  // 设备优先级方法（保持原有功能）
  int getDevicePriority(String deviceName) {
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

  bool isObdDevice(String deviceName) => getDevicePriority(deviceName) <= 3;

  String getPriorityName(int priority) {
    switch (priority) {
      case 1: return "OBD Device";
      case 2: return "OBD Adapter";
      case 3: return "Diagnostic Tool";
      case 4: return "Other Device";
      default: return "Unknown";
    }
  }

  // 过滤扫描结果：移除设备名为空的和信号太弱的设备
  List<fb.ScanResult> _filterScanResults(List<fb.ScanResult> results) {
    const int minRssi = -90; // 最小信号强度阈值，低于此值的设备将被过滤

    return results.where((result) {
      // 过滤掉设备名为空的设备
      if (result.device.platformName.trim().isEmpty) {
        return false;
      }

      // 过滤掉信号太弱的设备（RSSI值小于-90 dBm）
      if (result.rssi < minRssi) {
        return false;
      }

      return true;
    }).toList();
  }

  void _sortScanResults() {
    // 先应用过滤
    _scanResults = _filterScanResults(_scanResults);

    // 然后排序
    _scanResults.sort((a, b) {
      int aPriority = getDevicePriority(a.device.platformName);
      int bPriority = getDevicePriority(b.device.platformName);

      if (aPriority != bPriority) return aPriority.compareTo(bPriority);
      if (a.rssi != b.rssi) return b.rssi.compareTo(a.rssi);
      return a.device.platformName.compareTo(b.device.platformName);
    });
  }

  Future<void> initialize() async {
    // 初始化状态机
    _stateMachine.initialize();

    await _deviceStorage.initialize();
    await _audioService.initialize();
    // 初始化定位服务
    await _geolocatorService.initialize();
    await _weatherService.initialize();
    await _requestPermissions();

    // 监听手机蓝牙适配器状态变化
    fb.FlutterBluePlus.adapterState.listen((state) {
      _bluetoothState = state;
      _bluetoothStateController.add(state);
      // 状态机更新
      if (state == fb.BluetoothAdapterState.on) {
        _stateMachine.onBluetoothOn();
      } else {
        _stateMachine.onBluetoothOff();
      }
      log("Bluetooth adapter state changed: $state");
    });

    // 设置扫描结果监听器（只设置一次）
    fb.FlutterBluePlus.scanResults.listen((results) {
      _scanResults = results;
      _sortScanResults();
      _scanResultsController.add(_scanResults);
      // 更新扫描结果数量到状态机
      _stateMachine.updateScanCount(_scanResults.length);
    }).onError((error) {
      logError("Error listening to scan results: $error");
    });

    // Mock数据生成定时器（每200ms）
    if (enableMockData) {
      logInfo("enableMockData");
      // 触发后台保活
      await _initializeBackgroundService();
      // 触发通知
      await _connectDeviceAfterNotice();
      await Future.delayed(const Duration(seconds: 3));

      // 启动采样服务
      _samplingService.start();
      // 测试数据定时器
      _mockDataTimer?.cancel();
      log("启动Mock数据生成定时器，间隔${mockDataIntervalMs}ms");
      _mockDataTimer = Timer.periodic(
        Duration(milliseconds: mockDataIntervalMs),
            (_) {
              ObdData data = _testAIAnalysis.generateMockObdData();
              // 计算档位
              data.currentGear = _gearCalculationService.calculateGear(data);
              // 将mock数据添加到采样服务
              _samplingService.addObdData(data);
              // mock数据页面展示
              _obdDataController.add(data);
        },
      );
    }

    _bluetoothState = await fb.FlutterBluePlus.adapterState.first;
    _bluetoothStateController.add(_bluetoothState);

    if (_bluetoothState == fb.BluetoothAdapterState.on) {
      _stateMachine.onBluetoothOn();
      Future.delayed(const Duration(milliseconds: 100), () => _checkAutoConnect());
    } else {
      _stateMachine.onBluetoothOff();
    }
  }

  Future<void> _connectDeviceAfterNotice() async {
    // 获取当前位置
    AmapGeocodingResponse? currentLocation = await _geolocatorService
        .getCurrentLocationInfo();
    String? weatherDesc = "";
    if (currentLocation != null) {
      logInfo("curLocation:${currentLocation.adcode}:${currentLocation
          .formattedAddress}");
      weatherDesc = await _weatherService.getWeatherDescription(
          currentLocation.adcode.toString());
      logInfo("weatherDesc:$weatherDesc");
    }
    await _aiAnalysisService.helloConnect(weatherDesc);
  }

  Future<void> _requestPermissions() async {
    if (!Platform.isAndroid) return;

    await Permission.bluetooth.request();
    await Permission.bluetoothConnect.request();
    await Permission.bluetoothScan.request();
    await Permission.location.request();
  }

  Future<void> startScan() async {
    // 通过状态机检查是否可以扫描
    if (!_stateMachine.current.canScan) return;

    int scanDeviceTimeout = _settingsService.scanDeviceTimeout;
    log("Starting scan wait ${scanDeviceTimeout}s");

    // 状态机更新为扫描中
    _stateMachine.startScan();

    try {
      final scanTimeout = Duration(seconds: scanDeviceTimeout);
      await fb.FlutterBluePlus.startScan(timeout: scanTimeout);

      // 只给扫描一些时间来发现设备
      await Future.delayed(scanTimeout);
      await stopScan();
    } catch (e) {
      logError("Scan error: $e");
      _stateMachine.onConnectFailed(e.toString());
    }
  }

  Future<void> stopScan() async {
    // 检查是否正在扫描
    if (!_stateMachine.current.isScanning) return;

    await fb.FlutterBluePlus.stopScan();

    // 状态机更新为扫描完成
    _stateMachine.scanStopped(hasDevices: _scanResults.isNotEmpty);
  }

  // 异常重试会走这里，手动链接会走这里
  Future<bool> connectToDevice(fb.BluetoothDevice device, {bool isRetry = false}) async {
    final deviceId = device.remoteId.str;
    final deviceName = device.platformName;

    if (_connectedDevice?.remoteId.str == deviceId && _stateMachine.current.isConnected) {
      return true;
    }

    log("Connecting to $deviceName ($deviceId)");

    // 状态机更新为连接中
    _stateMachine.startConnect(deviceName, deviceId);

    try {
      if (_connectedDevice != null) {
        await _connectedDevice!.disconnect();
      }

      await device.connect();
      _connectedDevice = device;
      _setupDeviceListener(device);

      await Future.delayed(const Duration(milliseconds: 1000));
      await _discoverServices(device);
      // 连接成功后，清空其他设备，只保留已连接设备
      // _clearScanResultsExceptConnected();
      await _initializeElm327();
      // 开启后台服务
      await _initializeBackgroundService();
      // 播放链接提示音
      await _connectDeviceAfterNotice();
      // await Future.delayed(const Duration(milliseconds: 500));
      _startPolling();
      await _deviceStorage.saveConnectedDevice(device);

      // 状态机更新为已连接
      _stateMachine.onConnected(deviceName, deviceId);

      return true;
    } catch (e) {
      logError("Connection error: $e");
      _stateMachine.onConnectFailed(e.toString());
      _handleDisconnection("连接失败: $e", false);
      return false;
    }
  }

  Future<void> _initializeBackgroundService() async {
    final foregroundService = ForegroundService();
    await foregroundService.startService();
  }

  Future<void> _discoverServices(fb.BluetoothDevice device) async {
    log("Discovering services");
    final services = await device.discoverServices();
    final characteristics = services.expand((s) => s.characteristics).toList();

    if (_tryCharacteristics(characteristics, notifyUuid, writeUuid)) return;

    for (final uuids in alternativeUuids) {
      if (_tryCharacteristics(characteristics, uuids['notify']!, uuids['write']!)) return;
    }

    if (_trySmartMatching(characteristics)) return;

    throw Exception("Required characteristics not found");
  }

  bool _tryCharacteristics(List<fb.BluetoothCharacteristic> characteristics, String notifyUuid, String writeUuid) {
    fb.BluetoothCharacteristic? notifyChar;
    fb.BluetoothCharacteristic? writeChar;

    for (final char in characteristics) {
      final uuid = char.uuid.toString().toLowerCase();
      if (uuid == notifyUuid.toLowerCase() && char.properties.notify) {
        notifyChar = char;
      } else if (uuid == writeUuid.toLowerCase() && (char.properties.write || char.properties.writeWithoutResponse)) {
        writeChar = char;
      }
    }

    if (notifyChar != null && writeChar != null) {
      _writeCharacteristic = writeChar;
      _setupNotificationListener(notifyChar);
      log("TryCharacteristics notifyChar $notifyChar");
      log("TryCharacteristics writeChar $writeChar");
      return true;
    }
    return false;
  }

  bool _trySmartMatching(List<fb.BluetoothCharacteristic> characteristics) {
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
      _setupNotificationListener(notifyChar);
      log("TrySmartMatching notifyChar $notifyChar");
      log("TrySmartMatching writeChar $writeChar");
      return true;
    }
    return false;
  }

  Future<void> _setupNotificationListener(fb.BluetoothCharacteristic characteristic) async {
    await characteristic.setNotifyValue(true);
    characteristic.lastValueStream.listen(_handleNotification);
  }

  void _setupDeviceListener(fb.BluetoothDevice device) {
    device.connectionState.listen((state) {
      if (state == fb.BluetoothConnectionState.disconnected && _connectedDevice != null) {
        _handleDisconnection("设备意外断开", true);
      }
    });
  }

  Future<void> _initializeElm327() async {
    Duration waitTime =  Duration(milliseconds: _settingsService.minCommandInterval);
    log("Initializing ELM327 command waitTime:{$waitTime}ms");
    await _sendAtCommand("ATZ");
    await Future.delayed(const Duration(milliseconds: 1000));
    await _sendAtCommand("ATE0");
    await Future.delayed(waitTime);
    await _sendAtCommand("ATL0");
    await Future.delayed(waitTime);
    await _sendAtCommand("ATH0");
    await Future.delayed(waitTime);
    await _sendAtCommand("ATSP0"); // 不要自动模式
    // await _sendAtCommand("ATSP6"); // 强制 CAN 11/500（GSX8s用的这个）
    await Future.delayed(waitTime);
  }

  Future<void> _sendAtCommand(String command) async {
    if (_writeCharacteristic == null) throw Exception("Write characteristic not available");

    final bytes = utf8.encode("$command\r");
    await _writeCharacteristic!.write(bytes, withoutResponse: false);
    log("AT command: $command");
  }

  void _handleNotification(List<int> value) {
    try {
      final response = utf8.decode(value, allowMalformed: true);
      _processObdResponse(response.trim());
    } catch (e) {
      logError("Notification error: $e");
    }
  }

  void _processObdResponse(String response) {
    // 过滤掉提示符和无效响应
    if (response.startsWith(">")) {
      return; // ELM327 提示符，跳过
    }

    if (!response.startsWith("41")) {
      // 非标准 OBD 响应，可能是错误信息
      logWarning("非标准 OBD 响应: $response");
      return;
    }

    final parts = response.split(" ");
    if (parts.length < 3) {
      logWarning("OBD 数据长度不足: $response");
      return;
    }

    final pid = parts[1];
    switch (pid) {
      case "0C":
        if (parts.length >= 4) {
          final a = int.tryParse(parts[2], radix: 16) ?? 0;
          final b = int.tryParse(parts[3], radix: 16) ?? 0;
          final rpm = ((a * 256) + b) / 4.0;
          _currentObdData = _currentObdData.copyWith(engineRpm: rpm);
        }
        break;
      case "0D":
        if (parts.length >= 3) {
          final speed = int.tryParse(parts[2], radix: 16) ?? 0;
          _currentObdData = _currentObdData.copyWith(vehicleSpeed: speed.toDouble());
        }
        break;
      case "05":
        if (parts.length >= 3) {
          final temp = int.tryParse(parts[2], radix: 16) ?? 0;
          final celsius = (temp - 40).toDouble();
          _currentObdData = _currentObdData.copyWith(coolantTemperature: celsius);
        }
        break;
      case "11":
        if (parts.length >= 3) {
          final position = int.tryParse(parts[2], radix: 16) ?? 0;
          final percent = (position * 100) / 255;
          _currentObdData = _currentObdData.copyWith(throttlePosition: percent);
        }
        break;
      case "0F":
        if (parts.length >= 3) {
          final temp = int.tryParse(parts[2], radix: 16) ?? 0;
          final celsius = (temp - 40).toDouble();
          _currentObdData = _currentObdData.copyWith(intakeAirTemperature: celsius);
        }
        break;
      case "0B":
        if (parts.length >= 3) {
          final pressure = int.tryParse(parts[2], radix: 16) ?? 0;
          _currentObdData = _currentObdData.copyWith(manifoldPressure: pressure.toDouble());
        }
        break;
      case "04":
        if (parts.length >= 3) {
          final load = int.tryParse(parts[2], radix: 16) ?? 0;
          final percent = (load * 100) / 255;
          _currentObdData = _currentObdData.copyWith(engineLoad: percent);
        }
        break;
      case "1F":
        if (parts.length >= 4) {
          final a = int.tryParse(parts[2], radix: 16) ?? 0;
          final b = int.tryParse(parts[3], radix: 16) ?? 0;
          final minutes = (a * 256) + b;
          _currentObdData = _currentObdData.copyWith(runTime: minutes);
        }
        break;
      case "45":
        if (parts.length >= 3) {
          final position = int.tryParse(parts[2], radix: 16) ?? 0;
          final percent = (position * 100) / 255;
          _currentObdData = _currentObdData.copyWith(absoluteThrottlePosition: percent);
        }
        break;
      case "42":
        if (parts.length >= 4) {
          final a = int.tryParse(parts[2], radix: 16) ?? 0;
          final b = int.tryParse(parts[3], radix: 16) ?? 0;
          final voltage = ((a * 256) + b) / 1000.0;
          _currentObdData = _currentObdData.copyWith(controlModuleVoltage: voltage);
        }
        break;
      case "21":
        if (parts.length >= 4) {
          final a = int.tryParse(parts[2], radix: 16) ?? 0;
          final b = int.tryParse(parts[3], radix: 16) ?? 0;
          final distance = (a * 256) + b;
          _currentObdData = _currentObdData.copyWith(distanceSinceMilOn: distance.toDouble());
        }
        break;
    }

    // 计算档位
    _currentObdData.currentGear = _gearCalculationService.calculateGear(_currentObdData);

    _obdDataController.add(_currentObdData);

    // 添加数据到采样服务和缓存服务
    _samplingService.addObdData(_currentObdData);
  }

  void _startPolling() {
    // 安全停止已有的轮询（不依赖 _isPolling 标志）
    if (_pollingTimer != null && _pollingTimer!.isActive) {
      log("Stopping existing polling timer before restart");
      _pollingTimer?.cancel();
      _pollingTimer = null;
    }

    log("Starting polling");
    _isPolling = true;

    // 启动采样服务
    _samplingService.start();


    // 高频命令（速度和转速）- 50ms间隔，20Hz更新率
    final highFreqPids = ["0D", "0C"]; // 速度、转速
    int highFreqIndex = 0;

    // 中频命令（影响驾驶体验的参数）- 200ms间隔，5Hz更新率
    final mediumFreqPids = ["11", "0F", "0B"]; // 油门、进气温度、进气压力
    int mediumFreqIndex = 0;

    // 低频命令（相对稳定的数据）- 500ms间隔，2Hz更新率
    final lowFreqPids = ["05", "04", "1F", "45", "42", "21"]; // 水温、负载、运行时间,环境温度,控制模块电压等
    int lowFreqIndex = 0;

    // 计时器计数器，用于控制不同频率的命令发送
    int tickCount = 0;
    // 最小的发送间隔（从设置服务获取）
    int minMilliseconds = _settingsService.minCommandInterval;
    log("Starting polling with min interval: ${minMilliseconds}ms");
    _pollingTimer = Timer.periodic(Duration(milliseconds: minMilliseconds), (timer) {
      if (!_isPolling || _connectedDevice == null || _writeCharacteristic == null) {
        timer.cancel();
        logError("Polling error: connectedDevice=null");
        return;
      }

      try {
        String command;

        // 每4个tick（200ms）发送一次中频命令
        if (tickCount % 4 == 0) {
          command = "01${mediumFreqPids[mediumFreqIndex]}";
          mediumFreqIndex = (mediumFreqIndex + 1) % mediumFreqPids.length;
        }
        // 每10个tick（500ms）发送一次低频命令
        else if (tickCount % 10 == 0) {
          command = "01${lowFreqPids[lowFreqIndex]}";
          lowFreqIndex = (lowFreqIndex + 1) % lowFreqPids.length;
        }
        // 每个tick都发送高频命令
        else {
          command = "01${highFreqPids[highFreqIndex]}";
          highFreqIndex = (highFreqIndex + 1) % highFreqPids.length;
        }

        final bytes = utf8.encode("$command\r");
        _writeCharacteristic!.write(bytes, withoutResponse: false);

        tickCount++;
        // 防止计数器溢出，每1000次循环重置（50秒）
        if (tickCount >= 1000) {
          tickCount = 0;
        }
      } catch (e) {
        logError("Polling error: $e");
      }
    });

    // int currentPidIndex = 0;
    // final pids = ["0C", "0D", "05", "11", "0F", "0B", "04", "1F", "45", "42", "21"];
    // int commandInterval = _settingsService.minCommandInterval;
    // _pollingTimer = Timer.periodic(Duration(milliseconds: commandInterval), (timer) {
    //   if (!_isPolling || _connectedDevice == null || _writeCharacteristic == null) {
    //     logError("Polling stopped: conditions not met, canceling timer");
    //     timer.cancel();
    //     _pollingTimer = null;
    //     return;
    //   }
    //
    //   try {
    //     final command = "01${pids[currentPidIndex]}";
    //     // log("SendQueryCommand $command");
    //     final bytes = utf8.encode("$command\r");
    //     _writeCharacteristic!.write(bytes, withoutResponse: false);
    //     currentPidIndex = (currentPidIndex + 1) % pids.length;
    //   } catch (e) {
    //     logError("Polling error: $e");
    //   }
    // });
  }

  void _stopPolling() {
    if (!_isPolling) {
      log("Polling already stopped, skipping");
      return;
    }

    log("Stopping polling");
    _isPolling = false;

    // 安全取消定时器
    if (_pollingTimer != null) {
      try {
        _pollingTimer?.cancel();
        _pollingTimer = null;
        log("Polling timer canceled and nullified");
      } catch (e) {
        logError("Error canceling polling timer: $e");
        _pollingTimer = null;
      }
    }

    // 停止采样服务
    _samplingService.stop();
    log("Polling completely stopped");
  }

  Future<void> disconnect() async {
    log("Disconnecting");

    // 状态机更新为断开中
    _stateMachine.startDisconnect();

    _stopPolling();

    if (_connectedDevice != null) {
      await _connectedDevice!.disconnect();
      _connectedDevice = null;
      _writeCharacteristic = null;
    }

    // 状态机更新为已断开
    _stateMachine.onDisconnected();
    _audioService.playDisconnectionSound();

    // 断开连接后重新扫描设备
    Future.delayed(const Duration(milliseconds: 1000), () {
      startScan();
    });
  }

  Future<void> _handleDisconnection(String reason, bool needConnect) async {
    // 检查是否用户主动断开（通过状态机）
    if (_stateMachine.current.isDisconnecting) {
      log("User initiated disconnection");
      return;
    }

    logWarning("Unexpected disconnection: $reason");
    _stopPolling();

    // 清空连接状态，确保UI正确更新
    _connectedDevice = null;
    _writeCharacteristic = null;

    _audioService.playDisconnectionSound();

    if (!needConnect) {
      // 不需要重试时，重新扫描设备
      _stateMachine.onDisconnected();
      Future.delayed(const Duration(milliseconds: 1000), () {
        startScan();
      });
      return;
    }

    // 尝试自动重连
    final lastDevice = await _deviceStorage.lastConnectedDevice;
    if (lastDevice != null) {
      _attemptAutoConnectWithRetry(lastDevice);
    }
  }

  Future<void> _checkAutoConnect() async {
    if (!_settingsService.autoConnectEnabled) return;

    final lastDevice = await _deviceStorage.lastConnectedDevice;
    if (lastDevice == null) return;

    // 状态机更新为重连中
    _stateMachine.startReconnect(lastDevice.deviceName);

    try {
      await _attemptAutoConnectWithRetry(lastDevice);
    } catch (e) {
      logError("Auto-connect error: $e");
      _stateMachine.reconnectFailed(e.toString());
    }
  }

  /// 带重试的自动连接（启动APP时自动连接，断连时自动连接）
  /// 优化：避免多次重复扫描，只在必要时启动扫描
  Future<void> _attemptAutoConnectWithRetry(lastDevice) async {
    const maxRetries = 2;
    final retryDelay = Duration(milliseconds: 500);

    // 开始扫描并等待完成
    if (!_stateMachine.current.isScanning) {
      log("Starting scan for retry");
      await startScan();
    }

    // 扫描已完成，检查结果
    final scanResult = _deviceStorage.findScanResult(_scanResults, lastDevice.deviceId);
    if (scanResult == null) {
      log("Last connected device not found in scan results");
      // 重连失败但扫描有结果时，状态保持idle让用户看到列表
      if (_scanResults.isNotEmpty) {
        _stateMachine.scanStopped(hasDevices: true);
      } else {
        _stateMachine.reconnectFailed('设备未找到');
      }
      return;
    }

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        log("Auto-connect attempt $attempt/$maxRetries");

        final success = await connectToDevice(scanResult.device);
        if (success) {
          log("Auto-connect successful to ${scanResult.device.platformName} after $attempt attempt(s)");
          return;
        }

        if (attempt < maxRetries) {
          log("Auto-connect attempt $attempt failed, retrying in ${retryDelay.inMilliseconds}ms");
          await Future.delayed(retryDelay);
        }
      } catch (e) {
        logError("Auto-connect attempt $attempt error: $e");
        if (attempt < maxRetries) {
          await Future.delayed(retryDelay);
        }
      }
    }

    _stateMachine.reconnectFailed('重连失败（$maxRetries 次尝试后）');
  }

  /// 获取上次连接的设备信息
  Future<Map<String, dynamic>?> getLastConnectedDeviceInfo() async {
    final device = await _deviceStorage.lastConnectedDevice;
    if (device == null) return null;

    return {
      'deviceId': device.deviceId,
      'deviceName': device.deviceName,
      'localName': device.localName,
      'lastConnected': device.lastConnected.toIso8601String(),
    };
  }

  /// 检查设备是否是最后连接的设备
  Future<bool> isLastConnectedDevice(String deviceId) async {
    return await _deviceStorage.isLastConnectedDevice(deviceId);
  }

  void dispose() {
    _stopPolling();

    if (_connectedDevice != null) {
      _connectedDevice!.disconnect();
      _connectedDevice = null;
    }

    _writeCharacteristic = null;

    // 关闭 Stream controllers
    _bluetoothStateController.close();
    _scanResultsController.close();
    _obdDataController.close();

    // 释放状态机
    _stateMachine.dispose();

    // 释放依赖服务
    _audioService.dispose();
    _samplingService.dispose();
    _aiAnalysisService.dispose();
    _geolocatorService.dispose();
    _weatherService.dispose();
    _deviceStorage.dispose();
    _settingsService.dispose();

    // 测试数据相关的
    if (enableMockData) {
      _mockDataTimer?.cancel();
      _mockDataTimer = null;
    }
  }
}