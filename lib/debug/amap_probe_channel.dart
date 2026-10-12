import 'package:flutter/services.dart';

/// Phase 0 高德导航广播抓包通道封装。
///
/// - [stream]：EventChannel 推来的每条高德广播原始字段 Map（未归一化）
/// - [start] / [stop]：动态注册 / 反注册广播接收器
/// - [queryState]：主动向高德查询当前导航状态（KEY_TYPE=13030）
///
/// 仅用于调试验证，不参与任何业务逻辑。对应原生侧仅在 debug 构建注册，
/// release 构建下方法调用会静默失败（MissingPluginException），调用方需自行容错。
class AmapProbeChannel {
  AmapProbeChannel._();

  static const EventChannel _events = EventChannel('amap_probe/events');
  static const MethodChannel _method = MethodChannel('amap_probe/method');

  /// 每条高德广播的原始字段 Map（含 `_action` / `_ts` / `KEY_TYPE` 及全部 extras）
  static Stream<Map<String, dynamic>> get stream => _events
      .receiveBroadcastStream()
      .map((event) => Map<String, dynamic>.from(event as Map));

  static Future<void> start() => _method.invokeMethod('start');

  static Future<void> stop() => _method.invokeMethod('stop');

  static Future<void> queryState() => _method.invokeMethod('queryState');

  /// 自测：从本应用发一条伪造的高德广播，验证接收链路是否通畅。
  ///
  /// 若自测数据出现在列表中 → 接收链路正常，收不到真数据说明是高德侧没发广播。
  static Future<void> selfTest() => _method.invokeMethod('selfTest');
}
