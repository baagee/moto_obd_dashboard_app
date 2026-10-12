import 'package:flutter/services.dart';

/// Plan B 高德导航通知抓包通道封装。
///
/// - [stream]：通知事件流（每条为原始字段 Map，未归一化）
/// - [isPermissionGranted]：是否已获得系统「通知使用权」
/// - [openSettings]：跳转系统「通知使用权」设置页
/// - [snapshot] / [stats]：取缓存快照与各包名计数
/// - [setShowAll]：是否记录所有应用的通知（默认仅高德）
///
/// 仅用于调试验证，不参与业务逻辑。对应原生侧仅在 debug 构建注册。
class NotificationProbeChannel {
  NotificationProbeChannel._();

  static const EventChannel _events = EventChannel('notification_probe/events');
  static const MethodChannel _method = MethodChannel('notification_probe/method');

  /// 通知事件流
  static Stream<Map<String, dynamic>> get stream => _events
      .receiveBroadcastStream()
      .map((event) => Map<String, dynamic>.from(event as Map));

  /// 是否已获得「通知使用权」
  static Future<bool> isPermissionGranted() async =>
      await _method.invokeMethod<bool>('isPermissionGranted') ?? false;

  /// 跳转系统「通知使用权」设置页
  static Future<void> openSettings() => _method.invokeMethod('openSettings');

  /// 清空缓存与统计
  static Future<void> clear() => _method.invokeMethod('clear');

  /// 取当前缓存快照
  static Future<List<Map<String, dynamic>>> snapshot() async {
    final list = await _method.invokeMethod<List<dynamic>>('getSnapshot') ?? [];
    return list
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList(growable: false);
  }

  /// 各包名通知计数
  static Future<Map<String, int>> stats() async {
    final map = await _method.invokeMethod<Map<dynamic, dynamic>>('getStats') ?? {};
    return map.map((k, v) => MapEntry(k.toString(), (v as num).toInt()));
  }

  /// 是否记录所有应用的通知（默认 false，仅记录高德）
  static Future<void> setShowAll(bool value) =>
      _method.invokeMethod('setShowAll', value);
}
