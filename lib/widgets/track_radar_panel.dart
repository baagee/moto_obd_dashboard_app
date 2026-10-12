import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/navi_provider.dart';
import 'gear_display_panel.dart';
import 'navi_card.dart';
import 'track_radar_card.dart';

/// 右下角面板
///
/// 左侧档位竖向展示常驻；右侧在**导航期间从轨迹雷达卡切换为导航卡**
/// （方案 §2.2：「导航开始时，右下角整卡从轨迹雷达切换为导航卡」），
/// 导航结束（`NaviState.off`）自动切回，零残留。
///
/// [TrackRadarCard] 本身不改动，仅由本面板决定是否挂载。
class TrackRadarPanel extends StatelessWidget {
  const TrackRadarPanel({super.key});

  @override
  Widget build(BuildContext context) {
    // 只 select 布尔翻转：GPS 每秒更新导航数据不会重建本面板
    final naviActive =
        context.select<NaviProvider, bool>((p) => p.hasSession);

    return Row(
      children: [
        // 左侧：档位竖向展示
        const Expanded(
          flex: 2,
          child: GearDisplayPanel(),
        ),

        const SizedBox(width: 8),

        // 右侧：轨迹雷达卡 / 导航卡
        Expanded(
          flex: 8,
          child: naviActive ? const NaviCard() : const TrackRadarCard(),
        ),
      ],
    );
  }
}
