import 'dart:math' as math;
import 'package:flutter_soloud/flutter_soloud.dart';
import '../models/engine_sound_style.dart';
import '../models/obd_data.dart';
import 'engine_sound_synthesizer.dart';

/// 发动机声浪播放引擎（SoLoud 驱动）
///
/// 管理 SoLoud 实例的生命周期，提供：
///   - start(style)：加载指定风格 buffer 并开始循环播放
///   - update(...)：实时调整播放速度/音量（< 30ms 延迟）
///   - stop()：停止所有播放
///   - playUpshiftSfx() / playDownshiftSfx()：播放换挡音效
///   - playDecelPop()：急减速回火音效（与 downshift 相同）
///
/// 注意：EngineSoundEngine 独立使用 flutter_soloud，
/// 不与 AudioService（audioplayers）共享引擎实例。
class EngineSoundEngine {
  final EngineSoundSynthesizer _synth;

  static const String _source = 'EngineSound';

  /// 日志回调，由 EngineSoundProvider 通过 createLogger(logProvider) 注入
  void Function(String source, LogType type, String message)? logCallback;

  SoLoud? _soLoud;
  bool _isInitialized = false;

  // 当前活跃的声音句柄
  SoundHandle? _toneHandle;
  SoundHandle? _noiseHandle;
  SoundHandle? _exhHandle;

  // 当前加载的声音资源
  AudioSource? _toneSource;
  AudioSource? _noiseSource;
  AudioSource? _exhSource;

  // SFX 资源（预加载）
  AudioSource? _upshiftSource;
  AudioSource? _downshiftSource;

  // 当前风格 id（可供日志使用）
  String _currentStyleId = 'i4';

  String get currentStyleId => _currentStyleId;

  // 参考转速（合成时使用的基准转速）
  static const int _refRpm = EngineSoundSynthesizer.refRpm;

  // 音量参数
  double _masterVolume = 1.0;
  double _toneVolume = 0.90;
  double _noiseVolume = 0.35;
  double _exhVolume = 0.25;

  // 当前播放速度
  double _currentPlaySpeed = 1.0;

  EngineSoundEngine({
    required EngineSoundSynthesizer synth,
    this.logCallback,
  }) : _synth = synth;

  bool get isInitialized => _isInitialized;

  void _log(LogType type, String message) {
    logCallback?.call(_source, type, message);
  }

  // ───────────────────────────────────────────────
  // 初始化 SoLoud
  // ───────────────────────────────────────────────

  /// 初始化 SoLoud 引擎（在 EngineSoundProvider.init() 中调用）
  Future<void> initSoLoud() async {
    try {
      _soLoud = SoLoud.instance;
      await _soLoud!.init(
        sampleRate: EngineSoundSynthesizer.sampleRate,
        bufferSize: 512, // 低延迟缓冲区
      );
      _isInitialized = true;
      // 全局软件增益：允许超过 1.0，骑行环境噪声大需要更高输出
      _soLoud!.setGlobalVolume(2.0);
      _log(LogType.success, 'SoLoud 初始化成功');
    } catch (e) {
      _log(LogType.error, 'SoLoud 初始化失败: $e');
      _isInitialized = false;
    }
  }

  // ───────────────────────────────────────────────
  // 启动/停止
  // ───────────────────────────────────────────────

  /// 启动指定风格的发动机声浪
  Future<void> start(EngineStyleConfig style) async {
    if (!_isInitialized || _soLoud == null) return;

    await _stopCurrentVoices();
    await _unloadCurrentSources();

    _currentStyleId = style.id;

    try {
      // 加载 tone buffer
      final toneBytes = _synth.getToneBuffer(style.id);
      if (toneBytes != null) {
        _toneSource = await _soLoud!.loadMem('tone_${style.id}', toneBytes);
      }

      // 加载 noise buffer
      final noiseBytes = _synth.getNoiseBuffer(style.id);
      if (noiseBytes != null) {
        _noiseSource = await _soLoud!.loadMem('noise_${style.id}', noiseBytes);
      }

      // 加载 exh buffer
      final exhBytes = _synth.getExhBuffer(style.id);
      if (exhBytes != null) {
        _exhSource = await _soLoud!.loadMem('exh_${style.id}', exhBytes);
      }

      // 加载 SFX（如果尚未加载）
      await _loadSfxIfNeeded();

      // 播放三层循环
      if (_toneSource != null) {
        _toneHandle = await _soLoud!.play(
          _toneSource!,
          volume: _toneVolume * _masterVolume,
          looping: true,
        );
      }
      if (_noiseSource != null) {
        _noiseHandle = await _soLoud!.play(
          _noiseSource!,
          volume: _noiseVolume * _masterVolume,
          looping: true,
        );
      }
      if (_exhSource != null) {
        _exhHandle = await _soLoud!.play(
          _exhSource!,
          volume: _exhVolume * _masterVolume,
          looping: true,
        );
      }

      _log(LogType.info, '开始播放风格: ${style.name}');
    } catch (e) {
      _log(LogType.error, '启动失败: $e');
    }
  }

  /// 停止所有播放
  Future<void> stop() async {
    await _stopCurrentVoices();
    _log(LogType.info, '停止播放');
  }

  // ───────────────────────────────────────────────
  // 实时参数更新（< 30ms）
  // ───────────────────────────────────────────────

  /// 实时更新发动机参数
  /// [rpm]：当前转速
  /// [throttle]：油门 0~100
  /// [load]：发动机负载 0~100
  /// [decelBoost]：收油减速增强系数（0~1，>0 时增强排气声）
  void update({
    required int rpm,
    required int throttle,
    required int load,
    double decelBoost = 0.0,
  }) {
    if (!_isInitialized || _soLoud == null) return;

    // 1. 计算播放速度：(rpm/refRpm)^0.65
    // 指数 0.65（原 0.85）：高速时变速幅度更小，减少频谱上移
    // rpm=9000: 0.85→ ×2.58，0.65→ ×2.10，频谱上移减少约 20%
    final double playSpeed = rpm > 0
        ? math.pow(rpm / _refRpm.toDouble(), 0.65).toDouble()
        : 0.3;
    _currentPlaySpeed = playSpeed.clamp(0.1, 3.5);

    // 2. 计算各层音量
    final double throttleNorm = throttle / 100.0;
    final double loadNorm = load / 100.0;

    // tone 层：主音调，随油门增强
    // 高速时（playSpeed>1.5）buffer 被变速拉到高频区域，轻微降音量防止刺耳
    final double toneHiSpeedAttn = playSpeed > 1.5
        ? (1.0 - (playSpeed - 1.5) / 3.5 * 0.30).clamp(0.55, 1.0)
        : 1.0;
    // 低速补偿：tone buffer 截止从 1500Hz 降到 800Hz，低速段音色稍暗，+20% 补偿
    final double toneLowSpeedBoost =
        playSpeed < 1.0 ? (1.0 + (1.0 - playSpeed) * 0.20) : 1.0;
    _toneVolume = (0.70 + throttleNorm * 0.30).clamp(0.0, 1.0) *
        toneHiSpeedAttn *
        toneLowSpeedBoost;

    // noise 层：机械噪声
    // noise buffer 已经被压到 120Hz 极低频，playSpeed 固定 1.0（见 _applyParams）
    // 但音量仍需随速度衰减，避免低频持续轰鸣感
    // 衰减指数 0.25（原 0.40）：更激进，playSpeed=2.0 → ×0.25，playSpeed=2.1 → ×0.20
    final double noiseHiSpeedAttn = playSpeed > 1.0
        ? math.pow(0.25, playSpeed - 1.0).toDouble().clamp(0.08, 1.0)
        : 1.0;
    _noiseVolume = (0.22 + loadNorm * 0.22).clamp(0.0, 0.50) * noiseHiSpeedAttn;

    // exh 层：排气声，收油时增强；高速时也轻微衰减
    final double exhHiSpeedAttn = playSpeed > 1.5
        ? (1.0 - (playSpeed - 1.5) / 4.0 * 0.40).clamp(0.45, 1.0)
        : 1.0;
    _exhVolume = (0.18 + decelBoost * 0.55).clamp(0.0, 0.75) * exhHiSpeedAttn;

    // 3. 应用到 SoLoud
    _applyParams();
  }

  void _applyParams() {
    final soLoud = _soLoud;
    if (soLoud == null) return;

    try {
      if (_toneHandle != null) {
        soLoud.setRelativePlaySpeed(_toneHandle!, _currentPlaySpeed);
        soLoud.setVolume(_toneHandle!, _toneVolume * _masterVolume);
      }
      if (_noiseHandle != null) {
        // 噪声层 playSpeed 固定为 1.0：noise buffer 已压到 120Hz 极低频
        // 不跟 RPM 变速，避免低频噪声被拉高到刺耳中频区
        soLoud.setRelativePlaySpeed(_noiseHandle!, 1.0);
        soLoud.setVolume(_noiseHandle!, _noiseVolume * _masterVolume);
      }
      if (_exhHandle != null) {
        soLoud.setRelativePlaySpeed(_exhHandle!, _currentPlaySpeed * 0.7 + 0.3);
        soLoud.setVolume(_exhHandle!, _exhVolume * _masterVolume);
      }
    } catch (e) {
      // 句柄可能已失效（停止时被清理），忽略
    }
  }

  /// 设置主音量
  /// [volume] 来自设置滑块（0.0~1.0），内部映射到 0.0~4.0 倍增益
  /// 骑行环境噪声大，需要较高增益才能听清
  void setMasterVolume(double volume) {
    // 非线性映射：前半段（0~0.5）线性到 0~1.0，后半段（0.5~1.0）到 1.0~4.0
    // 让用户感知更线性，同时提供足够的最大输出
    _masterVolume = volume <= 0.5
        ? volume * 2.0
        : 1.0 + (volume - 0.5) * 6.0;
    _applyParams();
  }

  // ───────────────────────────────────────────────
  // SFX 播放
  // ───────────────────────────────────────────────

  /// 升档音效
  Future<void> playUpshiftSfx() async {
    await _playSfx(_upshiftSource);
  }

  /// 降档/回火音效
  Future<void> playDownshiftSfx() async {
    await _playSfx(_downshiftSource);
  }

  /// 急减速回火（使用 downshift 音效）
  Future<void> playDecelPop() async {
    await _playSfx(_downshiftSource);
  }

  Future<void> _playSfx(AudioSource? source) async {
    if (!_isInitialized || _soLoud == null || source == null) return;
    try {
      await _soLoud!.play(source, volume: _masterVolume * 0.8);
    } catch (e) {
      _log(LogType.warning, 'SFX 播放失败: $e');
    }
  }

  // ───────────────────────────────────────────────
  // 资源管理
  // ───────────────────────────────────────────────

  Future<void> _loadSfxIfNeeded() async {
    final soLoud = _soLoud;
    if (soLoud == null) return;

    if (_upshiftSource == null) {
      final upBytes = _synth.upshiftBuffer;
      if (upBytes != null) {
        _upshiftSource = await soLoud.loadMem('upshift_sfx', upBytes);
      }
    }
    if (_downshiftSource == null) {
      final downBytes = _synth.downshiftBuffer;
      if (downBytes != null) {
        _downshiftSource = await soLoud.loadMem('downshift_sfx', downBytes);
      }
    }
  }

  Future<void> _stopCurrentVoices() async {
    final soLoud = _soLoud;
    if (soLoud == null) return;
    try {
      if (_toneHandle != null) {
        soLoud.stop(_toneHandle!);
        _toneHandle = null;
      }
      if (_noiseHandle != null) {
        soLoud.stop(_noiseHandle!);
        _noiseHandle = null;
      }
      if (_exhHandle != null) {
        soLoud.stop(_exhHandle!);
        _exhHandle = null;
      }
    } catch (e) {
      // 忽略已停止的句柄
    }
  }

  Future<void> _unloadCurrentSources() async {
    final soLoud = _soLoud;
    if (soLoud == null) return;
    try {
      if (_toneSource != null) {
        soLoud.disposeSource(_toneSource!);
        _toneSource = null;
      }
      if (_noiseSource != null) {
        soLoud.disposeSource(_noiseSource!);
        _noiseSource = null;
      }
      if (_exhSource != null) {
        soLoud.disposeSource(_exhSource!);
        _exhSource = null;
      }
    } catch (e) {
      // 忽略
    }
  }

  /// 释放 SoLoud 引擎（App 关闭时调用）
  Future<void> dispose() async {
    await _stopCurrentVoices();
    await _unloadCurrentSources();
    try {
      if (_upshiftSource != null) {
        _soLoud?.disposeSource(_upshiftSource!);
        _upshiftSource = null;
      }
      if (_downshiftSource != null) {
        _soLoud?.disposeSource(_downshiftSource!);
        _downshiftSource = null;
      }
      _soLoud?.deinit();
    } catch (e) {
      _log(LogType.warning, 'dispose 异常: $e');
    }
    _isInitialized = false;
  }
}
