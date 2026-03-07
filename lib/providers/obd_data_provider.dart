import 'package:flutter/material.dart';
import '../models/obd_data.dart';

/// OBD数据提供者 - 管理真实 OBD 数据（无 Mock）
/// 设备未连接时显示默认值（全为 0）
class OBDDataProvider extends ChangeNotifier {
  // 默认值（设备未连接时显示）
  static const int defaultRpm = 0;
  static const int defaultSpeed = 0;
  static const int defaultGear = 0;
  static const int defaultThrottle = 0;
  static const int defaultLoad = 0;
  static const int defaultLeanAngle = 0;
  static const String defaultLeanDirection = 'NONE';
  static const int defaultPressure = 0;
  static const double defaultVoltage = 0.0;
  static const int defaultCoolantTemp = 0;
  static const int defaultIntakeTemp = 0;

  // 最大数据点数
  static const int maxDataPoints = 30;
  static const int maxPressurePoints = 15;

  // OBD数据
  OBDData _data = OBDData(
    rpm: defaultRpm,
    speed: defaultSpeed,
    gear: defaultGear,
    throttle: defaultThrottle,
    load: defaultLoad,
    leanAngle: defaultLeanAngle,
    leanDirection: defaultLeanDirection,
    pressure: defaultPressure,
    voltage: defaultVoltage,
    coolantTemp: defaultCoolantTemp,
    intakeTemp: defaultIntakeTemp,
    rpmHistory: List.filled(maxDataPoints, 0),
    velocityHistory: List.filled(maxDataPoints, 0),
  );

  // 骑行事件列表
  final List<RidingEvent> _events = [];

  // 历史数据
  final List<int> _rpmHistory = List.filled(maxDataPoints, 0);
  final List<int> _velocityHistory = List.filled(maxDataPoints, 0);
  final List<int> _pressureHistory = [];

  // 连接状态
  bool _isDeviceConnected = false;

  // Getter
  OBDData get data => _data;
  List<RidingEvent> get events => _events;
  List<int> get pressureHistory => _pressureHistory;
  bool get isDeviceConnected => _isDeviceConnected;

  OBDDataProvider() {
    // 不再启动定时器，不生成 Mock 数据
  }

  /// 更新实时 OBD 数据（由 BluetoothProvider 调用）
  void updateRealTimeData({
    int? rpm,
    int? speed,
    int? throttle,
    int? load,
    int? coolantTemp,
    int? intakeTemp,
    int? pressure,
    double? voltage,
  }) {
    // 更新历史数据
    if (rpm != null) {
      _rpmHistory.add(rpm);
      if (_rpmHistory.length > maxDataPoints) _rpmHistory.removeAt(0);
    }
    if (speed != null) {
      _velocityHistory.add(speed);
      if (_velocityHistory.length > maxDataPoints) _velocityHistory.removeAt(0);
    }
    if (pressure != null) {
      _pressureHistory.add(pressure);
      if (_pressureHistory.length > maxPressurePoints) _pressureHistory.removeAt(0);
    }

    // 计算档位
    final currentSpeed = speed ?? _data.speed;
    final gear = _calculateGear(currentSpeed);

    _data = _data.copyWith(
      rpm: rpm ?? _data.rpm,
      speed: currentSpeed,
      gear: gear,
      throttle: throttle ?? _data.throttle,
      load: load ?? _data.load,
      coolantTemp: coolantTemp ?? _data.coolantTemp,
      intakeTemp: intakeTemp ?? _data.intakeTemp,
      pressure: pressure ?? _data.pressure,
      voltage: voltage ?? _data.voltage,
      rpmHistory: List.from(_rpmHistory),
      velocityHistory: List.from(_velocityHistory),
    );

    notifyListeners();
  }

  /// 重置数据为默认值（设备断开时调用）
  void resetData() {
    _isDeviceConnected = false;
    _rpmHistory.fillRange(0, maxDataPoints, 0);
    _velocityHistory.fillRange(0, maxDataPoints, 0);
    _pressureHistory.clear();

    _data = OBDData(
      rpm: defaultRpm,
      speed: defaultSpeed,
      gear: defaultGear,
      throttle: defaultThrottle,
      load: defaultLoad,
      leanAngle: defaultLeanAngle,
      leanDirection: defaultLeanDirection,
      pressure: defaultPressure,
      voltage: defaultVoltage,
      coolantTemp: defaultCoolantTemp,
      intakeTemp: defaultIntakeTemp,
      rpmHistory: List.filled(maxDataPoints, 0),
      velocityHistory: List.filled(maxDataPoints, 0),
    );

    notifyListeners();
  }

  /// 设置连接状态
  void setDeviceConnected(bool connected) {
    _isDeviceConnected = connected;
    if (!connected) {
      resetData();
    }
    notifyListeners();
  }

  int _calculateGear(int speed) {
    if (speed < 30) return 1;
    if (speed < 60) return 2;
    if (speed < 100) return 3;
    if (speed < 150) return 4;
    if (speed < 200) return 5;
    return 6;
  }
}
