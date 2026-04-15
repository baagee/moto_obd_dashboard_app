import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../providers/obd_data_provider.dart';
import '../widgets/combined_gauge_card.dart';
import '../widgets/side_stats_panel.dart';
import '../widgets/telemetry_chart_card.dart';
import '../widgets/riding_events_panel.dart';
import '../widgets/self_check_overlay.dart';
import '../widgets/gauges/classic_gauge_widget.dart';

/// 主仪表盘屏幕
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with AutomaticKeepAliveClientMixin {
  /// 控制自检覆盖层是否显示，APP启动后只播放一次
  bool _showSelfCheck = true;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixin 要求

    final gaugeStyle = context.select<SettingsProvider, String>(
      (s) => s.gaugeStyle,
    );
    final maxRpm = context.select<SettingsProvider, int>((s) => s.maxRpm);
    final warnRpm = context.select<SettingsProvider, int>((s) => s.warnRpm);
    final dangerRpm =
        context.select<SettingsProvider, int>((s) => s.dangerRpm);
    final maxSpeed = context.select<SettingsProvider, int>((s) => s.maxSpeed);
    final warnSpeed =
        context.select<SettingsProvider, int>((s) => s.warnSpeed);
    final dangerSpeed =
        context.select<SettingsProvider, int>((s) => s.dangerSpeed);

    return Container(
      color: Colors.transparent,
      child: Stack(
        children: [
          // ── 底层：根据风格切换布局 ──
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: gaugeStyle == 'classic'
                ? const ClassicDashboardLayout(key: ValueKey('classic'))
                : const _CyberpunkLayout(key: ValueKey('cyberpunk')),
          ),

          // ── 顶层：自检动画覆盖层（仅首次，仅赛博朋克风格） ──
          if (_showSelfCheck && gaugeStyle != 'classic')
            SelfCheckOverlay(
              onComplete: () {
                if (mounted) setState(() => _showSelfCheck = false);
              },
              maxRpm: maxRpm,
              warnRpm: warnRpm,
              dangerRpm: dangerRpm,
              maxSpeed: maxSpeed,
              warnSpeed: warnSpeed,
              dangerSpeed: dangerSpeed,
            ),
        ],
      ),
    );
  }
}

/// 赛博朋克三栏布局（原有布局提取）
class _CyberpunkLayout extends StatelessWidget {
  const _CyberpunkLayout({super.key});

  @override
  Widget build(BuildContext context) {
    // 确保 OBDDataProvider 被监听（原布局中子组件各自 select，此处保持原样）
    return const Padding(
      padding: EdgeInsets.all(8),
      child: Row(
        children: [
          // 第一列：车辆状态参数 (2/9)
          Expanded(
            flex: 2,
            child: SideStatsPanel(),
          ),

          SizedBox(width: 8),

          // 第二列：组合仪表盘（转速+时速合并为一个完整圆）(4/9)
          Expanded(
            flex: 4,
            child: CombinedGaugeCard(),
          ),

          SizedBox(width: 8),

          // 第三列：遥测图表和骑行事件（上下排列，1:2比例）(3/9)
          Expanded(
            flex: 3,
            child: Column(
              children: [
                // 上半部分：实时遥测折线图（1/3）
                Expanded(
                  flex: 1,
                  child: TelemetryChartCard(),
                ),

                SizedBox(height: 8),

                // 下半部分：骑行事件（2/3）
                Expanded(
                  flex: 2,
                  child: RidingEventsPanel(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// 确保 OBDDataProvider 引用不被 tree-shaking（classic 布局用到它）
// ignore: unused_element
void _ensureOBDImport(OBDDataProvider _) {}
