import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/cyber_button.dart';
import '../../../widgets/cyber_dialog.dart';
import '../../../widgets/cyber_toast.dart';
import '../../../widgets/navi_card.dart';
import '../settings_fields.dart';

/// 第三方服务设置面板（高德 API Key 配置）
class ApiSettingsPanel extends StatefulWidget {
  const ApiSettingsPanel({super.key});

  @override
  State<ApiSettingsPanel> createState() => _ApiSettingsPanelState();
}

class _ApiSettingsPanelState extends State<ApiSettingsPanel> {
  late String _amapKey;
  late String _originalKey;
  bool _isTesting = false;
  String? _testResult;
  bool? _testSuccess;

  bool get _isDirty => _amapKey != _originalKey;

  @override
  void initState() {
    super.initState();
    _amapKey = context.read<SettingsProvider>().amapKey;
    _originalKey = _amapKey;
  }

  Future<void> _onSave() async {
    await context.read<SettingsProvider>().setAmapKey(_amapKey);
    if (mounted) setState(() => _originalKey = _amapKey);
    if (mounted) CyberToast.show(context, 'API Key 已保存');
  }

  Future<void> _confirmReset() async {
    final confirmed = await CyberDialog.show<bool>(
      context: context,
      title: '重置确认',
      icon: Icons.refresh,
      accentColor: AppTheme.accentOrange,
      content: const Text('将把第三方服务配置恢复为默认值，是否继续？'),
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
      await context.read<SettingsProvider>().resetGroup('api');
      if (mounted)
        setState(() {
          _amapKey = context.read<SettingsProvider>().amapKey;
          _testResult = null;
          _testSuccess = null;
        });
    }
  }

  Future<void> _testAmapConnection() async {
    if (_amapKey.isEmpty) {
      setState(() {
        _testResult = '请先输入 API Key';
        _testSuccess = false;
      });
      return;
    }

    setState(() {
      _isTesting = true;
      _testResult = null;
      _testSuccess = null;
    });

    try {
      const lat = 39.9042;
      const lng = 116.4074;
      final url = Uri.parse(
        'https://restapi.amap.com/v3/geocode/regeo'
        '?key=$_amapKey&location=$lng,$lat&poitype=&radius=200&extensions=base&batch=false&roadlevel=0',
      );
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);
      final request = await client.getUrl(url);
      final response = await request.close();
      final body =
          await response.transform(const SystemEncoding().decoder).join();

      if (response.statusCode == 200 && body.contains('"status":"1"')) {
        setState(() {
          _testSuccess = true;
          _testResult = '连接成功，API Key 有效';
        });
      } else if (body.contains('"status":"0"')) {
        final infoMatch = RegExp(r'"info":"([^"]+)"').firstMatch(body);
        final info = infoMatch?.group(1) ?? '未知错误';
        setState(() {
          _testSuccess = false;
          _testResult = '请求失败：$info';
        });
      } else {
        setState(() {
          _testSuccess = false;
          _testResult = 'HTTP ${response.statusCode}';
        });
      }
      client.close();
    } catch (e) {
      setState(() {
        _testSuccess = false;
        _testResult = '连接异常：$e';
      });
    } finally {
      setState(() => _isTesting = false);
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
          const Icon(Icons.api_outlined, size: 16, color: AppTheme.primary),
          const SizedBox(width: 8),
          const Text('第三方服务', style: AppTheme.titleMedium),
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
          // ── 高德地图 ──
          const SettingsSectionTitle('▸  高德地图 Web 服务'),

          // 说明卡片
          Container(
            padding: const EdgeInsets.all(10),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              border:
                  Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.info_outline,
                        size: 12, color: AppTheme.primary),
                    const SizedBox(width: 6),
                    const Text(
                      '用于骑行记录中起点/终点地名解析',
                      style: TextStyle(
                          color: AppTheme.primary,
                          fontSize: 10,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  '前往 console.amap.com 创建「Web 服务」类型 Key。\n'
                  '留空时将回退到坐标格式显示，不影响其他功能。',
                  style: TextStyle(
                      color: AppTheme.textMuted, fontSize: 9, height: 1.5),
                ),
              ],
            ),
          ),

          SettingsPasswordField(
            label: '高德 Web 服务 API Key',
            hint: '格式示例：99d4e91045213ccda8ebee56a8061eb2',
            currentValue: _amapKey,
            onChanged: (v) => setState(() {
              _amapKey = v;
              _testResult = null;
              _testSuccess = null;
            }),
          ),

          // 测试连接按钮
          Row(
            children: [
              CyberButton.secondary(
                text: '测试连接',
                height: 30,
                fontSize: 11,
                icon: Icons.wifi_tethering,
                onPressed: _isTesting ? null : _testAmapConnection,
              ),
              if (_testResult != null) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        _testSuccess == true
                            ? Icons.check_circle_outline
                            : Icons.error_outline,
                        size: 14,
                        color: _testSuccess == true
                            ? AppTheme.accentGreen
                            : AppTheme.accentRed,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          _testResult!,
                          style: TextStyle(
                            color: _testSuccess == true
                                ? AppTheme.accentGreen
                                : AppTheme.accentRed,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),

          const SettingsDivider(),

          // ── 导航 HUD（高德分享路线）──
          // 本区块即时生效，不参与顶部「保存」的草稿流程
          const SettingsSectionTitle('▸  导航 HUD（高德分享路线）'),
          SettingsToggleField(
            label: '回前台自动同步分享短链',
            hint: '在高德分享行程后回到本 App，自动读剪贴板短链开始导航。'
                '关闭后仍可在仪表盘导航卡上手动粘贴。',
            value: context.watch<SettingsProvider>().naviAutoSync,
            onChanged: (v) =>
                context.read<SettingsProvider>().setNaviAutoSync(v),
          ),
          SettingsRadioField(
            label: '路线刷新间隔',
            options: const ['10', '30', '60'],
            optionLabels: const ['10 秒', '30 秒', '60 秒'],
            currentValue:
                context.watch<SettingsProvider>().naviRouteRefreshSec.toString(),
            onChanged: (v) =>
                context.read<SettingsProvider>().setNaviRouteRefreshSec(int.parse(v)),
          ),

          const SettingsDivider(),

          // ── 跟随高德停止（分享状态心跳）──
          const SettingsSectionTitle('▸  跟随高德停止'),
          SettingsToggleField(
            label: '高德停止导航时同步收尾',
            hint: '定期向高德确认这条分享是否还活着（行中 shareStatus / 行前 status）。'
                '判到"已停止/已结束/已过期"就结束导航（需连续两次确认，防后端节点抖动）。',
            value: context.watch<SettingsProvider>().naviShareStatusWatchOn,
            onChanged: (v) =>
                context.read<SettingsProvider>().setNaviShareStatusWatchOn(v),
          ),
          SettingsRadioField(
            label: '状态探测间隔',
            options: const ['5', '15', '30'],
            optionLabels: const ['5 秒', '15 秒', '30 秒'],
            currentValue: context
                .watch<SettingsProvider>()
                .naviShareStatusWatchSec
                .toString(),
            onChanged: (v) => context
                .read<SettingsProvider>()
                .setNaviShareStatusWatchSec(int.parse(v)),
          ),
          SettingsToggleField(
            label: '判到停止后继续导航',
            hint: '打开后不再自动收尾，只在导航卡上标"已停止"——适合只想按这条路线骑完、'
                '不跟随高德状态的场景。',
            value: !context.watch<SettingsProvider>().naviStopOnShareEnd,
            onChanged: (v) =>
                context.read<SettingsProvider>().setNaviStopOnShareEnd(!v),
          ),

          const SettingsDivider(),

          // ── 导航卡底图 ──
          const SettingsSectionTitle('▸  导航卡底图'),
          SettingsRadioField(
            label: '视窗里程',
            options: const ['150', '300', '600'],
            optionLabels: const ['150 m', '300 m', '600 m'],
            currentValue:
                context.watch<SettingsProvider>().naviMapAheadMeters.toString(),
            onChanged: (v) =>
                context.read<SettingsProvider>().setNaviMapAheadMeters(int.parse(v)),
          ),
          SettingsRadioField(
            label: '剩余时间',
            options: const ['clock', 'duration'],
            optionLabels: const ['到达时刻', '剩余时长'],
            currentValue: context.watch<SettingsProvider>().naviEtaMode,
            onChanged: (v) => context.read<SettingsProvider>().setNaviEtaMode(v),
          ),
          SettingsToggleField(
            label: '底图叠加路况着色',
            hint: '缓行/拥堵段在路线上叠一层彩带。默认关闭：红/琥珀已被"危险/超速"语义占用。',
            value: context.watch<SettingsProvider>().naviRouteTrafficColor,
            onChanged: (v) =>
                context.read<SettingsProvider>().setNaviRouteTrafficColor(v),
          ),

          const SizedBox(height: 4),
          Row(
            children: [
              CyberButton.secondary(
                text: '粘贴分享短链开始导航',
                height: 30,
                fontSize: 11,
                icon: Icons.alt_route,
                onPressed: () => showNaviPasteDialog(context),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            '单次路线响应约 228KB，30 秒刷新约 27MB/小时。\n'
            '隧道/地库无 GPS 时用 OBD 车速做航位推算，出隧道自动校正。',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 9, height: 1.6),
          ),

          const SettingsDivider(),

          // ── 说明 ──
          const SettingsSectionTitle('▸  关于 API 用量'),
          const Text(
            '高德 Web 服务每日免费调用量 5 万次。\n'
            '骑行结束时仅调用 1~2 次（起点+终点解析），日常使用不会超限。\n'
            '若超限或不需要地名解析，清空 Key 即可回退到坐标显示。',
            style: TextStyle(
              color: AppTheme.textMuted,
              fontSize: 9,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
