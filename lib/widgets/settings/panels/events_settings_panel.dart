import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/cyber_button.dart';
import '../../../widgets/cyber_dialog.dart';
import '../../../widgets/cyber_toast.dart';
import '../settings_fields.dart';

/// 骑行事件设置面板
class EventsSettingsPanel extends StatefulWidget {
  const EventsSettingsPanel({super.key});

  @override
  State<EventsSettingsPanel> createState() => _EventsSettingsPanelState();
}

class _EventsSettingsPanelState extends State<EventsSettingsPanel> {
  late Map<String, dynamic> _draft;

  @override
  void initState() {
    super.initState();
    _loadDraft();
  }

  void _loadDraft() {
    final s = context.read<SettingsProvider>();
    _draft = {
      'globalCooldown': s.globalCooldownSeconds.toDouble(),
      // 性能爆发
      'performanceBurst_enabled': s.performanceBurstEnabled,
      'performanceBurst_rpm': s.performanceBurstRpm.toDouble(),
      // 引擎过热
      'engineOverheat_enabled': s.engineOverheatEnabled,
      'engineOverheat_temp': s.engineOverheatTemp.toDouble(),
      // 电压异常
      'voltageAnomaly_enabled': s.voltageAnomalyEnabled,
      'voltageAnomaly_low': s.voltageAnomalyLow,
      'voltageAnomaly_high': s.voltageAnomalyHigh,
      // 高负荷
      'highLoad_enabled': s.highLoadEnabled,
      'highLoad_threshold': s.highLoadThreshold.toDouble(),
      // 长途骑行
      'longRiding_enabled': s.longRidingEnabled,
      'longRiding_hours': s.longRidingDurationHours,
      'longRiding_cooldown': s.longRidingCooldownSeconds.toDouble(),
      // 高效巡航
      'efficientCruising_enabled': s.efficientCruisingEnabled,
      'efficientCruising_speedMin': s.efficientCruisingSpeedMin.toDouble(),
      'efficientCruising_speedMax': s.efficientCruisingSpeedMax.toDouble(),
      'efficientCruising_loadMax': s.efficientCruisingLoadMax.toDouble(),
      'efficientCruising_cooldown': s.efficientCruisingCooldown.toDouble(),
      // 引擎预热
      'engineWarmup_enabled': s.engineWarmupEnabled,
      'engineWarmup_temp': s.engineWarmupTemp.toDouble(),
      'engineWarmup_rpmMax': s.engineWarmupRpmMax.toDouble(),
      // 低温风险
      'coldRisk_enabled': s.coldRiskEnabled,
      'coldRisk_temp': s.coldRiskTemp.toDouble(),
      'coldRisk_speedMin': s.coldRiskSpeedMin.toDouble(),
      'coldRisk_cooldown': s.coldRiskCooldown.toDouble(),
      // 极限压弯
      'extremeLean_enabled': s.extremeLeanEnabled,
      'extremeLean_speedMin': s.extremeLeanSpeedMin.toDouble(),
      'extremeLean_angleMin': s.extremeLeanAngleMin.toDouble(),
      'extremeLean_cooldown': s.extremeLeanCooldown.toDouble(),
    };
  }

  Future<void> _onSave() async {
    await context.read<SettingsProvider>().setBatch({
      'settings_events_globalCooldown':
          (_draft['globalCooldown'] as double).toInt(),
      'settings_events_performanceBurst_enabled':
          _draft['performanceBurst_enabled'] as bool,
      'settings_events_performanceBurst_rpmThreshold':
          (_draft['performanceBurst_rpm'] as double).toInt(),
      'settings_events_engineOverheat_enabled':
          _draft['engineOverheat_enabled'] as bool,
      'settings_events_engineOverheat_tempThreshold':
          (_draft['engineOverheat_temp'] as double).toInt(),
      'settings_events_voltageAnomaly_enabled':
          _draft['voltageAnomaly_enabled'] as bool,
      'settings_events_voltageAnomaly_low':
          _draft['voltageAnomaly_low'] as double,
      'settings_events_voltageAnomaly_high':
          _draft['voltageAnomaly_high'] as double,
      'settings_events_highLoad_enabled': _draft['highLoad_enabled'] as bool,
      'settings_events_highLoad_threshold':
          (_draft['highLoad_threshold'] as double).toInt(),
      'settings_events_longRiding_enabled':
          _draft['longRiding_enabled'] as bool,
      'settings_events_longRiding_durationHours':
          _draft['longRiding_hours'] as double,
      'settings_events_longRiding_cooldown':
          (_draft['longRiding_cooldown'] as double).toInt(),
      'settings_events_efficientCruising_enabled':
          _draft['efficientCruising_enabled'] as bool,
      'settings_events_efficientCruising_speedMin':
          (_draft['efficientCruising_speedMin'] as double).toInt(),
      'settings_events_efficientCruising_speedMax':
          (_draft['efficientCruising_speedMax'] as double).toInt(),
      'settings_events_efficientCruising_loadMax':
          (_draft['efficientCruising_loadMax'] as double).toInt(),
      'settings_events_efficientCruising_cooldown':
          (_draft['efficientCruising_cooldown'] as double).toInt(),
      'settings_events_engineWarmup_enabled':
          _draft['engineWarmup_enabled'] as bool,
      'settings_events_engineWarmup_temp':
          (_draft['engineWarmup_temp'] as double).toInt(),
      'settings_events_engineWarmup_rpmMax':
          (_draft['engineWarmup_rpmMax'] as double).toInt(),
      'settings_events_coldRisk_enabled': _draft['coldRisk_enabled'] as bool,
      'settings_events_coldRisk_temp':
          (_draft['coldRisk_temp'] as double).toInt(),
      'settings_events_coldRisk_speedMin':
          (_draft['coldRisk_speedMin'] as double).toInt(),
      'settings_events_coldRisk_cooldown':
          (_draft['coldRisk_cooldown'] as double).toInt(),
      'settings_events_extremeLean_enabled':
          _draft['extremeLean_enabled'] as bool,
      'settings_events_extremeLean_speedMin':
          (_draft['extremeLean_speedMin'] as double).toInt(),
      'settings_events_extremeLean_angleMin':
          (_draft['extremeLean_angleMin'] as double).toInt(),
      'settings_events_extremeLean_cooldown':
          (_draft['extremeLean_cooldown'] as double).toInt(),
    });
    if (mounted) CyberToast.show(context, '骑行事件设置已保存');
  }

  Future<void> _confirmReset() async {
    final confirmed = await CyberDialog.show<bool>(
      context: context,
      title: '重置确认',
      icon: Icons.refresh,
      accentColor: AppTheme.accentOrange,
      content: const Text('将把骑行事件阈值恢复为默认值，是否继续？'),
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
      await context.read<SettingsProvider>().resetGroup('events');
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
          const Icon(Icons.notifications_active_outlined,
              size: 16, color: AppTheme.primary),
          const SizedBox(width: 8),
          const Text('骑行事件', style: AppTheme.titleMedium),
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
          // ── 全局冷却 ──
          const SettingsSectionTitle('▸  全局配置'),
          SettingsSliderField(
            label: '全局事件冷却时间',
            hint: '同一事件触发后，此时间内不再重复提醒',
            value: _draft['globalCooldown'],
            defaultValue: 30,
            min: 5,
            max: 300,
            divisions: 59,
            valueFormatter: (v) => '${v.toInt()} s',
            onChanged: (v) => setState(() => _draft['globalCooldown'] = v),
          ),

          const SettingsDivider(),

          // ── 性能爆发 ──
          _buildEventSection(
            icon: Icons.flash_on,
            title: '性能爆发',
            enabledKey: 'performanceBurst_enabled',
            children: [
              SettingsSliderField(
                label: 'RPM 触发阈值',
                value: _draft['performanceBurst_rpm'],
                defaultValue: 6300,
                min: 3000,
                max: 12000,
                divisions: 90,
                valueFormatter: (v) => '${v.toInt()} rpm',
                onChanged: (v) =>
                    setState(() => _draft['performanceBurst_rpm'] = v),
              ),
            ],
          ),

          const SettingsDivider(),

          // ── 引擎过热 ──
          _buildEventSection(
            icon: Icons.thermostat,
            title: '引擎过热',
            enabledKey: 'engineOverheat_enabled',
            children: [
              SettingsSliderField(
                label: '水温警告阈值',
                value: _draft['engineOverheat_temp'],
                defaultValue: 105,
                min: 80,
                max: 130,
                divisions: 50,
                valueFormatter: (v) => '${v.toInt()} °C',
                onChanged: (v) =>
                    setState(() => _draft['engineOverheat_temp'] = v),
              ),
            ],
          ),

          const SettingsDivider(),

          // ── 电压异常 ──
          _buildEventSection(
            icon: Icons.bolt,
            title: '电压异常',
            enabledKey: 'voltageAnomaly_enabled',
            children: [
              SettingsSliderField(
                label: '欠压阈值',
                value: _draft['voltageAnomaly_low'],
                defaultValue: 11.5,
                min: 9.0,
                max: 13.0,
                divisions: 40,
                valueFormatter: (v) => '${v.toStringAsFixed(1)} V',
                onChanged: (v) =>
                    setState(() => _draft['voltageAnomaly_low'] = v),
              ),
              SettingsSliderField(
                label: '过压阈值',
                value: _draft['voltageAnomaly_high'],
                defaultValue: 15.3,
                min: 14.0,
                max: 18.0,
                divisions: 40,
                valueFormatter: (v) => '${v.toStringAsFixed(1)} V',
                onChanged: (v) =>
                    setState(() => _draft['voltageAnomaly_high'] = v),
              ),
            ],
          ),

          const SettingsDivider(),

          // ── 高发动机负荷 ──
          _buildEventSection(
            icon: Icons.speed,
            title: '高发动机负荷',
            enabledKey: 'highLoad_enabled',
            children: [
              SettingsSliderField(
                label: '负荷触发阈值',
                value: _draft['highLoad_threshold'],
                defaultValue: 70,
                min: 30,
                max: 100,
                divisions: 14,
                valueFormatter: (v) => '${v.toInt()} %',
                onChanged: (v) =>
                    setState(() => _draft['highLoad_threshold'] = v),
              ),
            ],
          ),

          const SettingsDivider(),

          // ── 长途骑行 ──
          _buildEventSection(
            icon: Icons.route,
            title: '长途骑行',
            enabledKey: 'longRiding_enabled',
            children: [
              SettingsSliderField(
                label: '触发骑行时长',
                value: _draft['longRiding_hours'],
                defaultValue: 1.0,
                min: 0.5,
                max: 5.0,
                divisions: 9,
                valueFormatter: (v) => '${v.toStringAsFixed(1)} h',
                onChanged: (v) =>
                    setState(() => _draft['longRiding_hours'] = v),
              ),
              SettingsSliderField(
                label: '事件重复冷却',
                value: _draft['longRiding_cooldown'],
                defaultValue: 1200,
                min: 300,
                max: 3600,
                divisions: 55,
                valueFormatter: (v) => '${v.toInt()} s',
                onChanged: (v) =>
                    setState(() => _draft['longRiding_cooldown'] = v),
              ),
            ],
          ),

          const SettingsDivider(),

          // ── 高效巡航 ──
          _buildEventSection(
            icon: Icons.eco_outlined,
            title: '高效巡航',
            enabledKey: 'efficientCruising_enabled',
            children: [
              SettingsSliderField(
                label: '车速下限',
                value: _draft['efficientCruising_speedMin'],
                defaultValue: 70,
                min: 40,
                max: 100,
                divisions: 12,
                valueFormatter: (v) => '${v.toInt()} km/h',
                onChanged: (v) =>
                    setState(() => _draft['efficientCruising_speedMin'] = v),
              ),
              SettingsSliderField(
                label: '车速上限',
                value: _draft['efficientCruising_speedMax'],
                defaultValue: 100,
                min: 80,
                max: 160,
                divisions: 16,
                valueFormatter: (v) => '${v.toInt()} km/h',
                onChanged: (v) =>
                    setState(() => _draft['efficientCruising_speedMax'] = v),
              ),
              SettingsSliderField(
                label: '负荷上限',
                value: _draft['efficientCruising_loadMax'],
                defaultValue: 30,
                min: 10,
                max: 60,
                divisions: 10,
                valueFormatter: (v) => '${v.toInt()} %',
                onChanged: (v) =>
                    setState(() => _draft['efficientCruising_loadMax'] = v),
              ),
              SettingsSliderField(
                label: '事件冷却',
                value: _draft['efficientCruising_cooldown'],
                defaultValue: 300,
                min: 60,
                max: 1800,
                divisions: 58,
                valueFormatter: (v) => '${v.toInt()} s',
                onChanged: (v) =>
                    setState(() => _draft['efficientCruising_cooldown'] = v),
              ),
            ],
          ),

          const SettingsDivider(),

          // ── 引擎预热 ──
          _buildEventSection(
            icon: Icons.heat_pump_outlined,
            title: '引擎预热警告',
            enabledKey: 'engineWarmup_enabled',
            children: [
              SettingsSliderField(
                label: '水温阈值（低于此值触发）',
                value: _draft['engineWarmup_temp'],
                defaultValue: 70,
                min: 30,
                max: 90,
                divisions: 12,
                valueFormatter: (v) => '${v.toInt()} °C',
                onChanged: (v) =>
                    setState(() => _draft['engineWarmup_temp'] = v),
              ),
              SettingsSliderField(
                label: 'RPM 阈值（高于此值触发）',
                value: _draft['engineWarmup_rpmMax'],
                defaultValue: 6000,
                min: 3000,
                max: 10000,
                divisions: 14,
                valueFormatter: (v) => '${v.toInt()} rpm',
                onChanged: (v) =>
                    setState(() => _draft['engineWarmup_rpmMax'] = v),
              ),
            ],
          ),

          const SettingsDivider(),

          // ── 低温环境风险 ──
          _buildEventSection(
            icon: Icons.ac_unit,
            title: '低温环境风险',
            enabledKey: 'coldRisk_enabled',
            children: [
              SettingsSliderField(
                label: '进气温度阈值（低于触发）',
                value: _draft['coldRisk_temp'],
                defaultValue: 5,
                min: -20,
                max: 15,
                divisions: 35,
                valueFormatter: (v) => '${v.toInt()} °C',
                onChanged: (v) => setState(() => _draft['coldRisk_temp'] = v),
              ),
              SettingsSliderField(
                label: '最低车速要求',
                value: _draft['coldRisk_speedMin'],
                defaultValue: 40,
                min: 10,
                max: 80,
                divisions: 14,
                valueFormatter: (v) => '${v.toInt()} km/h',
                onChanged: (v) =>
                    setState(() => _draft['coldRisk_speedMin'] = v),
              ),
              SettingsSliderField(
                label: '事件冷却',
                value: _draft['coldRisk_cooldown'],
                defaultValue: 120,
                min: 30,
                max: 600,
                divisions: 19,
                valueFormatter: (v) => '${v.toInt()} s',
                onChanged: (v) =>
                    setState(() => _draft['coldRisk_cooldown'] = v),
              ),
            ],
          ),

          const SettingsDivider(),

          // ── 极限压弯 ──
          _buildEventSection(
            icon: Icons.rotate_right,
            title: '极限压弯',
            enabledKey: 'extremeLean_enabled',
            children: [
              SettingsSliderField(
                label: '最低车速要求',
                value: _draft['extremeLean_speedMin'],
                defaultValue: 60,
                min: 20,
                max: 100,
                divisions: 16,
                valueFormatter: (v) => '${v.toInt()} km/h',
                onChanged: (v) =>
                    setState(() => _draft['extremeLean_speedMin'] = v),
              ),
              SettingsSliderField(
                label: '倾角触发阈值',
                value: _draft['extremeLean_angleMin'],
                defaultValue: 20,
                min: 5,
                max: 60,
                divisions: 55,
                valueFormatter: (v) => '${v.toInt()} °',
                onChanged: (v) =>
                    setState(() => _draft['extremeLean_angleMin'] = v),
              ),
              SettingsSliderField(
                label: '事件冷却',
                value: _draft['extremeLean_cooldown'],
                defaultValue: 60,
                min: 10,
                max: 300,
                divisions: 29,
                valueFormatter: (v) => '${v.toInt()} s',
                onChanged: (v) =>
                    setState(() => _draft['extremeLean_cooldown'] = v),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEventSection({
    required IconData icon,
    required String title,
    required String enabledKey,
    required List<Widget> children,
  }) {
    final enabled = _draft[enabledKey] as bool;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon,
                size: 13,
                color: enabled ? AppTheme.primary : AppTheme.textMuted),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                color: enabled ? AppTheme.primary : AppTheme.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const Spacer(),
            Transform.scale(
              scale: 0.75,
              child: Switch(
                value: enabled,
                activeColor: AppTheme.primary,
                inactiveTrackColor: AppTheme.primary.withValues(alpha: 0.15),
                onChanged: (v) => setState(() => _draft[enabledKey] = v),
              ),
            ),
          ],
        ),
        if (enabled) ...[
          const SizedBox(height: 4),
          ...children,
        ],
      ],
    );
  }
}
