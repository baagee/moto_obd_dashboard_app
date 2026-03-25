import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/obd_data_provider.dart';
import '../theme/app_theme.dart';

/// 档位显示面板
class GearDisplayPanel extends StatelessWidget {
  const GearDisplayPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<OBDDataProvider>(
      builder: (context, provider, child) {
        final gear = provider.data.gear;

        return Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // 顶部标签
            const Text('档位', style: AppTheme.labelMediumPrimary12),
            const SizedBox(height: 2),
            // 档位块
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GearBlock(gear: 6, currentGear: gear),
                  GearBlock(gear: 5, currentGear: gear),
                  GearBlock(gear: 4, currentGear: gear),
                  GearBlock(gear: 3, currentGear: gear),
                  GearBlock(gear: 2, currentGear: gear),
                  GearBlock(gear: 0, currentGear: gear), // N
                  GearBlock(gear: 1, currentGear: gear),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// 单个档位块（直角）
class GearBlock extends StatelessWidget {
  final int gear;
  final int currentGear;

  const GearBlock({super.key, required this.gear, required this.currentGear});

  @override
  Widget build(BuildContext context) {
    final isActive = gear == currentGear;
    final isNeutral = gear == 0;
    final displayText = isNeutral ? 'N' : '$gear';

    final activeColor = isNeutral ? AppTheme.accentOrange : AppTheme.accentCyan;
    const inactiveColor = AppTheme.primary50;

    return Container(
      width: 34,
      height: 23,
      margin: const EdgeInsets.symmetric(vertical: 1.5),
      decoration: BoxDecoration(
        color: isActive ? activeColor.withValues(alpha: 0.2) : Colors.transparent,
        border: Border.all(
          color: isActive ? activeColor : inactiveColor,
          width: 1,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: activeColor.withValues(alpha: 0.4),
                  blurRadius: 4,
                  spreadRadius: -1,
                ),
              ]
            : null,
      ),
      child: Center(
        child: Text(
          displayText,
          style: TextStyle(
            color: isActive ? activeColor : inactiveColor,
            fontSize: 16,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
