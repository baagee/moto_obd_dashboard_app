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

        // 骑行记录 Provider - 骑行数据持久化
        ChangeNotifierProvider<RidingRecordProvider>(
          create: (_) => RidingRecordProvider(),
        ),

        // 骑行统计 Provider - 管理事件检测和统计（依赖 OBDDataProvider + LogProvider + AudioService + RidingRecordProvider）
        ChangeNotifierProxyProvider2<OBDDataProvider, LogProvider, RidingStatsProvider>(
          create: (context) => RidingStatsProvider(
            obdDataProvider: context.read<OBDDataProvider>(),
            logProvider: context.read<LogProvider>(),
            audioService: context.read<AudioService>(),
            ridingRecordProvider: context.read<RidingRecordProvider>(),
          ),
          update: (context, obdDataProvider, logProvider, previous) =>
              previous ??
              RidingStatsProvider(
                obdDataProvider: obdDataProvider,
                logProvider: logProvider,
                audioService: context.read<AudioService>(),
                ridingRecordProvider: context.read<RidingRecordProvider>(),
              ),
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
        scaffoldBackgroundColor: const Color(0xFF0A1114),
      ),
      home: const MainContainer(),
    );
  }
}
