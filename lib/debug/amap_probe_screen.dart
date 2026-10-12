import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import '../theme/app_fonts.dart';
import '../widgets/cyber_button.dart';
import '../widgets/cyber_toast.dart';
import 'amap_probe_channel.dart';

/// Phase 0：高德导航广播抓包调试页。
///
/// 仅在 debug 构建从高级设置面板进入，用于在真机上验证：
/// 目标机型 + 目标高德版本能否收到 `AUTONAVI_STANDARD_BROADCAST_SEND`。
///
/// UI 遵循项目赛博风：复用 [CyberButton] / [AppTheme] / [AppFonts]。
class AmapProbeScreen extends StatefulWidget {
  const AmapProbeScreen({super.key});

  @override
  State<AmapProbeScreen> createState() => _AmapProbeScreenState();
}

class _AmapProbeScreenState extends State<AmapProbeScreen> {
  StreamSubscription<Map<String, dynamic>>? _sub;
  final List<_ProbeRecord> _records = [];
  final Map<int, int> _keyTypeCount = {};
  bool _listening = false;
  final ScrollController _scrollController = ScrollController();

  static const int _maxRecords = 500;

  @override
  void dispose() {
    _stop();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    if (_listening) return;
    try {
      _sub = AmapProbeChannel.stream.listen(_onBroadcast, onError: (Object e) {
        if (mounted) CyberToast.show(context, '事件流错误：$e');
      });
      await AmapProbeChannel.start();
      if (mounted) setState(() => _listening = true);
      // 本地记录：确认接收器已注册（不代表高德会发广播）
      _addLocalRecord('接收器已注册，等待高德广播…');
    } on PlatformException catch (e) {
      if (mounted) CyberToast.show(context, '启动失败：${e.message}');
    } on MissingPluginException {
      if (mounted) CyberToast.show(context, '探针未注册（需 debug 构建）');
    }
  }

  Future<void> _selfTest() async {
    try {
      await AmapProbeChannel.selfTest();
      if (mounted) {
        CyberToast.show(context, '已发出自测广播，观察列表');
      }
    } catch (e) {
      if (mounted) CyberToast.show(context, '自测失败：$e');
    }
  }

  /// 插入一条本地调试记录（非高德广播），用于显示探针自身状态
  void _addLocalRecord(String message) {
    setState(() {
      _records.insert(
        0,
        _ProbeRecord(
          keyType: -1,
          data: {
            '_ts': DateTime.now().millisecondsSinceEpoch,
            '_local': message,
          },
        ),
      );
      if (_records.length > _maxRecords) {
        _records.removeRange(_maxRecords, _records.length);
      }
    });
  }

  Future<void> _stop() async {
    await _sub?.cancel();
    _sub = null;
    try {
      await AmapProbeChannel.stop();
    } catch (_) {}
    if (mounted) setState(() => _listening = false);
  }

  Future<void> _queryState() async {
    try {
      await AmapProbeChannel.queryState();
      if (mounted) CyberToast.show(context, '已发送查询广播');
    } catch (e) {
      if (mounted) CyberToast.show(context, '查询失败：$e');
    }
  }

  void _onBroadcast(Map<String, dynamic> data) {
    final keyType = _asInt(data['KEY_TYPE']);
    setState(() {
      _records.insert(0, _ProbeRecord(keyType: keyType, data: data));
      if (_records.length > _maxRecords) {
        _records.removeRange(_maxRecords, _records.length);
      }
      _keyTypeCount[keyType] = (_keyTypeCount[keyType] ?? 0) + 1;
    });
  }

  void _clear() {
    setState(() {
      _records.clear();
      _keyTypeCount.clear();
    });
  }

  Future<void> _copyAll() async {
    if (_records.isEmpty) {
      CyberToast.show(context, '暂无数据可复制');
      return;
    }
    final buffer = StringBuffer();
    buffer.writeln('=== 高德广播抓包日志（共 ${_records.length} 条）===');
    buffer.writeln('统计：${_statsText()}');
    buffer.writeln('');
    for (final r in _records.reversed) {
      buffer.writeln('[KEY_TYPE=${r.keyType}] ${r.data}');
    }
    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    if (mounted) CyberToast.show(context, '已复制 ${_records.length} 条日志');
  }

  String _statsText() {
    if (_keyTypeCount.isEmpty) return '无';
    final entries = _keyTypeCount.entries.toList()
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
          const Icon(Icons.wifi_tethering, size: 16, color: AppTheme.primary),
          const SizedBox(width: 8),
          const Text('高德广播抓包 · Phase 0', style: AppTheme.titleMedium),
          const Spacer(),
          _buildStatusDot(),
        ],
      ),
    );
  }

  Widget _buildStatusDot() {
    final color = _listening ? AppTheme.gaugeNormal : AppTheme.textMuted;
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: _listening ? AppTheme.glowShadow(color, blur: 6) : null,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          _listening ? '监听中' : '已停止',
          style: TextStyle(color: color, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          CyberButton(
            text: _listening ? '停止监听' : '开始监听',
            type: _listening
                ? CyberButtonType.danger
                : CyberButtonType.success,
            height: 32,
            fontSize: 11,
            icon: _listening ? Icons.stop : Icons.play_arrow,
            onPressed: _listening ? _stop : _start,
          ),
          const SizedBox(width: 8),
          CyberButton.secondary(
            text: '主动查询',
            height: 32,
            fontSize: 11,
            icon: Icons.help_outline,
            onPressed: _queryState,
          ),
          const SizedBox(width: 8),
          CyberButton.secondary(
            text: '自测',
            height: 32,
            fontSize: 11,
            icon: Icons.bug_report_outlined,
            onPressed: _selfTest,
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
        '总计 ${_records.length} 条  |  KEY_TYPE 分布：${_statsText()}',
        style: AppFonts.monoStyle(fontSize: 10, color: AppTheme.textSecondary),
      ),
    );
  }

  Widget _buildList() {
    if (_records.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.radar, size: 40, color: AppTheme.textMuted),
            const SizedBox(height: 12),
            Text(
              _listening ? '监听中，请打开高德开始导航…' : '点击「开始监听」后打开高德导航',
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(8),
      itemCount: _records.length,
      itemBuilder: (context, index) => _buildRecordTile(_records[index]),
    );
  }

  Widget _buildRecordTile(_ProbeRecord record) {
    if (record.isLocal) {
      return Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: const BoxDecoration(
          border: Border(left: BorderSide(color: AppTheme.textMuted, width: 2)),
        ),
        child: Text(
          '· ${record.data['_local']}',
          style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
        ),
      );
    }
    final isNavi = record.keyType == 10001;
    final isSelfTest = record.data['_SELF_TEST'] == true;
    final accent = isSelfTest
        ? AppTheme.accentGreen
        : (isNavi ? AppTheme.gaugeNormal : AppTheme.primary60);
    return Container(
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
                isSelfTest ? '自测回环 KEY_TYPE=${record.keyType}' : 'KEY_TYPE=${record.keyType}',
                style: AppFonts.monoStyle(fontSize: 11, color: accent),
              ),
              const SizedBox(width: 8),
              Text(
                _formatTs(record.data['_ts']),
                style: AppFonts.monoStyle(
                    fontSize: 10, color: AppTheme.textMuted),
              ),
            ],
          ),
          // 导航信息优先展示关键字段
          if (isNavi) ...[
            const SizedBox(height: 4),
            _buildNaviHighlight(record.data),
          ],
          const SizedBox(height: 4),
          Text(
            _formatFields(record.data),
            style: AppFonts.monoStyle(
                fontSize: 10, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildNaviHighlight(Map<String, dynamic> data) {
    final icon = _asInt(data['NEW_ICON']) != 0
        ? _asInt(data['NEW_ICON'])
        : _asInt(data['ICON']);
    final road = data['NEXT_ROAD_NAME']?.toString() ?? '-';
    final dist = data['SEG_REMAIN_DIS_AUTO']?.toString() ?? '-';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: AppTheme.gaugeNormal.withValues(alpha: 0.08),
      child: Text(
        'ICON=$icon  →  $road  剩余 $dist',
        style: AppFonts.monoStyle(fontSize: 11, color: AppTheme.gaugeNormal),
      ),
    );
  }

  String _formatFields(Map<String, dynamic> data) {
    final entries = data.entries
        .where((e) => e.key != '_action' && e.key != '_ts')
        .map((e) => '${e.key}=${e.value}')
        .toList();
    return entries.join('  ');
  }

  String _formatTs(dynamic ts) {
    final ms = _asInt(ts);
    if (ms == 0) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(dt.hour)}:${two(dt.minute)}:${two(dt.second)}.'
        '${dt.millisecond.toString().padLeft(3, '0')}';
  }

  static int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? double.tryParse(v)?.toInt() ?? 0;
    return 0;
  }
}

/// 单条抓包记录
class _ProbeRecord {
  final int keyType;
  final Map<String, dynamic> data;

  _ProbeRecord({required this.keyType, required this.data});

  /// 本地调试记录（非高德广播）
  bool get isLocal => keyType == -1;
}
