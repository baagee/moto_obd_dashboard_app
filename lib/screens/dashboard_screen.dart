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
      decoration: const BoxDecoration(
        color: AppTheme.backgroundDark,
      ),
      child: const Padding(
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
      ),
    );
  }
}
