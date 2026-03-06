import 'package:flutter/foundation.dart';
import '../models/obd_data.dart';
import '../services/log_service.dart';

/// 日志 Provider - 集中管理所有业务日志
class LogProvider extends ChangeNotifier {
  static const int _maxLogs = 100; // 最多保存100条
  bool _isInitialized = false;

  final List<DiagnosticLog> _logs = [];

  // Getter
  List<DiagnosticLog> get logs => List.unmodifiable(_logs);
  bool get isInitialized => _isInitialized;

  List<DiagnosticLog> get successLogs =>
      _logs.where((log) => log.type == LogType.success).toList();

  List<DiagnosticLog> get warningLogs =>
      _logs.where((log) => log.type == LogType.warning).toList();

  List<DiagnosticLog> get errorLogs =>
      _logs.where((log) => log.type == LogType.error).toList();

  List<DiagnosticLog> get infoLogs =>
      _logs.where((log) => log.type == LogType.info).toList();

  int get totalCount => _logs.length;
  int get successCount => successLogs.length;
  int get warningCount => warningLogs.length;
  int get errorCount => errorLogs.length;
  int get infoCount => infoLogs.length;

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
      _logs.removeLast();
    }

    // 2. 实时写入文件
    LogService.appendLog(log);

    notifyListeners();
  }

  /// 清空日志（同时清空内存和文件）
  Future<void> clearLogs() async {
    _logs.clear();
    await LogService.clearLogFile();
    notifyListeners();
  }

  /// 分享日志文件
  Future<void> shareLogs() async {
    await LogService.shareLogFile();
  }
}
