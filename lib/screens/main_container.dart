import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/bluetooth_provider.dart';
import '../providers/log_provider.dart';
import '../providers/sensor_provider.dart';
import '../providers/riding_stats_provider.dart';
import '../providers/navigation_provider.dart';
import '../providers/theme_provider.dart';
import '../models/theme_colors.dart';
import '../services/audio_service.dart';
import '../models/riding_event.dart';
import '../models/event_voice_config.dart';
import '../widgets/bluetooth_status_icon.dart';
import '../widgets/bluetooth_alert_dialog.dart';
import '../widgets/event_notification_dialog.dart';
import 'dashboard_screen.dart';
import 'logs_screen.dart';
import 'bluetooth_scan_screen.dart';

/// 主容器 - 管理页面导航
class MainContainer extends StatefulWidget {
  const MainContainer({super.key});

  @override
  State<MainContainer> createState() => _MainContainerState();
}

class _MainContainerState extends State<MainContainer> {
  bool _hasCheckedBluetooth = false;
  bool _hasStartedRide = false;
  bool _hasShownEventNotification = false;

  final List<Widget> _pages = const [
    DashboardScreen(),
    LogsScreen(),
    BluetoothScanScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _initializeBluetooth();
    // ====== [测试代码] APP启动3秒后自动添加测试事件 ======
    // TODO: 测试完成后删除此代码
    // Future.delayed(const Duration(seconds: 3), () {
    //   if (mounted) {
    //     _triggerTestEvent();
    //   }
    // });
    // ====== [测试代码结束] ======
  }

  /// ====== [测试方法] 触发测试事件 ======
  /// TODO: 测试完成后删除此方法
  void _triggerTestEvent() {
    final statsProvider = context.read<RidingStatsProvider>();

    // 创建测试事件
    final testEvent = RidingEvent(
      type: RidingEventType.performanceBurst,
      title: '性能爆发',
      description: '测试事件：发动机转速高于6300rpm且车速快速攀升',
      triggerValue: 7500.0,
      threshold: 6300.0,
      timestamp: DateTime.now(),
      additionalData: {
        'isTestEvent': true, // 标记为测试事件
        'condition': 'test mode',
      },
    );

    // 手动触发测试事件（通过修改 RidingStatsProvider 的 latestEvent）
    // 这里直接调用 _showEventNotification 来测试弹窗
    _showEventNotification(testEvent);

    // 打印日志
    debugPrint('[测试] 已触发测试事件: ${testEvent.title}');
  }
  /// ====== [测试方法结束] ======

  Future<void> _initializeBluetooth() async {
    final bluetoothProvider = context.read<BluetoothProvider>();
    final logProvider = context.read<LogProvider>();
    final sensorProvider = context.read<SensorProvider>();

    // 初始化日志系统
    await logProvider.initialize();

    // 初始化倾角传感器（APP 启动时立即生效）
    sensorProvider.initialize();

    // 初始化蓝牙（依赖已通过 ProxyProvider 注入）
    // 骑行统计在蓝牙连接成功后自动开始
    await bluetoothProvider.initialize();
    _hasCheckedBluetooth = true;
    await _checkAndShowBluetoothDialog();
  }

  Future<void> _checkAndShowBluetoothDialog() async {
    if (!_hasCheckedBluetooth) return;

    final bluetoothProvider = context.read<BluetoothProvider>();

    // 检查是否需要显示弹窗
    if (!bluetoothProvider.hasPermission) {
      // 权限未授权，先请求权限
      final granted = await bluetoothProvider.requestPermission();
      if (!granted && mounted) {
        BluetoothAlertDialog.showPermissionDeniedDialog(
          context,
          onOpenSettings: () => bluetoothProvider.openSettings(),
        );
      }
    } else if (!bluetoothProvider.isBluetoothOn && mounted) {
      // 权限已授权但蓝牙未开启
      BluetoothAlertDialog.showBluetoothOffDialog(
        context,
        onOpenSettings: () => bluetoothProvider.openSettings(),
      );
    }
  }

  void _navigateTo(int index) {
    context.read<NavigationProvider>().setIndex(index);
  }

  void _navigateToBluetoothScan() {
    // 始终切换到 DEVICES 页面（使用 IndexedStack，共享顶部导航栏）
    _navigateTo(2);
  }

  /// 显示事件通知弹窗并播放语音
  void _showEventNotification(RidingEvent event) {
    if (!mounted) return;

    final audioService = context.read<AudioService>();
    final config = EventVoiceConfigManager.getConfig(event.type);

    // 播放语音
    if (config != null) {
      audioService.playAsset(config.audioAssetPath);
    }

    // 显示弹窗
    EventNotificationDialog.show(
      context: context,
      event: event,
    );
  }

  @override
  Widget build(BuildContext context) {
    // 拦截返回键，最小化应用到桌面而不是退出
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          // 最小化应用到系统桌面
          final intent = AndroidIntent(
            action: 'android.intent.action.MAIN',
            category: 'android.intent.category.HOME',
          );
          await intent.launch();
        }
      },
      child: Consumer<NavigationProvider>(
        builder: (context, navProvider, child) {
          return Consumer<BluetoothProvider>(
            builder: (context, bluetoothProvider, child) {
              // 监听骑行事件
              return Consumer<RidingStatsProvider>(
                builder: (context, statsProvider, child) {
                  final latestEvent = statsProvider.latestEvent;
                  if (latestEvent != null && !_hasShownEventNotification) {
                    _hasShownEventNotification = true;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _showEventNotification(latestEvent);
                      // 清除最新事件，避免重复显示
                      statsProvider.clearLatestEvent();
                      // 重置标志，允许显示下一个事件（3.5秒确保弹窗3秒关闭后再解锁）
                      Future.delayed(const Duration(milliseconds: 3500), () {
                        _hasShownEventNotification = false;
                      });
                    });
                  }

                  // 检测连接成功瞬间，启动骑行统计
                  final isConnected = bluetoothProvider.isDeviceConnected;
                  // 连接状态从 connected 变为 disconnected 时重置
                  if (!isConnected && _hasStartedRide) {
                    _hasStartedRide = false;
                    context.read<RidingStatsProvider>().endRide();
                  }
                  if (isConnected && !_hasStartedRide) {
                    _hasStartedRide = true;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      context.read<RidingStatsProvider>().startRide();
                    });
                  }

                  return Scaffold(
                    body: Column(
                      children: [
                        // 顶部导航栏
                        _TopNavigationBar(
                          currentIndex: navProvider.currentIndex,
                          onNavigate: _navigateTo,
                          onLinkVehiclePressed: _navigateToBluetoothScan,
                          isConnected: isConnected,
                          deviceName: bluetoothProvider.connectedDevice?.name,
                        ),

                        // 页面内容
                        Expanded(
                          child: IndexedStack(
                            index: navProvider.currentIndex,
                            children: _pages,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _TopNavigationBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onNavigate;
  final VoidCallback? onLinkVehiclePressed;
  final bool isConnected;
  final String? deviceName;

  const _TopNavigationBar({
    required this.currentIndex,
    required this.onNavigate,
    this.onLinkVehiclePressed,
    required this.isConnected,
    this.deviceName,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final colors = themeProvider.currentColors;
        return Container(
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: colors.backgroundDark.withOpacity(0.8),
            border: Border(
              bottom: BorderSide(
                color: colors.primary.withOpacity(0.2),
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
                            const TextSpan(
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
                  _NavItem(
                    'DASHBOARD',
                    isActive: currentIndex == 0,
                    onTap: () => onNavigate(0),
                    colors: colors,
                  ),
                  const SizedBox(width: 12),
                  _NavItem(
                    'LOGS',
                    isActive: currentIndex == 1,
                    onTap: () => onNavigate(1),
                    colors: colors,
                  ),
                  const SizedBox(width: 12),
                  _NavItem(
                    'DEVICES',
                    isActive: currentIndex == 2,
                    onTap: () => onNavigate(2),
                    colors: colors,
                  ),
                ],
              ),

              const SizedBox(width: 12),

              // 分隔线
              Container(
                height: 15,
                width: 1,
                color: colors.primary.withOpacity(0.2),
              ),

              const SizedBox(width: 10),

              // Link Vehicle按钮 - 根据连接状态显示不同文案
              GestureDetector(
                onTap: onLinkVehiclePressed,
                child: Container(
                  height: 21,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: isConnected ? colors.accentGreen : colors.primary,
                    borderRadius: BorderRadius.circular(5),
                    boxShadow: AppTheme.glowShadow(isConnected ? colors.accentGreen : colors.primary),
                  ),
                  child: Center(
                    child: Text(
                      isConnected && deviceName != null ? deviceName! : '设备未连接',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 7,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 6),

              // 蓝牙和信号状态图标
              const BluetoothStatusIcon(),
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
  final VoidCallback? onTap;
  final ThemeColors colors;

  const _NavItem(
    this.label, {
    this.isActive = false,
    this.onTap,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
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
      ),
    );
  }
}