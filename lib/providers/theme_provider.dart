import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/theme_colors.dart';
import '../theme/theme_definitions.dart';

/// 主题状态管理 Provider
/// 负责管理当前主题状态并在变更时通知监听器
/// 使用 shared_preferences 进行主题偏好持久化
class ThemeProvider extends ChangeNotifier {
  static const String _themeKey = 'app_theme';

  AppThemeType _currentTheme = AppThemeType.cyberBlue;
  bool _isInitialized = false;
  SharedPreferences? _prefs;

  /// 当前主题类型
  AppThemeType get currentTheme => _currentTheme;

  /// 是否已初始化
  bool get isInitialized => _isInitialized;

  /// 当前主题的颜色
  ThemeColors get currentColors => ThemeDefinitions.getThemeColors(_currentTheme);

  /// 是否为深色模式（light 主题为浅色模式）
  bool get isDarkMode => _currentTheme != AppThemeType.light;

  /// 初始化主题 Provider
  /// 从 SharedPreferences 加载保存的主题偏好
  Future<void> initialize() async {
    if (_isInitialized) return;

    _prefs = await SharedPreferences.getInstance();
    final themeName = _prefs?.getString(_themeKey);

    if (themeName != null) {
      _currentTheme = AppThemeType.values.firstWhere(
        (e) => e.name == themeName,
        orElse: () => AppThemeType.cyberBlue,
      );
    }

    _isInitialized = true;
    notifyListeners();
  }

  /// 设置主题
  /// 保存并切换到指定主题，同时持久化到 SharedPreferences
  Future<void> setTheme(AppThemeType theme) async {
    if (_currentTheme != theme) {
      _currentTheme = theme;
      await _prefs?.setString(_themeKey, theme.name);
      notifyListeners();
    }
  }
}
