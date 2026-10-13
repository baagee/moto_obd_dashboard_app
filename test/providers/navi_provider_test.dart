import 'dart:async';

import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:obd_dashboard/data/amap/models.dart';
import 'package:obd_dashboard/data/amap/route_analyzer.dart';
import 'package:obd_dashboard/data/amap/share_client.dart';
import 'package:obd_dashboard/providers/log_provider.dart';
import 'package:obd_dashboard/providers/navi_provider.dart';
import 'package:obd_dashboard/providers/obd_data_provider.dart';
import 'package:obd_dashboard/providers/settings_provider.dart';
import 'package:obd_dashboard/services/geocoding_service.dart';
import 'package:obd_dashboard/services/location_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// `NaviProvider` 单元测试（方案 §5.1）
///
/// 关键覆盖点：
/// - 状态迁移 `off → locating → navigating`，`offset` 超阈值 → `deviated`
/// - **通栏不抖动**：连续三动作场景下不发生 true→false→true
/// - 通栏收回：所有动作过了 8 秒窗口后转 false
/// - 生命周期：`stop()` 后订阅全部释放、状态回 `off`
///
/// 依赖通过构造函数注入（假 client + 可控 Position 流），不发任何真实网络请求。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeShareClient client;
  late OBDDataProvider obd;
  late StreamController<Position> positions;
  late NaviProvider navi;

  /// 合成路线：与实测德胜门桥同构的连续转弯（153m/31m/51m 量级）
  /// 累计里程：100 / 600 / 631 / 682 / 700 / 2000
  late AmapRoute route;

  setUp(() {
    route = _straightRoute(const [
      (action: 8, length: 100), // 直行，段末 100
      (action: 8, length: 500), // 直行，段末 600
      (action: 1, length: 31), // 左转，段末 631
      (action: 1, length: 51), // 左转，段末 682
      (action: 4, length: 18), // 右前方，段末 700
      (action: 8, length: 1300), // 直行，段末 2000
    ]);
    client = _FakeShareClient(route);
    obd = OBDDataProvider()..updateRealTimeData(speed: 80);
    positions = StreamController<Position>.broadcast();

    navi = NaviProvider(
      obdDataProvider: obd,
      logProvider: LogProvider(),
      client: client,
      positionStreamFactory: () => positions.stream,
      // 测试环境没有平台插件：显式给出"权限已授、即时定位为空"，
      // 否则 geolocator 在本环境会返回"系统定位未开启"，污染定位状态
      locationGate: () async => LocationPermissionStatus.granted,
      firstFixProvider: () async => null,
      // 这些用例断言的是"喂进去多少里程就是多少"（外加固定在 1 帧内的状态迁移），
      // 因此把平滑心跳冻到 1 小时，避免 200ms 心跳在 real-time 用例里悄悄推进里程。
      // 平滑本身由下面的「里程平滑」组用 20ms 心跳覆盖。
      smoothTickPeriod: const Duration(hours: 1),
      // 分享状态"复核"间隔（B）：注入 100ms（远小于 15s 心跳），让"自动复核"
      // 在真实时钟下几十毫秒就能跑完，又留足余量避免它在无关断言里提前触发。
      confirmProbePeriod: const Duration(milliseconds: 100),
    );
    addTearDown(() async {
      navi.dispose();
      await positions.close();
    });
  });

  /// 喂入原始 WGS-84 坐标（不依赖路线，`stop()` 之后也可调用）
  Future<void> feedRaw(double lat, double lng) async {
    positions.add(Position(
      latitude: lat,
      longitude: lng,
      timestamp: DateTime.now(),
      accuracy: 5,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 90,
      headingAccuracy: 0,
      speed: 80 / 3.6,
      speedAccuracy: 0,
    ));
    await pumpEventQueue();
  }

  /// 把"沿路线里程 d"处的坐标喂进 GPS 流。
  ///
  /// 走完整链路：GCJ-02 坐标 → 反算 WGS-84 → provider 内部再转回 GCJ-02 → 投影，
  /// 因此该断言同时验证了坐标系转换与投影。
  ///
  /// 注意：不要取正好落在动作点（segment 边界）上的 d —— 投影存在亚米级抖动，
  /// 会让"是否已越过该动作"翻转。测试统一取段内里程。
  Future<void> feedDistance(double d, {double offsetMeters = 0}) async {
    final gcj = _RouteCoord.at(navi, route, d, offsetMeters: offsetMeters);
    final wgs = _gcjToWgs(gcj.$1, gcj.$2);
    await feedRaw(wgs.$1, wgs.$2);
  }

  group('构建与状态机', () {
    test('初始状态 off，无会话', () {
      expect(navi.state, NaviState.off);
      expect(navi.hasSession, isFalse);
      expect(navi.isActive, isFalse);
    });

    test('start → locating（路线就绪，等首个 GPS）', () async {
      expect(await navi.start('https://surl.amap.com/abc'), isTrue);
      expect(navi.state, NaviState.locating);
      expect(navi.hasSession, isTrue);
      expect(navi.totalDistance, closeTo(2000, 0.5));
      expect(navi.upcomingActions, isEmpty); // 尚无定位
      expect(navi.speedLimitKmh, isNull);
    });

    test('首个定位到达 → navigating，投影里程与喂入里程一致', () async {
      await navi.start('https://surl.amap.com/abc');
      await feedDistance(300);
      expect(navi.state, NaviState.navigating);
      expect(navi.traveledDistance, closeTo(300, 2.0));
      expect(navi.currentRoad, '测试路');
      expect(navi.remaining!.meters, closeTo(1700, 3.0));
      expect(navi.nextAction!.atDistance, closeTo(600, 0.5));
      expect(navi.distanceToNextAction, closeTo(300, 2.0));
    });

    test('OBD 车速优先于 GPS 速度（隧道内也可用）', () async {
      obd.updateRealTimeData(speed: 20);
      await navi.start('https://surl.amap.com/abc');
      await feedDistance(300); // GPS 的 speed 固定为 80km/h
      expect(navi.speedKmh, closeTo(20, 0.01));
      expect(navi.nextAction!.atDistance, closeTo(600, 0.5));
      // 300m 用 20km/h → 54s，远大于 8s 窗口
      expect(navi.etaSeconds(navi.nextAction!), greaterThan(8));
    });

    test('offset 持续 > 100m → deviated，并触发重拉路线', () async {
      await navi.start('https://surl.amap.com/abc');
      await feedDistance(300);
      expect(navi.state, NaviState.navigating);
      final fetchesAfterStart = client.fetchCount;

      // 偏离 220m，连续 3 次（deviationFixThreshold）
      await feedDistance(310, offsetMeters: 220);
      await feedDistance(320, offsetMeters: 220);
      expect(navi.state, NaviState.navigating, reason: '未达阈值不应提前判定');
      await feedDistance(340, offsetMeters: 220);

      expect(navi.state, NaviState.deviated);
      expect(navi.offsetMeters, greaterThan(NaviProvider.deviationThresholdMeters));
      expect(client.fetchCount, greaterThan(fetchesAfterStart),
          reason: 'deviated 时应立即重拉 restoration');
    });

    test('重拉仍是同一份快照 → replanFailed（不再谎称重新规划）', () async {
      await navi.start('https://surl.amap.com/abc');
      await feedDistance(300);
      await feedDistance(310, offsetMeters: 220);
      await feedDistance(320, offsetMeters: 220);
      await feedDistance(340, offsetMeters: 220);
      // feedDistance 内含 pumpEventQueue，重拉（假 client 立即返回同一路线）已完成
      expect(navi.state, NaviState.deviated);
      expect(navi.replanFailed, isTrue,
          reason: '分享链接是快照，指纹未变 → 必须判定为"拿不到新路线"');
      expect(navi.routeUnchangedCount, greaterThan(0));

      // 回到路线上 → 恢复导航并清掉该标志
      await feedDistance(500);
      expect(navi.state, NaviState.navigating);
      expect(navi.replanFailed, isFalse, reason: '恢复后必须复位，否则下次偏离会带着旧结论');
    });

    test('真拿到新路线时 replanFailed 保持 false', () async {
      await navi.start('https://surl.amap.com/abc');
      await feedDistance(300);
      await feedDistance(310, offsetMeters: 220);
      await feedDistance(320, offsetMeters: 220);
      // 第 3 次偏离前先把路线换掉：重拉会拿到不同指纹
      client.routeOverride = _straightRoute(const [
        (action: 8, length: 100),
        (action: 8, length: 500),
        (action: 1, length: 700),
        (action: 8, length: 700),
      ]);
      await feedDistance(340, offsetMeters: 220);
      expect(navi.state, NaviState.deviated);
      expect(navi.replanFailed, isFalse, reason: '内容变化 = 重新规划成功');
      expect(navi.totalDistance, closeTo(2000, 1));
    });

    test('没有定位权限：如实报告原因，并保持订阅以便自动恢复', () async {
      final localPositions = StreamController<Position>.broadcast();
      final localNavi = NaviProvider(
        obdDataProvider: obd,
        logProvider: LogProvider(),
        client: client,
        positionStreamFactory: () => localPositions.stream,
        locationGate: () async => LocationPermissionStatus.deniedForever,
        firstFixProvider: () async => null,
      );
      await localNavi.start('https://surl.amap.com/abc');

      // 不再是静默的"定位中…"：状态里带上原因，UI 才有话可说
      expect(localNavi.state, NaviState.locating);
      expect(localNavi.gpsIssue, NaviGpsIssue.deniedForever);
      expect(localNavi.gpsNeedsSettings, isTrue);
      expect(localPositions.hasListener, isTrue,
          reason: '仍要订阅：用户去设置授权后应自动恢复，不用重贴短链');

      // 用户在系统设置里授权后，位置开始流动 → 自动恢复导航
      final gcj = localNavi.debugAnalyzer!.coordAt(300);
      final wgs = _gcjToWgs(gcj.lat, gcj.lon);
      localPositions.add(Position(
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
      await pumpEventQueue();
      expect(localNavi.gpsIssue, NaviGpsIssue.none);
      expect(localNavi.state, NaviState.navigating);

      await localNavi.stop();
      localNavi.dispose();
      await localPositions.close();
    });

    test('系统定位未开启：同样如实报告', () async {
      final localNavi = NaviProvider(
        obdDataProvider: obd,
        logProvider: LogProvider(),
        client: client,
        positionStreamFactory: () => positions.stream,
        locationGate: () async => LocationPermissionStatus.serviceDisabled,
        firstFixProvider: () async => null,
      );
      await localNavi.start('https://surl.amap.com/abc');
      expect(localNavi.gpsIssue, NaviGpsIssue.serviceDisabled);
      expect(localNavi.gpsNeedsSettings, isTrue);
      expect(localNavi.state, NaviState.locating);
      await localNavi.stop();
      localNavi.dispose();
    });

    test('回到路线后从 deviated 恢复 navigating', () async {
      await navi.start('https://surl.amap.com/abc');
      await feedDistance(300);
      await feedDistance(310, offsetMeters: 220);
      await feedDistance(320, offsetMeters: 220);
      await feedDistance(340, offsetMeters: 220);
      expect(navi.state, NaviState.deviated);

      await feedDistance(360);
      expect(navi.state, NaviState.navigating);
    });

    test('code != 1 → 静默收尾回 off（不摆终态卡）', () async {
      client.expireCode = '2';
      expect(await navi.start('https://surl.amap.com/abc'), isFalse);
      expect(navi.state, NaviState.off);
      expect(navi.hasSession, isFalse, reason: '第三列回默认面板，不出现"导航已结束"卡');
      expect(navi.errorMessage, contains('分享链接已失效'),
          reason: '原因仍要留给粘贴弹窗的 toast');
      expect(navi.bannerExpanded, isFalse);
    });

    test('空路线（paths: []）不建空会话，直接失败', () async {
      client.routeOverride = AmapRoute(const {'paths': []});
      expect(await navi.start('https://surl.amap.com/abc'), isFalse);
      expect(navi.state, NaviState.off);
      expect(navi.errorMessage, contains('空路线'));
    });

    test('短链解析失败 → 静默收尾回 off', () async {
      client.linkError = ShareLinkException('不是高德分享短链');
      expect(await navi.start('https://surl.amap.com/abc'), isFalse);
      expect(navi.state, NaviState.off);
      expect(navi.errorMessage, contains('不是高德分享短链'));
    });

    test('连续 3 次刷新失败 → stale（保留最后路线，不静默消失）', () async {
      await navi.start('https://surl.amap.com/abc');
      await feedDistance(300);
      expect(navi.state, NaviState.navigating);

      client.routeError = Exception('network down');
      navi.setRouteRefreshSec(10);
      for (var i = 0; i < NaviProvider.staleFailureThreshold; i++) {
        await client.triggerRefreshVia(navi);
      }
      expect(navi.state, NaviState.stale);
      expect(navi.totalDistance, closeTo(2000, 0.5), reason: '保留最后路线');
      expect(navi.errorCount, greaterThanOrEqualTo(3));
    });
  });

  group('通栏展开 / 收回（方案 §2.4）', () {
    test('进入 8 秒窗口前不展开，进入后展开', () async {
      await navi.start('https://surl.amap.com/abc');
      await feedDistance(300); // next=600 → 300m/22.2 ≈ 13.5s
      expect(navi.bannerExpanded, isFalse);
      expect(navi.etaSeconds(navi.nextAction!), greaterThan(8));

      await feedDistance(500); // next=600 → 100m/22.2 ≈ 4.5s
      expect(navi.bannerExpanded, isTrue);
      expect(navi.etaSeconds(navi.nextAction!), lessThan(8));
    });

    test('连续多动作期间通栏全程展开，不出现 true→false→true 抖动', () async {
      await navi.start('https://surl.amap.com/abc');
      await feedDistance(500); // 进入窗口：next=600 → 100m → 4.5s
      expect(navi.bannerExpanded, isTrue);

      final flags = <bool>[navi.bannerExpanded];
      final seenActionCodes = <int>{navi.nextAction!.actionCode};
      // 500 → 699，覆盖 600/631/682/700 四个动作点
      for (var d = 507.0; d <= 699; d += 7) {
        await feedDistance(d);
        flags.add(navi.bannerExpanded);
        seenActionCodes.add(navi.nextAction!.actionCode);
      }

      expect(flags.contains(false), isFalse,
          reason: "通栏在连续转弯期间不得收回（展开序列=$flags）");
      expect(seenActionCodes.length, greaterThanOrEqualTo(3),
          reason: '应跨越 直行/左转/右前方 多个动作，内容切换而非收回重开');
      // 内容确实在变（key 变化）但外壳保持展开
      expect(navi.upcomingActions.length, greaterThanOrEqualTo(1));
    });

    test('所有动作都过了 8 秒窗口后收回', () async {
      await navi.start('https://surl.amap.com/abc');
      await feedDistance(690); // next=700 → 10m → 0.45s，展开
      expect(navi.bannerExpanded, isTrue);

      await feedDistance(800); // next=2000 → 1200m → 54s，全部出窗口
      expect(navi.bannerExpanded, isFalse);

      await feedDistance(810);
      expect(navi.bannerExpanded, isFalse);
    });

    test('队列多个动作同时在窗口内时全部可读（limit=3）', () async {
      await navi.start('https://surl.amap.com/abc');
      await feedDistance(601); // next=631(1.35s) / 682(3.6s) / 700(4.5s)
      final up = navi.upcomingActions;
      expect(up.map((e) => e.atDistance.round()).toList(), [631, 682, 700]);
      expect(up.every((e) => navi.etaSeconds(e) < 8), isTrue);
      expect(navi.bannerExpanded, isTrue);
    });
  });

  group('限速联动（4d）', () {
    test('限速点生效范围内给出限速值，超速判定正确', () async {
      // 在 1000m 处放一个 60km/h 的测速点（cameras type==0 带 speed）
      client.routeOverride = _straightRoute(
        const [
          (action: 8, length: 2000),
        ],
        cameras: const [
          (lon: 116.3, lat: 40.0, segmentIndex: 0, linkIndex: 0, speed: 60),
        ],
      );
      await navi.start('https://surl.amap.com/abc');
      await feedDistance(500);

      expect(navi.speedLimitKmh, 60);
      expect(navi.speedKmh, closeTo(80, 0.01)); // OBD 车速
      expect(navi.isSpeeding, isTrue);

      obd.updateRealTimeData(speed: 40);
      await feedDistance(520);
      expect(navi.isSpeeding, isFalse);
    });

    test('脏坐标的限速点被过滤', () async {
      client.routeOverride = _straightRoute(
        const [
          (action: 8, length: 2000),
        ],
        cameras: const [
          // 与 facilities.general type==92 同类的坏点：经纬度越界
          (lon: 999.0, lat: 40.0, segmentIndex: 0, linkIndex: 0, speed: 30),
        ],
      );
      await navi.start('https://surl.amap.com/abc');
      await feedDistance(500);
      expect(navi.speedLimitKmh, isNull);
      expect(navi.isSpeeding, isFalse);
    });
  });

  group('底图切片（导航卡 v2）', () {
    test('无路线时切片为空', () {
      expect(navi.routeSlice.isEmpty, isTrue);
      expect(navi.routeMarkers, isEmpty);
      expect(navi.mapAheadMeters, NaviProvider.defaultMapAheadMeters);
    });

    test('E1 定位中：以路线起点为锚点先给出底图，但不含已行驶段', () async {
      await navi.start('https://surl.amap.com/abc');
      expect(navi.projection, isNull);
      final s = navi.routeSlice;
      expect(s.isEmpty, isFalse, reason: 'E1 也应画出路线（来自路线切线）');
      expect(s.vehicleDistance, 0);
      expect(s.behindMeters, 0);
      expect(s.toDistance, closeTo(navi.mapAheadMeters, 0.5));
    });

    test('定位后切片锚点跟随位置，车辆点落在线上', () async {
      await navi.start('https://surl.amap.com/abc');
      await feedDistance(700);
      final s = navi.routeSlice;
      expect(s.vehicleDistance, closeTo(700, 2.0));
      expect(s.fromDistance, closeTo(660, 2.0));
      expect(s.toDistance, closeTo(1000, 3.0)); // 700 + 300 但总里程 2000 → 未夹断
      final v = navi.debugAnalyzer!.coordAt(s.vehicleDistance);
      expect(s.points[s.vehicleIndex].lon, closeTo(v.lon, 1e-9));
      expect(s.points[s.vehicleIndex].lat, closeTo(v.lat, 1e-9));
      expect(s.trafficStates.length, s.points.length);
    });

    test('视窗里程可切换，切片跨度随之变化', () async {
      await navi.start('https://surl.amap.com/abc');
      await feedDistance(300);
      expect(navi.routeSlice.aheadMeters, closeTo(300, 0.5));

      navi.setMapAheadMeters(600);
      expect(navi.mapAheadMeters, 600);
      expect(navi.routeSlice.aheadMeters, closeTo(600, 0.5));

      navi.setMapAheadMeters(150);
      expect(navi.routeSlice.aheadMeters, closeTo(150, 0.5));

      // 越界值被钳制
      navi.setMapAheadMeters(5);
      expect(navi.mapAheadMeters, 100);
    });

    test('抖动抑制：里程小幅前移时视窗锚点保持不动', () async {
      await navi.start('https://surl.amap.com/abc');
      await feedDistance(300);
      final anchorBefore = navi.routeSlice.vehicleDistance;

      // 前进 2m（< sliceAnchorStepMeters）且路线接近直行 → 不重算
      await feedDistance(302);
      expect(navi.routeSlice.vehicleDistance, anchorBefore);

      // 前进 20m（> 阈值）→ 重算
      await feedDistance(325);
      expect(navi.routeSlice.vehicleDistance, greaterThan(anchorBefore));
    });

    test('底图标记：窗内限速点与红绿灯被收集，窗外被排除', () async {
      client.routeOverride = _straightRoute(
        const [
          (action: 8, length: 400),
          (action: 8, length: 200), // 该段起点（400m）有红绿灯
          (action: 8, length: 1400),
        ],
        cameras: const [
          // 限速点挂在第 2 段（segment_index=1 → 累计 400m）
          (lon: 116.3, lat: 40.0, segmentIndex: 1, linkIndex: 0, speed: 60),
        ],
        lightSegmentIndexes: const [1],
      );
      await navi.start('https://surl.amap.com/abc');
      await feedDistance(400); // 视窗 360..700

      final kinds = navi.routeMarkers.map((m) => m.kind).toSet();
      expect(kinds, contains(RouteMarkerKind.trafficLight));
      expect(kinds, contains(RouteMarkerKind.speedLimit));
      expect(
        navi.routeMarkers
            .where((m) => m.kind == RouteMarkerKind.speedLimit)
            .first
            .value,
        60,
      );

      // 远离后（视窗 1460..1800）窗内不再有标记
      await feedDistance(1500);
      expect(navi.routeMarkers, isEmpty);
    });

    test('stop() 清空切片与标记', () async {
      await navi.start('https://surl.amap.com/abc');
      await feedDistance(300);
      expect(navi.routeSlice.isEmpty, isFalse);
      await navi.stop();
      expect(navi.routeSlice.isEmpty, isTrue);
      expect(navi.routeMarkers, isEmpty);
    });
  });

  group('生命周期', () {
    test('stop() 后订阅与定时器全部释放，状态回 off，零残留', () async {
      await navi.start('https://surl.amap.com/abc');
      await feedDistance(300);
      expect(navi.state, NaviState.navigating);
      expect(positions.hasListener, isTrue);

      await navi.stop();

      expect(navi.state, NaviState.off);
      expect(navi.hasSession, isFalse);
      expect(navi.projection, isNull);
      expect(navi.upcomingActions, isEmpty);
      expect(navi.remaining, isNull);
      expect(navi.bannerExpanded, isFalse);
      expect(navi.currentRoad, isNull);
      expect(navi.speedLimitKmh, isNull);
      expect(positions.hasListener, isFalse, reason: 'GPS 订阅必须释放');

      // 停止后再喂定位不应产生任何变化（不会 notify）
      var notified = 0;
      navi.addListener(() => notified++);
      final fixesBefore = navi.gpsFixCount;
      await feedRaw(40.0005, 116.3012);
      expect(navi.gpsFixCount, fixesBefore);
      expect(notified, 0);
    });

    test('重复 start 会先清理上一次会话', () async {
      await navi.start('https://surl.amap.com/abc');
      await feedDistance(300);
      expect(navi.traveledDistance, closeTo(300, 2.0));

      await navi.start('https://surl.amap.com/def');
      expect(navi.state, NaviState.locating);
      expect(navi.traveledDistance, isNull, reason: '旧投影必须清空');
      expect(navi.shareUrl, 'https://surl.amap.com/def');
    });

    test('setRouteRefreshSec 夹到 [10, 120] 并生效', () async {
      expect(navi.routeRefreshSec, 30); // 默认
      navi.setRouteRefreshSec(5);
      expect(navi.routeRefreshSec, 10);
      navi.setRouteRefreshSec(600);
      expect(navi.routeRefreshSec, 120);
      navi.setRouteRefreshSec(15);
      expect(navi.routeRefreshSec, 15);
    });

    test('pause/resume：后台停订阅，回前台立即补一次', () async {
      await navi.start('https://surl.amap.com/abc');
      await feedDistance(300);
      expect(positions.hasListener, isTrue);

      navi.didChangeAppLifecycleState(AppLifecycleState.paused);
      expect(positions.hasListener, isFalse, reason: '后台应停 GPS 订阅');

      final fetchesBefore = client.fetchCount;
      navi.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await pumpEventQueue();
      expect(positions.hasListener, isTrue);
      expect(client.fetchCount, greaterThan(fetchesBefore),
          reason: '回前台应立即补一次路线刷新');
      expect(navi.state, NaviState.navigating);
    });
  });

  group('投影连续性（路线自邻近不跳动作）', () {
    // 复现实测形态：主辅路 / 立交匝道两段相隔仅 18m，
    // 纯"最近边"会把里程吸到几百米后的那一程，表现为下一个动作跳过后面的转弯。
    test('沿去程行驶时始终指向去程段末动作，不被吸到回程段', () async {
      client.routeOverride = _doubleBackRoute();
      await navi.start('https://surl.amap.com/abc');

      // 首个定位必须无偏移（此时还没有里程先验，全局最近是唯一可用信息）
      await feedDistance(40);
      expect(navi.state, NaviState.navigating);
      expect(navi.nextAction!.atDistance, closeTo(300, 0.5));

      // 之后定位带 10m 北偏 —— 距对面那段只有 8m，纯几何最近会选错
      for (final d in [80.0, 120.0, 160.0, 200.0, 240.0]) {
        await feedDistance(d, offsetMeters: 10);
        expect(navi.traveledDistance, closeTo(d, 25),
            reason: 'd=$d 处里程被吸到对面那段了');
        expect(navi.nextAction!.atDistance, closeTo(300, 0.5),
            reason: 'd=$d 处应仍指向去程段末的动作（300m），而不是回程段末（600m）');
        expect(navi.state, NaviState.navigating);
      }
    });

    test('对照：不传里程先验时同一坐标确实会被吸走（歧义客观存在）', () async {
      client.routeOverride = _doubleBackRoute();
      await navi.start('https://surl.amap.com/abc');
      final analyzer = navi.debugAnalyzer!;
      final c = analyzer.coordAt(120);
      final global = analyzer.project(c.lon, c.lat + 10 / 110540);
      final constrained = analyzer.project(c.lon, c.lat + 10 / 110540,
          nearDistance: 120);
      expect(global.distance, greaterThan(400),
          reason: '全局最近落在回程段（里程 ≈ 2*300-120）');
      expect(constrained.distance, closeTo(120, 5));
    });
  });

  group('里程平滑（推算-校正，真机"拐过弯还提示转弯"的体验修复）', () {
    late StreamController<Position> smoothPositions;
    late NaviProvider smooth;

    setUp(() {
      smoothPositions = StreamController<Position>.broadcast();
      smooth = NaviProvider(
        obdDataProvider: obd,
        logProvider: LogProvider(),
        client: client,
        positionStreamFactory: () => smoothPositions.stream,
        locationGate: () async => LocationPermissionStatus.granted,
        firstFixProvider: () async => null,
        // 20ms 心跳：毫秒级就能观察到平滑推进
        smoothTickPeriod: const Duration(milliseconds: 20),
      );
      addTearDown(() async {
        await smooth.stop();
        smooth.dispose();
        await smoothPositions.close();
      });
    });

    /// 喂入"沿路线里程 d、向北偏移 offsetMeters、GPS 速度 speedKmh"的定位
    ///
    /// [age] 模拟该定位的**龄期**（采集时刻 → 送达时刻）：`pos.timestamp` 取
    /// `now - age`，provider 会按当前车速把这段前推掉。
    Future<void> feedSmooth(
      double d, {
      double offsetMeters = 0,
      double speedKmh = 80,
      Duration age = Duration.zero,
    }) async {
      final gcj = _RouteCoord.at(smooth, route, d, offsetMeters: offsetMeters);
      final wgs = _gcjToWgs(gcj.$1, gcj.$2);
      smoothPositions.add(Position(
        latitude: wgs.$1,
        longitude: wgs.$2,
        timestamp: DateTime.now().subtract(age),
        accuracy: 5,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 90,
        headingAccuracy: 0,
        speed: speedKmh / 3.6,
        speedAccuracy: 0,
      ));
      await pumpEventQueue();
    }

    test('两帧之间按当前车速前推里程（不再等下一次定位）', () async {
      await smooth.start('https://surl.amap.com/abc');
      await feedSmooth(300);
      final d0 = smooth.projection!.distance;
      expect(d0, closeTo(300, 1));

      // 80km/h ≈ 22.2 m/s：300ms 应推进 ≈6.7m（容差覆盖调度抖动）
      await Future.delayed(const Duration(milliseconds: 300));
      final advanced = smooth.projection!.distance - d0;
      expect(advanced, greaterThan(3.0));
      expect(advanced, lessThan(12.0));

      // 校正步：新定位到达后里程被实测值整体覆盖，误差不累积
      await feedSmooth(310);
      expect(smooth.projection!.distance, closeTo(310, 1));
    });

    test('静止不推进：等红灯时里程不会自己往前爬', () async {
      // OBD 与 GPS 都报 0（只清 OBD 不够：还有 GPS 进球速度兜底）
      obd.updateRealTimeData(speed: 0);
      await smooth.start('https://surl.amap.com/abc');
      await feedSmooth(300, speedKmh: 0);
      final d0 = smooth.projection!.distance;

      await Future.delayed(const Duration(milliseconds: 300));
      expect(smooth.projection!.distance, d0,
          reason: '车速低于 minEtaSpeedMs 时不允许外推');
    });

    test('推算心跳不参与偏离判定（一次坏点不会被放大成 deviated）', () async {
      await smooth.start('https://surl.amap.com/abc');
      await feedSmooth(300); // 先上路：locating → navigating
      expect(smooth.state, NaviState.navigating);

      // 一次偏移 220m 的实测点：偏离阈值是"连续 3 次"（deviationFixThreshold）
      await feedSmooth(310, offsetMeters: 220);
      expect(smooth.state, NaviState.navigating);

      // 期间 20ms 心跳跑了十几次；若把推算值也算进偏离计数，会立刻凑满 3 次
      await Future.delayed(const Duration(milliseconds: 300));
      expect(smooth.state, NaviState.navigating,
          reason: '偏离是实测点的属性，5Hz 推算值不能把计数凑满');
    });

    test('偏离态不做平滑推进（车已不在路线上，前推里程没有意义）', () async {
      await smooth.start('https://surl.amap.com/abc');
      await feedSmooth(300);
      await feedSmooth(310, offsetMeters: 220);
      await feedSmooth(320, offsetMeters: 220);
      await feedSmooth(340, offsetMeters: 220);
      expect(smooth.state, NaviState.deviated);
      final d0 = smooth.projection!.distance;

      await Future.delayed(const Duration(milliseconds: 300));
      expect(smooth.projection!.distance, d0);
    });

    test('刹车到几乎停车：里程停下，但通栏按新的 ETA 收回', () async {
      await smooth.start('https://surl.amap.com/abc');
      await feedSmooth(560); // 段末动作在 600m → 前方 40m
      expect(smooth.bannerExpanded, isTrue, reason: '80km/h 下 ETA 1.8s');

      // 刹到 5km/h：里程几乎不动，但 40m / 2m/s = 20s，已离开 8 秒窗口
      obd.updateRealTimeData(speed: 5);
      await Future.delayed(const Duration(milliseconds: 300));
      final d1 = smooth.projection!.distance;
      await Future.delayed(const Duration(milliseconds: 200));

      expect(smooth.projection!.distance, d1,
          reason: '低于 minEtaSpeedMs 不再推进');
      expect(smooth.bannerExpanded, isFalse,
          reason: '通栏条件含 ETA，降速后必须收回，否则会在路口前一直挂着');
    });

    test('定位龄期补偿：采集→送达那段延迟也按车速补上', () async {
      await smooth.start('https://surl.amap.com/abc');
      // 500ms 龄期（芯片解算 + 融合 + 派发），80km/h ≈ 11.1m
      await feedSmooth(300, age: const Duration(milliseconds: 500));
      expect(smooth.projection!.distance, closeTo(311.1, 2.0),
          reason: '只从"收到时刻"起算会一直落后一个定位龄期，正是"进弯还差几十米"的来源');
    });

    test('龄期不可信（时间戳异常）时不补偿，避免凭空多跑几十米', () async {
      await smooth.start('https://surl.amap.com/abc');
      // 30s 的"龄期"只可能是时钟偏移 / 单位错 / 批处理积压
      await feedSmooth(300, age: const Duration(seconds: 30));
      expect(smooth.projection!.distance, closeTo(300, 1.0),
          reason: '宁可慢一点，也不能凭空把用户推到弯道之后');
    });

    test('龄期补偿与心跳不重复计数', () async {
      await smooth.start('https://surl.amap.com/abc');
      await feedSmooth(300, age: const Duration(milliseconds: 500));
      final d1 = smooth.projection!.distance;

      await Future.delayed(const Duration(milliseconds: 200));
      final advanced = smooth.projection!.distance - d1;
      // 200ms × 22.2m/s ≈ 4.4m；若龄期那段被算两遍会多出 ~11m
      expect(advanced, greaterThan(1.0));
      expect(advanced, lessThan(8.0));
    });

    test('长失联：里程持续按车速外推，并亮"推算中"', () async {
      await smooth.start('https://surl.amap.com/abc');
      await feedSmooth(300);
      final d0 = smooth.projection!.distance;

      // 超过 gpsStaleSeconds（5s）没有新定位 → 同一套心跳转为航位推算。
      // 这一等是真实的 5.2 秒：门槛是 static const，无法注入加速。
      await Future.delayed(const Duration(milliseconds: 5200));
      expect(smooth.extrapolating, isTrue);
      expect(smooth.projection!.distance, greaterThan(d0 + 20));
    });
  });

  group('分享状态心跳（高德那边停了就收尾）', () {
    /// 触发**一次**与定时器等价的状态探测（避免测试真等 15 秒心跳）。
    ///
    /// 末尾 `pumpEventQueue` 顺带让 `_endSession`（内部是 `unawaited`）跑完，
    /// 好让"收尾后 hasListener == false"这类断言成立；注入的复核间隔是 100ms，
    /// 这点耗时远不足以把它提前引爆。
    Future<void> probeOnce() async {
      await navi.debugStatusProbeNow();
      await pumpEventQueue();
    }

    /// 手动探测一次 + 等**自动复核**跑完（B：注入的 100ms 复核间隔）。
    Future<void> probeConfirmed() async {
      await probeOnce();
      await Future.delayed(const Duration(milliseconds: 300));
      await pumpEventQueue();
    }

    test('复核间隔远短于心跳周期（B 的核心）', () async {
      await navi.start('https://surl.amap.com/abc');
      await feedDistance(300);
      client.naviShareStatus = 5;

      await navi.debugStatusProbeNow();
      final first = client.naviStatusTimes.last;

      // 不再手动探测：复核定时器应自己发起第二次探测
      await Future.delayed(const Duration(milliseconds: 300));
      await pumpEventQueue();

      expect(client.naviStatusTimes.length, greaterThanOrEqualTo(2),
          reason: '首次判据后应自动复核一次');
      final gapMs = client.naviStatusTimes.last.difference(first).inMilliseconds;
      expect(gapMs, greaterThanOrEqualTo(10));
      expect(gapMs, lessThan(1000),
          reason: '复核必须远短于心跳（${navi.statusWatchSec}s），否则收尾又被拖到 15~30s');
      expect(navi.state, NaviState.off);
    });

    test('并发探测互斥：同一时刻的信息只算一次（B 的必要护栏）', () async {
      await navi.start('https://surl.amap.com/abc');
      await feedDistance(300);
      client.naviShareStatus = 5;

      unawaited(navi.debugStatusProbeNow());
      expect(navi.statusProbeCount, 1, reason: '首个调用同步计数');
      unawaited(navi.debugStatusProbeNow());
      unawaited(navi.debugStatusProbeNow());
      expect(navi.statusProbeCount, 1, reason: '被互斥拦下的调用不计数');

      await pumpEventQueue();
      expect(navi.state, NaviState.navigating,
          reason: '只算 1 次确认不能收尾（否则绕过 statusConfirmCount 的防护）');
    });

    test('回前台立即探一次（A），且进后台撤销待执行的复核', () async {
      await navi.start('https://surl.amap.com/abc');
      await feedDistance(300);

      client.naviShareStatus = 5;
      await navi.debugStatusProbeNow(); // strikes=1，挂上 100ms 复核
      expect(navi.debugConfirmProbePending, isTrue);

      navi.didChangeAppLifecycleState(AppLifecycleState.paused);
      expect(navi.debugConfirmProbePending, isFalse,
          reason: '进后台必须撤销待执行的复核，否则会在后台发请求');

      client.naviShareStatus = 1; // 回前台前分享又活了
      final before = navi.statusProbeCount;
      navi.didChangeAppLifecycleState(AppLifecycleState.resumed);
      expect(navi.statusProbeCount, before + 1,
          reason: 'A：回前台立即补探一次，不再等满 15s');

      await pumpEventQueue();
      expect(navi.state, NaviState.navigating);
    });

    test('复核期间 stop()：撤销复核，不再有残留探测', () async {
      await navi.start('https://surl.amap.com/abc');
      await feedDistance(300);
      client.naviShareStatus = 5;
      await probeOnce(); // strikes=1，挂复核
      expect(navi.debugConfirmProbePending, isTrue);

      await navi.stop();
      expect(navi.debugConfirmProbePending, isFalse, reason: 'stop() 必须撤销复核');

      final calls = client.naviStatusCalls;
      await Future.delayed(const Duration(milliseconds: 300));
      await pumpEventQueue();
      expect(client.naviStatusCalls, calls, reason: '复核不得再发探测');
    });

    test('复核给 unknown：计数清零、撤销复核、仍 navigating', () async {
      await navi.start('https://surl.amap.com/abc');
      await feedDistance(300);
      client.naviShareStatus = 5;
      await probeOnce();
      expect(navi.debugConfirmProbePending, isTrue);

      // 复核时快照变得不可判定（行中字段缺失 + 行前 code 非 1）→ unknown
      client.naviShareStatus = null;
      client.beforeCode = '2';

      await Future.delayed(const Duration(milliseconds: 300));
      await pumpEventQueue();
      expect(navi.state, NaviState.navigating, reason: 'unknown ≠ 已停止，不得收尾');
      expect(navi.debugConfirmProbePending, isFalse, reason: 'unknown 要打断确认链');
    });

    test('复核探测失败：不改状态；strike 保留，下次成功探测即可确认', () async {
      await navi.start('https://surl.amap.com/abc');
      await feedDistance(300);
      client.naviShareStatus = 5;
      await probeOnce();
      final failuresBefore = navi.statusProbeFailureCount;

      client.statusError = Exception('boom'); // 复核时网络断了
      await Future.delayed(const Duration(milliseconds: 300));
      await pumpEventQueue();
      expect(navi.state, NaviState.navigating, reason: '探测不到 ≠ 已停止');
      expect(navi.statusProbeFailureCount, failuresBefore + 1);

      // 失败的复核不清零计数（探测失败没有信息量）→ 下一次成功探测即可收尾
      client.statusError = null;
      await probeOnce();
      expect(navi.state, NaviState.off);
    });

    test('suspend 期间迟到的 verdict 不排复核（P0-2）', () async {
      await navi.start('https://surl.amap.com/abc');
      await feedDistance(300);
      client.naviShareStatus = 5;

      // 让这次探测挂在网络上（模拟"探测 in-flight 时进后台"）
      final gate = Completer<void>();
      client.statusGate = gate;
      final pending = navi.debugStatusProbeNow();
      await pumpEventQueue();

      navi.didChangeAppLifecycleState(AppLifecycleState.paused);

      // 放行：verdict 在 suspend **之后**才落地
      client.statusGate = null;
      gate.complete();
      await pending;
      await pumpEventQueue();

      expect(navi.debugConfirmProbePending, isFalse,
          reason: '后台不得挂出复核定时器（否则违反"后台一次都不探"）');

      final countAfterProbe = navi.statusProbeCount;
      await Future.delayed(const Duration(milliseconds: 300));
      await pumpEventQueue();
      expect(navi.statusProbeCount, countAfterProbe, reason: '后台期间一次都不探');
      expect(navi.state, NaviState.navigating, reason: '会话仍在（未收尾）');

      // 回前台 → 立即补探 → 完成确认 → 收尾（strikes 一直保留）
      navi.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await pumpEventQueue();
      await pumpEventQueue();
      expect(navi.state, NaviState.off);
    });

    test('跨会话隔离：旧会话迟到的探测不打在新会话上（P0-3）', () async {
      await navi.start('https://surl.amap.com/abc');
      await feedDistance(300);

      client.naviShareStatus = 5; // 旧会话：已停止
      final gate = Completer<void>();
      client.statusGate = gate;
      final stale = navi.debugStatusProbeNow(); // 旧探测挂在网络上
      await pumpEventQueue();

      await navi.stop(); // 收掉旧会话
      client.statusGate = null; // 后续探测不再卡住
      client.naviShareStatus = 1; // 新分享还活着（行前自检放行）
      await navi.start('https://surl.amap.com/abc'); // 重贴短链 → 新会话
      await feedDistance(300);
      expect(navi.state, NaviState.navigating);

      final countBefore = navi.statusProbeCount;
      final callsBefore = client.naviStatusCalls;
      client.naviShareStatus = 5; // 旧探测此刻才返回 stopped
      gate.complete();
      await stale;
      await pumpEventQueue();

      expect(navi.state, NaviState.navigating,
          reason: '旧 param 的返回不许打在新会话上');
      expect(navi.debugConfirmProbePending, isFalse, reason: '不得给新会话挂复核');

      await Future.delayed(const Duration(milliseconds: 300));
      await pumpEventQueue();
      expect(navi.statusProbeCount, countBefore, reason: '跨会话不得触发任何探测');
      expect(client.naviStatusCalls, callsBefore,
          reason: '旧 verdict 被丢弃，不应顺带引出发一次复核探测');
      expect(navi.state, NaviState.navigating);
    });

    test('中途开关心跳：关→开立即生效并补探一次（P0-1）', () async {
      await navi.start('https://surl.amap.com/abc');
      await feedDistance(300);
      final before = navi.statusProbeCount;

      SharedPreferences.setMockInitialValues(
          {'settings_navi_shareStatusWatchOn': false});
      final off = SettingsProvider();
      await off.init();
      navi.updateSettings(off);

      SharedPreferences.setMockInitialValues(
          {'settings_navi_shareStatusWatchOn': true});
      final on = SettingsProvider();
      await on.init();
      navi.updateSettings(on);

      expect(navi.statusProbeCount, before + 1,
          reason: '关→开是"从盲到明"，应像回前台一样立即补探（原来要等下次 start()）');
    });

    test('单次 stopped 不收尾；短间隔复核后自动收尾（防后端节点抖动误停）', () async {
      await navi.start('https://surl.amap.com/abc');
      await feedDistance(300);
      expect(navi.state, NaviState.navigating);

      client.naviShareStatus = 5; // 导航中途，高德那边停了
      await probeOnce();
      expect(navi.state, NaviState.navigating,
          reason: '一次判据不足以证明此刻真的停了');
      expect(navi.debugConfirmProbePending, isTrue,
          reason: 'B：首次判据后应挂上短间隔复核，而不是等满 15s');

      // 不再手动探测：等复核定时器自己跑完（注入 100ms）
      await Future.delayed(const Duration(milliseconds: 300));
      await pumpEventQueue();
      expect(navi.state, NaviState.off, reason: '静默收尾：不摆"导航已结束"卡');
      expect(navi.debugConfirmProbePending, isFalse, reason: '收尾后复核也要清掉');
      expect(navi.isActive, isFalse);
      expect(navi.hasSession, isFalse, reason: '第三列回默认面板');
      expect(navi.errorMessage, contains('高德那边已停止导航'));
    });

    test('抖动不累计：stopped → navigating 后计数清零，下一次只算第 1 次', () async {
      await navi.start('https://surl.amap.com/abc');
      await feedDistance(300);

      client.naviShareStatus = 5;
      await probeOnce(); // strikes=1，挂复核
      expect(navi.debugConfirmProbePending, isTrue);

      client.naviShareStatus = 1; // 复核时又活着了 → 计数清零 + 撤销复核
      await probeConfirmed();
      expect(navi.debugConfirmProbePending, isFalse);

      client.naviShareStatus = 5;
      await probeOnce(); // 从 1 重新开始
      expect(navi.state, NaviState.navigating,
          reason: '上一次的 1 次确认不得与这一次凑成收尾');
      expect(navi.debugConfirmProbePending, isTrue,
          reason: '这一次又挂起复核，说明计数确实回到了 1');
    });

    test('行中端点给不出结论 → 回落行前端点复核', () async {
      await navi.start('https://surl.amap.com/abc');
      await feedDistance(300);
      client.naviShareStatus = null; // 字段缺失 → unknown
      client.beforeStatus = 4; // 行前：分享者已在导航中 → 不是结束

      await probeOnce();
      await probeOnce();
      expect(client.beforeStatusCalls, greaterThanOrEqualTo(2),
          reason: '行中判不出时必须问行前端点');
      expect(navi.state, NaviState.navigating,
          reason: 'status=4 是"该切端点"，不是结束');
    });

    test('行前端点判停止同样能收尾（两次确认）', () async {
      await navi.start('https://surl.amap.com/abc');
      await feedDistance(300);
      client.naviShareStatus = null;
      client.beforeStatus = 2; // 路线分享已停止

      await probeOnce();
      expect(navi.state, NaviState.navigating);
      await probeOnce();
      expect(navi.state, NaviState.off, reason: '静默收尾');
      expect(navi.hasSession, isFalse);
    });

    test('code=10001 已过期 → 收尾，原因区别于"分享链接已失效"', () async {
      await navi.start('https://surl.amap.com/abc');
      await feedDistance(300);
      client.naviShareStatus = null;
      client.beforeCode = '10001';

      await probeOnce();
      await probeOnce();
      expect(navi.state, NaviState.off, reason: '静默收尾');
      expect(navi.errorMessage, contains('该分享已过期'));
      expect(navi.errorMessage, isNot(contains('失效')));
    });

    test('code=2/3（参数问题）永远不收尾', () async {
      await navi.start('https://surl.amap.com/abc');
      await feedDistance(300);
      client.naviShareStatus = null;
      client.beforeCode = '2';

      for (var i = 0; i < 5; i++) {
        await probeOnce();
      }
      expect(navi.state, NaviState.navigating);
    });

    test('探测失败不改状态（探测不到 ≠ 已停止）', () async {
      await navi.start('https://surl.amap.com/abc');
      await feedDistance(300);
      client.statusError = Exception('boom'); // 启动之后才开始探不通

      await probeOnce();
      await probeOnce();
      await probeOnce();
      expect(navi.state, NaviState.navigating);
      expect(navi.statusProbeFailureCount, 3);
    });

    test('收尾后零残留：心跳停止、GPS 订阅释放、通栏收回', () async {
      await navi.start('https://surl.amap.com/abc');
      await feedDistance(300);
      client.naviShareStatus = 6; // 路线分享结束
      await probeOnce();
      await probeOnce();
      expect(navi.state, NaviState.off, reason: '静默收尾');

      // 再探测不再产生任何变化（定时器已停）
      final calls = client.naviStatusCalls;
      await navi.debugStatusProbeNow();
      expect(client.naviStatusCalls, calls,
          reason: '已收尾（off）不是 active，探测应直接返回');
      expect(positions.hasListener, isFalse, reason: 'GPS 订阅必须释放');
      expect(navi.bannerExpanded, isFalse);
    });

    test('naviStopOnShareEnd=false：只提示"已停止"，继续导航', () async {
      SharedPreferences.setMockInitialValues(
          {'settings_navi_stopOnShareEnd': false});
      final settings = SettingsProvider();
      await settings.init();
      navi.updateSettings(settings);

      await navi.start('https://surl.amap.com/abc');
      await feedDistance(300);

      client.naviShareStatus = 5; // 导航中途高德那边停了
      await probeOnce();
      await probeOnce();
      expect(navi.state, NaviState.navigating, reason: '开关关掉就不掐导航');
      expect(navi.shareStoppedHint, isTrue, reason: '但必须让用户知道高德停了');
    });

    test('stop() 后状态心跳不留残：再次 start 不外泄旧计数', () async {
      await navi.start('https://surl.amap.com/abc');
      await feedDistance(300);
      client.naviShareStatus = 5;
      await probeOnce(); // 只确认 1 次，不收尾
      await navi.stop();

      // 重新开始时计数必须清零，否则"上一次的 1 次确认"会凑成这一次的收尾
      client.naviShareStatus = 1; // 行前自检：分享还在，允许启动
      await navi.start('https://surl.amap.com/abc');
      await feedDistance(300);
      client.naviShareStatus = 5;
      await probeOnce();
      expect(navi.state, NaviState.navigating);
    });
  });

  group('行前自检（刚粘贴时先问"这条分享还在导航吗"）', () {
    test('已结束（shareStatus=5）→ 不建立会话：状态停在 off、不拉路线、零残留', () async {
      client.naviShareStatus = 5;

      final ok = await navi.start('https://surl.amap.com/abc');
      await pumpEventQueue();

      expect(ok, isFalse);
      expect(navi.state, NaviState.off);
      expect(navi.hasSession, isFalse, reason: '不建会话 ⇒ 导航卡不渲染，回默认面板');
      expect(navi.isActive, isFalse);
      expect(navi.lastStartEndedShare, isTrue);
      expect(navi.errorMessage, contains('已结束'));
      expect(client.fetchCount, 0, reason: '既然已结束，就不该再把整条路线拉回来');
      expect(client.naviStatusCalls, 2, reason: '与心跳同一把尺：两次同向确认');
      expect(navi.shareUrl, isNull, reason: '零残留');
      expect(positions.hasListener, isFalse, reason: '不启动 GPS 订阅');
    });

    test('已结束的分享：全程不经过 locating，卡片一秒都不闪', () async {
      client.naviShareStatus = 5;
      final seen = <NaviState>[];
      void record() => seen.add(navi.state);
      navi.addListener(record);
      try {
        await navi.start('https://surl.amap.com/abc');
        await pumpEventQueue();
      } finally {
        navi.removeListener(record);
      }
      expect(seen, isNotEmpty, reason: '至少要通知一次，UI 才会停在默认面板');
      expect(seen, isNot(contains(NaviState.locating)),
          reason: '若先发 locating，hasSession 会短暂为 true → 卡片闪一下再消失');
      expect(seen.every((s) => s == NaviState.off), isTrue);
    });

    test('已结束的两种来源都拦下：行前 status=2 / code=10001', () async {
      client.naviShareStatus = null;
      client.beforeStatus = 2; // 行前：路线分享已停止
      expect(await navi.start('https://surl.amap.com/a'), isFalse);
      expect(navi.state, NaviState.off);
      expect(navi.lastStartEndedShare, isTrue);

      client.beforeStatus = 4;
      client.beforeCode = '10001'; // 分享已过期
      expect(await navi.start('https://surl.amap.com/b'), isFalse);
      expect(navi.state, NaviState.off);
      expect(navi.lastStartEndedShare, isTrue);
    });

    test('还在导航 → 照常启动，只多花一次探测', () async {
      final ok = await navi.start('https://surl.amap.com/abc');
      expect(ok, isTrue);
      expect(navi.state, NaviState.locating);
      expect(client.naviStatusCalls, 1, reason: '活着就一次问清，不必凑确认');
      expect(navi.lastStartEndedShare, isFalse);

      await feedDistance(300);
      expect(navi.state, NaviState.navigating);
    });

    test('行前 status=1（分享中、还没开始导航）不算结束，照常启动', () async {
      client.naviShareStatus = null;
      client.beforeStatus = 1;
      expect(await navi.start('https://surl.amap.com/abc'), isTrue);
      expect(navi.state, NaviState.locating);
    });

    test('探测失败 → fail-open 照常启动（探测不到 ≠ 已停止）', () async {
      client.statusError = Exception('boom');
      expect(await navi.start('https://surl.amap.com/abc'), isTrue);
      expect(navi.state, NaviState.locating);
      expect(navi.lastStartEndedShare, isFalse);
      expect(navi.statusProbeFailureCount, 1);
    });

    test('关掉分享状态心跳 → 不做行前自检（同一开关管两件事）', () async {
      SharedPreferences.setMockInitialValues(
          {'settings_navi_shareStatusWatchOn': false});
      final settings = SettingsProvider();
      await settings.init();
      navi.updateSettings(settings);

      client.naviShareStatus = 5; // 已结束，但自检被关掉
      expect(await navi.start('https://surl.amap.com/abc'), isTrue);
      expect(navi.state, NaviState.locating);
      expect(client.naviStatusCalls, 0);
    });

    test('naviStopOnShareEnd=false：已结束也照常启动，只提示"已停止"', () async {
      SharedPreferences.setMockInitialValues(
          {'settings_navi_stopOnShareEnd': false});
      final settings = SettingsProvider();
      await settings.init();
      navi.updateSettings(settings);

      client.naviShareStatus = 5;
      expect(await navi.start('https://surl.amap.com/abc'), isTrue,
          reason: '用户明确选了"高德停了也继续导航"，不该被自检拦下');
      expect(navi.state, NaviState.locating);
      expect(navi.lastStartEndedShare, isFalse);
      expect(navi.shareStoppedHint, isTrue, reason: '但卡片要如实提示');
    });
  });
}

// ---------------------------------------------------------------------------
// 测试替身与工具
// ---------------------------------------------------------------------------

class _FakeShareClient extends AmapShareClient {
  _FakeShareClient(this.route);

  AmapRoute route;
  AmapRoute? routeOverride;
  String? expireCode;
  Object? routeError;
  Object? linkError;
  int fetchCount = 0;

  // ----- 分享状态（判断"高德那边是否已停止导航"）-----

  /// 行中 `data.shareInfo.shareStatus`；null = 字段缺失（归一为 unknown）
  int? naviShareStatus = 1;

  /// 行前 `data.status`；null = 解析不到
  int? beforeStatus = 4;

  /// 行前顶层 code（"1" / "10001" / "2"）
  String beforeCode = '1';

  /// 非空时两个状态端点都抛异常（模拟网络/传输层失败）
  Object? statusError;

  /// 非空时状态探测会先在此 future 上等待：模拟"探测 in-flight"（P0-2 / P0-3 用例）。
  Completer<void>? statusGate;

  int naviStatusCalls = 0;
  int beforeStatusCalls = 0;

  /// 每次行中探测的**调用时刻**，供"复核间隔 < 心跳周期"断言用。
  final List<DateTime> naviStatusTimes = [];

  /// 每次 `resolveParam` 都给出不同值：真实场景里"重贴短链"就是换了一条分享，
  /// 只有 param 会变，才能守住"旧会话的迟到探测不打在新会话上"（P0-3）。
  int _paramSeq = 0;

  AmapRoute get _route => routeOverride ?? route;

  @override
  Future<String> resolveParam(String shareUrl) async {
    if (linkError != null) throw linkError!;
    return 'param-test-${++_paramSeq}';
  }

  @override
  Future<RouteEnvelope> fetchRoute(String param) async {
    fetchCount++;
    if (routeError != null) throw routeError!;
    return RouteEnvelope(
      code: expireCode ?? '1',
      result: true,
      message: 'Successful.',
      naviType: 9,
      route: _route,
    );
  }

  @override
  Future<ShareInfoEnvelope> probeNaviStatus(String param) async {
    naviStatusCalls++;
    naviStatusTimes.add(DateTime.now());
    final gate = statusGate;
    if (gate != null) await gate.future; // 模拟"探测还挂在网络上"
    if (statusError != null) throw statusError!;
    return ShareInfoEnvelope(
      result: true,
      code: '1',
      message: 'Successful.',
      shareStatus: naviShareStatus,
      members: const [],
    );
  }

  @override
  Future<ShareStatusEnvelope> fetchShareStatus(String param) async {
    beforeStatusCalls++;
    final gate = statusGate;
    if (gate != null) await gate.future;
    if (statusError != null) throw statusError!;
    return ShareStatusEnvelope(
      result: beforeCode == '1',
      code: beforeCode,
      message: 'Successful.',
      status: beforeStatus,
      safeReportParameter: null,
    );
  }

  /// 触发一次与定时器等价的路线刷新（避免测试里真等 10 秒）
  Future<void> triggerRefreshVia(NaviProvider navi) async {
    navi.debugRefreshRouteNow();
    await pumpEventQueue();
  }
}

/// 沿合成路线取里程 d 处的 GCJ-02 坐标
class _RouteCoord {
  static (double, double) at(
    NaviProvider navi,
    AmapRoute route,
    double d, {
    double offsetMeters = 0,
  }) {
    final analyzer = navi.debugAnalyzer!;
    final p = analyzer.coordAt(d);
    if (offsetMeters == 0) return (p.lat, p.lon);
    // 向北平移 offsetMeters（纬度方向 1° ≈ 110540m）
    return (p.lat + offsetMeters / 110540.0, p.lon);
  }
}

/// GCJ-02 → WGS-84 反算（迭代 3 次，用于构造 GPS 原始输入）
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

/// U 形往返路线：去程沿正东、回程在正北 [gapMeters] 处的平行线上折返。
///
/// 去程里程 d 与回程里程 `2*legLength - d` 在地面上只差 `gapMeters`
/// （默认 18m，与实测样本 d=220↔400 的 18.2m 同量级），用于复现
/// "主辅路 / 立交上下匝道"造成的投影歧义。
AmapRoute _doubleBackRoute({int legLength = 300, double gapMeters = 18}) {
  const metersPerLon = 111320.0 * 0.766; // cos(40°)
  const metersPerLat = 110540.0;
  const lat = 40.0;
  const lon = 116.30;
  final dLon = legLength / metersPerLon;
  final dLat = gapMeters / metersPerLat;

  Map<String, Object?> link(int begin, int end, int roadNameIndex) => {
        'link_index': 0,
        'length': legLength,
        'begin_index': begin,
        'end_index': end,
        'travel_time': 30,
        'road_name_index': roadNameIndex,
      };

  return AmapRoute({
    'roads_names': [
      {'road_name': '去程路'},
      {'road_name': '回程路'},
    ],
    'paths': [
      {
        'path_index': 0,
        'distance': legLength * 2,
        'travel_time': 60,
        'coords': [
          {'lon': lon, 'lat': lat},
          {'lon': lon + dLon, 'lat': lat},
          {'lon': lon + dLon, 'lat': lat + dLat},
          {'lon': lon, 'lat': lat + dLat},
        ],
        'segments': [
          {
            'segment_index': 0,
            'main_action': 2, // 右转，去程段末（300m）
            'links': [link(0, 1, 0)],
          },
          {
            'segment_index': 1,
            'main_action': 8, // 直行，回程段末（600m）
            'links': [link(2, 3, 1)],
          },
        ],
        'status': [],
        'group': [],
      },
    ],
  });
}

/// 生成沿正东方向的直线路线：每个 spec 一段、一段一条 link。
///
/// 声明的 link.length 是权威里程（`RouteAnalyzer` 用它做累计），
/// 几何点只用于 `coordAt` 插值，因此直线即可精确复现里程。
AmapRoute _straightRoute(
  List<({int action, int length})> specs, {
  List<
          ({
            double lon,
            double lat,
            int segmentIndex,
            int linkIndex,
            int speed,
          })>
      cameras = const [],
  List<int> lightSegmentIndexes = const [],
}) {
  const metersPerLon = 111320.0 * 0.766; // cos(40°)
  const lat = 40.0;
  final coords = <Map<String, Object?>>[
    {'lon': 116.30, 'lat': lat},
  ];
  final segments = <Map<String, Object?>>[];
  var lon = 116.30;
  var total = 0;

  for (var i = 0; i < specs.length; i++) {
    final spec = specs[i];
    lon += spec.length / metersPerLon;
    coords.add({'lon': lon, 'lat': lat});
    segments.add({
      'segment_index': i,
      'main_action': spec.action,
      'links': [
        {
          'link_index': 0,
          'length': spec.length,
          'begin_index': i,
          'end_index': i + 1,
          'travel_time': (spec.length / 10).round(),
          'road_name_index': 0,
          'has_traffic_light': lightSegmentIndexes.contains(i) ? 1 : 0,
        },
      ],
    });
    total += spec.length;
  }

  return AmapRoute({
    'roads_names': [
      {'road_name': '测试路'},
    ],
    'facilities': {
      'cameras': [
        for (final c in cameras)
          {
            'path_index': 0,
            'segment_index': c.segmentIndex,
            'link_index': c.linkIndex,
            'lon': c.lon,
            'lat': c.lat,
            'type': 0, // 0 = 带限速值的测速点
            'speed': c.speed,
          },
      ],
    },
    'paths': [
      {
        'path_index': 0,
        'distance': total,
        'travel_time': (total / 10).round(),
        'coords': coords,
        'segments': segments,
        'status': [
          {'traffic_state': 1, 'len': total},
        ],
        'group': [
          {'name': '测试路', 'dist': total, 'start_id': 0, 'count': 1},
        ],
      },
    ],
  });
}
