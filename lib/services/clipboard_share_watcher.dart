import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../models/log.dart';
import '../providers/navi_provider.dart';
import '../providers/settings_provider.dart';

/// 剪贴板分享短链识别 + 生命周期钩子
///
/// 高德导航中分享行程会生成 `https://surl.amap.com/xxxx` 短链；用户在
/// 高德里分享完回到本 App，即视为"想把这趟行程投到仪表盘"。因此：
///
/// - **App 回到前台时检测一次剪贴板**，命中即自动同步并开始导航（不弹确认）；
/// - 受 [SettingsProvider.naviAutoSync] 控制，用户可在设置页关闭；
/// - **同一条短链只自动同步一次**（去重），避免每次回前台都重拉路线；
/// - Android 10+ 限制后台读剪贴板，只能在前台/回前台时读取，因此
///   导航卡（`lib/widgets/navi_card.dart`）的手动粘贴入口是**永久兜底**。
class ClipboardShareWatcher with WidgetsBindingObserver {
  ClipboardShareWatcher({
    required NaviProvider naviProvider,
    required SettingsProvider settings,
    void Function(String source, LogType type, String message)? logCallback,
    void Function(String shareUrl)? onAutoSync,
  })  : _navi = naviProvider,
        _settings = settings,
        _log = logCallback,
        _onAutoSync = onAutoSync;

  final NaviProvider _navi;
  final SettingsProvider _settings;
  final void Function(String source, LogType type, String message)? _log;
  final void Function(String shareUrl)? _onAutoSync;

  static const String _source = 'Navi';

  /// 命中自动同步的短链特征
  static const String shareHost = 'surl.amap.com';

  bool _started = false;

  /// 去重：已经自动同步过的短链
  String? _lastHandled;

  bool get started => _started;
  bool get enabled => _settings.naviAutoSync;
  String? get lastHandled => _lastHandled;

  /// 文本里是否含高德分享短链
  static bool looksLikeShareUrl(String? text) {
    if (text == null) return false;
    final t = text.trim();
    if (t.isEmpty) return false;
    return t.contains(shareHost);
  }

  /// 从剪贴板取短链；无有效短链返回 null
  static Future<String?> readClipboardShareUrl() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text;
      if (!looksLikeShareUrl(text)) return null;
      return _firstUrl(text!);
    } catch (_) {
      return null;
    }
  }

  /// 从可能夹带四周文字的文本里抠出第一个 URL
  static String? _firstUrl(String text) {
    final t = text.trim();
    // 显式限定 URL 合法字符集：`\S+` 会把中文一起吞进来（中文不是空白）
    final m = RegExp(r"https?://[A-Za-z0-9\-._~:/?#\[\]@!$&()*+,;=%]+")
        .firstMatch(t);
    if (m != null) return _stripTrailing(m.group(0)!);
    // 没有协议头时按裸短链处理
    final i = t.indexOf(shareHost);
    if (i < 0) return null;
    final start = t.lastIndexOf(' ', i) + 1;
    final end = t.indexOf(' ', i);
    final bare = t.substring(start, end < 0 ? t.length : end);
    // 仍可能带上中文，按字符集再收一次
    return _stripTrailing(
      RegExp(r"^[A-Za-z0-9\-._~:/?#\[\]@!$&()*+,;=%]+").stringMatch(bare) ?? '',
    );
  }

  static String _stripTrailing(String s) {
    var out = s.trim();
    while (out.isNotEmpty &&
        '.,;，。；、）)】]》>”"'.contains(out[out.length - 1])) {
      out = out.substring(0, out.length - 1);
    }
    return out;
  }

  /// 开始监听生命周期，并立即检测一次剪贴板
  void start() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    unawaitedCheck();
  }

  /// 停止监听（不改变 NaviProvider 状态）
  void stop() {
    if (!_started) return;
    _started = false;
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_started) return;
    if (state == AppLifecycleState.resumed) {
      // 回前台是唯一稳定可读剪贴板的时机
      unawaitedCheck();
    }
  }

  void unawaitedCheck() {
    // ignore: discarded_futures
    checkOnce();
  }

  /// 检测一次剪贴板并（条件满足时）自动开始导航。
  ///
  /// [force] 为 true 时忽略 `naviAutoSync` 开关，供手动入口复用。
  /// 返回是否真的发起了一次导航。
  Future<bool> checkOnce({bool force = false}) async {
    if (!force && !enabled) return false;
    if (_navi.isActive) return false; // 导航进行中不打断

    final url = await readClipboardShareUrl();
    if (url == null) return false;
    if (url == _lastHandled) return false; // 去重
    if (url == _navi.shareUrl) return false;

    _lastHandled = url;
    _log?.call(_source, LogType.info, '剪贴板命中高德分享短链，自动同步：$url');
    final ok = await _navi.start(url);
    if (ok) _onAutoSync?.call(url);
    return ok;
  }

  /// 清除去重记录（用户重新分享同一条短链时可再次触发）
  void resetDedup() => _lastHandled = null;
}
