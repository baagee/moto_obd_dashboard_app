import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/engine_sound_style.dart';
import '../../../providers/engine_sound_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/cyber_button.dart';
import '../../../widgets/cyber_dialog.dart';
import '../../../widgets/cyber_toast.dart';
import '../settings_fields.dart';

/// 声浪系统设置面板
///
/// 包含：
///   - 开关 toggle（开启后立即预览怠速）
///   - 4 种风格选择按钮
///   - 音量、扰动、排气三个滑块
class EngineSoundSettingsPanel extends StatefulWidget {
  const EngineSoundSettingsPanel({super.key});

  @override
  State<EngineSoundSettingsPanel> createState() =>
      _EngineSoundSettingsPanelState();
}

class _EngineSoundSettingsPanelState extends State<EngineSoundSettingsPanel> {
  // 本地 draft（只有 volume/wobble/exhaust 需要 save 按钮，enabled 和 style 立即生效）
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
      'volume': s.engineSoundVolume,
      'wobble': s.engineSoundWobble,
      'exhaust': s.engineSoundExhaust,
    };
    _draft = Map.from(_original);
  }

  Future<void> _onSave() async {
    final s = context.read<SettingsProvider>();
    await s.setBatch({
      'settings_engineSound_volume': _draft['volume'] as double,
      'settings_engineSound_wobble': _draft['wobble'] as double,
      'settings_engineSound_exhaust': _draft['exhaust'] as double,
    });

    // 实时更新音量
    if (mounted) {
      final ep = context.read<EngineSoundProvider>();
      ep.setVolume(_draft['volume'] as double);
    }

    if (mounted) setState(() => _original = Map.from(_draft));
    if (mounted) CyberToast.show(context, '声浪参数已保存');
  }

  Future<void> _confirmReset() async {
    final confirmed = await CyberDialog.show<bool>(
      context: context,
      title: '重置确认',
      icon: Icons.refresh,
      accentColor: AppTheme.accentOrange,
      content: const Text('将把声浪参数恢复为默认值，是否继续？'),
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
      await context.read<SettingsProvider>().resetGroup('engineSound');
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
          const Icon(Icons.graphic_eq_outlined, size: 16, color: AppTheme.primary),
          const SizedBox(width: 8),
          const Text('发动机声浪', style: AppTheme.titleMedium),
          const Spacer(),
          CyberButton.secondary(
              text: '重置本组',
              height: 30,
              fontSize: 11,
              onPressed: _confirmReset),
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
    return Consumer2<SettingsProvider, EngineSoundProvider>(
      builder: (context, settings, ep, _) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStatusBanner(ep),

              // ── 声浪开关 ──
              const SettingsSectionTitle('▸  声浪系统'),
              _buildEnableToggle(settings, ep),

              const SettingsDivider(),

              // ── 风格选择 ──
              const SettingsSectionTitle('▸  发动机风格'),
              _buildStylePicker(settings, ep),

              const SettingsDivider(),

              // ── 音量参数 ──
              const SettingsSectionTitle('▸  声音参数'),
              SettingsSliderField(
                label: '主音量',
                value: _draft['volume'],
                defaultValue: 1.0,
                min: 0.0,
                max: 1.0,
                divisions: 20,
                valueFormatter: (v) => '${(v * 100).toInt()}%',
                onChanged: (v) => setState(() => _draft['volume'] = v),
              ),
              SettingsSliderField(
                label: '随机扰动',
                value: _draft['wobble'],
                defaultValue: 0.40,
                min: 0.0,
                max: 1.0,
                divisions: 20,
                valueFormatter: (v) => '${(v * 100).toInt()}%',
                onChanged: (v) => setState(() => _draft['wobble'] = v),
              ),
              SettingsSliderField(
                label: '排气混合',
                value: _draft['exhaust'],
                defaultValue: 0.50,
                min: 0.0,
                max: 1.0,
                divisions: 20,
                valueFormatter: (v) => '${(v * 100).toInt()}%',
                onChanged: (v) => setState(() => _draft['exhaust'] = v),
              ),

              const SettingsDivider(),

              // ── 说明 ──
              _buildInfoNote(),
            ],
          ),
        );
      },
    );
  }

  /// 系统状态 banner
  Widget _buildStatusBanner(EngineSoundProvider ep) {
    if (!ep.isReady) {
      final msg = ep.initError != null
          ? '声浪引擎初始化失败：${ep.initError}'
          : '声浪引擎正在初始化，请稍候...';
      return SettingsBanner(
        message: msg,
        type: SettingsBannerType.warning,
      );
    }
    if (ep.isPreviewMode) {
      return const SettingsBanner(
        message: '🔊 试听中...  中段巡航 → 拉转 → 收油（约 5 秒）',
        type: SettingsBannerType.info,
      );
    }
    if (ep.isPlaying) {
      return const SettingsBanner(
        message: '🎵 声浪引擎运行中  |  开启时事件提醒音将静音',
        type: SettingsBannerType.info,
      );
    }
    return const SettingsBanner(
      message: '声浪系统就绪。开启后发动机声音将通过蓝牙耳机实时播放。\n'
          '⚠️ 声浪开启时，骑行事件提醒音将自动静音（视觉弹窗保留）。',
    );
  }

  /// 开关
  Widget _buildEnableToggle(SettingsProvider settings, EngineSoundProvider ep) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '启用发动机声浪',
                  style: AppTheme.labelMedium.copyWith(fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  ep.isPlaying ? '运行中' : (ep.isReady ? '就绪' : '初始化中...'),
                  style: TextStyle(
                    color: ep.isPlaying ? AppTheme.primary : AppTheme.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: settings.engineSoundEnabled,
            onChanged: ep.isReady
                ? (v) async {
                    await ep.setEnabled(v);
                  }
                : null,
            activeColor: AppTheme.primary,
          ),
        ],
      ),
    );
  }

  /// 风格选择（4 个按钮）
  Widget _buildStylePicker(SettingsProvider settings, EngineSoundProvider ep) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: EngineStyles.all.map((style) {
              final isSelected = settings.engineSoundStyle == style.id;
              final isPreviewing = isSelected && ep.isPreviewMode;
              return _StyleChip(
                style: style,
                isSelected: isSelected,
                isPreviewing: isPreviewing,
                onTap: ep.isReady
                    ? () async {
                        await ep.previewStyle(style.id);
                      }
                    : null,
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          // 当前风格特征描述
          _buildStyleDescription(settings.engineSoundStyle),
        ],
      ),
    );
  }

  Widget _buildStyleDescription(String styleId) {
    final descriptions = {
      'i4': '直列四缸 · 2× 和 4× 谐波主导 · 均匀点火 · 清脆高转',
      'v4': 'V 型四缸 · 0.5× 半次频突出 · 不均匀点火 · 粗犷有力',
      'i6': '直列六缸 · 6× 谐波最强 · 点火最密 · 丝滑顺畅',
      'v8': 'V8 美式 · 低频主导 · 圆滑厚重 · 低沉咆哮',
    };
    final style = EngineStyles.fromId(styleId);
    final desc = descriptions[styleId] ?? '';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.primary20),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 14, color: AppTheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${style.name}  ·  ${style.cyls} 缸  ·  红线 ${style.maxRpm} rpm\n$desc',
              style: const TextStyle(
                color: AppTheme.textMuted,
                fontSize: 11,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoNote() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.accentOrange.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.accentOrange.withValues(alpha: 0.2)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.tips_and_updates_outlined,
              size: 14, color: AppTheme.accentOrange),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              '• 声音完全由 App 合成，无需外部音频文件\n'
              '• 通过蓝牙耳机聆听效果最佳\n'
              '• 首次启动需 ~300ms 合成时间（仅一次）\n'
              '• 音调随 OBD 转速实时变化，延迟 < 30ms',
              style: TextStyle(
                color: AppTheme.textMuted,
                fontSize: 11,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────────────────────────
// 风格选择 Chip
// ───────────────────────────────────────────────

class _StyleChip extends StatelessWidget {
  final EngineStyleConfig style;
  final bool isSelected;
  final bool isPreviewing;
  final VoidCallback? onTap;

  const _StyleChip({
    required this.style,
    required this.isSelected,
    this.isPreviewing = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primary.withValues(alpha: 0.18)
              : AppTheme.surface.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.primary20,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          children: [
            Stack(
              alignment: Alignment.topRight,
              children: [
                Icon(
                  _iconFor(style.id),
                  size: 20,
                  color: isSelected ? AppTheme.primary : AppTheme.textMuted,
                ),
                if (isPreviewing)
                  const Padding(
                    padding: EdgeInsets.only(right: 0, top: 0),
                    child: Icon(
                      Icons.volume_up,
                      size: 10,
                      color: AppTheme.primary,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              style.name,
              style: TextStyle(
                color: isSelected ? AppTheme.primary : AppTheme.textMuted,
                fontSize: 11,
                fontWeight:
                    isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            Text(
              isPreviewing ? '试听中' : '${style.cyls} 缸',
              style: TextStyle(
                color: isPreviewing ? AppTheme.primary : AppTheme.textMuted,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(String id) {
    switch (id) {
      case 'v4':
        return Icons.bolt_outlined;
      case 'i6':
        return Icons.waves_outlined;
      case 'v8':
        return Icons.whatshot_outlined;
      case 'i4':
      default:
        return Icons.tune_outlined;
    }
  }
}
