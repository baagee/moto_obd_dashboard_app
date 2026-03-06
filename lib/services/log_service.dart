import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/obd_data.dart';

/// 日志来源
class LogSource {
  static const String system = 'System';
  static const String bluetooth = 'Bluetooth';
  static const String obd = 'OBD';
  static const String elm327 = 'ELM327';
}

/// 日志服务 - 负责日志的实时写入和分享
class LogService {
  static const String _logFileName = 'obd_logs.txt';
  static String? _cachedFilePath;

  /// 获取日志文件路径
  static Future<String> getLogFilePath() async {
    if (_cachedFilePath != null) return _cachedFilePath!;
    final directory = await getApplicationDocumentsDirectory();
    _cachedFilePath = '${directory.path}/$_logFileName';
    return _cachedFilePath!;
  }

  /// 初始化日志文件（应用启动时调用）
  static Future<void> initLogFile() async {
    try {
      final filePath = await getLogFilePath();
      final file = File(filePath);

      if (!await file.exists()) {
        // 创建新文件并写入文件头
        final buffer = StringBuffer();
        buffer.writeln('OBD Dashboard Logs');
        buffer.writeln('=' * 50);
        buffer.writeln('File Created: ${DateTime.now().toIso8601String()}');
        buffer.writeln('=' * 50);
        buffer.writeln();
        await file.writeAsString(buffer.toString());
      }
    } catch (e) {
      // 初始化失败静默处理
    }
  }

  /// 实时追加写入单条日志到文件
  static Future<void> appendLog(DiagnosticLog log) async {
    try {
      final filePath = await getLogFilePath();
      final file = File(filePath);

      final typeStr = log.type.name.toUpperCase();
      final logLine = '[${log.formattedTime}] [$typeStr] [${log.source}] ${log.message}\n';

      await file.writeAsString(logLine, mode: FileMode.append);
    } catch (e) {
      // 写入失败静默处理
    }
  }

  /// 清空日志文件
  static Future<void> clearLogFile() async {
    try {
      final filePath = await getLogFilePath();
      final file = File(filePath);

      // 重新写入文件头
      final buffer = StringBuffer();
      buffer.writeln('OBD Dashboard Logs');
      buffer.writeln('=' * 50);
      buffer.writeln('File Cleared: ${DateTime.now().toIso8601String()}');
      buffer.writeln('=' * 50);
      buffer.writeln();
      await file.writeAsString(buffer.toString());
    } catch (e) {
      // 清空失败静默处理
    }
  }

  /// 分享日志文件
  static Future<void> shareLogFile() async {
    try {
      final filePath = await getLogFilePath();
      final file = File(filePath);

      if (await file.exists()) {
        await Share.shareXFiles(
          [XFile(filePath)],
          subject: 'OBD Dashboard Logs',
        );
      }
    } catch (e) {
      // 分享失败静默处理
    }
  }
}
