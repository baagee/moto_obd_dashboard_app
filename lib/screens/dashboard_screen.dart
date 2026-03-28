import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/combined_gauge_card.dart';
import '../widgets/side_stats_panel.dart';
import '../widgets/telemetry_chart_card.dart';
import '../widgets/riding_events_panel.dart';

/// 主仪表盘屏幕
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.deepSpace,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 左上角：霓虹青晕光（提高透明度，明显可见）
          Positioned(
            left: -60,
            top: -60,
            child: Container(
              width: 380,
              height: 380,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.accentCyan.withValues(alpha: 0.22),
                    AppTheme.accentCyan.withValues(alpha: 0.0),
                  ],
                  stops: const [0.0, 1.0],
                ),
              ),
            ),
          ),
          // 右下角：品红晕光（主晕光）
          Positioned(
            right: -60,
            bottom: -60,
            child: Container(
              width: 340,
              height: 340,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.neonPink.withValues(alpha: 0.28),
                    AppTheme.neonPink.withValues(alpha: 0.0),
                  ],
                  stops: const [0.0, 1.0],
                ),
              ),
            ),
          ),
          // 右上角：品红副晕光（模拟参考图右侧光束）
          Positioned(
            right: -40,
            top: -40,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.neonPink.withValues(alpha: 0.18),
                    AppTheme.neonPink.withValues(alpha: 0.0),
                  ],
                  stops: const [0.0, 1.0],
                ),
              ),
            ),
          ),
          // 主内容层
          const _DashboardContent(),
        ],
      ),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent();

  @override
  Widget build(BuildContext context) {
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
