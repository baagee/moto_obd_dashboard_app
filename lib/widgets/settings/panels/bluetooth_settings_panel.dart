import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/cyber_button.dart';
import '../../../widgets/cyber_dialog.dart';
import '../../../widgets/cyber_dialog.dart';
import '../../../widgets/cyber_dialog.dart';
import '../../../widgets/cyber_dialog.dart';
import '../../../widgets/cyber_dialog.dart';
import '../../../widgets/cyber_toast.dart';
import '../settings_fields.dart';

/// 蓝牙参数设置面板
class BluetoothSettingsPanel extends StatefulWidget {
  const BluetoothSettingsPanel({super.key});

  @override
  State<BluetoothSettingsPanel> createState() => _BluetoothSettingsPanelState();
}

class _BluetoothSettingsPanelState extends State<BluetoothSettingsPanel> {
  late Map<String, dynamic> _draft;

  @override
  void initState() {
    super.initState();
    _loadDraft();
  }

  void _loadDraft() {
    final s = context.read<SettingsProvider>();
    _draft = {
      'scanTimeout': s.scanTimeoutSeconds.toDouble(),
      'minRssi': s.minRssi.toDouble(),
      'connectionTimeout': s.connectionTimeoutSeconds.toDouble(),
      'elm327InitWait': s.elm327InitWaitMs.toDouble(),
      'highSpeedInterval': s.highSpeedPidIntervalMs.toDouble(),
      'mediumSpeedInterval': s.mediumSpeedPidIntervalMs.toDouble(),
      'lowSpeedInterval': s.lowSpeedPidIntervalMs.toDouble(),
    };
  }

  Future<void> _onSave() async {
    await context.read<SettingsProvider>().setBatch({
      'settings_bluetooth_scanTimeout':
          (_draft['scanTimeout'] as double).toInt(),
      'settings_bluetooth_minRssi': (_draft['minRssi'] as double).toInt(),
      'settings_bluetooth_connectionTimeout':
          (_draft['connectionTimeout'] as double).toInt(),
      'settings_bluetooth_elm327InitWait':
          (_draft['elm327InitWait'] as double).toInt(),
      'settings_bluetooth_highSpeedPidInterval':
          (_draft['highSpeedInterval'] as double).toInt(),
      'settings_bluetooth_mediumSpeedPidInterval':
          (_draft['mediumSpeedInterval'] as double).toInt(),
      'settings_bluetooth_lowSpeedPidInterval':
          (_draft['lowSpeedInterval'] as double).toInt(),
    });
    if (mounted) CyberToast.show(context, '蓝牙参数已保存（下次连接时生效）');
  }

  Future<void> _confirmReset() async {
    final confirmed = await CyberDialog.show<bool>(
      context: context,
      title: '重置确认',
      icon: Icons.refresh,
      accentColor: AppTheme.accentOrange,
      content: const Text('将把蓝牙参数恢复为默认值，是否继续？'),
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
      await context.read<SettingsProvider>().resetGroup('bluetooth');
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
          const Icon(Icons.bluetooth_outlined,
              size: 16, color: AppTheme.primary),
          const SizedBox(width: 8),
          const Text('蓝牙连接', style: AppTheme.titleMedium),
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
            message: '修改蓝牙参数后，下次连接 ELM327 时才生效。\n'
                '调整前请确保理解各参数含义，错误配置可能导致连接失败。',
            type: SettingsBannerType.warning,
          ),

          // ── 扫描与连接 ──
          const SettingsSectionTitle('▸  扫描与连接'),
          SettingsSliderField(
            label: '扫描超时时间',
            hint: '搜索蓝牙设备的最大等待时长',
            value: _draft['scanTimeout'],
            defaultValue: 3,
            min: 1,
            max: 30,
            divisions: 29,
            valueFormatter: (v) => '${v.toInt()} s',
            onChanged: (v) => setState(() => _draft['scanTimeout'] = v),
          ),
          SettingsSliderField(
            label: '最低信号强度 (RSSI)',
            hint: '弱于此值的设备将被过滤，负值越大信号越弱',
            value: _draft['minRssi'],
            defaultValue: -90,
            min: -120,
            max: -40,
            divisions: 16,
            valueFormatter: (v) => '${v.toInt()} dBm',
            onChanged: (v) => setState(() => _draft['minRssi'] = v),
          ),
          SettingsSliderField(
            label: '连接超时时间',
            hint: '发起连接后的最大等待时长',
            value: _draft['connectionTimeout'],
            defaultValue: 2,
            min: 1,
            max: 10,
            divisions: 9,
            valueFormatter: (v) => '${v.toInt()} s',
            onChanged: (v) => setState(() => _draft['connectionTimeout'] = v),
          ),

          const SettingsDivider(),

          // ── ELM327 初始化 ──
          const SettingsSectionTitle('▸  ELM327 初始化'),
          SettingsSliderField(
            label: 'ELM327 初始化等待',
            hint: '连接后等待 ELM327 准备就绪的时长，过短可能导致初始化失败',
            value: _draft['elm327InitWait'],
            defaultValue: 1000,
            min: 200,
            max: 5000,
            divisions: 48,
            valueFormatter: (v) => '${v.toInt()} ms',
            onChanged: (v) => setState(() => _draft['elm327InitWait'] = v),
          ),

          const SettingsDivider(),

          // ── OBD PID 轮询频率 ──
          const SettingsSectionTitle('▸  OBD PID 轮询间隔'),
          Container(
            padding: const EdgeInsets.all(10),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              border:
                  Border.all(color: AppTheme.primary.withValues(alpha: 0.15)),
            ),
            child: const Text(
              '系统根据当前车速自动切换轮询速度：\n'
              '高速（≥ 30km/h）→ 高频采集   中速（5-30km/h）→ 中频   低速（< 5km/h）→ 低频\n'
              '降低间隔可提升数据刷新率，但会加大 ELM327 通信压力。',
              style: TextStyle(
                  color: AppTheme.textMuted, fontSize: 9, height: 1.5),
            ),
          ),
          SettingsSliderField(
            label: '高速轮询间隔',
            hint: '车速 ≥ 30km/h 时使用',
            value: _draft['highSpeedInterval'],
            defaultValue: 50,
            min: 20,
            max: 200,
            divisions: 18,
            valueFormatter: (v) => '${v.toInt()} ms',
            onChanged: (v) => setState(() => _draft['highSpeedInterval'] = v),
          ),
          SettingsSliderField(
            label: '中速轮询间隔',
            hint: '车速 5-30km/h 时使用',
            value: _draft['mediumSpeedInterval'],
            defaultValue: 200,
            min: 50,
            max: 500,
            divisions: 9,
            valueFormatter: (v) => '${v.toInt()} ms',
            onChanged: (v) => setState(() => _draft['mediumSpeedInterval'] = v),
          ),
          SettingsSliderField(
            label: '低速轮询间隔',
            hint: '车速 < 5km/h 或怠速时使用',
            value: _draft['lowSpeedInterval'],
            defaultValue: 500,
            min: 100,
            max: 2000,
            divisions: 19,
            valueFormatter: (v) => '${v.toInt()} ms',
            onChanged: (v) => setState(() => _draft['lowSpeedInterval'] = v),
          ),
        ],
      ),
    );
  }
}
