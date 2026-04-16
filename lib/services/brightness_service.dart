import 'package:flutter/widgets.dart';
import 'package:screen_brightness/screen_brightness.dart';

/// 屏幕最低亮度保障服务
///
/// 作用：APP 处于前台时，强制保持屏幕亮度不低于 [_minBrightness]；
///       退到后台时自动恢复系统亮度控制，不影响用户日常使用。
///
/// 使用方式：
///   在 main() 的 runApp 之前：
///     final brightnessService = BrightnessService()..init();
///   实例需保持在顶层变量中以防止被 GC 回收。
///
/// 如需修改最低亮度，只需调整 [_minBrightness] 常量即可。
class BrightnessService with WidgetsBindingObserver {
  /// 骑行仪表盘最低亮度阈值
  ///
  /// 取值范围：0.0（全暗）~ 1.0（最亮）
  /// 默认 0.6，适合户外骑行阳光直射场景下清晰可见。
  /// 若需在室内降低亮度使用，可改为 0.3。
  static const double _minBrightness = 0.6;

  /// 初始化服务：注册 AppLifecycle 监听并立即应用最低亮度
  void init() {
    WidgetsBinding.instance.addObserver(this);
    _applyMinBrightness();
  }

  /// 释放资源：移除监听并恢复系统亮度控制
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // 恢复系统自动亮度控制，避免影响其他 APP
    ScreenBrightness().resetScreenBrightness();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        // APP 回到前台（从后台恢复、锁屏解锁后）重新应用最低亮度
        _applyMinBrightness();
      case AppLifecycleState.paused:
        // APP 退到后台时释放亮度控制，恢复系统行为
        ScreenBrightness().resetScreenBrightness();
      default:
        break;
    }
  }

  /// 检查当前亮度，若低于阈值则提升至 [_minBrightness]
  ///
  /// 注意：若用户手动将亮度调高于阈值，此方法不会干预（不降低亮度）。
  Future<void> _applyMinBrightness() async {
    try {
      final current = await ScreenBrightness().current;
      if (current < _minBrightness) {
        await ScreenBrightness().setScreenBrightness(_minBrightness);
      }
    } catch (_) {
      // 部分设备/模拟器不支持亮度控制，静默忽略异常
    }
  }
}
