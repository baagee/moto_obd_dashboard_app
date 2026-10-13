import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obd_dashboard/providers/log_provider.dart';
import 'package:obd_dashboard/providers/obd_data_provider.dart';
import 'package:obd_dashboard/providers/riding_stats_provider.dart';
import 'package:obd_dashboard/providers/settings_provider.dart';
import 'package:obd_dashboard/widgets/track_radar_card.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// [TrackRadarCard] 扫描动画按骑行状态启停的回归测试。
///
/// 背景（性能优化）：雷达的 4 秒循环扫描动画此前在 `initState` 就永久
/// `repeat()`，未骑行（STANDBY）时也常驻 60fps 重绘。改动后动画应跟随
/// `RidingStatsProvider.isRiding` 启停：未骑行时零 ticker 开销，开始骑行后
/// 立即恢复。
///
/// 用 [_FakeRidingStatsProvider] 覆盖 `isRiding` getter 直接切换状态，
/// 不经过真实 `startRide()`/`endRide()`（会触发定位/数据库插件调用，
/// 测试环境无平台通道 mock，容易遗留未清理的 Timer）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeRidingStatsProvider stats;
  late OBDDataProvider obd;
  late SettingsProvider settings;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    obd = OBDDataProvider();
    stats = _FakeRidingStatsProvider(
      obdDataProvider: obd,
      logProvider: LogProvider(),
    );
    settings = SettingsProvider();
    await settings.init();
  });

  Widget harness() {
    return MaterialApp(
      home: MultiProvider(
        providers: [
          ChangeNotifierProvider<OBDDataProvider>.value(value: obd),
          ChangeNotifierProvider<RidingStatsProvider>.value(value: stats),
          ChangeNotifierProvider<SettingsProvider>.value(value: settings),
        ],
        child: const Scaffold(
          body: SizedBox(width: 300, height: 200, child: TrackRadarCard()),
        ),
      ),
    );
  }

  testWidgets('未骑行（STANDBY）时扫描动画不排帧，零 ticker 开销', (tester) async {
    stats.ridingForTest = false;
    await tester.pumpWidget(harness());
    await tester.pump();

    // 推进超过一个完整动画周期（4s），没有待处理的 transient 帧回调即代表
    // AnimationController 处于停止态，不会每帧触发 markNeedsPaint。
    await tester.pump(const Duration(seconds: 5));
    expect(
      SchedulerBinding.instance.transientCallbackCount,
      0,
      reason: '未骑行时雷达扫描动画应已停止，不应再排帧',
    );
  });

  testWidgets('开始骑行后扫描动画立即恢复排帧', (tester) async {
    stats.ridingForTest = false;
    await tester.pumpWidget(harness());
    await tester.pump();
    expect(SchedulerBinding.instance.transientCallbackCount, 0);

    stats.ridingForTest = true;
    await tester.pump();

    expect(
      SchedulerBinding.instance.transientCallbackCount,
      greaterThan(0),
      reason: '开始骑行后应恢复扫描动画，排上下一帧回调',
    );
  });

  testWidgets('骑行结束后扫描动画再次停止', (tester) async {
    stats.ridingForTest = true;
    await tester.pumpWidget(harness());
    await tester.pump();
    expect(SchedulerBinding.instance.transientCallbackCount, greaterThan(0));

    stats.ridingForTest = false;
    await tester.pump();

    expect(
      SchedulerBinding.instance.transientCallbackCount,
      0,
      reason: '骑行结束后应停止扫描动画，不再常驻重绘',
    );
  });
}

/// 测试替身：覆盖 [RidingStatsProvider.isRiding]，绕开真实
/// `startRide()`/`endRide()` 的定位 / 数据库副作用。
class _FakeRidingStatsProvider extends RidingStatsProvider {
  bool _riding = false;

  _FakeRidingStatsProvider({
    required super.obdDataProvider,
    required super.logProvider,
  });

  @override
  bool get isRiding => _riding;

  set ridingForTest(bool value) {
    _riding = value;
    notifyListeners();
  }
}
