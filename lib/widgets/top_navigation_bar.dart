import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'bluetooth_status_icon.dart';

/// 顶部导航栏
class TopNavigationBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onNavigate;
  final VoidCallback? onLinkVehiclePressed;
  final bool isConnected;
  final String? deviceName;
  final List<String> navItems;

  const TopNavigationBar({
    super.key,
    required this.currentIndex,
    required this.onNavigate,
    this.onLinkVehiclePressed,
    required this.isConnected,
    this.deviceName,
    this.navItems = const ['DASHBOARD', 'LOGS', 'DEVICES'],
  });

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
            children: _buildNavItems(),
          ),

          const SizedBox(width: 12),

          // 分隔线
          Container(
            height: 15,
            width: 1,
            color: AppTheme.primary.withOpacity(0.2),
          ),

          const SizedBox(width: 10),

          // Link Vehicle按钮 - 根据连接状态显示不同文案
          GestureDetector(
            onTap: onLinkVehiclePressed,
            child: Container(
              height: 21,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              constraints: const BoxConstraints(maxWidth: 80),
              decoration: BoxDecoration(
                color: isConnected ? AppTheme.accentGreen : AppTheme.primary,
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                boxShadow: AppTheme.glowShadow(
                  isConnected ? AppTheme.accentGreen : AppTheme.primary,
                ),
              ),
              child: Center(
                child: Text(
                  isConnected && deviceName != null ? deviceName! : (isConnected ? 'LINKED' : 'LINK VEHICLE'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 7,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),

          const SizedBox(width: 6),

          // 蓝牙和信号状态图标
          const BluetoothStatusIcon(),
        ],
      ),
    );
  }

  List<Widget> _buildNavItems() {
    final items = <Widget>[];
    for (int i = 0; i < navItems.length; i++) {
      if (i > 0) {
        items.add(const SizedBox(width: 12));
      }
      items.add(
        _NavItem(
          navItems[i],
          isActive: currentIndex == i,
          onTap: () => onNavigate(i),
        ),
      );
    }
    return items;
  }
}

class _NavItem extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback? onTap;

  const _NavItem(this.label, {this.isActive = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 60,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                textAlign: TextAlign.center,
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
                  width: 50,
                  color: AppTheme.primary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
