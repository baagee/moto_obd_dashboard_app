/// 诊断日志类型
enum LogType {
  success,
  error,
  warning,
  info,
}

/// 日志过滤类型
enum LogFilterType {
  all,
  success,
  warning,
  error,
  info,
}

/// 诊断日志模型
class DiagnosticLog {
  final LogType type;
  final String message;
  final DateTime timestamp;
  final String source; // 日志来源

  DiagnosticLog({
    required this.type,
    required this.message,
    required this.source,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  String get formattedTime {
    final h = timestamp.hour.toString().padLeft(2, '0');
    final m = timestamp.minute.toString().padLeft(2, '0');
    final s = timestamp.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}
