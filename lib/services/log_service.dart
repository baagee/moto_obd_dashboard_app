import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/obd_data.dart';

/// 日志服务 - 负责日志的实时写入和分享
class LogService {
  static const String _logFileName = 'obd_logs.txt';
  static String? _cachedFilePath;

  /// 写入队列 - 用于异步顺序写入（StreamController 保证单线程顺序处理）
  static final StreamController<String> _writeQueue =
      StreamController<String>.broadcast();

  /// 初始化后台写入监听
  static void _initWriteListener() {
    _writeQueue.stream.listen(_processWriteQueue);
  }

  /// 处理写入队列
  static Future<void> _processWriteQueue(String logLine) async {
    try {
      final filePath = await getLogFilePath();
      final file = File(filePath);
      await file.writeAsString(logLine, encoding: utf8, mode: FileMode.append);
    } catch (e) {
      // 写入失败静默处理
    }
  }

  /// 获取日志文件路径
  static Future<String> getLogFilePath() async {
    if (_cachedFilePath != null) return _cachedFilePath!;
    final directory = await getApplicationDocumentsDirectory();
    _cachedFilePath = '${directory.path}/$_logFileName';
    return _cachedFilePath!;
  }

  /// 初始化日志文件（应用启动时调用）
  static Future<void> initLogFile() async {
    // 启动后台写入监听
    _initWriteListener();

    try {
      final filePath = await getLogFilePath();
      final file = File(filePath);

      if (!await file.exists()) {
        // 创建新文件并写入文件头
        final buffer = StringBuffer();
        buffer.writeln('OBD Logs');
        buffer.writeln('=' * 50);
        buffer.writeln('File Created: ${DateTime.now().toIso8601String()}');
        buffer.writeln('=' * 50);
        buffer.writeln();
        await file.writeAsString(buffer.toString(), encoding: utf8);
      }
    } catch (e) {
      // 初始化失败静默处理
    }
  }

  /// 实时追加写入单条日志到文件（通过队列异步顺序写入）
  static Future<void> appendLog(DiagnosticLog log) async {
    final typeStr = log.type.name.toUpperCase();
    final logLine = '[${log.formattedTime}] [$typeStr] [${log.source}] ${log.message}\n';

    // 加入队列，由后台监听器顺序处理
    _writeQueue.add(logLine);
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
      await file.writeAsString(buffer.toString(), encoding: utf8);
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
          [XFile(filePath, mimeType: 'text/plain; charset=utf-8')],
          subject: 'OBD Dashboard Logs',
        );
      }
    } catch (e) {
      // 分享失败静默处理
    }
  }
}
