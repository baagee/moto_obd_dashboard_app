import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import '../models/obd_data.dart';
import '../providers/log_provider.dart';
import '../providers/loggable.dart';

/// 语音播放服务
/// 使用 audioplayers 包播放音频文件
///
/// Audio Focus 策略：
///   - Android: 申请 AUDIOFOCUS_GAIN_TRANSIENT，播完后 release() 归还焦点
///     → QQ/网易云等后台音乐会在提示音播完后自动恢复
///   - iOS: AVAudioSessionCategory.ambient，与背景音乐共存（叠加播放）
class AudioService extends ChangeNotifier {
  AudioPlayer? _audioPlayer;

  static const String _source = 'Audio';

  void Function(String, LogType, String)? _logCallback;

  AudioService({LogProvider? logProvider}) {
    if (logProvider != null) {
      _logCallback = createLogger(logProvider);
    }
  }

  /// 当前是否正在播放
  bool _isPlaying = false;

  /// 当前播放进度 (0.0 - 1.0)
  double _progress = 0.0;

  /// 当前播放时长（毫秒）
  int _currentDurationMs = 0;

  /// 播放完成回调
  VoidCallback? onComplete;

  /// 播放进度更新回调
  void Function(double progress)? onProgressUpdate;

  /// 全局 AudioContext（临时音频焦点）
  static final AudioContext _audioContext = AudioContext(
    android: AudioContextAndroid(
      // GAIN_TRANSIENT：临时占用焦点，释放后系统通知其他 App 恢复播放
      audioFocus: AndroidAudioFocus.gainTransient,
      usageType: AndroidUsageType.media,
      contentType: AndroidContentType.sonification,
      stayAwake: false,
      isSpeakerphoneOn: false,
    ),
    iOS: AudioContextIOS(
      // ambient：不打断其他 App 播放，提示音叠加
      category: AVAudioSessionCategory.ambient,
      options: {
        AVAudioSessionOptions.mixWithOthers,
      },
    ),
  );

  /// 播放 assets 目录中的音频文件
  /// [assetPath] - assets 下的路径，如 'assets/audio/test.mp3'
  /// [getDurationMs] - 可选的时长获取回调，用于进度显示
  Future<void> playAsset(
    String assetPath, {
    int Function()? getDurationMs,
  }) async {
    // 停止上一个（会 release 焦点）
    await stop();

    // 每次播放创建新实例，确保焦点状态干净
    final player = AudioPlayer();
    _audioPlayer = player;

    // 设置临时音频焦点
    try {
      await player.setAudioContext(_audioContext);
    } catch (e) {
      final msg = 'setAudioContext 失败: $e';
      _logCallback?.call(_source, LogType.warning, msg);
    }

    _setupListeners(player);

    try {
      await player.setSource(AssetSource(assetPath.replaceFirst('assets/', '')));

      // 尝试获取音频时长
      if (getDurationMs != null) {
        _currentDurationMs = getDurationMs();
      } else {
        _currentDurationMs = 2000;
        final duration = await player.getDuration();
        if (duration != null) {
          _currentDurationMs = duration.inMilliseconds;
        }
      }

      await player.resume();
      _isPlaying = true;
      _progress = 0.0;
      _logCallback?.call(_source, LogType.info, '开始播放: $assetPath');
      notifyListeners();
    } catch (e) {
      final msg = '播放失败: $assetPath，原因: $e';
      _logCallback?.call(_source, LogType.error, msg);
      _isPlaying = false;
      await _releasePlayer(player);
      notifyListeners();
    }
  }

  void _setupListeners(AudioPlayer player) {
    // 播放完成 → release 归还 Audio Focus，其他 App 自动恢复
    player.onPlayerComplete.listen((_) async {
      _isPlaying = false;
      _progress = 1.0;
      _logCallback?.call(_source, LogType.success, '播放完成，已归还音频焦点');
      notifyListeners();
      onComplete?.call();
      await _releasePlayer(player);
      if (_audioPlayer == player) _audioPlayer = null;
    });

    player.onPlayerStateChanged.listen((state) {
      if (_audioPlayer == player) {
        _isPlaying = state == PlayerState.playing;
        notifyListeners();
      }
    });

    player.onPositionChanged.listen((position) {
      if (_audioPlayer == player && _currentDurationMs > 0) {
        _progress = position.inMilliseconds / _currentDurationMs;
        onProgressUpdate?.call(_progress);
        notifyListeners();
      }
    });
  }

  Future<void> _releasePlayer(AudioPlayer player) async {
    try {
      await player.stop();
      await player.release(); // 关键：归还 Audio Focus
      await player.dispose();
    } catch (_) {}
  }

  /// 停止播放
  Future<void> stop() async {
    final player = _audioPlayer;
    _audioPlayer = null;
    if (player != null) {
      await _releasePlayer(player);
    }
    _isPlaying = false;
    _progress = 0.0;
    _currentDurationMs = 0;
    notifyListeners();
  }

  /// 暂停播放
  Future<void> pause() async {
    await _audioPlayer?.pause();
    _isPlaying = false;
    notifyListeners();
  }

  /// 恢复播放
  Future<void> resume() async {
    await _audioPlayer?.resume();
    _isPlaying = true;
    notifyListeners();
  }

  /// 获取当前是否正在播放
  bool get isPlaying => _isPlaying;

  /// 获取当前播放进度 (0.0 - 1.0)
  double get progress => _progress;

  /// 获取当前播放时长（毫秒）
  int get currentDurationMs => _currentDurationMs;

  @override
  void dispose() {
    final player = _audioPlayer;
    _audioPlayer = null;
    if (player != null) {
      _releasePlayer(player);
    }
    super.dispose();
  }
}
