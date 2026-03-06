import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'dashboard_screen.dart';
import 'logs_screen.dart';

/// 主容器 - 管理页面导航
class MainContainer extends StatefulWidget {
  const MainContainer({super.key});

  @override
  State<MainContainer> createState() => _MainContainerState();
}

class _MainContainerState extends State<MainContainer> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    DashboardScreen(),
    LogsScreen(),
  ];

  void _navigateTo(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // 顶部导航栏
          _TopNavigationBar(
            currentIndex: _currentIndex,
            onNavigate: _navigateTo,
          ),

          // 页面内容
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: _pages,
            ),
          ),
        ],
      ),
    );
  }
}

class _TopNavigationBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onNavigate;

  const _TopNavigationBar({
    required this.currentIndex,
    required this.onNavigate,
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
            children: [
              _NavItem(
                'DASHBOARD',
                isActive: currentIndex == 0,
                onTap: () => onNavigate(0),
              ),
              const SizedBox(width: 12),
              _NavItem(
                'LOGS',
                isActive: currentIndex == 1,
                onTap: () => onNavigate(1),
              ),
              const SizedBox(width: 12),
              _NavItem('SETTINGS', onTap: () {}),
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
  final VoidCallback? onTap;

  const _NavItem(
    this.label, {
    this.isActive = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
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
      ),
    );
  }
}