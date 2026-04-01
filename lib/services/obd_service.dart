import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fb;
import '../constants/bluetooth_constants.dart';
import '../models/obd_data.dart';
import '../providers/obd_data_provider.dart';
import '../providers/settings_provider.dart';

/// OBD 数据解析结果
class ObdParseResult {
  final int? rpm; // 转速
  final int? speed; // 时速
  final int? throttle; // 油门开度
  final int? load; // 发动机负载
  final int? coolantTemp; // 水温
  final int? intakeTemp; // 进气温度
  final int? pressure; // 进气歧管压力
  final double? voltage; // 电压
  final int timestamp; // 采集时间戳（毫秒）

  const ObdParseResult({
    this.rpm,
    this.speed,
    this.throttle,
    this.load,
    this.coolantTemp,
    this.intakeTemp,
    this.pressure,
    this.voltage,
    this.timestamp = 0,
  });
}

/// OBD 服务 - 负责 OBD 协议解析和数据轮询
class OBDService {
  final OBDDataProvider _obdDataProvider;

  // 日志回调 - 替代直接引用 LogProvider
  void Function(String source, LogType type, String message)? logCallback;

  fb.BluetoothCharacteristic? _writeCharacteristic;
  Timer? _pollingTimer;
  bool _isPollingActive = false; // 轮询是否处于活动状态

  // 分级轮询常量 - 基础间隔固定 50ms，各频率倍率在 startPolling 时从 SettingsProvider 动态计算
  static const int pollingBaseInterval =
      BluetoothConstants.pollingBaseIntervalMs;
  static const List<String> highFreqPids = ['010D', '010C'];
  static const List<String> mediumFreqPids = ['0111', '010F', '010B'];
  static const List<String> lowFreqPids = ['0105', '0104', '0145', '0142'];

  SettingsProvider? _settings;

  // codeflicker-fix: OPT-Issue-9/omvh7ni7j93qpiynr7sw
  OBDService({
    required OBDDataProvider obdDataProvider,
    this.logCallback,
    SettingsProvider? settings,
  })  : _obdDataProvider = obdDataProvider,
        _settings = settings;

  /// 更新 SettingsProvider 引用（由 BluetoothProvider 在 settings 变化时调用）
  void updateSettings(SettingsProvider? settings) {
    _settings = settings;
  }

  /// 设置写入特征
  void setWriteCharacteristic(fb.BluetoothCharacteristic? characteristic) {
    _writeCharacteristic = characteristic;
  }

  /// 初始化 ELM327 适配器
  Future<void> initialize() async {
    if (_writeCharacteristic == null) {
      logCallback?.call('ELM327', LogType.error, '写入特征未设置');
      throw Exception('写入特征未设置');
    }

    logCallback?.call('ELM327', LogType.info, '开始初始化 ELM327...');

    // ATZ 复位
    sendCommand("ATZ");
    // codeflicker-fix: LOGIC-Issue-006/odko2evgylfq2rjqqr53
    await Future.delayed(Duration(
        milliseconds: _settings?.elm327InitWaitMs ??
            BluetoothConstants.elm327InitWait.inMilliseconds));

    // ATE0 关闭回显
    sendCommand("ATE0");
    await Future.delayed(BluetoothConstants.obdCommandInterval);

    // ATL0 关闭行尾
    sendCommand("ATL0");
    await Future.delayed(BluetoothConstants.obdCommandInterval);

    // ATH0 关闭头信息
    sendCommand("ATH0");
    await Future.delayed(BluetoothConstants.obdCommandInterval);

    // ATSP0 自动协议
    sendCommand("ATSP0");
    await Future.delayed(BluetoothConstants.obdCommandInterval);

    logCallback?.call('ELM327', LogType.success, 'ELM327 初始化完成');
  }

  /// 解析 OBD 响应
  ObdParseResult? parseResponse(String response) {
    // 过滤 ELM327 提示符和空响应
    if (response.startsWith(">") || response.isEmpty) {
      return null;
    }

    // 非标准 OBD 响应
    if (!response.startsWith("41")) {
      // logCallback?.call('OBD', LogType.warning, '非标准 OBD 响应: $response');
      return null;
    }

    final parts = response.split(" ").where((s) => s.isNotEmpty).toList();
    if (parts.length < 3) {
      return null;
    }

    final pid = parts[1];

    switch (pid) {
      case "0C": // RPM = ((A*256)+B)/4
        if (parts.length >= 4) {
          final a = int.tryParse(parts[2], radix: 16) ?? 0;
          final b = int.tryParse(parts[3], radix: 16) ?? 0;
          return ObdParseResult(rpm: ((a * 256) + b) ~/ 4);
        }
        break;
      case "0D": // 车速
        if (parts.length >= 3) {
          var speed = int.tryParse(parts[2], radix: 16) ?? 0;
          final factor = _settings?.speedCorrectionFactor ?? 1.08;
          speed = (speed * factor).toInt();
          return ObdParseResult(speed: speed);
        }
        break;
      case "05": // 冷却液温度 = A-40
        if (parts.length >= 3) {
          final temp = int.tryParse(parts[2], radix: 16) ?? 0;
          return ObdParseResult(coolantTemp: temp - 40);
        }
        break;
      case "11": // 节气门位置 = A*100/255
        if (parts.length >= 3) {
          final position = int.tryParse(parts[2], radix: 16) ?? 0;
          return ObdParseResult(throttle: (position * 100) ~/ 255);
        }
        break;
      case "0F": // 进气温度 = A-40
        if (parts.length >= 3) {
          final temp = int.tryParse(parts[2], radix: 16) ?? 0;
          return ObdParseResult(intakeTemp: temp - 40);
        }
        break;
      case "0B": // 进气歧管压力
        if (parts.length >= 3) {
          return ObdParseResult(
              pressure: int.tryParse(parts[2], radix: 16) ?? 0);
        }
        break;
      case "04": // 引擎负荷 = A*100/255
        if (parts.length >= 3) {
          final load = int.tryParse(parts[2], radix: 16) ?? 0;
          return ObdParseResult(load: (load * 100) ~/ 255);
        }
        break;
      case "45": // 绝对节气门位置 = A*100/255 (同 0111) 重复了，先注释下
        // if (parts.length >= 3) {
        //   final position = int.tryParse(parts[2], radix: 16) ?? 0;
        //   return ObdParseResult(throttle: (position * 100) ~/ 255);
        // }
        break;
      case "42": // 控制模块电压 = ((A*256)+B)/1000
        if (parts.length >= 4) {
          final a = int.tryParse(parts[2], radix: 16) ?? 0;
          final b = int.tryParse(parts[3], radix: 16) ?? 0;
          return ObdParseResult(voltage: ((a * 256) + b) / 1000.0);
        }
        break;
    }
    return null;
  }

  /// 处理 OBD 通知
  void handleNotification(List<int> value) {
    if (value.isEmpty) return;

    // 记录数据采集时间戳
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    try {
      final response = utf8.decode(value, allowMalformed: true).trim();
      final result = parseResponse(response);
      if (result == null) {
        return;
      }
      // 应用解析结果（包含时间戳）
      _obdDataProvider.updateRealTimeData(
        rpm: result.rpm,
        speed: result.speed,
        throttle: result.throttle,
        load: result.load,
        coolantTemp: result.coolantTemp,
        intakeTemp: result.intakeTemp,
        pressure: result.pressure,
        voltage: result.voltage,
        timestamp: timestamp,
      );
    } catch (e) {
      logCallback?.call('OBD', LogType.error, '解析数据失败: $e');
    }
  }

  /// 发送 OBD 命令
  void sendCommand(String command) {
    // 如果轮询未启动或写入特征为空，跳过发送
    if (_writeCharacteristic == null) {
      logCallback?.call('OBD', LogType.warning,
          'sendCommand 跳过: _writeCharacteristic=${_writeCharacteristic != null}');
      return;
    }
    try {
      final bytes = utf8.encode("$command\r");
      _writeCharacteristic!.write(bytes, withoutResponse: false);
    } catch (e) {
      final errorMsg = e.toString();
      logCallback?.call(
          'OBD', LogType.error, '发送命令失败: $command, 错误: $errorMsg');
      if (errorMsg.contains('device is disconnected') ||
          errorMsg.contains('disconnected')) {
        stopPolling();
      } else {}
    }
  }

  /// 启动分级轮询
  void startPolling() {
    if (_isPollingActive) {
      return;
    }
    _isPollingActive = true;
    logCallback?.call('OBD', LogType.info, '启动 OBD 轮询（分级模式）...');

    _pollingTimer?.cancel();
    int tickCount = 0;
    int highFreqIndex = 0;
    int mediumFreqIndex = 0;
    int lowFreqIndex = 0;

    // 叠加调度：Timer 固定 50ms 节拍（设置里各档均为 50 的倍数，倍率必为整数）
    // 每 tick 各频率独立判断，到期就发，互不排斥（每 tick 最多 3 条）
    final highInterval =
        (_settings?.highSpeedPidIntervalMs ?? 50).clamp(50, 1000);
    final mediumInterval =
        (_settings?.mediumSpeedPidIntervalMs ?? 250).clamp(250, 1500);
    final lowInterval =
        (_settings?.lowSpeedPidIntervalMs ?? 500).clamp(500, 2000);

    // 倍率 = 目标间隔 / 50ms，设置保证整除，无精度误差
    final highRatio = (highInterval / pollingBaseInterval).round().clamp(1, 20);
    final mediumRatio =
        (mediumInterval / pollingBaseInterval).round().clamp(1, 30);
    final lowRatio =
        (lowInterval / pollingBaseInterval).round().clamp(1, 40);

    _pollingTimer = Timer.periodic(
      const Duration(milliseconds: pollingBaseInterval),
      (timer) {
        if (_pollingTimer == null) {
          logCallback?.call('OBD', LogType.warning, '_pollingTimer is null');
          return;
        }
        if (_writeCharacteristic == null || _isPollingActive == false) {
          logCallback?.call(
              'OBD', LogType.warning, '写入特征为空，isPollingActive=false');
          timer.cancel();
          return;
        }

        // 高频：每 highRatio 个 tick 发一条
        if (tickCount % highRatio == 0) {
          sendCommand(highFreqPids[highFreqIndex]);
          highFreqIndex = (highFreqIndex + 1) % highFreqPids.length;
        }

        // 中频：每 mediumRatio 个 tick 额外发一条
        if (tickCount % mediumRatio == 0) {
          sendCommand(mediumFreqPids[mediumFreqIndex]);
          mediumFreqIndex = (mediumFreqIndex + 1) % mediumFreqPids.length;
        }

        // 低频：每 lowRatio 个 tick 额外发一条
        if (tickCount % lowRatio == 0) {
          sendCommand(lowFreqPids[lowFreqIndex]);
          lowFreqIndex = (lowFreqIndex + 1) % lowFreqPids.length;
        }

        tickCount++;
        // tickCount 重置：取三个倍率最小公倍数，防止溢出
        if (tickCount >= highRatio * mediumRatio * lowRatio) tickCount = 0;
      },
    );

    logCallback?.call('OBD', LogType.success, 'OBD 分级轮询已启动');
  }

  /// 停止轮询
  void stopPolling() {
    _isPollingActive = false;
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  /// 释放资源
  void dispose() {
    stopPolling();
    _writeCharacteristic = null;
  }
}
