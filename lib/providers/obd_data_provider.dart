import 'package:flutter/material.dart';
import '../models/obd_data.dart';
import '../utils/gear_util.dart';

/// OBD数据提供者 - 管理真实 OBD 数据（无 Mock）
/// 设备未连接时显示默认值（全为 0）
class OBDDataProvider extends ChangeNotifier {
  // 数据更新回调列表
  final List<VoidCallback> _onDataUpdateCallbacks = [];

  /// 注册数据更新回调
  void addDataUpdateListener(VoidCallback callback) {
    _onDataUpdateCallbacks.add(callback);
  }

  /// 移除数据更新回调
  void removeDataUpdateListener(VoidCallback callback) {
    _onDataUpdateCallbacks.remove(callback);
  }

  /// 通知数据更新
  void _notifyDataUpdate() {
    for (final callback in _onDataUpdateCallbacks) {
      callback();
    }
  }

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
  );

  // 骑行事件列表
  // final List<RidingEvent> _events = [];

  // 历史数据
  final List<int> _rpmHistory = List.generate(maxDataPoints, (_) => 0);
  final List<int> _velocityHistory = List.generate(maxDataPoints, (_) => 0);
  final List<int> _pressureHistory = List.generate(maxDataPoints, (_) => 0);
  // final List<int> _timestampHistory = List.generate(maxDataPoints, (_) => 0);

  // 连接状态
  bool _isDeviceConnected = false;

  // Getter
  OBDData get data => _data; // cur data
  List<int> get rpmHistory => _rpmHistory;
  List<int> get velocityHistory => _velocityHistory;
  List<int> get pressureHistory => _pressureHistory;
  // List<int> get timestampHistory => _timestampHistory;
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
    int? timestamp,
  }) {
    // 更新时间戳历史
    // if (timestamp != null) {
    //   _timestampHistory.add(timestamp);
    //   if (_timestampHistory.length > maxDataPoints) _timestampHistory.removeAt(0);
    // }
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
      if (_pressureHistory.length > maxDataPoints) _pressureHistory.removeAt(0);
    }

    // 计算档位
    final currentSpeed = speed ?? _data.speed;
    final currentThrottle = throttle ?? _data.throttle;
    final currentLoad = load ?? _data.load;
    final gear = GSX8SCalculator.calculateGear(
      rpm ?? _data.rpm,
      currentSpeed,
      throttle: currentThrottle,
      load: currentLoad,
    );

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
    );

    notifyListeners();
    _notifyDataUpdate();
  }

  /// 重置数据为默认值（设备断开时调用）
  void resetData() {
    _isDeviceConnected = false;
    _rpmHistory.clear();
    _velocityHistory.clear();
    _pressureHistory.clear();
    // _timestampHistory.clear();

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

  /// 更新倾角数据（由 SensorService 调用）
  void updateLeanAngle(int angle, String direction) {
    _data = _data.copyWith(
      leanAngle: angle,
      leanDirection: direction,
    );
    notifyListeners();
    _notifyDataUpdate();
  }

  /// 零点校准（将当前角度设为零点）
  void calibrateLeanAngle() {
    // 校准后角度归零
    _data = _data.copyWith(
      leanAngle: 0,
      leanDirection: 'NONE',
    );
    notifyListeners();
  }
}
