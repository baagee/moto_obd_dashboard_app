import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'providers/obd_data_provider.dart';
import 'providers/bluetooth_provider.dart';
import 'providers/log_provider.dart';
import 'providers/sensor_provider.dart';
import 'providers/riding_stats_provider.dart';
import 'providers/riding_record_provider.dart';
import 'providers/navigation_provider.dart';
import 'providers/settings_provider.dart';
import 'services/audio_service.dart';
import 'screens/main_container.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ① 在 runApp 之前完成 SharedPreferences 初始化
  // SharedPreferences.getInstance() 在真机上通常 < 20ms，不会造成可感知的启动延迟
  final settingsProvider = SettingsProvider();
  await settingsProvider.init();

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
        // ① SettingsProvider：注入已初始化的实例（_prefs 已就绪）
        ChangeNotifierProvider<SettingsProvider>.value(
          value: settingsProvider,
        ),
        // codeflicker-fix: OPT-Issue-2/omvh7ni7j93qpiynr7sw
        // OBDDataProvider 注入 SettingsProvider，使 calculateGear 能读取用户配置的传动比
        ChangeNotifierProxyProvider<SettingsProvider, OBDDataProvider>(
          create: (_) => OBDDataProvider(),
          update: (context, settings, previous) {
            previous?.updateSettings(settings);
            return previous ?? OBDDataProvider();
          },
        ),
        ChangeNotifierProvider<LogProvider>(
          create: (_) => LogProvider(),
        ),
        ChangeNotifierProvider<NavigationProvider>(
          create: (_) => NavigationProvider(),
        ),
        // 音频服务 Provider（依赖 LogProvider）
        ChangeNotifierProxyProvider<LogProvider, AudioService>(
          create: (context) => AudioService(
            logProvider: context.read<LogProvider>(),
          ),
          update: (context, logProvider, previous) =>
              previous ?? AudioService(logProvider: logProvider),
        ),

        // 传感器 Provider - 管理倾角传感器（依赖 OBDDataProvider + LogProvider + SettingsProvider）
        ChangeNotifierProxyProvider3<OBDDataProvider, LogProvider,
            SettingsProvider, SensorProvider>(
          create: (context) => SensorProvider(
            obdDataProvider: context.read<OBDDataProvider>(),
            logProvider: context.read<LogProvider>(),
            settings: context.read<SettingsProvider>(),
          ),
          update: (context, obdDataProvider, logProvider, settings, previous) {
            previous?.updateSettings(settings);
            return previous ??
                SensorProvider(
                  obdDataProvider: obdDataProvider,
                  logProvider: logProvider,
                  settings: settings,
                );
          },
        ),

        // BluetoothProvider（依赖 OBDDataProvider + LogProvider + AudioService + SettingsProvider）
        ChangeNotifierProxyProvider4<OBDDataProvider, LogProvider, AudioService,
            SettingsProvider, BluetoothProvider>(
          create: (context) => BluetoothProvider(
            obdDataProvider: context.read<OBDDataProvider>(),
            logProvider: context.read<LogProvider>(),
            audioService: context.read<AudioService>(),
            settings: context.read<SettingsProvider>(),
          ),
          update: (context, obdDataProvider, logProvider, audioService,
              settings, previous) {
            previous?.updateSettings(settings);
            return previous ??
                BluetoothProvider(
                  obdDataProvider: obdDataProvider,
                  logProvider: logProvider,
                  audioService: audioService,
                  settings: settings,
                );
          },
        ),

        // 骑行记录 Provider - 骑行数据持久化（依赖 LogProvider + SettingsProvider）
        // codeflicker-fix: LOGIC-Issue-001/odko2evgylfq2rjqqr53
        ChangeNotifierProxyProvider2<LogProvider, SettingsProvider,
            RidingRecordProvider>(
          create: (context) => RidingRecordProvider(
            logProvider: context.read<LogProvider>(),
            settingsProvider: context.read<SettingsProvider>(),
          ),
          update: (context, logProvider, settings, previous) {
            previous?.updateSettings(settings);
            return previous ??
                RidingRecordProvider(
                  logProvider: logProvider,
                  settingsProvider: settings,
                );
          },
        ),

        // 骑行统计 Provider - 管理事件检测和统计（依赖 OBDDataProvider + LogProvider + AudioService + RidingRecordProvider + SettingsProvider）
        // codeflicker-fix: LOGIC-Issue-001/odko2evgylfq2rjqqr53
        ChangeNotifierProxyProvider3<OBDDataProvider, LogProvider,
            SettingsProvider, RidingStatsProvider>(
          create: (context) => RidingStatsProvider(
            obdDataProvider: context.read<OBDDataProvider>(),
            logProvider: context.read<LogProvider>(),
            audioService: context.read<AudioService>(),
            ridingRecordProvider: context.read<RidingRecordProvider>(),
            settingsProvider: context.read<SettingsProvider>(),
          ),
          update: (context, obdDataProvider, logProvider, settings, previous) {
            previous?.updateSettings(settings);
            return previous ??
                RidingStatsProvider(
                  obdDataProvider: obdDataProvider,
                  logProvider: logProvider,
                  audioService: context.read<AudioService>(),
                  ridingRecordProvider: context.read<RidingRecordProvider>(),
                  settingsProvider: settings,
                );
          },
        ),
      ],
      child: const OBDDashboardApp(),
    ),
  );
}

class OBDDashboardApp extends StatelessWidget {
  const OBDDashboardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CYBER-CYCLE OBD',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        fontFamily: GoogleFonts.spaceGrotesk().fontFamily,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF0DA6F2),
          surface: Color(0xFF162229),
          error: Color(0xFFFF4D4D),
        ),
        scaffoldBackgroundColor: Colors.transparent,
      ),
      builder: (context, child) => GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        behavior: HitTestBehavior.translucent,
        child: child!,
      ),
      home: const MainContainer(),
    );
  }
}
