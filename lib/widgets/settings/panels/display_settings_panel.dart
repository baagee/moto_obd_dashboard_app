import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/cyber_button.dart';
import '../../../widgets/cyber_dialog.dart';
import '../settings_fields.dart';

/// 仪表盘显示量程设置面板
class DisplaySettingsPanel extends StatefulWidget {
  const DisplaySettingsPanel({super.key});

  @override
  State<DisplaySettingsPanel> createState() => _DisplaySettingsPanelState();
}

class _DisplaySettingsPanelState extends State<DisplaySettingsPanel> {
  late Map<String, dynamic> _draft;

  @override
  void initState() {
    super.initState();
    _loadDraft();
  }

  void _loadDraft() {
    final s = context.read<SettingsProvider>();
    _draft = {
      'maxRpm': s.maxRpm.toDouble(),
      'warnRpm': s.warnRpm.toDouble(),
      'dangerRpm': s.dangerRpm.toDouble(),
      'maxSpeed': s.maxSpeed.toDouble(),
      'warnSpeed': s.warnSpeed.toDouble(),
      'dangerSpeed': s.dangerSpeed.toDouble(),
      'flashThreshold': s.flashThreshold.toDouble(),
      'maxCoolantTemp': s.maxCoolantTemp.toDouble(),
      'coolantWarnTemp': s.coolantWarnTemp.toDouble(),
      'maxIntakeTemp': s.maxIntakeTemp.toDouble(),
      'intakeWarnTemp': s.intakeWarnTemp.toDouble(),
    };
  }

  Future<void> _onSave() async {
    await context.read<SettingsProvider>().setBatch({
      'settings_display_maxRpm': (_draft['maxRpm'] as double).toInt(),
      'settings_display_warnRpm': (_draft['warnRpm'] as double).toInt(),
      'settings_display_dangerRpm': (_draft['dangerRpm'] as double).toInt(),
      'settings_display_maxSpeed': (_draft['maxSpeed'] as double).toInt(),
      'settings_display_warnSpeed': (_draft['warnSpeed'] as double).toInt(),
      'settings_display_dangerSpeed': (_draft['dangerSpeed'] as double).toInt(),
      'settings_display_flashThreshold':
          (_draft['flashThreshold'] as double).toInt(),
      'settings_display_maxCoolantTemp':
          (_draft['maxCoolantTemp'] as double).toInt(),
      'settings_display_coolantWarnTemp':
          (_draft['coolantWarnTemp'] as double).toInt(),
      'settings_display_maxIntakeTemp':
          (_draft['maxIntakeTemp'] as double).toInt(),
      'settings_display_intakeWarnTemp':
          (_draft['intakeWarnTemp'] as double).toInt(),
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('仪表盘量程已保存，立即生效'),
          backgroundColor: AppTheme.accentGreen,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _confirmReset() async {
    final confirmed = await CyberDialog.show<bool>(
      context: context,
      title: '重置确认',
      icon: Icons.refresh,
      accentColor: AppTheme.accentOrange,
      content: const Text('将把仪表盘显示量程恢复为默认值（GSX-8S），是否继续？'),
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
      await context.read<SettingsProvider>().resetGroup('display');
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
          const Icon(Icons.speed_outlined, size: 16, color: AppTheme.primary),
          const SizedBox(width: 8),
          const Text('仪表盘量程', style: AppTheme.titleMedium),
          const Spacer(),
          CyberButton.secondary(
            text: '重置本组',
            height: 30,
            fontSize: 11,
            onPressed: _confirmReset,
          ),
          const SizedBox(width: 8),
          CyberButton.primary(
            text: '保 存',
            width: 90,
            height: 30,
            fontSize: 11,
            icon: Icons.save_outlined,
            onPressed: _onSave,
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
            message: '修改量程后无需重启，仪表盘实时生效。\n'
                '颜色区间：正常 → 警告（橙/紫）→ 危险（红）。',
          ),

          // ── 转速表 RPM ──
          const SettingsSectionTitle('▸  转速表 (RPM)'),
          SettingsSliderField(
            label: '最大量程',
            value: _draft['maxRpm'],
            defaultValue: 12000,
            min: 8000,
            max: 20000,
            divisions: 12,
            valueFormatter: (v) => '${v.toInt()} rpm',
            onChanged: (v) => setState(() => _draft['maxRpm'] = v),
          ),
          SettingsSliderField(
            label: '警告转速（变橙色）',
            value: _draft['warnRpm'],
            defaultValue: 7000,
            min: 3000,
            max: 15000,
            divisions: 24,
            valueFormatter: (v) => '${v.toInt()} rpm',
            onChanged: (v) => setState(() => _draft['warnRpm'] = v),
          ),
          SettingsSliderField(
            label: '危险转速（变红色）',
            value: _draft['dangerRpm'],
            defaultValue: 9000,
            min: 5000,
            max: 18000,
            divisions: 26,
            valueFormatter: (v) => '${v.toInt()} rpm',
            onChanged: (v) => setState(() => _draft['dangerRpm'] = v),
          ),

          const SettingsDivider(),

          // ── 速度表 Speed ──
          const SettingsSectionTitle('▸  速度表 (km/h)'),
          SettingsSliderField(
            label: '最大量程',
            value: _draft['maxSpeed'],
            defaultValue: 240,
            min: 100,
            max: 350,
            divisions: 25,
            valueFormatter: (v) => '${v.toInt()} km/h',
            onChanged: (v) => setState(() => _draft['maxSpeed'] = v),
          ),
          SettingsSliderField(
            label: '警告车速（变紫色）',
            value: _draft['warnSpeed'],
            defaultValue: 120,
            min: 60,
            max: 250,
            divisions: 19,
            valueFormatter: (v) => '${v.toInt()} km/h',
            onChanged: (v) => setState(() => _draft['warnSpeed'] = v),
          ),
          SettingsSliderField(
            label: '危险车速（变红色）',
            value: _draft['dangerSpeed'],
            defaultValue: 180,
            min: 100,
            max: 320,
            divisions: 22,
            valueFormatter: (v) => '${v.toInt()} km/h',
            onChanged: (v) => setState(() => _draft['dangerSpeed'] = v),
          ),
          SettingsSliderField(
            label: '超速闪烁阈值',
            hint: '车速超过此值时仪表盘外圈触发闪烁警告',
            value: _draft['flashThreshold'],
            defaultValue: 100,
            min: 60,
            max: 300,
            divisions: 24,
            valueFormatter: (v) => '${v.toInt()} km/h',
            onChanged: (v) => setState(() => _draft['flashThreshold'] = v),
          ),

          const SettingsDivider(),

          // ── 温度进度条 ──
          const SettingsSectionTitle('▸  温度进度条'),
          SettingsSliderField(
            label: '冷却水温最大值',
            value: _draft['maxCoolantTemp'],
            defaultValue: 120,
            min: 80,
            max: 150,
            divisions: 14,
            valueFormatter: (v) => '${v.toInt()} °C',
            onChanged: (v) => setState(() => _draft['maxCoolantTemp'] = v),
          ),
          SettingsSliderField(
            label: '冷却水温警告值（变橙/红）',
            value: _draft['coolantWarnTemp'],
            defaultValue: 100,
            min: 60,
            max: 140,
            divisions: 16,
            valueFormatter: (v) => '${v.toInt()} °C',
            onChanged: (v) => setState(() => _draft['coolantWarnTemp'] = v),
          ),
          SettingsSliderField(
            label: '进气温度最大值',
            value: _draft['maxIntakeTemp'],
            defaultValue: 80,
            min: 40,
            max: 120,
            divisions: 16,
            valueFormatter: (v) => '${v.toInt()} °C',
            onChanged: (v) => setState(() => _draft['maxIntakeTemp'] = v),
          ),
          SettingsSliderField(
            label: '进气温度警告值（变橙/红）',
            value: _draft['intakeWarnTemp'],
            defaultValue: 50,
            min: 20,
            max: 100,
            divisions: 16,
            valueFormatter: (v) => '${v.toInt()} °C',
            onChanged: (v) => setState(() => _draft['intakeWarnTemp'] = v),
          ),
        ],
      ),
    );
  }
}
