import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../providers/obd_data_provider.dart';
import '../widgets/combined_gauge_card.dart';
import '../widgets/side_stats_panel.dart';
import '../widgets/telemetry_chart_card.dart';
import '../widgets/track_radar_panel.dart';
import '../widgets/self_check_overlay.dart';
import '../widgets/danger_pulse_overlay.dart';
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

  /// 长按切换仪表盘风格
  void _toggleGaugeStyle() {
    final settings = context.read<SettingsProvider>();
    final next = settings.gaugeStyle == 'classic' ? 'cyberpunk' : 'classic';
    settings.setGaugeStyle(next);
    // 切换回赛博朋克时重新播放自检动画
    if (next == 'cyberpunk') {
      setState(() => _showSelfCheck = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixin 要求

    final gaugeStyle = context.select<SettingsProvider, String>(
      (s) => s.gaugeStyle,
    );
    final maxRpm = context.select<SettingsProvider, int>((s) => s.maxRpm);
    final warnRpm = context.select<SettingsProvider, int>((s) => s.warnRpm);
    final dangerRpm = context.select<SettingsProvider, int>((s) => s.dangerRpm);
    final maxSpeed = context.select<SettingsProvider, int>((s) => s.maxSpeed);
    final warnSpeed = context.select<SettingsProvider, int>((s) => s.warnSpeed);
    final dangerSpeed =
        context.select<SettingsProvider, int>((s) => s.dangerSpeed);

    return GestureDetector(
      onLongPress: _toggleGaugeStyle,
      // translucent：长按手势不拦截子 Widget 的点击事件
      behavior: HitTestBehavior.translucent,
      child: Container(
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
      ),
    );
  }
}

/// 赛博朋克三栏布局（原有布局提取）
class _CyberpunkLayout extends StatelessWidget {
  const _CyberpunkLayout({super.key});

  @override
  Widget build(BuildContext context) {
    // 危险状态：RPM 或速度超过 danger 阈值时触发呼吸闪烁
    // select 监听 bool 翻转，数据每帧变化不会导致布局重建
    final dangerRpm = context.select<SettingsProvider, int>((s) => s.dangerRpm);
    final dangerSpeed =
        context.select<SettingsProvider, int>((s) => s.dangerSpeed);
    final rpmDanger = context
        .select<OBDDataProvider, bool>((p) => p.data.rpm > dangerRpm);
    final speedDanger = context
        .select<OBDDataProvider, bool>((p) => p.data.speed > dangerSpeed);

    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          // 第一列：车辆状态参数 (2/9)
          const Expanded(
            flex: 2,
            child: SideStatsPanel(),
          ),

          const SizedBox(width: 8),

          // 第二列：组合仪表盘（转速+时速合并为一个完整圆）(4/9)
          Expanded(
            flex: 4,
            child: Stack(
              children: [
                const CombinedGaugeCard(),
                Positioned.fill(
                  child: DangerPulseOverlay(
                    danger: rpmDanger || speedDanger,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // 第三列：遥测图表和轨迹雷达（上下排列，1:2比例）(3/9)
          const Expanded(
            flex: 3,
            child: Column(
              children: [
                // 上半部分：实时遥测折线图（1/3）
                Expanded(
                  flex: 1,
                  child: TelemetryChartCard(),
                ),

                SizedBox(height: 8),

                // 下半部分：轨迹雷达（2/3）
                Expanded(
                  flex: 2,
                  child: TrackRadarPanel(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
