import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'providers/obd_data_provider.dart';
import 'providers/bluetooth_provider.dart';
import 'providers/log_provider.dart';
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

  runApp(const OBDDashboardApp());
}

class OBDDashboardApp extends StatelessWidget {
  const OBDDashboardApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 创建 Provider 实例
    final obdProvider = OBDDataProvider();
    final bluetoothProvider = BluetoothProvider();
    final logProvider = LogProvider();

    // 建立 BluetoothProvider 和 OBDDataProvider 的关联
    bluetoothProvider.setOBDDataProvider(obdProvider);
    // 建立 BluetoothProvider 和 LogProvider 的关联
    bluetoothProvider.setLogProvider(logProvider);

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<OBDDataProvider>.value(value: obdProvider),
        ChangeNotifierProvider<BluetoothProvider>.value(value: bluetoothProvider),
        ChangeNotifierProvider<LogProvider>.value(value: logProvider),
      ],
      child: MaterialApp(
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
      ),
    );
  }
}
