import '../models/riding_event.dart';

/// 事件语音配置模型
/// 用于配置每个事件类型的语音播报
class EventVoiceConfig {
  /// 事件类型
  final RidingEventType eventType;

  /// 音频文件路径（assets 路径）
  final String audioAssetPath;

  /// 语音时长获取回调（毫秒）
  /// 动态获取音频时长
  final int Function()? getDurationMs;

  const EventVoiceConfig({
    required this.eventType,
    required this.audioAssetPath,
    this.getDurationMs,
  });

  /// 默认语音时长（当无法获取时长时使用）
  static const int defaultDurationMs = 2000;
}

/// 事件语音配置管理器
/// 提供默认的语音配置映射
class EventVoiceConfigManager {
  EventVoiceConfigManager._();

  /// 获取所有默认配置
  static List<EventVoiceConfig> getDefaultConfigs() {
    return [
      const EventVoiceConfig(
        eventType: RidingEventType.performanceBurst,
        audioAssetPath: 'assets/audio/performance_burst.mp3',
        getDurationMs: null,
      ),
      const EventVoiceConfig(
        eventType: RidingEventType.efficientCruising,
        audioAssetPath: 'assets/audio/efficient_cruising.mp3',
        getDurationMs: null,
      ),
      const EventVoiceConfig(
        eventType: RidingEventType.engineOverheating,
        audioAssetPath: 'assets/audio/engine_overheating.mp3',
        getDurationMs: null,
      ),
      const EventVoiceConfig(
        eventType: RidingEventType.voltageAnomaly,
        audioAssetPath: 'assets/audio/voltage_anomaly.mp3',
        getDurationMs: null,
      ),
      const EventVoiceConfig(
        eventType: RidingEventType.longRiding,
        audioAssetPath: 'assets/audio/long_riding.mp3',
        getDurationMs: null,
      ),
      const EventVoiceConfig(
        eventType: RidingEventType.highEngineLoad,
        audioAssetPath: 'assets/audio/high_engine_load.mp3',
        getDurationMs: null,
      ),
      const EventVoiceConfig(
        eventType: RidingEventType.engineWarmup,
        audioAssetPath: 'assets/audio/engine_warmup.mp3',
        getDurationMs: null,
      ),
      const EventVoiceConfig(
        eventType: RidingEventType.coldEnvironmentRisk,
        audioAssetPath: 'assets/audio/cold_environment.mp3',
        getDurationMs: null,
      ),
      const EventVoiceConfig(
        eventType: RidingEventType.extremeLean,
        audioAssetPath: 'assets/audio/extreme_lean.mp3',
        getDurationMs: null,
      ),
      const EventVoiceConfig(
        eventType: RidingEventType.gearShiftUp,
        audioAssetPath: 'assets/audio/gear_shift_up.mp3',
        getDurationMs: null,
      ),
      const EventVoiceConfig(
        eventType: RidingEventType.gearShiftDown,
        audioAssetPath: 'assets/audio/gear_shift_down.mp3',
        getDurationMs: null,
      ),
    ];
  }

  /// 获取配置映射
  static Map<RidingEventType, EventVoiceConfig> getConfigMap() {
    final configs = getDefaultConfigs();
    return {for (var config in configs) config.eventType: config};
  }

  /// 根据事件类型获取配置
  static EventVoiceConfig? getConfig(RidingEventType eventType) {
    return getConfigMap()[eventType];
  }
}
