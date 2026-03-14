import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'providers/obd_data_provider.dart';
import 'providers/bluetooth_provider.dart';
import 'providers/log_provider.dart';
import 'providers/sensor_provider.dart';
import 'providers/riding_stats_provider.dart';
import 'providers/navigation_provider.dart';
import 'providers/theme_provider.dart';
import 'services/audio_service.dart';
import 'screens/main_container.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // 强制横屏
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // 隐藏系统UI（状态栏和导航栏）以获得沉浸式体验
  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.immersiveSticky,
  );

  runApp(
    MultiProvider(
      providers: [
        // 主题 Provider - 必须在其他依赖它的 Provider 之前初始化
        ChangeNotifierProvider<ThemeProvider>(
          create: (_) => ThemeProvider()..initialize(),
        ),

        // 基础 Providers（无依赖）
        ChangeNotifierProvider<OBDDataProvider>(
          create: (_) => OBDDataProvider(),
        ),
        ChangeNotifierProvider<LogProvider>(
          create: (_) => LogProvider(),
        ),
        ChangeNotifierProvider<NavigationProvider>(
          create: (_) => NavigationProvider(),
        ),
        // 音频服务 Provider
        ChangeNotifierProvider<AudioService>(
          create: (_) => AudioService(),
        ),

        // 传感器 Provider - 管理倾角传感器（依赖 OBDDataProvider + LogProvider）
        ChangeNotifierProxyProvider2<OBDDataProvider, LogProvider, SensorProvider>(
          create: (context) => SensorProvider(
            obdDataProvider: context.read<OBDDataProvider>(),
            logProvider: context.read<LogProvider>(),
          ),
          update: (context, obdDataProvider, logProvider, previous) =>
              previous ??
              SensorProvider(
                obdDataProvider: obdDataProvider,
                logProvider: logProvider,
              ),
        ),

        // ProxyProvider - 通过依赖注入创建 BluetoothProvider
        // OBDDataProvider 和 LogProvider 会在创建时自动注入
        ChangeNotifierProxyProvider2<OBDDataProvider, LogProvider, BluetoothProvider>(
          create: (context) => BluetoothProvider(
            obdDataProvider: context.read<OBDDataProvider>(),
            logProvider: context.read<LogProvider>(),
          ),
          update: (context, obdDataProvider, logProvider, previous) =>
              previous ??
              BluetoothProvider(
                obdDataProvider: obdDataProvider,
                logProvider: logProvider,
              ),
        ),

        // 骑行统计 Provider - 管理事件检测和统计（依赖 OBDDataProvider + LogProvider + AudioService）
        ChangeNotifierProxyProvider2<OBDDataProvider, LogProvider, RidingStatsProvider>(
          create: (context) => RidingStatsProvider(
            obdDataProvider: context.read<OBDDataProvider>(),
            logProvider: context.read<LogProvider>(),
            audioService: context.read<AudioService>(),
          ),
          update: (context, obdDataProvider, logProvider, previous) =>
              previous ??
              RidingStatsProvider(
                obdDataProvider: obdDataProvider,
                logProvider: logProvider,
                audioService: context.read<AudioService>(),
              ),
        ),
      ],
      child: const OBDDashboardApp(),
    ),
  );
}

class OBDDashboardApp extends StatefulWidget {
  const OBDDashboardApp({super.key});

  @override
  State<OBDDashboardApp> createState() => _OBDDashboardAppState();
}

class _OBDDashboardAppState extends State<OBDDashboardApp> {
  ThemeProvider? _themeProvider;
  bool _hasInitializedStatusBar = false;

  @override
  void initState() {
    super.initState();
    // 延迟初始化状态栏同步，确保 ThemeProvider 已初始化
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeStatusBar();
    });
  }

  void _initializeStatusBar() {
    final themeProvider = context.read<ThemeProvider>();
    _themeProvider = themeProvider;

    // 初始设置状态栏
    _updateStatusBar();

    // 监听主题变化
    themeProvider.addListener(_onThemeChanged);
    _hasInitializedStatusBar = true;
  }

  void _onThemeChanged() {
    _updateStatusBar();
  }

  void _updateStatusBar() {
    final themeProvider = _themeProvider;
    if (themeProvider == null) return;

    final isDark = themeProvider.isDarkMode;

    // 根据主题设置状态栏亮度
    // 深色主题：状态栏使用深色背景 + 浅色图标
    // 浅色主题：状态栏使用浅色背景 + 深色图标
    SystemChrome.setSystemUIOverlayStyle(
      isDark
          ? SystemUiOverlayStyle(
              statusBarBrightness: Brightness.dark,
              statusBarIconBrightness: Brightness.light,
            )
          : SystemUiOverlayStyle(
              statusBarBrightness: Brightness.light,
              statusBarIconBrightness: Brightness.dark,
            ),
    );
  }

  @override
  void dispose() {
    // 清理监听器，防止内存泄漏
    if (_hasInitializedStatusBar) {
      _themeProvider?.removeListener(_onThemeChanged);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        final colors = themeProvider.currentColors;
        final isDark = themeProvider.isDarkMode;

        // 首次渲染时设置状态栏
        if (!_hasInitializedStatusBar && themeProvider.isInitialized) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _initializeStatusBar();
          });
        }

        return MaterialApp(
          title: 'CYBER-CYCLE OBD',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            brightness: isDark ? Brightness.dark : Brightness.light,
            fontFamily: GoogleFonts.spaceGrotesk().fontFamily,
            colorScheme: isDark
                ? ColorScheme.dark(
                    primary: colors.primary,
                    surface: colors.surface,
                    error: colors.accentRed,
                  )
                : ColorScheme.light(
                    primary: colors.primary,
                    surface: colors.surface,
                    error: colors.accentRed,
                  ),
            scaffoldBackgroundColor: colors.backgroundDark,
          ),
          home: const MainContainer(),
        );
      },
    );
  }
}
