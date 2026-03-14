import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/theme_colors.dart';
import '../services/sunrise_sunset_service.dart';
import '../theme/theme_definitions.dart';

/// 主题状态管理 Provider
/// 负责管理当前主题状态并在变更时通知监听器
/// 使用 shared_preferences 进行主题偏好持久化
class ThemeProvider extends ChangeNotifier {
  static const String _themeKey = 'app_theme';
  static const String _autoSwitchKey = 'auto_theme_switch';

  AppThemeType _currentTheme = AppThemeType.cyberBlue;
  bool _isInitialized = false;
  SharedPreferences? _prefs;

  // 日出日落服务
  SunriseSunsetService? _sunriseSunsetService;

  // 自动切换开关状态
  bool _isAutoSwitchEnabled = false;

  // 自动切换定时器
  Timer? _autoSwitchTimer;

  /// 当前主题类型
  AppThemeType get currentTheme => _currentTheme;

  /// 是否已初始化
  bool get isInitialized => _isInitialized;

  /// 当前主题的颜色
  ThemeColors get currentColors => ThemeDefinitions.getThemeColors(_currentTheme);

  /// 是否为深色模式（light 主题为浅色模式）
  bool get isDarkMode => _currentTheme != AppThemeType.light;

  /// 是否启用了自动主题切换
  bool get isAutoSwitchEnabled => _isAutoSwitchEnabled;

  /// 设置日出日落服务
  void setSunriseSunsetService(SunriseSunsetService service) {
    _sunriseSunsetService = service;
  }

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

    // 加载自动切换设置
    _isAutoSwitchEnabled = _prefs?.getBool(_autoSwitchKey) ?? false;

    // 如果启用了自动切换，启动定时器
    if (_isAutoSwitchEnabled) {
      await startAutoSwitchTimer();
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

  /// 设置自动主题切换
  /// 启用或禁用自动根据日出日落切换主题
  Future<void> setAutoSwitch(bool enabled) async {
    if (_isAutoSwitchEnabled == enabled) return;

    _isAutoSwitchEnabled = enabled;
    await _prefs?.setBool(_autoSwitchKey, enabled);

    if (enabled) {
      // 启用时立即检查并启动定时器
      await checkAutoSwitch();
      await startAutoSwitchTimer();
    } else {
      // 禁用时停止定时器
      _autoSwitchTimer?.cancel();
      _autoSwitchTimer = null;
    }

    notifyListeners();
  }

  /// 检查自动切换
  /// 根据当前时间判断是否需要切换主题
  Future<void> checkAutoSwitch() async {
    if (!_isAutoSwitchEnabled) return;
    if (_sunriseSunsetService == null) return;

    final times = await _sunriseSunsetService!.getSunriseSunsetTimes();
    if (times == null) return;

    final now = DateTime.now();

    // 判断是否为白天（日出和日落之间）
    final isDaytime = now.isAfter(times.sunrise) && now.isBefore(times.sunset);

    // 白天使用浅色主题，夜间使用深色主题
    final targetTheme = isDaytime ? AppThemeType.light : AppThemeType.cyberBlue;

    // 仅在主题不同时切换
    if (_currentTheme != targetTheme) {
      await setTheme(targetTheme);
    }
  }

  /// 启动自动切换定时器
  /// 每 5 分钟检查一次时间
  Future<void> startAutoSwitchTimer() async {
    // 取消已有定时器
    _autoSwitchTimer?.cancel();

    // 创建新定时器（每 5 分钟检查一次）
    _autoSwitchTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => checkAutoSwitch(),
    );
  }

  @override
  void dispose() {
    _autoSwitchTimer?.cancel();
    super.dispose();
  }
}
