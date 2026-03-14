import 'package:flutter/foundation.dart';

/// 导航 Provider - 管理页面导航状态
class NavigationProvider extends ChangeNotifier {
  int _currentIndex = 0;

  int get currentIndex => _currentIndex;

  /// 设置导航索引
  void setIndex(int index) {
    if (_currentIndex != index) {
      _currentIndex = index;
      notifyListeners();
    }
  }

  /// 导航到仪表盘
  void goToDashboard() => setIndex(0);

  /// 导航到日志
  void goToLogs() => setIndex(1);

  /// 导航到设备
  void goToDevices() => setIndex(2);
}
