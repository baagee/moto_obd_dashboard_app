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
///   6. 支持风格试听（previewStyle）：在无 OBD 数据时自动播放演示序列
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

  // 试听状态
  bool _isPreviewMode = false;
  Timer? _previewTimer; // 演示序列驱动 Timer
  int _previewStep = 0; // 当前演示步骤索引

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

  // ── 演示序列（拉转速）──
  // 每帧 100ms，共 40 帧 = 4.0s
  // [rpm, throttle, load]
  static const List<List<int>> _previewSequence = [
    // 0.0~0.5s：怠速起步
    [1200, 5, 10], [1300, 5, 10], [1400, 8, 12], [1600, 10, 15], [1800, 15, 18],
    // 0.5~1.5s：缓慢加速
    [2200, 25, 30], [2800, 35, 38], [3400, 45, 48], [4100, 55, 56], [4800, 65, 64],
    // 1.0~2.5s：持续拉转
    [5400, 72, 70], [6000, 78, 75], [6600, 82, 80], [7100, 86, 83], [7600, 88, 86],
    // 2.5~3.0s：接近红线
    [8000, 90, 88], [8300, 92, 89], [8600, 93, 90], [8800, 94, 91], [9000, 95, 92],
    // 3.0~4.0s：红线区保持
    [9000, 94, 91], [9000, 94, 91], [9000, 93, 91], [9000, 93, 90], [9000, 92, 90],
    [9000, 92, 90], [9000, 92, 89], [9000, 91, 89], [9000, 91, 89], [9000, 91, 88],
    [9000, 90, 88], [9000, 90, 88], [9000, 90, 87], [9000, 90, 87], [9000, 90, 87],
    [9000, 90, 86], [9000, 90, 86], [9000, 89, 86], [9000, 89, 85], [9000, 89, 85],
  ];

  // Getters
  bool get isReady => _isReady;
  bool get isPlaying => _isPlaying;
  bool get isPreviewMode => _isPreviewMode;
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

  Future<void> init() async {
    try {
      _log(LogType.info, '开始 PCM 合成...');
      await _synth.init();
      await _engine.initSoLoud();
      _isReady = _engine.isInitialized;
      _log(LogType.success, '初始化完成，ready=$_isReady');
    } catch (e) {
      _initError = e.toString();
      _isReady = false;
      _log(LogType.error, '初始化失败: $e');
    }
    notifyListeners();

    if (_isReady && _settings.engineSoundEnabled) {
      _startPolling();
    }
  }

  // ───────────────────────────────────────────────
  // 开启/关闭
  // ───────────────────────────────────────────────

  Future<void> startEngineSound() async {
    if (!_isReady) return;
    _cancelPreview(); // 开启 OBD 模式时取消试听
    _startPolling();
    _log(LogType.info, '声浪功能已开启，等待转速数据...');
  }

  Future<void> stopEngineSound() async {
    _cancelPreview();
    _stopPolling();
    await _stopPlayback();
  }

  Future<void> setEnabled(bool enabled) async {
    await _settings.setEngineSoundEnabled(enabled);
    if (enabled) {
      await startEngineSound();
    } else {
      await stopEngineSound();
    }
  }

  Future<void> setStyle(String styleId) async {
    await _settings.setEngineSoundStyle(styleId);
    if (_isPlaying && !_isPreviewMode) {
      // OBD 驱动中：重启新风格
      await _stopPlayback();
      await _startPlayback();
    }
    // 试听模式中切换风格由 previewStyle 处理
  }

  Future<void> setVolume(double volume) async {
    await _settings.setEngineSoundVolume(volume);
    _engine.setMasterVolume(volume);
  }

  // ───────────────────────────────────────────────
  // 风格试听（设置页使用）
  // ───────────────────────────────────────────────

  /// 试听指定风格
  ///
  /// 若 OBD 正在输出转速数据（引擎运转中），则仅切换风格，不触发试听序列。
  /// 否则播放 4 秒演示序列（怠速→拉转→巡航→收油），结束后自动停止。
  Future<void> previewStyle(String styleId) async {
    if (!_isReady) return;

    // 切换风格配置
    await _settings.setEngineSoundStyle(styleId);

    // 若当前 OBD 有真实转速，只切换风格，不播试听
    if (_obdData.data.rpm > 0 && !_isPreviewMode) {
      if (_isPlaying) {
        await _stopPlayback();
        await _startPlayback();
      }
      _log(LogType.info, '有OBD转速，切换风格: $styleId');
      return;
    }

    // ── 触发试听演示序列 ──
    _cancelPreview(); // 取消上一次试听（支持快速切换）

    if (_isPlaying && !_isPreviewMode) {
      // OBD 驱动播放中，先停止
      await _stopPlayback();
    }

    _log(LogType.info, '开始试听: $styleId');
    _isPreviewMode = true;
    _previewStep = 0;

    // 启动播放
    await _startPlayback();

    // 推第一帧参数，让声音立刻有"感觉"
    _applyPreviewFrame(0);

    // 启动演示序列 Timer（每 100ms 推一帧）
    _previewTimer = Timer.periodic(const Duration(milliseconds: 100), (t) {
      _previewStep++;
      if (_previewStep >= _previewSequence.length) {
        // 演示结束，自动停止
        _finishPreview();
        return;
      }
      _applyPreviewFrame(_previewStep);
    });

    notifyListeners();
  }

  void _applyPreviewFrame(int step) {
    final frame = _previewSequence[step];
    final rpm = frame[0];
    final throttle = frame[1];
    final load = frame[2];
    final decelBoost =
        (throttle < 10 && rpm > 2000) ? (1.0 - throttle / 10.0) : 0.0;
    _engine.update(
      rpm: rpm,
      throttle: throttle,
      load: load,
      decelBoost: decelBoost,
    );
  }

  void _finishPreview() {
    _cancelPreview();
    _stopPlayback();
    _log(LogType.info, '试听结束');
    notifyListeners();
  }

  void _cancelPreview() {
    _previewTimer?.cancel();
    _previewTimer = null;
    if (_isPreviewMode) {
      _isPreviewMode = false;
      _previewStep = 0;
      notifyListeners();
    }
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
  // 100ms 轮询驱动（OBD 模式）
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
    // 试听模式下，OBD 轮询不干预播放，但若真实 rpm 出现则中断试听
    if (_isPreviewMode) {
      final liveRpm = _obdData.data.rpm;
      if (liveRpm > 0) {
        _log(LogType.info, '检测到真实转速 $liveRpm rpm，中断试听');
        _cancelPreview(); // 中断试听序列
        // 不停止播放，直接接管参数更新
        _isPlaying = true; // 已在播放中
      } else {
        return; // 试听中，OBD 无数据，跳过
      }
    }

    final data = _obdData.data;
    final int rpm = data.rpm;
    final int throttle = data.throttle;
    final int load = data.load;
    final int gear = data.gear;

    // ── 根据转速自动启停 ──────────────────────────────
    if (rpm > 0) {
      _zeroRpmFrames = 0;
      if (!_isPlaying) {
        _startPlayback();
        return;
      }
    } else {
      _zeroRpmFrames++;
      if (_isPlaying && _zeroRpmFrames >= _zeroRpmStopThreshold) {
        _log(LogType.info, '转速持续为0（${_zeroRpmFrames * 100}ms），停止声浪');
        _stopPlayback();
        _prevGear = 0;
        _prevThrottle = 0;
        _prevRpm = 0;
        return;
      }
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

    // ── 减速增强系数 ──────────────────────────────────
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
  // 资源释放
  // ───────────────────────────────────────────────

  @override
  Future<void> dispose() async {
    _cancelPreview();
    _stopPolling();
    await _engine.stop();
    _audioService.setEngineSoundActive(false);
    await _engine.dispose();
    super.dispose();
  }
}
