import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/theme_colors.dart';
import '../providers/theme_provider.dart';

/// 顶部导航栏
class TopNavigationBar extends StatelessWidget {
  const TopNavigationBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final colors = themeProvider.currentColors;

        return Container(
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: colors.backgroundDark.withValues(alpha: 0.8),
            border: Border(
              bottom: BorderSide(
                color: colors.primary.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              // Logo区域
              Row(
                children: [
                  Icon(
                    Icons.settings_input_antenna,
                    color: colors.primary,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RichText(
                        text: TextSpan(
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
                                color: colors.primary,
                                fontSize: 9,
                                fontWeight: FontWeight.w300,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        'SYSTEM PROTOCOL ACTIVE',
                        style: TextStyle(
                          color: colors.primary,
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
                  _NavItem('DASHBOARD', isActive: true, colors: colors),
                  const SizedBox(width: 12),
                  _NavItem('SETTINGS', colors: colors),
                ],
              ),

              const SizedBox(width: 12),

              // 分隔线
              Container(
                height: 15,
                width: 1,
                color: colors.primary.withValues(alpha: 0.2),
              ),

              const SizedBox(width: 10),

              // Link Vehicle按钮
              Container(
                height: 21,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: colors.primary,
                  borderRadius: BorderRadius.circular(5),
                  boxShadow: [
                    BoxShadow(
                      color: colors.primary.withValues(alpha: 0.5),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Center(
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
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                    color: colors.primary.withValues(alpha: 0.1),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.bluetooth_connected,
                      color: colors.accentGreen,
                      size: 12,
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.signal_cellular_alt,
                      color: colors.primary,
                      size: 12,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _NavItem extends StatelessWidget {
  final String label;
  final bool isActive;
  final ThemeColors colors;

  const _NavItem(this.label, {this.isActive = false, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isActive ? colors.primary : colors.textSecondary,
            fontSize: 8,
            fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
          ),
        ),
        if (isActive)
          Container(
            margin: const EdgeInsets.only(top: 2),
            height: 1,
            width: 40,
            color: colors.primary,
          ),
      ],
    );
  }
}
