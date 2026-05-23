import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/engine_sound_style.dart';
import '../models/obd_data.dart';
import '../providers/log_provider.dart';
import '../providers/loggable.dart';
import '../providers/obd_data_provider.dart';
import '../providers/settings_provider.dart';
import '../services/audio_service.dart';
import '../services/engine_sound_engine.dart';
import '../services/engine_sound_synthesizer.dart';

/// 发动机声浪 Provider
///
/// 职责：
///   1. 每 100ms 轮询 OBDDataProvider，驱动 EngineSoundEngine.update()
///   2. 根据转速数据自动启停声浪：
///      - rpm > 0（引擎运转）且功能已开启 → 自动启动
///      - rpm == 0（无数据 / 引擎停转）   → 自动停止
///   3. 检测换挡事件，触发 SFX
///   4. 检测急减速回火，触发 decelPop
///   5. 与 AudioService 互斥（声浪开启时屏蔽事件提醒音频）
class EngineSoundProvider extends ChangeNotifier {
  final OBDDataProvider _obdData;
  final SettingsProvider _settings;
  final AudioService _audioService;

  late final EngineSoundSynthesizer _synth;
  late final EngineSoundEngine _engine;

  static const String _source = 'EngineSound';

  void Function(String source, LogType type, String message)? _logCallback;

  // 状态
  bool _isReady = false; // PCM 合成完成 + SoLoud 就绪
  bool _isPlaying = false;
  String? _initError;

  // 上一帧状态（用于换挡/回火检测）
  int _prevGear = 0;
  int _prevThrottle = 0;
  int _prevRpm = 0;

  // 连续 rpm==0 的帧数，超过阈值才停止（防止短暂数据抖动误停）
  int _zeroRpmFrames = 0;
  // 连续 1 帧（100ms）rpm==0 才停止声浪
  static const int _zeroRpmStopThreshold = 1;

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
    LogProvider? logProvider,
  })  : _obdData = obdData,
        _settings = settings,
        _audioService = audioService {
    if (logProvider != null) {
      _logCallback = createLogger(logProvider);
    }
    _synth = EngineSoundSynthesizer();
    _engine = EngineSoundEngine(
      synth: _synth,
      logCallback: _logCallback,
    );
  }

  void _log(LogType type, String message) {
    _logCallback?.call(_source, type, message);
  }

  // ───────────────────────────────────────────────
  // 初始化（App 启动时在后台完成）
  // ───────────────────────────────────────────────

  /// 初始化合成器 + SoLoud，完成后启动轮询
  /// 在 main.dart 中后台调用（不阻塞 UI）
  Future<void> init() async {
    try {
      _log(LogType.info, '开始 PCM 合成...');
      await _synth.init(); // ~200~500ms 在 Dart 中执行
      await _engine.initSoLoud();
      _isReady = _engine.isInitialized;
      _log(LogType.success, '初始化完成，ready=$_isReady');
    } catch (e) {
      _initError = e.toString();
      _isReady = false;
      _log(LogType.error, '初始化失败: $e');
    }
    notifyListeners();

    // 初始化完成后启动轮询，由轮询根据转速自动启停声浪
    if (_isReady && _settings.engineSoundEnabled) {
      _startPolling();
    }
  }

  // ───────────────────────────────────────────────
  // 开启/关闭（手动控制，供设置页使用）
  // ───────────────────────────────────────────────

  /// 开启声浪（仅启动轮询，实际播放由轮询检测到 rpm>0 后触发）
  Future<void> startEngineSound() async {
    if (!_isReady) return;
    _startPolling();
    _log(LogType.info, '声浪功能已开启，等待转速数据...');
  }

  /// 停止声浪播放并停止轮询
  Future<void> stopEngineSound() async {
    _stopPolling();
    await _stopPlayback();
  }

  /// 切换开关（供设置页联动）
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
      // 重启新风格
      await _stopPlayback();
      await _startPlayback();
    }
  }

  /// 设置主音量（立即生效）
  Future<void> setVolume(double volume) async {
    await _settings.setEngineSoundVolume(volume);
    _engine.setMasterVolume(volume);
  }

  // ───────────────────────────────────────────────
  // 内部：实际播放控制
  // ───────────────────────────────────────────────

  Future<void> _startPlayback() async {
    if (_isPlaying) return;
    final style = EngineStyles.fromId(_settings.engineSoundStyle);
    _audioService.setEngineSoundActive(true);
    await _engine.start(style);
    _engine.setMasterVolume(_settings.engineSoundVolume);
    _isPlaying = true;
    notifyListeners();
    _log(LogType.info, '声浪开始播放: ${style.name}');
  }

  Future<void> _stopPlayback() async {
    if (!_isPlaying) return;
    await _engine.stop();
    _audioService.setEngineSoundActive(false);
    _isPlaying = false;
    _zeroRpmFrames = 0;
    notifyListeners();
    _log(LogType.info, '声浪停止播放');
  }

  // ───────────────────────────────────────────────
  // 设置更新（由 main.dart ProxyProvider 驱动）
  // ───────────────────────────────────────────────

  void updateSettings(SettingsProvider settings) {
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
    final data = _obdData.data;
    final int rpm = data.rpm;
    final int throttle = data.throttle;
    final int load = data.load;
    final int gear = data.gear;

    // ── 根据转速自动启停 ──────────────────────────────
    if (rpm > 0) {
      // 有转速数据：重置零转速计数，确保声浪在播放
      _zeroRpmFrames = 0;
      if (!_isPlaying) {
        _startPlayback();
        return; // 本帧先启动，下帧再更新参数
      }
    } else {
      // rpm == 0：累计连续零转速帧数
      _zeroRpmFrames++;
      if (_isPlaying && _zeroRpmFrames >= _zeroRpmStopThreshold) {
        _log(LogType.info, '转速持续为0（${_zeroRpmFrames * 100}ms），停止声浪');
        _stopPlayback();
        _prevGear = 0;
        _prevThrottle = 0;
        _prevRpm = 0;
        return;
      }
      // 未达阈值或本来就没在播放，不处理
      if (!_isPlaying) return;
    }

    // ── 换挡检测 ──────────────────────────────────────
    if (_prevGear > 0 && gear > 0 && gear != _prevGear) {
      if (gear > _prevGear) {
        _engine.playUpshiftSfx();
      } else {
        _engine.playDownshiftSfx();
      }
    }

    // ── 急减速回火检测 ────────────────────────────────
    if (_prevThrottle >= _decelPopThrottleHigh &&
        throttle < _decelPopThrottleLow &&
        _prevRpm > _decelPopRpmMin) {
      _engine.playDecelPop();
    }

    // ── 计算减速增强系数 ──────────────────────────────
    final double decelBoost =
        (throttle < 10 && rpm > 2000) ? (1.0 - throttle / 10.0) : 0.0;

    // ── 更新引擎参数 ──────────────────────────────────
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

  /// 以怠速状态预览当前风格（设置页试听）
  Future<void> startIdlePreview() async {
    if (!_isReady) return;
    if (_isPlaying) return;
    final style = EngineStyles.fromId(_settings.engineSoundStyle);
    _audioService.setEngineSoundActive(true);
    await _engine.start(style);
    _engine.setMasterVolume(_settings.engineSoundVolume);
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
