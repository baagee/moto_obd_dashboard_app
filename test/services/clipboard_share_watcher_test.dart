import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:obd_dashboard/data/amap/models.dart';
import 'package:obd_dashboard/data/amap/share_client.dart';
import 'package:obd_dashboard/providers/log_provider.dart';
import 'package:obd_dashboard/providers/navi_provider.dart';
import 'package:obd_dashboard/providers/obd_data_provider.dart';
import 'package:obd_dashboard/providers/settings_provider.dart';
import 'package:obd_dashboard/services/clipboard_share_watcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// `ClipboardShareWatcher` 单元测试
///
/// 剪贴板读取通过 mock `SystemChannels.platform` 的 `Clipboard.getData` 实现
/// （与 Flutter 框架自身的测法一致），因此不依赖真实设备剪贴板。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const shareUrl = 'https://surl.amap.com/6xgi0FI66V3';
  const anotherUrl = 'https://surl.amap.com/another1';

  late SettingsProvider settings;
  late _FakeShareClient client;
  late NaviProvider navi;
  late StreamController<Position> positions;
  late ClipboardShareWatcher watcher;

  /// 当前 mock 剪贴板内容
  String? clipboardText;

  setUp(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.getData') {
        return clipboardText == null ? null : {'text': clipboardText};
      }
      return null;
    });

    SharedPreferences.setMockInitialValues({});
    settings = SettingsProvider();
    await settings.init();

    client = _FakeShareClient();
    positions = StreamController<Position>.broadcast();
    navi = NaviProvider(
      obdDataProvider: OBDDataProvider(),
      logProvider: LogProvider(),
      client: client,
      positionStreamFactory: () => positions.stream,
    );

    clipboardText = shareUrl;
    watcher = ClipboardShareWatcher(
      naviProvider: navi,
      settings: settings,
      logCallback: (_, __, ___) {},
    );

    addTearDown(() async {
      watcher.stop();
      navi.dispose();
      await positions.close();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });
  });

  group('短链识别', () {
    test('looksLikeShareUrl：命中高德分享短链', () {
      expect(ClipboardShareWatcher.looksLikeShareUrl(shareUrl), isTrue);
      expect(
        ClipboardShareWatcher.looksLikeShareUrl('  $shareUrl  '),
        isTrue,
      );
      expect(
        ClipboardShareWatcher.looksLikeShareUrl('看我的行程 $shareUrl 快来'),
        isTrue,
      );
    });

    test('looksLikeShareUrl：非分享短链一律不命中', () {
      expect(ClipboardShareWatcher.looksLikeShareUrl(null), isFalse);
      expect(ClipboardShareWatcher.looksLikeShareUrl(''), isFalse);
      expect(ClipboardShareWatcher.looksLikeShareUrl('   '), isFalse);
      expect(ClipboardShareWatcher.looksLikeShareUrl('正常的一段文字'), isFalse);
      expect(
        ClipboardShareWatcher.looksLikeShareUrl('https://www.amap.com/route'),
        isFalse,
      );
    });

    test('readClipboardShareUrl：从夹带文字里抠出 URL 并去掉尾部标点', () async {
      clipboardText = '看我的行程 $shareUrl，快来';
      expect(await ClipboardShareWatcher.readClipboardShareUrl(), shareUrl);

      clipboardText = '  无短链  ';
      expect(await ClipboardShareWatcher.readClipboardShareUrl(), isNull);
    });
  });

  group('自动同步（naviAutoSync）', () {
    test('开启时回前台命中剪贴板 → 自动开始导航', () async {
      expect(settings.naviAutoSync, isTrue, reason: '默认开启');
      expect(await watcher.checkOnce(), isTrue);
      expect(navi.shareUrl, shareUrl);
      expect(navi.state, isNot(NaviState.off));
    });

    test('同一条短链只自动同步一次（去重，避免每次回前台都重拉路线）', () async {
      expect(await watcher.checkOnce(), isTrue);
      await navi.stop(); // 结束导航，排除"导航中不打断"的影响
      expect(watcher.lastHandled, shareUrl);

      expect(await watcher.checkOnce(), isFalse, reason: '同一条短链不应重复触发');
      expect(navi.state, NaviState.off);

      watcher.resetDedup();
      expect(await watcher.checkOnce(), isTrue, reason: '用户重新分享后可再次触发');
    });

    test('关闭开关时不自动同步，手动入口（force）仍可用', () async {
      await settings.setNaviAutoSync(false);

      expect(await watcher.checkOnce(), isFalse);
      expect(navi.state, NaviState.off);

      expect(await watcher.checkOnce(force: true), isTrue);
      expect(navi.shareUrl, shareUrl);
    });

    test('导航进行中不打断', () async {
      await watcher.checkOnce();
      expect(navi.isActive, isTrue);

      clipboardText = anotherUrl;
      expect(await watcher.checkOnce(), isFalse);
      expect(navi.shareUrl, shareUrl, reason: '不应被新短链顶掉');
    });

    test('剪贴板无短链时不产生任何会话', () async {
      clipboardText = '一段无关的文字';
      expect(await watcher.checkOnce(), isFalse);
      expect(navi.state, NaviState.off);
      expect(watcher.lastHandled, isNull);
    });
  });

  group('生命周期钩子', () {
    test('start() 后回前台自动检测一次剪贴板', () async {
      watcher.start();
      await pumpEventQueue();
      expect(client.resolveParamCount, 1, reason: 'start() 应立即检测一次');

      await navi.stop();
      clipboardText = anotherUrl;
      watcher.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await pumpEventQueue();
      expect(navi.shareUrl, anotherUrl, reason: '回前台应再次检测');
      expect(client.resolveParamCount, 2);
    });

    test('stop() 后回前台不再检测', () async {
      watcher.start();
      await pumpEventQueue();
      await navi.stop();
      watcher.stop();
      watcher.resetDedup();

      clipboardText = anotherUrl;
      watcher.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await pumpEventQueue();
      expect(navi.state, NaviState.off);
      expect(watcher.started, isFalse);
    });
  });
}

// ---------------------------------------------------------------------------
// 测试替身
// ---------------------------------------------------------------------------

class _FakeShareClient extends AmapShareClient {
  int resolveParamCount = 0;

  @override
  Future<String> resolveParam(String shareUrl) async {
    resolveParamCount++;
    return 'param-test';
  }

  // 显式实现两个状态端点：即便某个用例把时间推过心跳周期，也绝不会打到真实网络
  @override
  Future<ShareInfoEnvelope> probeNaviStatus(String param) async =>
      ShareInfoEnvelope(
        result: true,
        code: '1',
        message: 'Successful.',
        shareStatus: 1,
        members: const [],
      );

  @override
  Future<ShareStatusEnvelope> fetchShareStatus(String param) async =>
      ShareStatusEnvelope(
        result: true,
        code: '1',
        message: 'Successful.',
        status: 4,
        safeReportParameter: null,
      );

  @override
  Future<RouteEnvelope> fetchRoute(String param) async => RouteEnvelope(
        code: '1',
        result: true,
        message: 'Successful.',
        naviType: 9,
        route: AmapRoute(const {
          'roads_names': [
            {'road_name': '测试路'},
          ],
          'paths': [
            {
              'path_index': 0,
              'distance': 1000,
              'travel_time': 100,
              'coords': [
                {'lon': 116.3000, 'lat': 40.0000},
                {'lon': 116.3100, 'lat': 40.0000},
              ],
              'segments': [
                {
                  'segment_index': 0,
                  'main_action': 1,
                  'links': [
                    {
                      'link_index': 0,
                      'length': 1000,
                      'begin_index': 0,
                      'end_index': 1,
                      'travel_time': 100,
                      'road_name_index': 0,
                    },
                  ],
                },
              ],
              'status': [],
              'group': [],
            },
          ],
        }),
      );
}
