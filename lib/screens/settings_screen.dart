import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/settings/panels/vehicle_settings_panel.dart';
import '../widgets/settings/panels/events_settings_panel.dart';
import '../widgets/settings/panels/display_settings_panel.dart';
import '../widgets/settings/panels/bluetooth_settings_panel.dart';
import '../widgets/settings/panels/api_settings_panel.dart';
import '../widgets/settings/panels/advanced_settings_panel.dart';

/// 设置页面
///
/// 作为 MainContainer PageView 的普通子页面，共用顶部 TopNavigationBar，
/// 自身只渲染左右分栏内容，无需独立 Scaffold。
///
/// 左侧：导航分组列表（车辆参数 / 骑行事件 / 仪表盘 / 蓝牙 / 第三方服务 / 高级设置）
/// 右侧：IndexedStack 展示各面板（保持滚动位置，避免重建）
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _selectedIndex = 0;

  static const List<_NavGroup> _groups = [
    _NavGroup(icon: Icons.two_wheeler, label: '车辆参数'),
    _NavGroup(icon: Icons.notifications_active_outlined, label: '骑行事件'),
    _NavGroup(icon: Icons.speed_outlined, label: '仪表盘'),
    _NavGroup(icon: Icons.bluetooth_outlined, label: '蓝牙'),
    _NavGroup(icon: Icons.api_outlined, label: '第三方服务'),
    _NavGroup(icon: Icons.tune_outlined, label: '高级设置'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.transparent,
      child: Row(
        children: [
          // ===== 左侧导航列 =====
          _buildNavColumn(),

          // 分隔线
          Container(
            width: 1,
            color: AppTheme.primary.withValues(alpha: 0.15),
          ),

          // ===== 右侧内容区 =====
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: const [
                VehicleSettingsPanel(),
                EventsSettingsPanel(),
                DisplaySettingsPanel(),
                BluetoothSettingsPanel(),
                ApiSettingsPanel(),
                AdvancedSettingsPanel(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavColumn() {
    return Container(
      width: 120,
      color: Colors.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: AppTheme.primary.withValues(alpha: 0.2),
                ),
              ),
            ),
            child: Text(
              'SETTINGS',
              style: TextStyle(
                color: AppTheme.primary.withValues(alpha: 0.6),
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
          ),
          ...List.generate(_groups.length, (i) {
            final group = _groups[i];
            final isSelected = _selectedIndex == i;
            return GestureDetector(
              onTap: () => setState(() => _selectedIndex = i),
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.primary.withValues(alpha: 0.1)
                      : Colors.transparent,
                  border: Border(
                    left: BorderSide(
                      color: isSelected ? AppTheme.primary : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      group.icon,
                      size: 16,
                      color: isSelected
                          ? AppTheme.primary
                          : AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        group.label,
                        style: TextStyle(
                          color: isSelected
                              ? AppTheme.primary
                              : AppTheme.textSecondary,
                          fontSize: 13,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// 导航分组配置
class _NavGroup {
  final IconData icon;
  final String label;
  const _NavGroup({required this.icon, required this.label});
}
