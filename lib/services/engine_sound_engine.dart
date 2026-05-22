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
  double _masterVolume = 0.75;
  double _toneVolume = 0.75;
  double _noiseVolume = 0.30;
  double _exhVolume = 0.20;

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

    // 1. 计算播放速度
    // playSpeed = (rpm / refRpm)^0.85
    final double playSpeed = rpm > 0
        ? math.pow(rpm / _refRpm.toDouble(), 0.85).toDouble()
        : 0.3;
    _currentPlaySpeed = playSpeed.clamp(0.1, 5.0);

    // 2. 计算各层音量
    // 油门/负载控制谐波/噪声比例
    final double throttleNorm = throttle / 100.0;
    final double loadNorm = load / 100.0;

    // tone 层：主音调，随油门增强
    _toneVolume = (0.55 + throttleNorm * 0.35).clamp(0.0, 1.0);

    // noise 层：机械噪声，随负载变化
    _noiseVolume = (0.20 + loadNorm * 0.25).clamp(0.0, 1.0);

    // exh 层：排气声，收油时增强
    _exhVolume = (0.12 + decelBoost * 0.50).clamp(0.0, 0.70);

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
        // 噪声层的速度变化较小（排气/机械声对速度不那么敏感）
        soLoud.setRelativePlaySpeed(
            _noiseHandle!, _currentPlaySpeed * 0.5 + 0.5);
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

  /// 设置主音量（0.0~1.0）
  void setMasterVolume(double volume) {
    _masterVolume = volume.clamp(0.0, 1.0);
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
