import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// 底部状态栏
class StatusFooter extends StatelessWidget {
  const StatusFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surface.withOpacity(0.8),
        border: Border(
          top: BorderSide(
            color: AppTheme.primary.withOpacity(0.2),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 左侧状态
          Row(
            children: [
              _StatusItem(
                dotColor: AppTheme.accentGreen,
                label: 'OBD-II Link: ACTIVE',
              ),
              const SizedBox(width: 24),
              _StatusItem(
                dotColor: AppTheme.accentGreen,
                label: 'Engine Comms: NOMINAL',
              ),
            ],
          ),

          // 右侧版本信息
          Text(
            'SYSTEM_VERSION_HASH: 0x82A1B4F92',
            style: TextStyle(
              color: AppTheme.primary.withOpacity(0.4),
              fontSize: 9,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusItem extends StatelessWidget {
  final Color dotColor;
  final String label;

  const _StatusItem({
    required this.dotColor,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: dotColor,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: AppTheme.primary.withOpacity(0.4),
            fontSize: 9,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }
}