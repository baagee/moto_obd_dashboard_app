import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:obd_dashboard/data/amap/models.dart';
import 'package:obd_dashboard/data/amap/share_client.dart';
import 'package:obd_dashboard/providers/log_provider.dart';
import 'package:obd_dashboard/providers/navi_provider.dart';
import 'package:obd_dashboard/providers/obd_data_provider.dart';
import 'package:obd_dashboard/services/geocoding_service.dart';
import 'package:obd_dashboard/services/location_service.dart';
import 'package:obd_dashboard/widgets/navi_card.dart';
import 'package:obd_dashboard/widgets/navi_turn_arrow.dart';
import 'package:provider/provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('NaviCard 真实渲染（导航中）', (tester) async {
    final obd = OBDDataProvider()..updateRealTimeData(speed: 80);
    final positions = StreamController<Position>.broadcast();
    final client = _FakeShareClient();
    final navi = NaviProvider(
      obdDataProvider: obd,
      logProvider: LogProvider(),
      client: client,
      positionStreamFactory: () => positions.stream,
      // 测试环境没有平台插件：显式给出"权限已授、即时定位为空"，
      // 否则卡片会渲染成"系统定位未开启"，金样本就不是正常导航态了
      locationGate: () async => LocationPermissionStatus.granted,
      firstFixProvider: () async => null,
      // 金样本要求位置固定：冻结里程平滑心跳（否则每次 pump 都会挪动底图）
      smoothTickPeriod: const Duration(hours: 1),
    );

    try {
      await navi.start('https://surl.amap.com/a');
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: ChangeNotifierProvider<NaviProvider>.value(
              value: navi,
              child: Center(
                child: Container(
                  width: 212,
                  height: 244,
                  color: const Color(0xFF0B0E12),
                  child: const NaviCard(),
                ),
              ),
            ),
          ),
        ),
      );

      Future<void> feed(double d) async {
        final gcj = navi.debugAnalyzer!.coordAt(d);
        final wgs = _gcjToWgs(gcj.lat, gcj.lon);
        positions.add(Position(
          latitude: wgs.$1,
          longitude: wgs.$2,
          timestamp: DateTime.now(),
          accuracy: 5,
          altitude: 0,
          altitudeAccuracy: 0,
          heading: 90,
          headingAccuracy: 0,
          speed: 80 / 3.6,
          speedAccuracy: 0,
        ));
        await tester.pump();
        await tester.pump();
      }

      await feed(500);
      await tester.pump(const Duration(milliseconds: 100));

      // ignore: avoid_print
      print('displayActionCode = ${navi.displayActionCode}');
      final arrowFinder = find.byWidgetPredicate((w) => w is NaviTurnArrow);
      for (final e in arrowFinder.evaluate()) {
        final w = e.widget as NaviTurnArrow;
        // ignore: avoid_print
        print('NaviTurnArrow type=${w.type} size=${w.size} '
            'rect=${tester.getRect(find.byWidget(w))}');
      }

      await expectLater(
        find.byType(Container).first,
        matchesGoldenFile('navi_card_real.png'),
      );
    } finally {
      await navi.stop();
      navi.dispose();
      await positions.close();
    }
  });
}

(double, double) _gcjToWgs(double lat, double lng) {
  var wgsLat = lat;
  var wgsLng = lng;
  for (var i = 0; i < 3; i++) {
    final g = GeocodingService.wgs84ToGcj02(wgsLat, wgsLng);
    wgsLat -= g[0] - lat;
    wgsLng -= g[1] - lng;
  }
  return (wgsLat, wgsLng);
}

class _FakeShareClient extends AmapShareClient {
  @override
  Future<String> resolveParam(String shareUrl) async => 'param-test';

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
              'distance': 2000,
              'travel_time': 200,
              'coords': [
                {'lon': 116.3000, 'lat': 40.0000},
                {'lon': 116.3100, 'lat': 40.0000},
                {'lon': 116.3200, 'lat': 40.0000},
              ],
              'segments': [
                {
                  'segment_index': 0,
                  'main_action': 1,
                  'links': [
                    {
                      'link_index': 0,
                      'length': 600,
                      'begin_index': 0,
                      'end_index': 1,
                      'travel_time': 60,
                      'road_name_index': 0,
                    },
                  ],
                },
                {
                  'segment_index': 1,
                  'main_action': 2,
                  'links': [
                    {
                      'link_index': 0,
                      'length': 1400,
                      'begin_index': 1,
                      'end_index': 2,
                      'travel_time': 140,
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
