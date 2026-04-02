import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/cyber_button.dart';
import '../../../widgets/cyber_dialog.dart';
import '../../../widgets/cyber_toast.dart';
import '../settings_fields.dart';

/// 车辆参数设置面板
class VehicleSettingsPanel extends StatefulWidget {
  const VehicleSettingsPanel({super.key});

  @override
  State<VehicleSettingsPanel> createState() => _VehicleSettingsPanelState();
}

class _VehicleSettingsPanelState extends State<VehicleSettingsPanel> {
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
      'primaryRatio': s.primaryRatio,
      'finalRatio': s.finalRatio,
      'tireCircumference': s.tireCircumference,
      'gearRatio_1': s.gearRatios[0],
      'gearRatio_2': s.gearRatios[1],
      'gearRatio_3': s.gearRatios[2],
      'gearRatio_4': s.gearRatios[3],
      'gearRatio_5': s.gearRatios[4],
      'gearRatio_6': s.gearRatios[5],
      'speedCorrectionFactor': s.speedCorrectionFactor,
      'neutralSpeedThreshold': s.neutralSpeedThreshold.toDouble(),
      'neutralRpmThreshold': s.neutralRpmThreshold.toDouble(),
    };
    _draft = Map.from(_original);
  }

  Future<void> _onSave() async {
    await context.read<SettingsProvider>().setBatch({
      'settings_vehicle_primaryRatio': _draft['primaryRatio'] as double,
      'settings_vehicle_finalRatio': _draft['finalRatio'] as double,
      'settings_vehicle_tireCircumference':
          _draft['tireCircumference'] as double,
      'settings_vehicle_gearRatio_1': _draft['gearRatio_1'] as double,
      'settings_vehicle_gearRatio_2': _draft['gearRatio_2'] as double,
      'settings_vehicle_gearRatio_3': _draft['gearRatio_3'] as double,
      'settings_vehicle_gearRatio_4': _draft['gearRatio_4'] as double,
      'settings_vehicle_gearRatio_5': _draft['gearRatio_5'] as double,
      'settings_vehicle_gearRatio_6': _draft['gearRatio_6'] as double,
      'settings_vehicle_speedCorrectionFactor':
          _draft['speedCorrectionFactor'] as double,
      'settings_vehicle_neutralSpeedThreshold':
          (_draft['neutralSpeedThreshold'] as double).toInt(),
      'settings_vehicle_neutralRpmThreshold':
          (_draft['neutralRpmThreshold'] as double).toInt(),
    });
    if (mounted) setState(() => _original = Map.from(_draft));
    if (mounted) CyberToast.show(context, '车辆参数已保存');
  }

  Future<void> _confirmReset() async {
    final confirmed = await CyberDialog.show<bool>(
      context: context,
      title: '重置确认',
      icon: Icons.refresh,
      accentColor: AppTheme.accentOrange,
      content: const Text('将把车辆参数恢复为默认值（GSX-8S），是否继续？'),
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
      await context.read<SettingsProvider>().resetGroup('vehicle');
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
          const Icon(Icons.two_wheeler, size: 16, color: AppTheme.primary),
          const SizedBox(width: 8),
          const Text('车辆参数', style: AppTheme.titleMedium),
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
          // ── 传动比 ──
          const SettingsSectionTitle('▸  传动系数'),
          SettingsStepperField(
            label: '主传动比',
            hint: '曲轴到变速箱输入轴的减速比',
            value: _draft['primaryRatio'],
            defaultValue: 1.675,
            step: 0.001,
            bigStep: 0.01,
            minValue: 0.5,
            maxValue: 5.0,
            decimalPlaces: 3,
            onChanged: (v) => setState(() => _draft['primaryRatio'] = v),
          ),
          SettingsStepperField(
            label: '终传动比',
            hint: '主驱动链轮 / 后轮链轮齿数比',
            value: _draft['finalRatio'],
            defaultValue: 2.764,
            step: 0.001,
            bigStep: 0.01,
            minValue: 1.0,
            maxValue: 6.0,
            decimalPlaces: 3,
            onChanged: (v) => setState(() => _draft['finalRatio'] = v),
          ),
          SettingsStepperField(
            label: '轮胎周长',
            hint: '后轮实际滚动周长，影响车速与档位计算精度',
            value: _draft['tireCircumference'],
            defaultValue: 1.97857,
            step: 0.001,
            bigStep: 0.01,
            minValue: 1.5,
            maxValue: 2.5,
            decimalPlaces: 5,
            unit: 'm',
            onChanged: (v) => setState(() => _draft['tireCircumference'] = v),
          ),

          const SettingsDivider(),

          // ── 各档位速比 ──
          const SettingsSectionTitle('▸  变速箱各档速比'),
          ...List.generate(6, (i) {
            final gear = i + 1;
            const defaults = [3.071, 2.200, 1.700, 1.416, 1.230, 1.107];
            return SettingsStepperField(
              label: '$gear 档速比',
              value: _draft['gearRatio_$gear'],
              defaultValue: defaults[i],
              step: 0.001,
              bigStep: 0.01,
              minValue: 0.5,
              maxValue: 6.0,
              decimalPlaces: 3,
              onChanged: (v) => setState(() => _draft['gearRatio_$gear'] = v),
            );
          }),

          const SettingsDivider(),

          // ── 车速修正 ──
          const SettingsSectionTitle('▸  车速修正'),
          SettingsStepperField(
            label: '车速修正系数',
            hint: 'OBD 车速 × 系数 = 显示车速，补偿仪表读数偏差',
            value: _draft['speedCorrectionFactor'],
            defaultValue: 1.08,
            step: 0.01,
            bigStep: 0.05,
            minValue: 0.8,
            maxValue: 1.3,
            decimalPlaces: 2,
            unit: '×',
            onChanged: (v) =>
                setState(() => _draft['speedCorrectionFactor'] = v),
          ),

          const SettingsDivider(),

          // ── 空挡判断阈值 ──
          const SettingsSectionTitle('▸  空挡判断阈值'),
          SettingsSliderField(
            label: '空挡车速阈值',
            hint: '车速低于此值时判断为空挡',
            value: _draft['neutralSpeedThreshold'],
            defaultValue: 3,
            min: 0,
            max: 20,
            divisions: 20,
            valueFormatter: (v) => '${v.toInt()} km/h',
            onChanged: (v) =>
                setState(() => _draft['neutralSpeedThreshold'] = v),
          ),
          SettingsSliderField(
            label: '空挡转速阈值',
            hint: 'RPM 低于此值时判断为空挡',
            value: _draft['neutralRpmThreshold'],
            defaultValue: 1200,
            min: 500,
            max: 3000,
            divisions: 25,
            valueFormatter: (v) => '${v.toInt()} rpm',
            onChanged: (v) => setState(() => _draft['neutralRpmThreshold'] = v),
          ),
        ],
      ),
    );
  }
}
