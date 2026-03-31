import 'package:flutter/foundation.dart';
import '../services/sensor_service.dart';
import 'log_provider.dart';
import 'obd_data_provider.dart';
import 'settings_provider.dart';

/// 传感器 Provider - 管理倾角传感器
/// 负责传感器初始化、启动、停止、校准
class SensorProvider extends ChangeNotifier {
  final OBDDataProvider _obdDataProvider;
  late final SensorService _sensorService;

  SensorProvider({
    required OBDDataProvider obdDataProvider,
    required LogProvider logProvider,
    SettingsProvider? settings,
  }) : _obdDataProvider = obdDataProvider {
    _sensorService = SensorService(
      obdDataProvider: obdDataProvider,
      logCallback: (source, type, message) =>
          logProvider.addLog(source, type, message),
      settings: settings,
    );
  }

  /// Settings 变更时由 ProxyProvider 调用，将最新 SettingsProvider 透传给 SensorService
  void updateSettings(SettingsProvider? settings) {
    _sensorService.updateSettings(settings);
  }

  /// 初始化传感器服务（APP 启动时调用）
  void initialize() {
    _sensorService.start();
  }

  /// 零点校准
  void calibrate() {
    _sensorService.calibrate();
    _obdDataProvider.calibrateLeanAngle();
  }

  @override
  void dispose() {
    _sensorService.dispose();
    super.dispose();
  }
}
