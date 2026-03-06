import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// 顶部导航栏
class TopNavigationBar extends StatelessWidget {
  const TopNavigationBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppTheme.backgroundDark.withOpacity(0.8),
        border: Border(
          bottom: BorderSide(
            color: AppTheme.primary.withOpacity(0.2),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Logo区域
          Row(
            children: [
              const Icon(
                Icons.settings_input_antenna,
                color: AppTheme.primary,
                size: 18,
              ),
              const SizedBox(width: 6),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: const TextSpan(
                      children: [
                        TextSpan(
                          text: 'CYBER-CYCLE ',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextSpan(
                          text: 'OBD_v2.0',
                          style: TextStyle(
                            color: AppTheme.primary,
                            fontSize: 9,
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Text(
                    'SYSTEM PROTOCOL ACTIVE',
                    style: TextStyle(
                      color: AppTheme.primary,
                      fontSize: 6,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const Spacer(),

          // 导航菜单
          Row(
            children: [
              _NavItem('DASHBOARD', isActive: true),
              const SizedBox(width: 12),
              _NavItem('SETTINGS'),
            ],
          ),

          const SizedBox(width: 12),

          // 分隔线
          Container(
            height: 15,
            width: 1,
            color: AppTheme.primary.withOpacity(0.2),
          ),

          const SizedBox(width: 10),

          // Link Vehicle按钮
          Container(
            height: 21,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: AppTheme.primary,
              borderRadius: BorderRadius.circular(5),
              boxShadow: AppTheme.glowShadow(AppTheme.primary),
            ),
            child: const Center(
              child: Text(
                'LINK VEHICLE',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 7,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),

          const SizedBox(width: 6),

          // 状态图标
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(
                color: AppTheme.primary.withOpacity(0.1),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.bluetooth_connected,
                  color: AppTheme.accentGreen,
                  size: 12,
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.signal_cellular_alt,
                  color: AppTheme.primary,
                  size: 12,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final String label;
  final bool isActive;

  const _NavItem(this.label, {this.isActive = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isActive ? AppTheme.primary : AppTheme.textSecondary,
            fontSize: 8,
            fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
          ),
        ),
        if (isActive)
          Container(
            margin: const EdgeInsets.only(top: 2),
            height: 1,
            width: 40,
            color: AppTheme.primary,
          ),
      ],
    );
  }
}