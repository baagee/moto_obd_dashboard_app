import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 设置 Provider - 统一管理所有可配置参数，持久化至 SharedPreferences
///
/// 使用方式：在 main() 中、runApp() 之前 await settingsProvider.init()，
/// 保证首帧即可读取正确的持久化值，完全消除参数窗口期。
class SettingsProvider extends ChangeNotifier {
  late SharedPreferences _prefs;

  /// 在 main() 中、runApp() 之前 await 调用
  /// 完成后 _prefs 保证就绪，runApp 执行时首帧即可读取正确持久化值
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    // 不调用 notifyListeners()：此时 Widget 树尚未构建，无需通知
  }

  // ===== 通用读写辅助 =====
  // 注意：_prefs 使用 late 非空声明，init() 在 runApp 前已 await 完成，调用时保证就绪
  double _getDouble(String key, double def) => _prefs.getDouble(key) ?? def;
  int _getInt(String key, int def) => _prefs.getInt(key) ?? def;
  bool _getBool(String key, bool def) => _prefs.getBool(key) ?? def;
  String _getString(String key, String def) => _prefs.getString(key) ?? def;

  Future<void> _setDouble(String key, double v) async {
    await _prefs.setDouble(key, v);
    notifyListeners();
  }

  Future<void> _setInt(String key, int v) async {
    await _prefs.setInt(key, v);
    notifyListeners();
  }

  Future<void> _setBool(String key, bool v) async {
    await _prefs.setBool(key, v);
    notifyListeners();
  }

  Future<void> _setString(String key, String v) async {
    await _prefs.setString(key, v);
    notifyListeners();
  }

  /// 批量写入多个 key，完成后只触发一次 notifyListeners()。
  /// values 中每个 entry 的 value 类型须为 double / int / bool / String。
  Future<void> setBatch(Map<String, dynamic> values) async {
    for (final entry in values.entries) {
      final v = entry.value;
      if (v is double) {
        await _prefs.setDouble(entry.key, v);
      } else if (v is int) {
        await _prefs.setInt(entry.key, v);
      } else if (v is bool) {
        await _prefs.setBool(entry.key, v);
      } else if (v is String) {
        await _prefs.setString(entry.key, v);
      }
    }
    notifyListeners();
  }

  // ===== 车辆参数 =====

  static const List<double> _defaultGearRatios = [
    3.071,
    2.200,
    1.700,
    1.416,
    1.230,
    1.107
  ];

  double get primaryRatio => _getDouble('settings_vehicle_primaryRatio', 1.675);
  double get finalRatio => _getDouble('settings_vehicle_finalRatio', 2.764);
  double get tireCircumference =>
      _getDouble('settings_vehicle_tireCircumference', 1.97857);
  List<double> get gearRatios => List.generate(
      6,
      (i) => _getDouble(
          'settings_vehicle_gearRatio_${i + 1}', _defaultGearRatios[i]));
  double get speedCorrectionFactor =>
      _getDouble('settings_vehicle_speedCorrectionFactor', 1.08);
  int get neutralSpeedThreshold =>
      _getInt('settings_vehicle_neutralSpeedThreshold', 3);
  int get neutralRpmThreshold =>
      _getInt('settings_vehicle_neutralRpmThreshold', 1200);

  Future<void> setPrimaryRatio(double v) =>
      _setDouble('settings_vehicle_primaryRatio', v);
  Future<void> setFinalRatio(double v) =>
      _setDouble('settings_vehicle_finalRatio', v);
  Future<void> setTireCircumference(double v) =>
      _setDouble('settings_vehicle_tireCircumference', v);
  Future<void> setGearRatio(int gear, double value) =>
      _setDouble('settings_vehicle_gearRatio_$gear', value);
  Future<void> setSpeedCorrectionFactor(double v) =>
      _setDouble('settings_vehicle_speedCorrectionFactor', v);
  Future<void> setNeutralSpeedThreshold(int v) =>
      _setInt('settings_vehicle_neutralSpeedThreshold', v);
  Future<void> setNeutralRpmThreshold(int v) =>
      _setInt('settings_vehicle_neutralRpmThreshold', v);

  // ===== 蓝牙连接 =====

  int get scanTimeoutSeconds => _getInt('settings_bluetooth_scanTimeout', 3);
  int get minRssi => _getInt('settings_bluetooth_minRssi', -90);
  int get connectionTimeoutSeconds =>
      _getInt('settings_bluetooth_connectionTimeout', 2);
  int get elm327InitWaitMs =>
      _getInt('settings_bluetooth_elm327InitWait', 1000);
  int get highSpeedPidIntervalMs =>
      _getInt('settings_bluetooth_highSpeedPidInterval', 50).clamp(50, 1000);
  int get mediumSpeedPidIntervalMs =>
      _getInt('settings_bluetooth_mediumSpeedPidInterval', 250)
          .clamp(250, 1500);
  int get lowSpeedPidIntervalMs =>
      _getInt('settings_bluetooth_lowSpeedPidInterval', 500).clamp(500, 2000);

  Future<void> setScanTimeoutSeconds(int v) =>
      _setInt('settings_bluetooth_scanTimeout', v);
  Future<void> setMinRssi(int v) => _setInt('settings_bluetooth_minRssi', v);
  Future<void> setConnectionTimeoutSeconds(int v) =>
      _setInt('settings_bluetooth_connectionTimeout', v);
  Future<void> setElm327InitWaitMs(int v) =>
      _setInt('settings_bluetooth_elm327InitWait', v);
  Future<void> setHighSpeedPidIntervalMs(int v) =>
      _setInt('settings_bluetooth_highSpeedPidInterval', v);
  Future<void> setMediumSpeedPidIntervalMs(int v) =>
      _setInt('settings_bluetooth_mediumSpeedPidInterval', v);
  Future<void> setLowSpeedPidIntervalMs(int v) =>
      _setInt('settings_bluetooth_lowSpeedPidInterval', v);

  // ===== 骑行事件 =====

  int get globalCooldownSeconds =>
      _getInt('settings_events_globalCooldown', 30);
  Future<void> setGlobalCooldownSeconds(int v) =>
      _setInt('settings_events_globalCooldown', v);

  bool get performanceBurstEnabled =>
      _getBool('settings_events_performanceBurst_enabled', true);
  int get performanceBurstRpm =>
      _getInt('settings_events_performanceBurst_rpmThreshold', 6300);
  Future<void> setPerformanceBurstEnabled(bool v) =>
      _setBool('settings_events_performanceBurst_enabled', v);
  Future<void> setPerformanceBurstRpm(int v) =>
      _setInt('settings_events_performanceBurst_rpmThreshold', v);

  bool get engineOverheatEnabled =>
      _getBool('settings_events_engineOverheat_enabled', true);
  int get engineOverheatTemp =>
      _getInt('settings_events_engineOverheat_tempThreshold', 105);
  Future<void> setEngineOverheatEnabled(bool v) =>
      _setBool('settings_events_engineOverheat_enabled', v);
  Future<void> setEngineOverheatTemp(int v) =>
      _setInt('settings_events_engineOverheat_tempThreshold', v);

  bool get voltageAnomalyEnabled =>
      _getBool('settings_events_voltageAnomaly_enabled', true);
  double get voltageAnomalyLow =>
      _getDouble('settings_events_voltageAnomaly_low', 11.5);
  double get voltageAnomalyHigh =>
      _getDouble('settings_events_voltageAnomaly_high', 15.3);
  Future<void> setVoltageAnomalyEnabled(bool v) =>
      _setBool('settings_events_voltageAnomaly_enabled', v);
  Future<void> setVoltageAnomalyLow(double v) =>
      _setDouble('settings_events_voltageAnomaly_low', v);
  Future<void> setVoltageAnomalyHigh(double v) =>
      _setDouble('settings_events_voltageAnomaly_high', v);

  bool get highLoadEnabled =>
      _getBool('settings_events_highLoad_enabled', true);
  int get highLoadThreshold =>
      _getInt('settings_events_highLoad_threshold', 70);
  Future<void> setHighLoadEnabled(bool v) =>
      _setBool('settings_events_highLoad_enabled', v);
  Future<void> setHighLoadThreshold(int v) =>
      _setInt('settings_events_highLoad_threshold', v);

  bool get longRidingEnabled =>
      _getBool('settings_events_longRiding_enabled', true);
  double get longRidingDurationHours =>
      _getDouble('settings_events_longRiding_durationHours', 1.0);
  int get longRidingCooldownSeconds =>
      _getInt('settings_events_longRiding_cooldown', 1200);
  Future<void> setLongRidingEnabled(bool v) =>
      _setBool('settings_events_longRiding_enabled', v);
  Future<void> setLongRidingDurationHours(double v) =>
      _setDouble('settings_events_longRiding_durationHours', v);
  Future<void> setLongRidingCooldownSeconds(int v) =>
      _setInt('settings_events_longRiding_cooldown', v);

  bool get efficientCruisingEnabled =>
      _getBool('settings_events_efficientCruising_enabled', true);
  int get efficientCruisingSpeedMin =>
      _getInt('settings_events_efficientCruising_speedMin', 70);
  int get efficientCruisingSpeedMax =>
      _getInt('settings_events_efficientCruising_speedMax', 100);
  int get efficientCruisingLoadMax =>
      _getInt('settings_events_efficientCruising_loadMax', 30);
  int get efficientCruisingCooldown =>
      _getInt('settings_events_efficientCruising_cooldown', 300);
  Future<void> setEfficientCruisingEnabled(bool v) =>
      _setBool('settings_events_efficientCruising_enabled', v);
  Future<void> setEfficientCruisingSpeedMin(int v) =>
      _setInt('settings_events_efficientCruising_speedMin', v);
  Future<void> setEfficientCruisingSpeedMax(int v) =>
      _setInt('settings_events_efficientCruising_speedMax', v);
  Future<void> setEfficientCruisingLoadMax(int v) =>
      _setInt('settings_events_efficientCruising_loadMax', v);
  Future<void> setEfficientCruisingCooldown(int v) =>
      _setInt('settings_events_efficientCruising_cooldown', v);

  bool get engineWarmupEnabled =>
      _getBool('settings_events_engineWarmup_enabled', true);
  int get engineWarmupTemp => _getInt('settings_events_engineWarmup_temp', 70);
  int get engineWarmupRpmMax =>
      _getInt('settings_events_engineWarmup_rpmMax', 6000);
  Future<void> setEngineWarmupEnabled(bool v) =>
      _setBool('settings_events_engineWarmup_enabled', v);
  Future<void> setEngineWarmupTemp(int v) =>
      _setInt('settings_events_engineWarmup_temp', v);
  Future<void> setEngineWarmupRpmMax(int v) =>
      _setInt('settings_events_engineWarmup_rpmMax', v);

  bool get coldRiskEnabled =>
      _getBool('settings_events_coldRisk_enabled', true);
  int get coldRiskTemp => _getInt('settings_events_coldRisk_temp', 5);
  int get coldRiskSpeedMin => _getInt('settings_events_coldRisk_speedMin', 40);
  int get coldRiskCooldown => _getInt('settings_events_coldRisk_cooldown', 120);
  Future<void> setColdRiskEnabled(bool v) =>
      _setBool('settings_events_coldRisk_enabled', v);
  Future<void> setColdRiskTemp(int v) =>
      _setInt('settings_events_coldRisk_temp', v);
  Future<void> setColdRiskSpeedMin(int v) =>
      _setInt('settings_events_coldRisk_speedMin', v);
  Future<void> setColdRiskCooldown(int v) =>
      _setInt('settings_events_coldRisk_cooldown', v);

  bool get extremeLeanEnabled =>
      _getBool('settings_events_extremeLean_enabled', true);
  int get extremeLeanSpeedMin =>
      _getInt('settings_events_extremeLean_speedMin', 60);
  int get extremeLeanAngleMin =>
      _getInt('settings_events_extremeLean_angleMin', 20);
  int get extremeLeanCooldown =>
      _getInt('settings_events_extremeLean_cooldown', 60);
  Future<void> setExtremeLeanEnabled(bool v) =>
      _setBool('settings_events_extremeLean_enabled', v);
  Future<void> setExtremeLeanSpeedMin(int v) =>
      _setInt('settings_events_extremeLean_speedMin', v);
  Future<void> setExtremeLeanAngleMin(int v) =>
      _setInt('settings_events_extremeLean_angleMin', v);
  Future<void> setExtremeLeanCooldown(int v) =>
      _setInt('settings_events_extremeLean_cooldown', v);

  // ===== 换挡提醒 =====

  bool get gearShiftUpEnabled =>
      _getBool('settings_events_gearShiftUp_enabled', true);
  int get gearShiftUpRpm => _getInt('settings_events_gearShiftUp_rpm', 8000);
  bool get gearShiftDownEnabled =>
      _getBool('settings_events_gearShiftDown_enabled', true);
  int get gearShiftDownRpm =>
      _getInt('settings_events_gearShiftDown_rpm', 2500);

  Future<void> setGearShiftUpEnabled(bool v) =>
      _setBool('settings_events_gearShiftUp_enabled', v);
  Future<void> setGearShiftUpRpm(int v) =>
      _setInt('settings_events_gearShiftUp_rpm', v);
  Future<void> setGearShiftDownEnabled(bool v) =>
      _setBool('settings_events_gearShiftDown_enabled', v);
  Future<void> setGearShiftDownRpm(int v) =>
      _setInt('settings_events_gearShiftDown_rpm', v);

  // ===== 仪表盘显示 =====

  /// 仪表盘风格：'cyberpunk' | 'classic'
  String get gaugeStyle => _getString('settings_gauge_style', 'cyberpunk');
  Future<void> setGaugeStyle(String v) => _setString('settings_gauge_style', v);

  int get maxRpm => _getInt('settings_display_maxRpm', 12000);
  int get warnRpm => _getInt('settings_display_warnRpm', 7000);
  int get dangerRpm => _getInt('settings_display_dangerRpm', 9000);
  int get maxSpeed => _getInt('settings_display_maxSpeed', 240);
  int get warnSpeed => _getInt('settings_display_warnSpeed', 120);
  int get dangerSpeed => _getInt('settings_display_dangerSpeed', 180);

  Future<void> setMaxRpm(int v) => _setInt('settings_display_maxRpm', v);
  Future<void> setWarnRpm(int v) => _setInt('settings_display_warnRpm', v);
  Future<void> setDangerRpm(int v) => _setInt('settings_display_dangerRpm', v);
  Future<void> setMaxSpeed(int v) => _setInt('settings_display_maxSpeed', v);
  Future<void> setWarnSpeed(int v) => _setInt('settings_display_warnSpeed', v);
  Future<void> setDangerSpeed(int v) =>
      _setInt('settings_display_dangerSpeed', v);

  // ===== 第三方服务 =====

  /// 高德 Web 服务 API Key
  /// 默认为空字符串，用户需在设置页面填写自己的 Key
  // codeflicker-fix: LOGIC-Issue-007/odko2evgylfq2rjqqr53
  String get amapKey => _getString('settings_api_amapKey', '');
  Future<void> setAmapKey(String v) => _setString('settings_api_amapKey', v);

  // ===== 高级设置 =====

  double get sensorAlpha => _getDouble('settings_advanced_sensorAlpha', 0.98);
  int get movingAverageWindow =>
      _getInt('settings_advanced_movingAverageWindow', 5);
  double get deadzoneThreshold =>
      _getDouble('settings_advanced_deadzoneThreshold', 1.0);
  double get minMoveDistance =>
      _getDouble('settings_advanced_minMoveDistance', 3.0);
  int get maxGpsGapSeconds => _getInt('settings_advanced_maxGpsGapSeconds', 30);
  int get minRidingDistance =>
      _getInt('settings_advanced_minRidingDistance', 20);
  int get maxEventHistory => _getInt('settings_advanced_maxEventHistory', 100);

  Future<void> setSensorAlpha(double v) =>
      _setDouble('settings_advanced_sensorAlpha', v);
  Future<void> setMovingAverageWindow(int v) =>
      _setInt('settings_advanced_movingAverageWindow', v);
  Future<void> setDeadzoneThreshold(double v) =>
      _setDouble('settings_advanced_deadzoneThreshold', v);
  Future<void> setMinMoveDistance(double v) =>
      _setDouble('settings_advanced_minMoveDistance', v);
  Future<void> setMaxGpsGapSeconds(int v) =>
      _setInt('settings_advanced_maxGpsGapSeconds', v);
  Future<void> setMinRidingDistance(int v) =>
      _setInt('settings_advanced_minRidingDistance', v);
  Future<void> setMaxEventHistory(int v) =>
      _setInt('settings_advanced_maxEventHistory', v);

  // ===== 批量重置 =====

  // codeflicker-fix: OPT-Issue-12/omvh7ni7j93qpiynr7sw
  // ⚠️ 维护规则：每新增一个 getter/setter，必须同步在此列表中添加对应的 key
  // 否则 resetGroup() 和 resetAll() 对该 key 无效
  static const Map<String, List<String>> _groupKeys = {
    'vehicle': [
      'settings_vehicle_primaryRatio',
      'settings_vehicle_finalRatio',
      'settings_vehicle_tireCircumference',
      'settings_vehicle_gearRatio_1',
      'settings_vehicle_gearRatio_2',
      'settings_vehicle_gearRatio_3',
      'settings_vehicle_gearRatio_4',
      'settings_vehicle_gearRatio_5',
      'settings_vehicle_gearRatio_6',
      'settings_vehicle_speedCorrectionFactor',
      'settings_vehicle_neutralSpeedThreshold',
      'settings_vehicle_neutralRpmThreshold',
    ],
    'bluetooth': [
      'settings_bluetooth_scanTimeout',
      'settings_bluetooth_minRssi',
      'settings_bluetooth_connectionTimeout',
      'settings_bluetooth_elm327InitWait',
      'settings_bluetooth_highSpeedPidInterval',
      'settings_bluetooth_mediumSpeedPidInterval',
      'settings_bluetooth_lowSpeedPidInterval',
    ],
    'events': [
      'settings_events_globalCooldown',
      'settings_events_performanceBurst_enabled',
      'settings_events_performanceBurst_rpmThreshold',
      'settings_events_engineOverheat_enabled',
      'settings_events_engineOverheat_tempThreshold',
      'settings_events_voltageAnomaly_enabled',
      'settings_events_voltageAnomaly_low',
      'settings_events_voltageAnomaly_high',
      'settings_events_highLoad_enabled',
      'settings_events_highLoad_threshold',
      'settings_events_longRiding_enabled',
      'settings_events_longRiding_durationHours',
      'settings_events_longRiding_cooldown',
      'settings_events_efficientCruising_enabled',
      'settings_events_efficientCruising_speedMin',
      'settings_events_efficientCruising_speedMax',
      'settings_events_efficientCruising_loadMax',
      'settings_events_efficientCruising_cooldown',
      'settings_events_engineWarmup_enabled',
      'settings_events_engineWarmup_temp',
      'settings_events_engineWarmup_rpmMax',
      'settings_events_coldRisk_enabled',
      'settings_events_coldRisk_temp',
      'settings_events_coldRisk_speedMin',
      'settings_events_coldRisk_cooldown',
      'settings_events_extremeLean_enabled',
      'settings_events_extremeLean_speedMin',
      'settings_events_extremeLean_angleMin',
      'settings_events_extremeLean_cooldown',
      'settings_events_gearShiftUp_enabled',
      'settings_events_gearShiftUp_rpm',
      'settings_events_gearShiftDown_enabled',
      'settings_events_gearShiftDown_rpm',
    ],
    'display': [
      'settings_gauge_style',
      'settings_display_maxRpm',
      'settings_display_warnRpm',
      'settings_display_dangerRpm',
      'settings_display_maxSpeed',
      'settings_display_warnSpeed',
      'settings_display_dangerSpeed',
    ],
    'api': [
      'settings_api_amapKey',
    ],
    'advanced': [
      'settings_advanced_sensorAlpha',
      'settings_advanced_movingAverageWindow',
      'settings_advanced_deadzoneThreshold',
      'settings_advanced_minMoveDistance',
      'settings_advanced_maxGpsGapSeconds',
      'settings_advanced_minRidingDistance',
      'settings_advanced_maxEventHistory',
    ],
  };

  Future<void> resetGroup(String group) async {
    final keys = _groupKeys[group] ?? [];
    for (final key in keys) {
      await _prefs
          .remove(key); // _prefs 为 late 非空，init() 在 runApp 前已 await，此处无需 ?.
    }
    notifyListeners();
  }

  Future<void> resetAll() async {
    // codeflicker-fix: Q-2/odko2evgylfq2rjqqr53（用户需求）
    // 只清除 settings_ 前缀的 key，不影响 DeviceStorageService 等其他持久化数据
    final allKeys = _groupKeys.values.expand((keys) => keys).toList();
    for (final key in allKeys) {
      await _prefs.remove(key);
    }
    notifyListeners();
  }
}
