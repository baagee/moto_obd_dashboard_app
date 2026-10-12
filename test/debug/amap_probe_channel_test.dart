import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obd_dashboard/debug/amap_probe_channel.dart';

/// Phase 0 抓包通道单元测试。
///
/// 通过 mock 平台通道验证：
/// - MethodChannel 的 start / stop / queryState 下发正确
/// - EventChannel 事件能正确解码为 Map<String, dynamic>，且字段类型混杂不崩溃
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const methodChannel = MethodChannel('amap_probe/method');
  const eventChannelName = 'amap_probe/events';
  final methodLog = <MethodCall>[];

  setUp(() {
    methodLog.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, (call) async {
      methodLog.add(call);
      return true;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, null);
  });

  group('MethodChannel 命令下发', () {
    test('start() 下发 method == start', () async {
      await AmapProbeChannel.start();
      expect(methodLog.single.method, 'start');
    });

    test('stop() 下发 method == stop', () async {
      await AmapProbeChannel.stop();
      expect(methodLog.single.method, 'stop');
    });

    test('queryState() 下发 method == queryState', () async {
      await AmapProbeChannel.queryState();
      expect(methodLog.single.method, 'queryState');
    });
  });

  group('EventChannel 事件解码', () {
    // 模拟原生侧通过 EventChannel 推送一条广播
    Future<void> emitEvent(Map<dynamic, dynamic> payload) async {
      final encoded =
          const StandardMethodCodec().encodeSuccessEnvelope(payload);
      await TestDefaultBinaryMessengerBinding
          .instance.defaultBinaryMessenger
          .handlePlatformMessage(
        eventChannelName,
        encoded,
        (_) {},
      );
    }

    test('标准导航事件正确解码为 Map<String, dynamic>', () async {
      final future = AmapProbeChannel.stream.first;
      // 先订阅触发 listen，再推事件
      await Future<void>.delayed(Duration.zero);
      await emitEvent(<dynamic, dynamic>{
        'KEY_TYPE': 10001,
        'ICON': 2,
        'NEXT_ROAD_NAME': '中关村大街',
        'SEG_REMAIN_DIS_AUTO': '350',
      });
      final event = await future;
      expect(event, isA<Map<String, dynamic>>());
      expect(event['KEY_TYPE'], 10001);
      expect(event['ICON'], 2);
      expect(event['NEXT_ROAD_NAME'], '中关村大街');
    });

    test('字段类型混杂（含 List / String / int）不抛异常且字段完整', () async {
      final future = AmapProbeChannel.stream.first;
      await Future<void>.delayed(Duration.zero);
      await emitEvent(<dynamic, dynamic>{
        'KEY_TYPE': 13012,
        'ints': <int>[1, 2, 3], // 对应原生 IntArray.toList()
        'name': 'lane',
        'flag': true,
        'speed': 42,
      });
      final event = await future;
      expect(event['KEY_TYPE'], 13012);
      expect(event['ints'], <int>[1, 2, 3]);
      expect(event['name'], 'lane');
      expect(event['flag'], true);
      expect(event['speed'], 42);
    });
  });
}
