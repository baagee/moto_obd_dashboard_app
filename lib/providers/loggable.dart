import '../models/obd_data.dart';
import 'log_provider.dart';

/// 创建日志回调的工厂函数
/// 用于简化 Provider 中的日志回调初始化
///
/// 使用示例:
/// ```dart
/// _logCallback = createLogger(logProvider);
/// ```
void Function(String source, LogType type, String message) createLogger(LogProvider logProvider) {
  return (source, type, message) => logProvider.addLog(source, type, message);
}
