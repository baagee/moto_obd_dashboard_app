import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import '../theme/app_fonts.dart';
import '../widgets/cyber_button.dart';
import '../widgets/cyber_toast.dart';
import 'notification_probe_channel.dart';

/// Plan B：高德导航通知抓包调试页。
///
/// 仅在 debug 构建从高级设置面板进入，用于在真机上验证：
/// 高德导航时，通知栏里到底有没有「转向 / 路名 / 距离」等信息。
///
/// 相比广播探针，这里额外提供「显示全部应用」开关——若高德通知里没数据，
/// 可借此确认监听服务本身是否正常工作。
class NotificationProbeScreen extends StatefulWidget {
  const NotificationProbeScreen({super.key});

  @override
  State<NotificationProbeScreen> createState() =>
      _NotificationProbeScreenState();
}

class _NotificationProbeScreenState extends State<NotificationProbeScreen> {
  StreamSubscription<Map<String, dynamic>>? _sub;
  final List<_NotifRecord> _records = [];
  final Set<String> _expanded = {};
  Map<String, int> _stats = {};
  bool _granted = false;
  bool _showAll = false;

  static const int _maxRecords = 300;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    try {
      _sub = NotificationProbeChannel.stream.listen(_onNotification,
          onError: (Object e) {
        if (mounted) CyberToast.show(context, '事件流错误：$e');
      });
      final results = await Future.wait([
        NotificationProbeChannel.isPermissionGranted(),
        NotificationProbeChannel.snapshot(),
        NotificationProbeChannel.stats(),
      ]);
      if (!mounted) return;
      setState(() {
        _granted = results[0] as bool;
        _records
          ..clear()
          ..addAll((results[1] as List).cast<Map<String, dynamic>>()
              .map(_NotifRecord.fromMap));
        _stats = results[2] as Map<String, int>;
      });
    } on MissingPluginException {
      if (mounted) CyberToast.show(context, '探针未注册（需 debug 构建）');
    }
  }

  void _onNotification(Map<String, dynamic> data) {
    if (!mounted) return;
    setState(() {
      _records.add(_NotifRecord.fromMap(data));
      if (_records.length > _maxRecords) {
        _records.removeRange(0, _records.length - _maxRecords);
      }
      final pkg = data['pkg']?.toString() ?? '';
      if (pkg.isNotEmpty && pkg != '_local') {
        _stats[pkg] = (_stats[pkg] ?? 0) + 1;
      }
    });
  }

  Future<void> _refreshPermission() async {
    final granted = await NotificationProbeChannel.isPermissionGranted();
    if (!mounted) return;
    setState(() => _granted = granted);
    CyberToast.show(context, granted ? '已获得通知使用权' : '尚未获得通知使用权');
  }

  Future<void> _openSettings() async {
    await NotificationProbeChannel.openSettings();
    if (mounted) {
      CyberToast.show(context, '请在列表中勾选「高德通知抓包(调试)」');
    }
  }

  Future<void> _toggleShowAll() async {
    final next = !_showAll;
    await NotificationProbeChannel.setShowAll(next);
    if (!mounted) return;
    setState(() => _showAll = next);
    CyberToast.show(context, next ? '已开启：记录全部应用通知' : '已关闭：仅记录高德通知');
  }

  Future<void> _clear() async {
    await NotificationProbeChannel.clear();
    if (!mounted) return;
    setState(() {
      _records.clear();
      _stats = {};
      _expanded.clear();
    });
  }

  Future<void> _copyAll() async {
    if (_records.isEmpty) {
      CyberToast.show(context, '暂无数据可复制');
      return;
    }
    final buffer = StringBuffer();
    buffer.writeln('=== 高德通知抓包日志（共 ${_records.length} 条）===');
    buffer.writeln('包名统计：${_statsText()}');
    buffer.writeln('');
    for (final r in _records) {
      buffer.writeln(r.toLogLine());
    }
    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    if (mounted) CyberToast.show(context, '已复制 ${_records.length} 条日志');
  }

  String _statsText() {
    if (_stats.isEmpty) return '无';
    final entries = _stats.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.map((e) => '${e.key}:${e.value}').join('  ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildPermissionBar(),
            _buildToolbar(),
            _buildStatsBar(),
            Expanded(child: _buildList()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.primary20)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            behavior: HitTestBehavior.opaque,
            child: const Icon(Icons.arrow_back_ios_new,
                size: 16, color: AppTheme.primary),
          ),
          const SizedBox(width: 12),
          const Icon(Icons.notifications_active_outlined,
              size: 16, color: AppTheme.primary),
          const SizedBox(width: 8),
          const Text('高德通知抓包 · Plan B', style: AppTheme.titleMedium),
          const Spacer(),
          Text(
            '${_records.length} 条',
            style: AppFonts.monoStyle(
                fontSize: 11, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionBar() {
    final color = _granted ? AppTheme.accentGreen : AppTheme.accentOrange;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: color.withValues(alpha: 0.08),
      child: Row(
        children: [
          Icon(
            _granted ? Icons.check_circle_outline : Icons.warning_amber_outlined,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              _granted
                  ? '已获得「通知使用权」，等待高德发出通知…'
                  : '未获得「通知使用权」——必须先在系统设置里授权，否则收不到任何通知',
              style: TextStyle(color: color, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          CyberButton.secondary(
            text: '授权设置',
            height: 32,
            fontSize: 11,
            icon: Icons.settings_outlined,
            onPressed: _openSettings,
          ),
          const SizedBox(width: 8),
          CyberButton.secondary(
            text: '刷新权限',
            height: 32,
            fontSize: 11,
            icon: Icons.refresh,
            onPressed: _refreshPermission,
          ),
          const SizedBox(width: 8),
          CyberButton(
            text: _showAll ? '仅高德' : '显示全部',
            type: _showAll
                ? CyberButtonType.primary
                : CyberButtonType.secondary,
            height: 32,
            fontSize: 11,
            icon: Icons.apps,
            onPressed: _toggleShowAll,
          ),
          const Spacer(),
          CyberButton.secondary(
            text: '复制全部',
            height: 32,
            fontSize: 11,
            icon: Icons.copy,
            onPressed: _copyAll,
          ),
          const SizedBox(width: 8),
          CyberButton.secondary(
            text: '清空',
            height: 32,
            fontSize: 11,
            icon: Icons.clear_all,
            onPressed: _clear,
          ),
        ],
      ),
    );
  }

  Widget _buildStatsBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: AppTheme.surface40,
      child: Text(
        '包名分布：${_statsText()}',
        style: AppFonts.monoStyle(fontSize: 10, color: AppTheme.textSecondary),
      ),
    );
  }

  Widget _buildList() {
    if (_records.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.notifications_none,
                  size: 40, color: AppTheme.textMuted),
              const SizedBox(height: 12),
              Text(
                _granted
                    ? '已授权，等待通知中…\n请打开高德开始导航，或点「显示全部」确认监听是否生效'
                    : '请先点「授权设置」，在系统列表里勾选「高德通知抓包(调试)」',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _records.length,
      itemBuilder: (context, index) => _buildRecordTile(_records[index]),
    );
  }

  Widget _buildRecordTile(_NotifRecord record) {
    if (record.isLocal) {
      return Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: const BoxDecoration(
          border: Border(left: BorderSide(color: AppTheme.textMuted, width: 2)),
        ),
        child: Text(
          '· ${record.title ?? ''}',
          style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
        ),
      );
    }

    final isAmap = _NotifRecord.amapPackages.contains(record.pkg);
    final accent = isAmap ? AppTheme.gaugeNormal : AppTheme.primary60;
    final expanded = _expanded.contains(record.key);

    return GestureDetector(
      onTap: () => setState(() {
        if (expanded) {
          _expanded.remove(record.key);
        } else {
          _expanded.add(record.key);
        }
      }),
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          color: AppTheme.surface50,
          border: Border(left: BorderSide(color: accent, width: 2)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  record.pkg,
                  style: AppFonts.monoStyle(fontSize: 11, color: accent),
                ),
                const SizedBox(width: 8),
                Text(
                  record.timeText,
                  style: AppFonts.monoStyle(
                      fontSize: 10, color: AppTheme.textMuted),
                ),
                const Spacer(),
                if (record.isOngoing)
                  const Text('常驻',
                      style: TextStyle(
                          color: AppTheme.accentOrange, fontSize: 10)),
                Icon(
                  expanded ? Icons.expand_less : Icons.expand_more,
                  size: 14,
                  color: AppTheme.textMuted,
                ),
              ],
            ),
            if (record.title != null) ...[
              const SizedBox(height: 4),
              Text(
                record.title!,
                style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold),
              ),
            ],
            if (record.text != null) ...[
              const SizedBox(height: 2),
              Text(
                record.text!,
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 11),
              ),
            ],
            if (record.bigText != null) ...[
              const SizedBox(height: 2),
              Text(
                'BIG: ${record.bigText}',
                style: AppFonts.monoStyle(
                    fontSize: 10, color: AppTheme.accentCyan),
              ),
            ],
            // 自定义视图里反射出的文本——高德转向卡片最可能藏在这里
            if (record.remoteViewsText.isNotEmpty) ...[
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                color: AppTheme.gaugeNormal.withValues(alpha: 0.08),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '自定义视图文本（${record.remoteViewsText.length} 项）',
                      style: AppFonts.monoStyle(
                          fontSize: 9, color: AppTheme.gaugeNormal),
                    ),
                    const SizedBox(height: 2),
                    ...record.remoteViewsText.take(expanded ? 100 : 6).map(
                          (t) => Text(
                            t,
                            style: AppFonts.monoStyle(
                                fontSize: 9, color: AppTheme.textPrimary),
                          ),
                        ),
                  ],
                ),
              ),
            ],
            if (expanded) ...[
              const SizedBox(height: 6),
              const Divider(color: AppTheme.primary20, height: 1),
              const SizedBox(height: 6),
              Text(
                '全部 extras：',
                style: AppFonts.monoStyle(
                    fontSize: 10, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 4),
              ...record.extrasAll.entries.map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    '${e.key} = ${e.value}',
                    style: AppFonts.monoStyle(
                        fontSize: 9, color: AppTheme.textSecondary),
                  ),
                ),
              ),
              if (record.actions.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  '按钮：${record.actions.join(' | ')}',
                  style: AppFonts.monoStyle(
                      fontSize: 10, color: AppTheme.accentOrange),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

/// 单条通知记录
class _NotifRecord {
  final Map<String, dynamic> data;

  _NotifRecord(this.data);

  factory _NotifRecord.fromMap(Map<String, dynamic> map) => _NotifRecord(map);

  static const Set<String> amapPackages = {
    'com.autonavi.minimap',
    'com.autonavi.amapauto',
    'com.autonavi.amap',
  };

  String get pkg => data['pkg']?.toString() ?? '';
  bool get isLocal => data['_kind'] == 'local';
  bool get isOngoing => data['isOngoing'] == true;
  String? get title => data['EXTRA_TITLE']?.toString();
  String? get text => data['EXTRA_TEXT']?.toString();
  String? get bigText => data['EXTRA_BIG_TEXT']?.toString();

  List<String> get actions {
    final a = data['actions'];
    if (a is List) return a.map((e) => e.toString()).toList();
    return const [];
  }

  /// 自定义视图（RemoteViews）内反射读出的文本
  List<String> get remoteViewsText {
    final a = data['remoteViewsText'];
    if (a is List) return a.map((e) => e.toString()).toList();
    return const [];
  }

  Map<String, dynamic> get extrasAll {
    final e = data['extrasAll'];
    if (e is Map) return Map<String, dynamic>.from(e);
    return const {};
  }

  /// 唯一 key，用于展开状态
  String get key => '${data['_ts']}_$pkg';

  String get timeText {
    final ms = data['_ts'];
    if (ms is! int) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(dt.hour)}:${two(dt.minute)}:${two(dt.second)}';
  }

  /// 复制到剪贴板时的单行输出
  String toLogLine() {
    final b = StringBuffer();
    b.write('[$timeText][$pkg]');
    if (isOngoing) b.write('[常驻]');
    if (title != null) b.write(' TITLE=$title');
    if (text != null) b.write(' TEXT=$text');
    if (bigText != null) b.write(' BIG=$bigText');
    if (data['hasCustomView'] == true) b.write(' CUSTOM_VIEW=true');
    if (data['largeIconInfo'] != null) b.write(' LARGE_ICON=${data['largeIconInfo']}');
    if (remoteViewsText.isNotEmpty) {
      b.write(' RV=${remoteViewsText.join(' | ')}');
    }
    if (extrasAll.isNotEmpty) b.write(' extras=$extrasAll');
    return b.toString();
  }
}
