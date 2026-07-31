import 'package:flutter/material.dart';

import 'gear_display_panel.dart';
import 'track_radar_card.dart';

/// 轨迹雷达面板
/// 左侧档位竖向展示，右侧轨迹雷达卡片（最近 15 分钟实时轨迹 + 事件徽章）
class TrackRadarPanel extends StatelessWidget {
  const TrackRadarPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        // 左侧：档位竖向展示
        Expanded(
          flex: 2,
          child: GearDisplayPanel(),
        ),

        SizedBox(width: 8),

        // 右侧：轨迹雷达卡片
        Expanded(
          flex: 8,
          child: TrackRadarCard(),
        ),
      ],
    );
  }
}
