import 'package:flutter/material.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:provider/provider.dart';
import '../providers/bluetooth_provider.dart';
import '../providers/log_provider.dart';
import '../providers/sensor_provider.dart';
import '../providers/riding_stats_provider.dart';
import '../providers/navigation_provider.dart';
import '../services/audio_service.dart';
import '../models/riding_event.dart';
import '../models/event_voice_config.dart';
import '../widgets/bluetooth_alert_dialog.dart';
import '../widgets/event_notification_dialog.dart';
import '../widgets/top_navigation_bar.dart';
import 'dashboard_screen.dart';
import 'record_screen.dart';
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

  late final PageController _pageController;

  final List<Widget> _pages = const [
    DashboardScreen(),
    RecordScreen(),
    LogsScreen(),
    BluetoothScanScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: context.read<NavigationProvider>().currentIndex);
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
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _navigateToBluetoothScan() {
    // 始终切换到 DEVICES 页面（使用 IndexedStack，共享顶部导航栏）
    _navigateTo(2);
  }

  /// 构建PageView并监听骑行事件
  Widget _buildPageView(BuildContext context) {
    return Selector<RidingStatsProvider, RidingEvent?>(
      selector: (_, stats) => stats.latestEvent,
      builder: (context, latestEvent, _) {
        if (latestEvent != null && !_hasShownEventNotification) {
          _hasShownEventNotification = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showEventNotification(latestEvent);
            // 清除最新事件，避免重复显示
            context.read<RidingStatsProvider>().clearLatestEvent();
            // 重置标志，允许显示下一个事件（3.5秒确保弹窗3秒关闭后再解锁）
            Future.delayed(const Duration(milliseconds: 3500), () {
              _hasShownEventNotification = false;
            });
          });
        }
        return PageView(
          controller: _pageController,
          onPageChanged: (index) {
            context.read<NavigationProvider>().setIndex(index);
          },
          children: _pages,
        );
      },
    );
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
  void dispose() {
    _pageController.dispose();
    super.dispose();
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
      child: Scaffold(
        body: Column(
          children: [
            // 顶部导航栏 - 使用 Selector 精确监听
            Selector<NavigationProvider, int>(
              selector: (_, nav) => nav.currentIndex,
              builder: (context, currentIndex, _) {
                // 监听蓝牙连接状态
                return Selector<BluetoothProvider, bool>(
                  selector: (_, bt) => bt.isDeviceConnected,
                  builder: (context, isConnected, _) {
                    // 连接状态变化时管理骑行统计
                    if (!isConnected && _hasStartedRide) {
                      _hasStartedRide = false;
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        context.read<RidingStatsProvider>().endRide();
                      });
                    }
                    if (isConnected && !_hasStartedRide) {
                      _hasStartedRide = true;
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        context.read<RidingStatsProvider>().startRide();
                      });
                    }

                    return Selector<BluetoothProvider, String?>(
                      selector: (_, bt) => bt.connectedDevice?.name,
                      builder: (context, deviceName, _) {
                        return TopNavigationBar(
                          currentIndex: currentIndex,
                          onNavigate: _navigateTo,
                          onLinkVehiclePressed: _navigateToBluetoothScan,
                          isConnected: isConnected,
                          deviceName: deviceName,
                        );
                      },
                    );
                  },
                );
              },
            ),

            // 页面内容 - 使用 PageView 实现滑动切换
            Expanded(
              child: _buildPageView(context),
            ),
          ],
        ),
      ),
    );
  }
}