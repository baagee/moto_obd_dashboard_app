import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/engine_sound_style.dart';
import '../providers/obd_data_provider.dart';
import '../providers/settings_provider.dart';
import '../services/audio_service.dart';
import '../services/engine_sound_engine.dart';
import '../services/engine_sound_synthesizer.dart';

/// 发动机声浪 Provider
///
/// 职责：
///   1. 订阅 OBDDataProvider，每 100ms 驱动 EngineSoundEngine.update()
///   2. 检测换挡事件，触发 SFX
///   3. 检测急减速回火，触发 decelPop
///   4. 与 AudioService 互斥（声浪开启时屏蔽事件提醒音频）
///   5. 监听 SettingsProvider 变化，同步设置（音量/风格/开关）
class EngineSoundProvider extends ChangeNotifier {
  final OBDDataProvider _obdData;
  final SettingsProvider _settings;
  final AudioService _audioService;

  late final EngineSoundSynthesizer _synth;
  late final EngineSoundEngine _engine;

  // 状态
  bool _isReady = false; // PCM 合成完成 + SoLoud 就绪
  bool _isPlaying = false;
  String? _initError;

  // 上一帧状态（用于换挡/回火检测）
  int _prevGear = 0;
  int _prevThrottle = 0;
  int _prevRpm = 0;

  // 急减速回火检测：油门从 >60% 降至 <10% 且 rpm >4000
  static const int _decelPopThrottleHigh = 60;
  static const int _decelPopThrottleLow = 10;
  static const int _decelPopRpmMin = 4000;

  // 100ms 轮询定时器
  Timer? _pollTimer;

  // Getters
  bool get isReady => _isReady;
  bool get isPlaying => _isPlaying;
  String? get initError => _initError;

  EngineSoundProvider({
    required OBDDataProvider obdData,
    required SettingsProvider settings,
    required AudioService audioService,
  })  : _obdData = obdData,
        _settings = settings,
        _audioService = audioService {
    _synth = EngineSoundSynthesizer();
    _engine = EngineSoundEngine(synth: _synth);
  }

  // ───────────────────────────────────────────────
  // 初始化（App 启动时在后台完成）
  // ───────────────────────────────────────────────

  /// 初始化合成器 + SoLoud
  /// 在 main.dart 中启动后台初始化（不阻塞 UI）
  Future<void> init() async {
    try {
      debugPrint('[EngineSoundProvider] 开始 PCM 合成...');
      await _synth.init(); // ~200~500ms 在 Dart 中执行
      await _engine.initSoLoud();
      _isReady = _engine.isInitialized;
      debugPrint('[EngineSoundProvider] 初始化完成，ready=$_isReady');
    } catch (e) {
      _initError = e.toString();
      _isReady = false;
      debugPrint('[EngineSoundProvider] 初始化失败: $e');
    }
    notifyListeners();

    // 若设置中声浪为开启状态，自动启动
    if (_isReady && _settings.engineSoundEnabled) {
      await startEngineSound();
    }
  }

  // ───────────────────────────────────────────────
  // 开启/关闭
  // ───────────────────────────────────────────────

  /// 开启声浪播放
  Future<void> startEngineSound() async {
    if (!_isReady) return;
    if (_isPlaying) return;

    final style = EngineStyles.fromId(_settings.engineSoundStyle);

    // 互斥：屏蔽 AudioService 的事件提醒
    _audioService.setEngineSoundActive(true);

    await _engine.start(style);
    _engine.setMasterVolume(_settings.engineSoundVolume);

    _isPlaying = true;
    _startPolling();
    notifyListeners();
    debugPrint('[EngineSoundProvider] 声浪已启动: ${style.name}');
  }

  /// 停止声浪播放
  Future<void> stopEngineSound() async {
    if (!_isPlaying) return;

    _stopPolling();
    await _engine.stop();

    // 解除互斥
    _audioService.setEngineSoundActive(false);

    _isPlaying = false;
    notifyListeners();
    debugPrint('[EngineSoundProvider] 声浪已停止');
  }

  /// 切换开关（供 SettingsProvider 联动）
  Future<void> setEnabled(bool enabled) async {
    await _settings.setEngineSoundEnabled(enabled);
    if (enabled) {
      await startEngineSound();
    } else {
      await stopEngineSound();
    }
  }

  /// 切换风格（立即生效）
  Future<void> setStyle(String styleId) async {
    await _settings.setEngineSoundStyle(styleId);
    if (_isPlaying) {
      // 重新启动新风格
      _stopPolling();
      await _engine.stop();
      _isPlaying = false;
      await startEngineSound();
    }
  }

  /// 设置主音量（立即生效）
  Future<void> setVolume(double volume) async {
    await _settings.setEngineSoundVolume(volume);
    _engine.setMasterVolume(volume);
  }

  // ───────────────────────────────────────────────
  // 设置更新（由 main.dart ProxyProvider 驱动）
  // ───────────────────────────────────────────────

  void updateSettings(SettingsProvider settings) {
    // 注意：此处 settings 与 _settings 是同一实例（ProxyProvider 传入相同对象）
    // 主要用于触发音量/风格同步
    if (_isPlaying) {
      _engine.setMasterVolume(_settings.engineSoundVolume);
    }
  }

  // ───────────────────────────────────────────────
  // 100ms 轮询驱动
  // ───────────────────────────────────────────────

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      _onOBDUpdate();
    });
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  void _onOBDUpdate() {
    if (!_isPlaying) return;
    final data = _obdData.data;

    final int rpm = data.rpm;
    final int throttle = data.throttle;
    final int load = data.load;
    final int gear = data.gear;

    // 换挡检测
    if (_prevGear > 0 && gear > 0 && gear != _prevGear) {
      if (gear > _prevGear) {
        _engine.playUpshiftSfx();
      } else {
        _engine.playDownshiftSfx();
      }
    }

    // 急减速回火检测：油门从 >60% 降至 <10% 且 rpm >4000
    if (_prevThrottle >= _decelPopThrottleHigh &&
        throttle < _decelPopThrottleLow &&
        _prevRpm > _decelPopRpmMin) {
      _engine.playDecelPop();
    }

    // 计算减速增强系数
    final double decelBoost =
        (throttle < 10 && rpm > 2000) ? (1.0 - throttle / 10.0) : 0.0;

    // 更新引擎参数
    _engine.update(
      rpm: rpm,
      throttle: throttle,
      load: load,
      decelBoost: decelBoost,
    );

    _prevGear = gear;
    _prevThrottle = throttle;
    _prevRpm = rpm;
  }

  // ───────────────────────────────────────────────
  // 预览怠速（设置页使用）
  // ───────────────────────────────────────────────

  /// 以怠速状态预览当前风格（开启设置时用于试听）
  Future<void> startIdlePreview() async {
    if (!_isReady) return;
    if (_isPlaying) return;

    final style = EngineStyles.fromId(_settings.engineSoundStyle);
    _audioService.setEngineSoundActive(true);
    await _engine.start(style);
    _engine.setMasterVolume(_settings.engineSoundVolume);
    // 以怠速参数更新一次
    _engine.update(rpm: 1500, throttle: 5, load: 10, decelBoost: 0.0);
    _isPlaying = true;
    notifyListeners();
  }

  // ───────────────────────────────────────────────
  // 资源释放
  // ───────────────────────────────────────────────

  @override
  Future<void> dispose() async {
    _stopPolling();
    await _engine.stop();
    _audioService.setEngineSoundActive(false);
    await _engine.dispose();
    super.dispose();
  }
}
