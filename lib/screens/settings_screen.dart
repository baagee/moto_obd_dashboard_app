import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/theme_colors.dart';
import '../providers/theme_provider.dart';
import '../theme/theme_definitions.dart';

/// 设置页面 - 主题选择和自动切换设置
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final colors = themeProvider.currentColors;

        return Scaffold(
          backgroundColor: colors.backgroundDark,
          appBar: AppBar(
            title: Text(
              '设置',
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            backgroundColor: colors.surface,
            elevation: 0,
            iconTheme: IconThemeData(color: colors.primary),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 主题选择区域
              _buildSectionTitle('主题选择', colors),
              const SizedBox(height: 12),
              _buildThemeSelector(themeProvider, colors),

              const SizedBox(height: 32),

              // 自动切换区域
              _buildSectionTitle('自动切换', colors),
              const SizedBox(height: 12),
              _buildAutoSwitchTile(themeProvider, colors),
            ],
          ),
        );
      },
    );
  }

  /// 构建分区标题
  Widget _buildSectionTitle(String title, ThemeColors colors) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: TextStyle(
          color: colors.primary,
          fontSize: 13,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
        ),
      ),
    );
  }

  /// 构建主题选择器
  Widget _buildThemeSelector(ThemeProvider themeProvider, ThemeColors colors) {
    return Container(
      decoration: BoxDecoration(
        color: colors.surface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colors.primary.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: AppThemeType.values.map((themeType) {
          final isSelected = themeProvider.currentTheme == themeType;
          return _ThemeTile(
            themeType: themeType,
            isSelected: isSelected,
            colors: colors,
            onTap: () => themeProvider.setTheme(themeType),
          );
        }).toList(),
      ),
    );
  }

  /// 构建自动切换开关
  Widget _buildAutoSwitchTile(ThemeProvider themeProvider, ThemeColors colors) {
    return Container(
      decoration: BoxDecoration(
        color: colors.surface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colors.primary.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: SwitchListTile(
        title: Text(
          '根据日出日落自动切换',
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '日出后使用浅色主题，日落后使用深色主题',
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 11,
            ),
          ),
        ),
        value: themeProvider.isAutoSwitchEnabled,
        onChanged: (value) => themeProvider.setAutoSwitch(value),
        activeColor: colors.primary,
        inactiveThumbColor: colors.textMuted,
        inactiveTrackColor: colors.surface,
      ),
    );
  }
}

/// 主题选项组件
class _ThemeTile extends StatelessWidget {
  final AppThemeType themeType;
  final bool isSelected;
  final ThemeColors colors;
  final VoidCallback onTap;

  const _ThemeTile({
    required this.themeType,
    required this.isSelected,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final themeColors = ThemeDefinitions.getThemeColors(themeType);

    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: themeColors.backgroundDark,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? themeColors.primary : themeColors.primary.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: themeColors.primary.withOpacity(0.3),
                    blurRadius: 8,
                    spreadRadius: 0,
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: themeColors.primary,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
      title: Text(
        _getThemeName(themeType),
        style: TextStyle(
          color: isSelected ? colors.primary : colors.textPrimary,
          fontSize: 14,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        ),
      ),
      subtitle: Text(
        _getThemeDescription(themeType),
        style: TextStyle(
          color: colors.textSecondary,
          fontSize: 11,
        ),
      ),
      trailing: isSelected
          ? Icon(
              Icons.check_circle,
              color: colors.primary,
              size: 20,
            )
          : null,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }

  String _getThemeName(AppThemeType type) {
    switch (type) {
      case AppThemeType.cyberBlue:
        return '赛博蓝';
      case AppThemeType.red:
        return '烈焰红';
      case AppThemeType.orange:
        return '活力橙';
      case AppThemeType.light:
        return '日光白';
    }
  }

  String _getThemeDescription(AppThemeType type) {
    switch (type) {
      case AppThemeType.cyberBlue:
        return '深色背景 + 蓝色霓虹';
      case AppThemeType.red:
        return '深色背景 + 红色强调';
      case AppThemeType.orange:
        return '深色背景 + 橙色活力';
      case AppThemeType.light:
        return '浅色背景 + 清晰易读';
    }
  }
}
