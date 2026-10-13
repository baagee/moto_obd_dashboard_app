import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:obd_dashboard/data/amap/models.dart';
import 'package:obd_dashboard/data/amap/share_client.dart';

/// `AmapShareClient` 单元测试（方案 §5.1）
///
/// 用**真实本地 HttpServer** 替代 mock：`dart:io` 的 HttpClient 走真实 socket，
/// 因此短链 302 的 `Location` 读取、POST 空 body、非 200 分支都是被真正执行的
/// 代码路径，而不是"假装调用了"。端点通过 `routeApi` / `infoApi` 注入。
void main() {
  late HttpServer server;
  late AmapShareClient client;

  /// 短链本身也指向本地服务：`resolveParam` 会对入参 URL 发真实 GET
  late String shortLink;

  /// GET（短链）返回的 302 Location；null 表示不设置该响应头
  String? redirectLocation;

  /// GET（短链）返回的状态码
  int getStatus = 302;

  /// POST restoration 的响应体与状态码
  String routeBody = '';
  int routeStatus = 200;

  /// POST info 的响应体与状态码
  String infoBody = '';
  int infoStatus = 200;

  /// GET 行前状态端点（/ws/user/route/share/info）的响应体与状态码
  String shareStatusBody = '';
  int shareStatusStatus = 200;

  /// 记录最近一次 GET 的 URI（校验方法与 param 编码）
  Uri? lastGetUri;

  /// 记录最近一次 POST 请求携带的头部，用于校验 Origin/Referer/UA/Cookie
  Map<String, String> lastPostHeaders = const {};

  setUp(() async {
    redirectLocation = null;
    getStatus = 302;
    routeStatus = 200;
    infoStatus = 200;
    shareStatusStatus = 200;
    lastGetUri = null;
    lastPostHeaders = const {};

    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      final res = req.response;
      if (req.method == 'GET') {
        lastGetUri = req.uri;
        // 行前状态端点也是 GET：必须先与"短链 GET"区分开
        if (req.uri.path.contains('user/route/share/info')) {
          res.statusCode = shareStatusStatus;
          res.headers.contentType = ContentType.json;
          res.write(shareStatusBody);
          await res.close();
          return;
        }
        res.statusCode = getStatus;
        if (redirectLocation != null) {
          res.headers.set(HttpHeaders.locationHeader, redirectLocation!);
        }
        await res.close();
        return;
      }

      lastPostHeaders = {
        for (final name in [
          'origin',
          HttpHeaders.refererHeader,
          HttpHeaders.userAgentHeader,
          HttpHeaders.cookieHeader,
        ])
          name: req.headers.value(name) ?? '',
      };
      final isRoute = req.uri.path.contains('restoration');
      res.statusCode = isRoute ? routeStatus : infoStatus;
      res.headers.contentType = ContentType.json;
      res.write(isRoute ? routeBody : infoBody);
      await res.close();
    });

    final base = 'http://127.0.0.1:${server.port}';
    shortLink = '$base/s/abcdefg';
    client = AmapShareClient(
      routeApi: '$base/ws/share/lbs/route/restoration',
      infoApi: '$base/ws/share/lbs/info',
      shareRouteApi: '$base/ws/user/route/share/info',
      timeout: const Duration(seconds: 5),
    );
  });

  tearDown(() async {
    client.close();
    await server.close(force: true);
  });

  // -------------------------------------------------------------------------
  // 1. 短链 → param
  // -------------------------------------------------------------------------

  group('短链解析', () {
    test('302 Location 里的 urlParameter 被解码为 param', () async {
      const param = 'kH0AAptqxne8MqTR9ssPkDdjHJ0MvIZu+/7kYnS5+AHicKe+/55hU=';
      redirectLocation = 'https://static3.amap.com/activity/2020NewDriveSafeV5/'
          'index.html?from=main&urlParameter=${Uri.encodeComponent(param)}';

      expect(await client.resolveParam(shortLink), param);
    });

    test('from=before_navi（行中分享）抛 ShareLinkException', () async {
      redirectLocation = 'https://static3.amap.com/activity/2020NewDriveSafeV5/'
          'index.html?from=before_navi&urlParameter=xxx';
      await expectLater(
        client.resolveParam(shortLink),
        throwsA(isA<ShareLinkException>()),
      );
    });

    test('302 缺少 urlParameter 抛 ShareLinkException', () async {
      redirectLocation =
          'https://static3.amap.com/activity/2020NewDriveSafeV5/index.html?from=main';
      await expectLater(
        client.resolveParam(shortLink),
        throwsA(isA<ShareLinkException>()),
      );
    });

    test('短链未返回 Location（200）抛 ShareLinkException', () async {
      getStatus = 200;
      await expectLater(
        client.resolveParam(shortLink),
        throwsA(isA<ShareLinkException>()),
      );
    });
  });

  // -------------------------------------------------------------------------
  // 2. restoration / info
  // -------------------------------------------------------------------------

  group('restoration 接口', () {
    test('restorationInfo 是 JSON 字符串 → 二次解析成功，含路线几何', () async {
      routeBody = _envelope(
        code: '1',
        result: true,
        restorationInfo: jsonEncode(_innerRoute(distance: 1200)),
      );

      final env = await client.fetchRoute('p');
      expect(env.code, '1');
      expect(env.result, isTrue);
      expect(env.route.paths, hasLength(1));
      expect(env.route.main.distance, 1200);
      expect(env.route.main.coords, hasLength(4));
      expect(env.route.main.segments, hasLength(2));
      expect(env.route.roadNameOf(0), '测试路');
      expect(env.route.roadNameOf(99), '内部道路'); // 越界兜底
    });

    test('POST 携带 Origin / Referer / User-Agent / Cookie', () async {
      routeBody = _envelope(
        code: '1',
        result: true,
        restorationInfo: jsonEncode(_innerRoute()),
      );
      await client.fetchRoute('p');
      expect(lastPostHeaders['origin'], AmapShareClient.defaultOrigin);
      expect(lastPostHeaders[HttpHeaders.refererHeader],
          AmapShareClient.defaultReferer);
      expect(lastPostHeaders[HttpHeaders.userAgentHeader],
          AmapShareClient.defaultUserAgent);
      expect(lastPostHeaders[HttpHeaders.cookieHeader],
          AmapShareClient.defaultCookie);
    });

    test('code=2 且 result=false 抛 ShareApiException', () async {
      routeBody = _envelope(code: '2', result: false, message: '分享已过期');
      await expectLater(
        client.fetchRoute('p'),
        throwsA(isA<ShareApiException>()),
      );
    });

    test('code=3 且 result=false 抛 ShareApiException', () async {
      routeBody = _envelope(code: '3', result: false, message: '分享已取消');
      await expectLater(
        client.fetchRoute('p'),
        throwsA(isA<ShareApiException>()),
      );
    });

    test('code=2 但 result=true 不抛（失效判定由上层 NaviProvider 负责）', () async {
      routeBody = _envelope(
        code: '2',
        result: true,
        restorationInfo: jsonEncode(_innerRoute()),
      );
      final env = await client.fetchRoute('p');
      expect(env.code, '2');
      expect(env.result, isTrue);
    });

    test('HTTP 500 抛 ShareApiException', () async {
      routeStatus = 500;
      routeBody = 'boom';
      await expectLater(
        client.fetchRoute('p'),
        throwsA(isA<ShareApiException>()),
      );
    });
  });

  group('info 接口', () {
    test('解析 shareMembers 与 locInfo', () async {
      infoBody = jsonEncode({
        'result': true,
        'message': 'Successful.',
        'data': {
          'shareMembers': [
            {
              'uid': 235110563,
              'nickName': 'Dyfkhi',
              'battery': 50,
              'online': true,
              'locInfo': {
                'lon': 116.2948275,
                'lat': 40.05403111111111,
                'address': '北京市海淀区后厂村路',
                'locationUpdateTime': 1791435362,
                'nowTime': 1791435399,
                'speed': 4,
              },
            },
          ],
        },
      });

      final env = await client.fetchInfo('p');
      expect(env.result, isTrue);
      final m = env.first!;
      expect(m.nickName, 'Dyfkhi');
      expect(m.locationLagSeconds, 1791435399 - 1791435362);
      expect(m.locInfo!.lon, closeTo(116.2948275, 1e-9));
    });

    test('result=false 抛 ShareApiException', () async {
      infoBody = jsonEncode({'result': false, 'message': 'not found'});
      await expectLater(
        client.fetchInfo('p'),
        throwsA(isA<ShareApiException>()),
      );
    });
  });

  // -------------------------------------------------------------------------
  // 3. 分享状态（判断"导航是否已停止"）
  // -------------------------------------------------------------------------

  group('行前状态端点（GET /ws/user/route/share/info）', () {
    test('code=10001 → alive == expired（实测逐字响应）', () async {
      shareStatusBody = '{"code":"10001","data":null,"errMsg":"Record Not Exist.",'
          '"message":"Record Not Exist.","result":false,'
          '"timestamp":"1791615141","version":"v3-557faf3"}';

      final env = await client.fetchShareStatus('p');
      expect(env.code, '10001');
      expect(env.alive, ShareAlive.expired);
    });

    test('走 GET，且 param 只 percent-encode 一次', () async {
      const param = 'kH0AAptqxne8MqTR9ssPkDdjHJ0MvIZu+/7kYnS5+AHicKe+/55hU=';
      shareStatusBody = '{"code":"1","data":{"status":1},"result":true}';

      await client.fetchShareStatus(param);
      expect(lastGetUri!.path, contains('/ws/user/route/share/info'));
      expect(lastGetUri!.queryParameters['param'], param,
          reason: '编两次会得到 code=2 DecodeUrlParameterError');
    });

    test('code=2（参数问题）不抛异常，落 unknown 而不是"已结束"', () async {
      shareStatusBody = '{"code":"2","data":null,"errMsg":"DecodeUrlParameterError",'
          '"message":"Failure.","result":false}';

      final env = await client.fetchShareStatus('p');
      expect(env.alive, ShareAlive.unknown);
    });

    test('HTTP 500 抛 ShareApiException（只有传输层错误才算探测失败）', () async {
      shareStatusStatus = 500;
      shareStatusBody = 'boom';
      await expectLater(
        client.fetchShareStatus('p'),
        throwsA(isA<ShareApiException>()),
      );
    });
  });

  group('行中状态探测（POST /ws/share/lbs/info）', () {
    test('probeNaviStatus 不因 result=false 抛异常（对照 fetchInfo 会抛）', () async {
      infoBody = jsonEncode({'result': false, 'message': 'not found'});

      final env = await client.probeNaviStatus('p');
      expect(env.result, isFalse);
      expect(env.alive, ShareAlive.unknown);

      await expectLater(
        client.fetchInfo('p'),
        throwsA(isA<ShareApiException>()),
      );
    });

    test('shareStatus=5 → stopped（实测值）', () async {
      infoBody = jsonEncode({
        'result': true,
        'message': 'Successful.',
        'data': {
          'shareInfo': {'shareStatus': 5},
        },
      });

      expect((await client.probeNaviStatus('p')).alive, ShareAlive.stopped);
    });
  });

  group('真实离线样本（存在时）', () {
    final sample = File('test/fixtures/amap/sample-restoration.json');

    test('sample-restoration.json 能完整解析并复现里程指纹', () async {
      if (!sample.existsSync()) {
        markTestSkipped('缺少离线样本 ${sample.path}');
        return;
      }
      routeBody = sample.readAsStringSync();
      final env = await client.fetchRoute('p');
      expect(env.code, '1');
      expect(env.route.main.distance, 27734);
      expect(env.route.main.coords, hasLength(526));
      expect(env.route.roadNames, isNotEmpty);
    });
  });
}

// ---------------------------------------------------------------------------
// 响应体构造
// ---------------------------------------------------------------------------

String _envelope({
  required String code,
  required bool result,
  String message = 'Successful.',
  String? restorationInfo,
}) =>
    jsonEncode({
      'code': code,
      'result': result,
      'message': message,
      'data': {
        'naviType': 9,
        'restorationInfo': restorationInfo ?? '{}',
      },
    });

Map<String, Object?> _innerRoute({int distance = 300}) => {
      'route': {
        'timestamp': 1791435420353,
        'version': 'test-1',
        'code': '1',
        'roads_names': [
          {'road_name': '测试路'},
          {'road_name': '目标路'},
        ],
        'paths': [
          {
            'path_index': 0,
            'distance': distance,
            'travel_time': 60,
            'traffic_light_count': 1,
            'coords': [
              {'lon': 116.3000, 'lat': 40.0000},
              {'lon': 116.3010, 'lat': 40.0000},
              {'lon': 116.3020, 'lat': 40.0005},
              {'lon': 116.3030, 'lat': 40.0010},
            ],
            'segments': [
              {
                'segment_index': 0,
                'main_action': 3,
                'links': [
                  {
                    'link_index': 0,
                    'length': distance ~/ 2,
                    'begin_index': 0,
                    'end_index': 1,
                    'travel_time': 30,
                    'road_name_index': 0,
                  },
                ],
              },
              {
                'segment_index': 1,
                'main_action': 1,
                'links': [
                  {
                    'link_index': 0,
                    'length': distance - distance ~/ 2,
                    'begin_index': 1,
                    'end_index': 3,
                    'travel_time': 30,
                    'road_name_index': 1,
                  },
                ],
              },
            ],
            'status': [
              {'traffic_state': 1, 'len': distance},
            ],
            'group': [
              {'name': '测试路', 'dist': distance, 'start_id': 0, 'count': 2},
            ],
          },
        ],
      },
    };
