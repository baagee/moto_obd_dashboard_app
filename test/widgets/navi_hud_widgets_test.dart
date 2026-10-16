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
import 'package:obd_dashboard/theme/app_theme.dart';
import 'package:obd_dashboard/widgets/navi_card.dart';
import 'package:obd_dashboard/widgets/navi_hud_banner.dart';
import 'package:obd_dashboard/widgets/navi_turn_arrow.dart';
import 'package:provider/provider.dart';

/// 导航 HUD 两个新组件的**布局/渲染**冒烟测试
///
/// 关注三件容易在真机上才暴露的事：
/// 1. 未导航时通栏高度为零（非导航态零占位）
/// 2. 展开时通栏高度等于方案规定的 72px（并且不出现 overflow）
/// 3. 第三列被压缩到 196px 时导航卡等比缩小、不裁切
///
/// 说明：`testWidgets` 使用 FakeAsync 时钟，因此**不能**用 `pumpEventQueue`
/// 等待流事件，必须用 `tester.pump()` 推进帧；每个用例结束前显式 `stop()`
/// 释放 NaviProvider 的定时器，避免"Timer still pending"。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeShareClient client;
  late OBDDataProvider obd;
  late StreamController<Position> positions;
  late NaviProvider navi;

  setUp(() {
    obd = OBDDataProvider()..updateRealTimeData(speed: 80);
    positions = StreamController<Position>.broadcast();
    client = _FakeShareClient();
    navi = NaviProvider(
      obdDataProvider: obd,
      logProvider: LogProvider(),
      client: client,
      positionStreamFactory: () => positions.stream,
      // 测试环境没有平台插件：显式给出"权限已授、即时定位为空"
      locationGate: () async => LocationPermissionStatus.granted,
      firstFixProvider: () async => null,
      // 本文件断言的是**布局**（高度 72px、不 overflow）与固定距离文案
      // （"剩余 100 米"）。里程平滑会让距离随 pump 的时间前进（350ms → 96 米），
      // 所以这里把平滑心跳冻到 1 小时；平滑行为本身由
      // `test/providers/navi_provider_test.dart` 的「里程平滑」组覆盖。
      smoothTickPeriod: const Duration(hours: 1),
    );
    addTearDown(() async {
      await navi.stop();
      navi.dispose();
      await positions.close();
    });
  });

  /// 建树。
  ///
  /// [loose] 为 true 时给子组件**松约束**（让它按自身内容决定高度，用于验证
  /// 通栏 0 / 72px 的折叠行为）；为 false 时给紧约束（模拟真实三栏槽位，
  /// 用于验证导航卡在固定槽位内不溢出）。
  Future<void> mount(
    WidgetTester tester,
    Widget child, {
    Size size = const Size(834, 244),
    bool loose = false,
    NaviProvider? provider,
  }) {
    return tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: ChangeNotifierProvider<NaviProvider>.value(
            value: provider ?? navi,
            child: Center(
              child: SizedBox(
                width: size.width,
                height: size.height,
                child: loose
                    ? Align(alignment: Alignment.topCenter, child: child)
                    : child,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 开始导航并建树
  Future<void> startAndMount(
    WidgetTester tester,
    Widget child, {
    Size size = const Size(834, 244),
    bool loose = false,
    NaviProvider? provider,
  }) async {
    await (provider ?? navi).start('https://surl.amap.com/a');
    await mount(tester, child, size: size, loose: loose, provider: provider);
  }

  /// 喂入"沿路线里程 d、向北偏移 offsetMeters"处的 GPS（WGS-84）并推进一帧
  ///
  /// [provider] 默认用共享的 [navi]；用例自建 provider 时要显式传入（坐标取自
  /// 它自己的 analyzer）。
  Future<void> feed(
    WidgetTester tester,
    double d, {
    double offsetMeters = 0,
    NaviProvider? provider,
  }) async {
    final gcj = (provider ?? navi).debugAnalyzer!.coordAt(d);
    final wgs = _gcjToWgs(gcj.lat + offsetMeters / 110540.0, gcj.lon);
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
    await tester.pump(); // 交付 stream 事件
    await tester.pump(); // 让 provider 通知引发的重建落地
  }

  /// `testWidgets` 包装：用例结束前强制 `stop()`。
  ///
  /// `addTearDown` 在框架的"Timer still pending"不变式校验**之后**才执行，
  /// 因此定时器必须在用例体内就释放。
  void naviTestWidgets(
    String description,
    Future<void> Function(WidgetTester tester) body,
  ) {
    testWidgets(description, (tester) async {
      try {
        await body(tester);
      } finally {
        await navi.stop();
      }
    });
  }

  group('NaviHudBanner', () {
    naviTestWidgets('未导航：高度为 0，零占位', (tester) async {
      await mount(tester, const NaviHudBanner(), loose: true);
      await tester.pump(const Duration(milliseconds: 350));
      expect(tester.getSize(find.byType(NaviHudBanner)).height, 0);
      expect(tester.takeException(), isNull);
    });

    naviTestWidgets('导航中但未进 8 秒窗口：仍为 0', (tester) async {
      await startAndMount(tester, const NaviHudBanner(), loose: true);
      await feed(tester, 300); // 段末动作在 600m → 13.5s
      await tester.pump(const Duration(milliseconds: 350));
      expect(navi.bannerExpanded, isFalse);
      expect(tester.getSize(find.byType(NaviHudBanner)).height, 0);
    });

    naviTestWidgets('临近路口：展开到 72px，显示距离 / 动作名 / 路线', (tester) async {
      await startAndMount(tester, const NaviHudBanner(), loose: true);
      await feed(tester, 500); // 段末动作在 600m → 4.5s，进入 8 秒窗口
      expect(navi.bannerExpanded, isTrue);

      // AnimatedSize 需要"承接变化的那一帧 + 一个时间片"才走完折叠动画
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump(const Duration(milliseconds: 50));

      expect(tester.getSize(find.byType(NaviHudBanner)).height,
          closeTo(NaviHudBanner.expandedHeight, 1.0));
      expect(find.text('100'), findsOneWidget); // 剩余距离 600-500
      // 动作名与路线合并为一行 RichText（横屏空间充足）
      expect(find.textContaining('直行', findRichText: true), findsOneWidget);
      expect(find.textContaining('测试路', findRichText: true), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });

  group('NaviCard', () {
    naviTestWidgets('未导航：不渲染任何导航文案', (tester) async {
      await mount(tester, const NaviCard(), size: const Size(212, 244));
      expect(find.textContaining('导航'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    naviTestWidgets('导航中：亮度可控的底图 + 动作条 + 指标条，标准高度不溢出', (tester) async {
      await startAndMount(tester, const NaviCard(), size: const Size(212, 244));
      await feed(tester, 500);
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('导航中'), findsOneWidget);
      // ② 底图区域存在且足够高（可读性下限；v2.1 起为卡片内最大的一块）
      final mapSize = tester.getSize(find.byKey(NaviCard.mapKey));
      expect(mapSize.height, greaterThanOrEqualTo(100),
          reason: '244px 槽位下底图应占 ~120px（进度条移除后空间进一步让给底图，仍是卡片内最大的一块）');
      expect(mapSize.width, greaterThan(150));
      // ③ 下一个动作条：在地图**下方**（独立元素，不再覆盖在地图上）
      expect(find.text('100'), findsOneWidget);
      expect(find.text('米'), findsOneWidget);
      expect(find.text('直行'), findsOneWidget);
      final arrow = tester.widget<NaviTurnArrow>(find.byType(NaviTurnArrow));
      expect(arrow.size, lessThan(48), reason: '转向箭头从旧的 88px 居中主体降为动作条内的小尺寸元素');
      expect(arrow.size, greaterThan(30));
      final mapRect = tester.getRect(find.byKey(NaviCard.mapKey));
      final arrowRect = tester.getRect(find.byType(NaviTurnArrow));
      expect(arrowRect.top, greaterThan(mapRect.bottom),
          reason: '动作条必须在地图区域之下，不与其争同一块矩形');
      // ⑤ 指标条在最底部
      final metricRect = tester.getRect(find.text('剩余里程'));
      expect(metricRect.top, greaterThan(arrowRect.bottom));
      expect(tester.takeException(), isNull);
    });

    naviTestWidgets('指标条四列各自独立渲染（不再单行拼接截断）', (tester) async {
      await startAndMount(tester, const NaviCard(), size: const Size(212, 244));
      await feed(tester, 500);
      await tester.pump(const Duration(milliseconds: 100));

      // 四列标签齐备
      expect(find.text('剩余里程'), findsOneWidget);
      expect(find.text('剩余时间'), findsOneWidget);
      expect(find.text('红绿灯'), findsOneWidget);
      expect(find.text('总里程'), findsOneWidget);
      final metricLabel = tester.widget<Text>(find.text('剩余里程'));
      final metricValue = tester.widget<Text>(find.text('1.5 km'));
      expect(metricLabel.style!.fontSize, 11);
      expect(metricValue.style!.fontSize, 14);
      expect(metricLabel.style!.color, AppTheme.dashboardLabel);
      // 值：剩余里程 1.5 km（2000-500）
      expect(find.text('1.5 km'), findsOneWidget);
      // 总里程 = 路线全长 2.0 km（样本 totalDistance=2000）
      expect(find.text('2.0 km'), findsOneWidget);
      // 剩余时间默认为"预计到达时刻"：HH:mm
      expect(
        find.byWidgetPredicate((w) =>
            w is Text &&
            w.data != null &&
            RegExp(r'^\d{2}:\d{2}$').hasMatch(w.data!)),
        findsOneWidget,
      );
      // 旧版"单行拼接"形态不复存在
      expect(find.textContaining('剩余 1.5 km · '), findsNothing);
      expect(tester.takeException(), isNull);
    });

    naviTestWidgets('通栏展开把第三列压到 196px：底图仍有可读高度且不溢出', (tester) async {
      await startAndMount(tester, const NaviCard(), size: const Size(196, 196));
      await feed(tester, 500);
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('导航中'), findsOneWidget);
      expect(tester.getSize(find.byKey(NaviCard.mapKey)).height,
          greaterThanOrEqualTo(72),
          reason: '通栏展开把第三列压到 196px 时底图仍应 ≥72px（下方区块已整体加大）');
      // 压缩后指标条仍然完整可读
      expect(find.text('剩余里程'), findsOneWidget);
      expect(find.text('总里程'), findsOneWidget);
      final metricLabel = tester.widget<Text>(find.text('剩余里程'));
      final metricValue = tester.widget<Text>(find.text('1.5 km'));
      expect(metricLabel.style!.fontSize, 11);
      expect(metricValue.style!.fontSize, 14);
      expect(tester.takeException(), isNull,
          reason: '244 → 196 压缩后不得 overflow');
    });

    naviTestWidgets('E0 缺少定位权限：标题说实话，整卡可点去系统设置', (tester) async {
      final denied = NaviProvider(
        obdDataProvider: obd,
        logProvider: LogProvider(),
        client: client,
        positionStreamFactory: () => positions.stream,
        locationGate: () async => LocationPermissionStatus.deniedForever,
        firstFixProvider: () async => null,
      );
      try {
        await startAndMount(tester, const NaviCard(),
            size: const Size(212, 244), provider: denied);
        await tester.pump(const Duration(milliseconds: 100));

        expect(denied.gpsIssue, NaviGpsIssue.deniedForever);
        // 不能只显示"定位中…"让用户干等
        expect(find.textContaining('没有定位权限'), findsOneWidget);
        expect(find.text('NO GPS'), findsOneWidget);
        final gd = find.descendant(
          of: find.byType(NaviCard),
          matching: find.byType(GestureDetector),
        );
        expect(
          tester.widgetList<GestureDetector>(gd).any((g) => g.onTap != null),
          isTrue,
          reason: '缺权限时应整卡可点，直达系统设置',
        );
        expect(tester.takeException(), isNull);
      } finally {
        await denied.stop();
        denied.dispose();
      }
    });

    naviTestWidgets('E4 高德那边停止导航：静默收尾，卡片消失回默认面板', (tester) async {
      final local = NaviProvider(
        obdDataProvider: obd,
        logProvider: LogProvider(),
        client: client,
        positionStreamFactory: () => positions.stream,
        locationGate: () async => LocationPermissionStatus.granted,
        firstFixProvider: () async => null,
        smoothTickPeriod: const Duration(hours: 1),
      );
      try {
        await startAndMount(tester, const NaviCard(),
            size: const Size(212, 244), provider: local);
        await feed(tester, 300, provider: local);
        await tester.pump(const Duration(milliseconds: 50));
        expect(local.state, NaviState.navigating);

        // 导航**中途**高德那边停了（行前自检只在刚粘贴时跑，这里必须后置）
        client.naviShareStatus = 5;

        // 单次不收尾（防后端节点抖动），连续两次才收尾
        await local.debugStatusProbeNow();
        await tester.pump(const Duration(milliseconds: 20));
        expect(local.state, NaviState.navigating);
        await local.debugStatusProbeNow();
        await tester.pump(const Duration(milliseconds: 20));

        expect(local.state, NaviState.off);
        expect(local.hasSession, isFalse, reason: '第三列应回默认的轨迹雷达卡');
        expect(local.isActive, isFalse);
        // 不再有任何"导航已结束"终态卡（标题、副文案、"重贴"入口都不该出现）
        expect(find.text('导航已结束'), findsNothing);
        expect(find.text('高德那边已停止导航'), findsNothing);
        expect(find.text('分享链接已失效'), findsNothing);
        expect(find.textContaining('导航'), findsNothing);
        expect(tester.takeException(), isNull);
      } finally {
        await local.stop();
        local.dispose();
      }
    });

    naviTestWidgets('W2 自动复核也能收尾：探测一次后由复核定时器收尾，无残留', (tester) async {
      final local = NaviProvider(
        obdDataProvider: obd,
        logProvider: LogProvider(),
        client: client,
        positionStreamFactory: () => positions.stream,
        locationGate: () async => LocationPermissionStatus.granted,
        firstFixProvider: () async => null,
        smoothTickPeriod: const Duration(hours: 1),
        // 复核间隔注入 20ms（FakeAsync 下由 tester.pump 精确推进，不会等真实 3s）
        confirmProbePeriod: const Duration(milliseconds: 20),
      );
      try {
        await startAndMount(tester, const NaviCard(),
            size: const Size(212, 244), provider: local);
        await feed(tester, 300, provider: local);
        await tester.pump(const Duration(milliseconds: 50));
        expect(local.state, NaviState.navigating);

        client.naviShareStatus = 5; // 导航中途高德那边停了

        // 只探一次：第二次交给 20ms 复核定时器，不手动探测
        await local.debugStatusProbeNow();
        expect(local.debugConfirmProbePending, isTrue);

        await tester.pump(const Duration(milliseconds: 20));
        await tester.pump();
        expect(local.debugConfirmProbePending, isFalse, reason: '复核应已跑完并撤销');
        expect(local.state, NaviState.off);
        expect(local.hasSession, isFalse, reason: '第三列回默认面板');
        // 无 pending timer：naviTestWidgets 的 finally + 框架不变式会替我们再确认一次
      } finally {
        await local.stop();
        local.dispose();
      }
    });

    naviTestWidgets('行前自检：粘贴时分享已结束 → 卡片根本不被拉起', (tester) async {
      client.naviShareStatus = 5; // 刚粘贴时高德那边就已经停了
      final local = NaviProvider(
        obdDataProvider: obd,
        logProvider: LogProvider(),
        client: client,
        positionStreamFactory: () => positions.stream,
        locationGate: () async => LocationPermissionStatus.granted,
        firstFixProvider: () async => null,
        smoothTickPeriod: const Duration(hours: 1),
      );
      try {
        final ok = await local.start('https://surl.amap.com/a');
        expect(ok, isFalse);
        await mount(tester, const NaviCard(),
            size: const Size(212, 244), provider: local);
        await tester.pump(const Duration(milliseconds: 100));

        expect(local.state, NaviState.off);
        expect(local.hasSession, isFalse);
        expect(local.lastStartEndedShare, isTrue);
        // 关键：不是"显示了一张已结束的卡"，而是**根本没有卡片** ——
        // 用户回到默认的轨迹雷达面板，不需要知道曾经有过一条已结束的分享。
        expect(find.textContaining('导航'), findsNothing);
        expect(find.text('高德那边已停止导航'), findsNothing);
        expect(find.text('导航已结束'), findsNothing);
        expect(find.text('分享链接已失效'), findsNothing);
        expect(tester.takeException(), isNull);
      } finally {
        await local.stop();
        local.dispose();
      }
    });

    naviTestWidgets('E1 定位中：底图先给出，动作距离显示 --', (tester) async {
      await startAndMount(tester, const NaviCard(), size: const Size(212, 244));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('定位中'), findsOneWidget);
      expect(find.text('--'), findsWidgets);
      // 无定位也要有底图（来自路线起点）
      expect(tester.getSize(find.byKey(NaviCard.mapKey)).height,
          greaterThanOrEqualTo(80));
      expect(tester.takeException(), isNull);
    });

    naviTestWidgets('E2 偏离路线：进入偏离态并给出可见提示', (tester) async {
      await startAndMount(tester, const NaviCard(), size: const Size(212, 244));
      await feed(tester, 300);
      for (final d in [310.0, 320.0, 340.0]) {
        await feed(tester, d, offsetMeters: 220);
      }
      expect(navi.state, NaviState.deviated);

      await tester.pump(const Duration(milliseconds: 100));
      expect(find.textContaining('已偏离'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    naviTestWidgets('E2b 确认拿不到新路线：不再谎称"重新规划中"，改为可点重贴', (tester) async {
      await startAndMount(tester, const NaviCard(), size: const Size(212, 244));
      await feed(tester, 300);
      for (final d in [310.0, 320.0, 340.0]) {
        await feed(tester, d, offsetMeters: 220);
      }
      // 假 client 每次都返回同一条路线（分享链接是快照）→ 重拉必然拿不到新路线
      expect(navi.state, NaviState.deviated);
      expect(navi.replanFailed, isTrue);
      expect(navi.routeUnchangedCount, greaterThan(0));

      await tester.pump(const Duration(milliseconds: 100));
      expect(find.textContaining('重新规划中'), findsNothing,
          reason: '分享链接是快照，重新规划不可能成功，界面不能说谎');
      expect(find.textContaining('点此重新粘贴短链'), findsOneWidget);

      // 整卡可点 → 打开粘贴弹窗（唯一可行的脱困出口）
      final gd = find.descendant(
        of: find.byType(NaviCard),
        matching: find.byType(GestureDetector),
      );
      expect(gd, findsWidgets);
      expect(tester.widgetList<GestureDetector>(gd).any((g) => g.onTap != null),
          isTrue,
          reason: '偏离且无法重新规划时整卡应可点');
      expect(tester.takeException(), isNull);
    });

    naviTestWidgets('E3 分享失效：静默收尾，卡片消失回默认面板', (tester) async {
      client.expireCode = '3';
      await startAndMount(tester, const NaviCard(), size: const Size(212, 244));
      await tester.pump(const Duration(milliseconds: 100));

      expect(navi.state, NaviState.off);
      expect(navi.hasSession, isFalse);
      expect(navi.errorMessage, contains('分享链接已失效'),
          reason: '原因留给日志 / 粘贴弹窗，界面上不出现');
      expect(find.text('导航已结束'), findsNothing);
      expect(find.text('分享链接已失效'), findsNothing);
      expect(find.text('点击此处重新粘贴短链'), findsNothing);
      expect(find.textContaining('导航'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}

/// GCJ-02 → WGS-84 反算（迭代 3 次），用于构造 GPS 原始输入
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

/// 假 client：0..600m 段末为直行、600..2000m 段末为左转
class _FakeShareClient extends AmapShareClient {
  String? expireCode;

  /// 行中 `shareStatus`（1 = 仍在分享；5/6/7 = 已停止 → 触发 E4「导航已结束」）
  int? naviShareStatus = 1;

  @override
  Future<String> resolveParam(String shareUrl) async => 'param-test';

  // 显式实现两个状态端点：即便某个用例把时间推过心跳周期，也绝不会打到真实网络
  @override
  Future<ShareInfoEnvelope> probeNaviStatus(String param) async =>
      ShareInfoEnvelope(
        result: true,
        code: '1',
        message: 'Successful.',
        shareStatus: naviShareStatus,
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
        code: expireCode ?? '1',
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
                  'main_action': 8,
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
                  'main_action': 1,
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
