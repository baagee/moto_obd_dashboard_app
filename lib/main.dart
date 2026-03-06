import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'providers/obd_data_provider.dart';
import 'providers/bluetooth_provider.dart';
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
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => OBDDataProvider()),
        ChangeNotifierProvider(create: (_) => BluetoothProvider()),
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