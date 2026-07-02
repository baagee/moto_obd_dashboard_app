import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/cyber_button.dart';
import '../../../widgets/cyber_dialog.dart';
import '../../../widgets/cyber_toast.dart';
import '../settings_fields.dart';

/// 高级设置面板（传感器 / GPS 参数）
class AdvancedSettingsPanel extends StatefulWidget {
  const AdvancedSettingsPanel({super.key});

  @override
  State<AdvancedSettingsPanel> createState() => _AdvancedSettingsPanelState();
}

class _AdvancedSettingsPanelState extends State<AdvancedSettingsPanel> {
  late Map<String, dynamic> _draft;
  late Map<String, dynamic> _original;

  bool get _isDirty => !settingsMapsEqual(_draft, _original);

  @override
  void initState() {
    super.initState();
    _loadDraft();
  }

  void _loadDraft() {
    final s = context.read<SettingsProvider>();
    _original = {
      'minMoveDistance': s.minMoveDistance,
      'maxGpsGapSeconds': s.maxGpsGapSeconds.toDouble(),
      'minRidingDistance': s.minRidingDistance.toDouble(),
      'maxEventHistory': s.maxEventHistory.toDouble(),
    };
    _draft = Map.from(_original);
  }

  Future<void> _onSave() async {
    await context.read<SettingsProvider>().setBatch({
      'settings_advanced_minMoveDistance': _draft['minMoveDistance'] as double,
      'settings_advanced_maxGpsGapSeconds':
          (_draft['maxGpsGapSeconds'] as double).toInt(),
      'settings_advanced_minRidingDistance':
          (_draft['minRidingDistance'] as double).toInt(),
      'settings_advanced_maxEventHistory':
          (_draft['maxEventHistory'] as double).toInt(),
    });
    if (mounted) setState(() => _original = Map.from(_draft));
    if (mounted) CyberToast.show(context, '高级参数已保存');
  }

  Future<void> _confirmReset() async {
    final confirmed = await CyberDialog.show<bool>(
      context: context,
      title: '重置确认',
      icon: Icons.refresh,
      accentColor: AppTheme.accentOrange,
      content: const Text('将把高级参数恢复为默认值，是否继续？'),
      actions: [
        CyberButton.secondary(
          text: '取消',
          height: 32,
          fontSize: 11,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        const SizedBox(width: 8),
        CyberButton.danger(
          text: '确认重置',
          height: 32,
          fontSize: 11,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
    if (confirmed == true && mounted) {
      await context.read<SettingsProvider>().resetGroup('advanced');
      if (mounted) setState(() => _loadDraft());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.primary20)),
      ),
      child: Row(
        children: [
          const Icon(Icons.tune_outlined, size: 16, color: AppTheme.primary),
          const SizedBox(width: 8),
          const Text('高级设置', style: AppTheme.titleMedium),
          const Spacer(),
          CyberButton.secondary(
              text: '重置本组', height: 30, fontSize: 11, onPressed: _confirmReset),
          const SizedBox(width: 8),
          CyberButton.primary(
            text: '保 存',
            width: 90,
            height: 30,
            fontSize: 11,
            icon: Icons.save_outlined,
            onPressed: _isDirty ? _onSave : null,
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SettingsBanner(
            message: '以下参数面向调试用途，修改不当可能影响骑行事件检测。\n'
                '如无特殊需求，请勿更改默认值。',
            type: SettingsBannerType.danger,
          ),

          // ── GPS 过滤 ──
          const SettingsSectionTitle('▸  GPS 轨迹过滤'),
          SettingsSliderField(
            label: '最小移动距离',
            hint: '小于此距离视为静止，不计入 GPS 里程',
            value: _draft['minMoveDistance'],
            defaultValue: 3.0,
            min: 0.5,
            max: 20.0,
            divisions: 39,
            valueFormatter: (v) => '${v.toStringAsFixed(1)} m',
            onChanged: (v) => setState(() => _draft['minMoveDistance'] = v),
          ),
          SettingsSliderField(
            label: 'GPS 失联最大间隔',
            hint: '超过此时长的 GPS 跳跃视为失联，不计入里程',
            value: _draft['maxGpsGapSeconds'],
            defaultValue: 30,
            min: 5,
            max: 120,
            divisions: 23,
            valueFormatter: (v) => '${v.toInt()} s',
            onChanged: (v) => setState(() => _draft['maxGpsGapSeconds'] = v),
          ),
          SettingsSliderField(
            label: '骑行记录最小有效距离',
            hint: '行驶距离低于此值将被丢弃，防止误触产生无效记录',
            value: _draft['minRidingDistance'],
            defaultValue: 20,
            min: 5,
            max: 100,
            divisions: 19,
            valueFormatter: (v) => '${v.toInt()} m',
            onChanged: (v) => setState(() => _draft['minRidingDistance'] = v),
          ),

          const SettingsDivider(),

          // ── 事件历史 ──
          const SettingsSectionTitle('▸  事件记录'),
          SettingsSliderField(
            label: '事件历史最大条数',
            hint: '超过此数量时自动丢弃最旧的事件',
            value: _draft['maxEventHistory'],
            defaultValue: 100,
            min: 20,
            max: 500,
            divisions: 48,
            valueFormatter: (v) => '${v.toInt()} 条',
            onChanged: (v) => setState(() => _draft['maxEventHistory'] = v),
          ),
        ],
      ),
    );
  }
}
