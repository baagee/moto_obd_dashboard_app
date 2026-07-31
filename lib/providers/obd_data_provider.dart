import 'package:flutter/material.dart';
import '../models/obd_data.dart';
import '../providers/settings_provider.dart';
import '../utils/gear_util.dart';

/// OBD数据提供者 - 管理真实 OBD 数据（无 Mock）
/// 设备未连接时显示默认值（全为 0）
class OBDDataProvider extends ChangeNotifier {
  // 默认值（设备未连接时显示）
  static const int defaultRpm = 0;
  static const int defaultSpeed = 0;
  static const int defaultGear = 0;
  static const int defaultThrottle = 0;
  static const int defaultLoad = 0;
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
    pressure: defaultPressure,
    voltage: defaultVoltage,
    coolantTemp: defaultCoolantTemp,
    intakeTemp: defaultIntakeTemp,
  );

  // 历史数据
  List<int> _rpmHistory = List.generate(maxDataPoints, (_) => 0);
  List<int> _velocityHistory = List.generate(maxDataPoints, (_) => 0);
  List<int> _pressureHistory = List.generate(maxDataPoints, (_) => 0);

  // 连接状态
  bool _isDeviceConnected = false;

  // 峰值保持（Peak-Hold）：本次骑行的最高 RPM / 最高速度
  // 骑行开始（startRide）或设备断开（resetData）时清零
  int _peakRpm = 0;
  int _peakSpeed = 0;

  // Getter
  OBDData get data => _data; // cur data
  List<int> get rpmHistory => _rpmHistory;
  List<int> get velocityHistory => _velocityHistory;
  List<int> get pressureHistory => _pressureHistory;
  bool get isDeviceConnected => _isDeviceConnected;
  int get peakRpm => _peakRpm;
  int get peakSpeed => _peakSpeed;

  SettingsProvider? _settingsProvider;

  // codeflicker-fix: OPT-Issue-2/omvh7ni7j93qpiynr7sw
  /// 更新 SettingsProvider 引用（由 main.dart ProxyProvider 在 settings 变化时调用）
  void updateSettings(SettingsProvider? settings) {
    _settingsProvider = settings;
  }

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

    // 更新峰值（Peak-Hold）
    if (rpm != null && rpm > _peakRpm) _peakRpm = rpm;
    if (speed != null && speed > _peakSpeed) _peakSpeed = speed;

    // 计算档位
    final currentSpeed = speed ?? _data.speed;
    final currentThrottle = throttle ?? _data.throttle;
    final currentLoad = load ?? _data.load;
    // codeflicker-fix: OPT-Issue-2/omvh7ni7j93qpiynr7sw
    final config = _settingsProvider != null
        ? GearConfig.fromSettings(_settingsProvider!)
        : GearConfig.defaults;
    final gear = GSX8SCalculator.calculateGear(
      rpm ?? _data.rpm,
      currentSpeed,
      throttle: currentThrottle,
      load: currentLoad,
      config: config,
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
  }

  /// 清零峰值（骑行开始时调用）
  void resetPeaks() {
    _peakRpm = 0;
    _peakSpeed = 0;
  }

  /// 重置数据为默认值（设备断开时调用）
  void resetData() {
    _isDeviceConnected = false;
    _rpmHistory = List.generate(maxDataPoints, (_) => 0);
    _velocityHistory = List.generate(maxDataPoints, (_) => 0);
    _pressureHistory = List.generate(maxDataPoints, (_) => 0);
    resetPeaks();

    _data = OBDData(
      rpm: defaultRpm,
      speed: defaultSpeed,
      gear: defaultGear,
      throttle: defaultThrottle,
      load: defaultLoad,
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
}
