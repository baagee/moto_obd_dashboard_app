import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obd_dashboard/providers/navigation_provider.dart';
import 'package:obd_dashboard/screens/main_container.dart';
import 'package:provider/provider.dart';

/// [TickerModeBoundPage] 回归测试（主容器切 Tab 时暂停仪表盘动画）。
///
/// 背景（性能优化）：PageView 用 AutomaticKeepAliveClientMixin 保持仪表盘页
/// 挂载，切到其他 Tab 时其内部的 AnimationController（雷达扫描、呼吸动画等）
/// 此前仍在离屏跑 60fps。包一层 [TickerModeBoundPage] 后，`currentIndex`
/// 不等于目标页时 `TickerMode.enabled = false`，页面内子树的 ticker 应整体
/// 挂起；切回来自动恢复。
///
/// 用一个自带 AnimationController 的最小 Widget 代替真实 DashboardScreen，
/// 不拖带蓝牙/定位/数据库等重依赖，只验证 TickerMode 的开关效果本身。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('非当前页：子树动画不排帧；切回当前页：立即恢复', (tester) async {
    final nav = NavigationProvider();

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<NavigationProvider>.value(
          value: nav,
          child: const Scaffold(
            body: TickerModeBoundPage(
              pageIndex: 0,
              child: _RepeatingAnimationProbe(),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    // 初始 currentIndex == 0 == pageIndex，动画应在跑
    expect(SchedulerBinding.instance.transientCallbackCount, greaterThan(0));

    // 切到其他 Tab（index=1）：子树应整体挂起，零 ticker 开销
    nav.setIndex(1);
    await tester.pump();
    expect(
      SchedulerBinding.instance.transientCallbackCount,
      0,
      reason: '离屏页的动画应被 TickerMode 挂起，不应再排帧',
    );

    // 切回当前页（index=0）：动画自动恢复，不需要手动重启
    nav.setIndex(0);
    await tester.pump();
    expect(
      SchedulerBinding.instance.transientCallbackCount,
      greaterThan(0),
      reason: '切回当前页后动画应自动恢复排帧',
    );
  });
}

/// 最小化的"常驻 repeat() 动画"探针，模拟雷达/呼吸动画的 ticker 行为。
class _RepeatingAnimationProbe extends StatefulWidget {
  const _RepeatingAnimationProbe();

  @override
  State<_RepeatingAnimationProbe> createState() =>
      _RepeatingAnimationProbeState();
}

class _RepeatingAnimationProbeState extends State<_RepeatingAnimationProbe>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => const SizedBox.shrink(),
    );
  }
}
