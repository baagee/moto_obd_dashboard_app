import 'package:flutter/foundation.dart';
import '../models/obd_data.dart';
import '../services/log_service.dart';

/// 日志 Provider - 集中管理所有业务日志
class LogProvider extends ChangeNotifier {
  static const int _maxLogs = 100; // 最多保存100条
  bool _isInitialized = false;

  final List<DiagnosticLog> _logs = [];
  LogFilterType _currentFilter = LogFilterType.all;

  // 缓存各类型日志数量
  int _successCount = 0;
  int _warningCount = 0;
  int _errorCount = 0;
  int _infoCount = 0;

  // Getter
  List<DiagnosticLog> get logs => List.unmodifiable(_logs);
  bool get isInitialized => _isInitialized;
  LogFilterType get currentFilter => _currentFilter;

  int get successCount => _successCount;
  int get warningCount => _warningCount;
  int get errorCount => _errorCount;
  int get infoCount => _infoCount;
  int get totalCount => _logs.length;

  /// 设置过滤类型
  void setFilter(LogFilterType filter) {
    if (_currentFilter != filter) {
      _currentFilter = filter;
      notifyListeners();
    }
  }

  /// 获取过滤后的日志
  List<DiagnosticLog> get filteredLogs {
    if (_currentFilter == LogFilterType.all) {
      return logs;
    }
    return _logs.where((log) {
      switch (_currentFilter) {
        case LogFilterType.success:
          return log.type == LogType.success;
        case LogFilterType.warning:
          return log.type == LogType.warning;
        case LogFilterType.error:
          return log.type == LogType.error;
        case LogFilterType.info:
          return log.type == LogType.info;
        case LogFilterType.all:
          return true;
      }
    }).toList();
  }

  /// 获取过滤后各类型的数量
  Map<LogFilterType, int> get filterCounts => {
        LogFilterType.all: totalCount,
        LogFilterType.success: _successCount,
        LogFilterType.warning: _warningCount,
        LogFilterType.error: _errorCount,
        LogFilterType.info: _infoCount,
      };

  /// 初始化日志系统（应用启动时调用）
  Future<void> initialize() async {
    if (_isInitialized) return;

    // 初始化日志文件
    await LogService.initLogFile();

    _isInitialized = true;
    notifyListeners();
  }

  /// 添加日志（同时写入内存和实时写入文件）
  void addLog(String source, LogType type, String message) {
    final log = DiagnosticLog(
      type: type,
      message: message,
      source: source,
    );

    // 1. 添加到内存列表
    _logs.insert(0, log);

    // 超过最大数量时移除最旧的日志
    if (_logs.length > _maxLogs) {
      final removed = _logs.removeLast();
      // 更新计数
      _decrementCount(removed.type);
    }

    // 2. 更新计数
    _incrementCount(type);

    // 3. 实时写入文件
    LogService.appendLog(log);

    notifyListeners();
  }

  void _incrementCount(LogType type) {
    switch (type) {
      case LogType.success:
        _successCount++;
        break;
      case LogType.warning:
        _warningCount++;
        break;
      case LogType.error:
        _errorCount++;
        break;
      case LogType.info:
        _infoCount++;
        break;
    }
  }

  void _decrementCount(LogType type) {
    switch (type) {
      case LogType.success:
        _successCount--;
        break;
      case LogType.warning:
        _warningCount--;
        break;
      case LogType.error:
        _errorCount--;
        break;
      case LogType.info:
        _infoCount--;
        break;
    }
  }

  /// 清空日志（同时清空内存和文件）
  Future<void> clearLogs() async {
    _logs.clear();
    _successCount = 0;
    _warningCount = 0;
    _errorCount = 0;
    _infoCount = 0;
    await LogService.clearLogFile();
    notifyListeners();
  }

  /// 分享日志文件
  Future<void> shareLogs() async {
    await LogService.shareLogFile();
  }
}
