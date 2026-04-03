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

  /// 串行写入链：每次写入都链接在上一次完成之后，彻底杜绝并发竞争
  static Future<void> _lastWrite = Future.value();

  /// 获取日志文件路径
  static Future<String> getLogFilePath() async {
    if (_cachedFilePath != null) return _cachedFilePath!;
    final directory = await getApplicationDocumentsDirectory();
    _cachedFilePath = '${directory.path}/$_logFileName';
    return _cachedFilePath!;
  }

  /// 将任意写操作串行化：始终链接在上一次写入之后执行
  static void _enqueue(Future<void> Function() task) {
    _lastWrite = _lastWrite.then((_) => task()).catchError((_) {});
  }

  /// 初始化日志文件（应用启动时调用）
  static Future<void> initLogFile() async {
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

  /// 实时追加写入单条日志到文件（串行队列，保证顺序、无覆盖）
  static void appendLog(DiagnosticLog log) {
    final typeStr = log.type.name.toUpperCase();
    final logLine =
        '[${log.formattedTime}] [$typeStr] [${log.source}] ${log.message}\n';
    _enqueue(() async {
      final filePath = await getLogFilePath();
      await File(filePath)
          .writeAsString(logLine, encoding: utf8, mode: FileMode.append);
    });
  }

  /// 清空日志文件（同样走串行队列，避免与追加写入竞争）
  static Future<void> clearLogFile() async {
    final completer = Completer<void>();
    _enqueue(() async {
      try {
        final filePath = await getLogFilePath();
        final buffer = StringBuffer();
        buffer.writeln('OBD Dashboard Logs');
        buffer.writeln('=' * 50);
        buffer.writeln('File Cleared: ${DateTime.now().toIso8601String()}');
        buffer.writeln('=' * 50);
        buffer.writeln();
        await File(filePath).writeAsString(buffer.toString(), encoding: utf8);
      } finally {
        completer.complete();
      }
    });
    return completer.future;
  }

  /// 直接追加原始文本到日志文件（不经过 LogProvider，不触发 notifyListeners）
  /// 用于帧率监控等高频日志，避免 UI rebuild
  static void appendRawLine(String line) {
    _enqueue(() async {
      final filePath = await getLogFilePath();
      await File(filePath)
          .writeAsString('$line\n', encoding: utf8, mode: FileMode.append);
    });
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
