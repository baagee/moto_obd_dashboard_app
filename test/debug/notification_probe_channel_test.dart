import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obd_dashboard/debug/notification_probe_channel.dart';

/// Plan B 通知抓包通道单元测试。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const methodChannel = MethodChannel('notification_probe/method');
  const eventChannelName = 'notification_probe/events';
  final methodLog = <MethodCall>[];

  setUp(() {
    methodLog.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, (call) async {
      methodLog.add(call);
      switch (call.method) {
        case 'isPermissionGranted':
          return true;
        case 'getSnapshot':
          return <Map<String, dynamic>>[
            {'_kind': 'notification', 'pkg': 'com.autonavi.minimap', 'id': 1},
          ];
        case 'getStats':
          return <String, int>{'com.autonavi.minimap': 3};
        default:
          return null;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, null);
  });

  group('MethodChannel 命令', () {
    test('isPermissionGranted 返回布尔值', () async {
      expect(await NotificationProbeChannel.isPermissionGranted(), isTrue);
    });

    test('openSettings 下发正确 method', () async {
      await NotificationProbeChannel.openSettings();
      expect(methodLog.single.method, 'openSettings');
    });

    test('clear 下发正确 method', () async {
      await NotificationProbeChannel.clear();
      expect(methodLog.single.method, 'clear');
    });

    test('setShowAll 携带布尔参数', () async {
      await NotificationProbeChannel.setShowAll(true);
      expect(methodLog.single.method, 'setShowAll');
      expect(methodLog.single.arguments, true);
    });

    test('snapshot 正确解码列表', () async {
      final list = await NotificationProbeChannel.snapshot();
      expect(list, hasLength(1));
      expect(list.first['pkg'], 'com.autonavi.minimap');
    });

    test('stats 正确解码为 Map<String, int>', () async {
      final stats = await NotificationProbeChannel.stats();
      expect(stats['com.autonavi.minimap'], 3);
    });
  });

  group('EventChannel 事件解码', () {
    Future<void> emitEvent(Map<dynamic, dynamic> payload) async {
      final encoded = const StandardMethodCodec().encodeSuccessEnvelope(payload);
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(eventChannelName, encoded, (_) {});
    }

    test('通知事件正确解码为 Map<String, dynamic>', () async {
      final future = NotificationProbeChannel.stream.first;
      await Future<void>.delayed(Duration.zero);
      await emitEvent(<dynamic, dynamic>{
        'pkg': 'com.autonavi.minimap',
        'EXTRA_TITLE': '正在导航',
        'extrasAll': <String, dynamic>{'android.title': 'String:正在导航'},
        'remoteViewsText': <String>[
          'setTextViewText=300米后右转',
          'setTextViewText=中关村大街',
        ],
        'actions': <String>['退出导航'],
      });
      final event = await future;
      expect(event, isA<Map<String, dynamic>>());
      expect(event['pkg'], 'com.autonavi.minimap');
      expect(event['EXTRA_TITLE'], '正在导航');
      expect(event['remoteViewsText'], hasLength(2));
      expect(event['remoteViewsText'][0], contains('右转'));
      expect(event['actions'], <String>['退出导航']);
    });
  });
}
