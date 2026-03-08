import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// 语音播放服务
/// 使用 audioplayers 包播放音频文件
class AudioService extends ChangeNotifier {
  final AudioPlayer _audioPlayer = AudioPlayer();

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

  AudioService() {
    _initPlayer();
  }

  void _initPlayer() {
    // 监听播放完成
    _audioPlayer.onPlayerComplete.listen((_) {
      _isPlaying = false;
      _progress = 1.0;
      notifyListeners();
      onComplete?.call();
    });

    // 监听播放状态变化
    _audioPlayer.onPlayerStateChanged.listen((state) {
      _isPlaying = state == PlayerState.playing;
      notifyListeners();
    });

    // 监听播放位置变化
    _audioPlayer.onPositionChanged.listen((position) {
      if (_currentDurationMs > 0) {
        _progress = position.inMilliseconds / _currentDurationMs;
        onProgressUpdate?.call(_progress);
        notifyListeners();
      }
    });
  }

  /// 播放 assets 目录中的音频文件
  /// [assetPath] - assets 下的路径，如 'assets/audio/test.mp3'
  /// [getDurationMs] - 可选的时长获取回调，用于进度显示
  Future<void> playAsset(
    String assetPath, {
    int Function()? getDurationMs,
  }) async {
    // 停止当前播放
    await stop();

    try {
      // 设置音频源
      await _audioPlayer.setSource(AssetSource(assetPath.replaceFirst('assets/', '')));

      // 尝试获取音频时长
      if (getDurationMs != null) {
        _currentDurationMs = getDurationMs();
      } else {
        // 使用默认时长
        _currentDurationMs = 2000;
        // 尝试从播放器获取实际时长
        final duration = await _audioPlayer.getDuration();
        if (duration != null) {
          _currentDurationMs = duration.inMilliseconds;
        }
      }

      // 开始播放
      await _audioPlayer.resume();
      _isPlaying = true;
      _progress = 0.0;
      notifyListeners();
    } catch (e) {
      debugPrint('AudioService: Failed to play $assetPath: $e');
      _isPlaying = false;
      notifyListeners();
    }
  }

  /// 停止播放
  Future<void> stop() async {
    await _audioPlayer.stop();
    _isPlaying = false;
    _progress = 0.0;
    _currentDurationMs = 0;
    notifyListeners();
  }

  /// 暂停播放
  Future<void> pause() async {
    await _audioPlayer.pause();
    _isPlaying = false;
    notifyListeners();
  }

  /// 恢复播放
  Future<void> resume() async {
    await _audioPlayer.resume();
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
    _audioPlayer.dispose();
    super.dispose();
  }
}
