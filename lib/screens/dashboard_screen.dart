import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/obd_data_provider.dart';
import '../widgets/rpm_gauge_card.dart';
import '../widgets/speed_gear_card.dart';
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
        color: Color(0xFF0A1114),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Consumer<OBDDataProvider>(
          builder: (context, provider, child) {
            return const Row(
              children: [
                // 第一列：车辆状态参数 (2/9)
                Expanded(
                  flex: 2,
                  child: SideStatsPanel(),
                ),

                SizedBox(width: 8),

                // 第二列：转速和时速仪表盘（上下排列）(4/9)
                Expanded(
                  flex: 4,
                  child: Column(
                    children: [
                      // 上半部分：转速半圆仪表盘
                      Expanded(
                        child: RPMGaugeCard(),
                      ),

                      SizedBox(height: 8),

                      // 下半部分：时速半圆仪表盘
                      Expanded(
                        child: SpeedGearCard(),
                      ),
                    ],
                  ),
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
            );
          },
        ),
      ),
    );
  }
}
