import 'package:flutter/material.dart';
import '../models/riding_record.dart';
import '../screens/riding_track_screen.dart';
import '../theme/app_theme.dart';
import 'cyber_dialog.dart';
import 'cyber_button.dart';

/// 骑行强度等级（按最高速度分级）
enum _RideIntensity { normal, moderate, intense }

/// 可滑动删除的骑行记录卡片（基于 Dismissible）
class SwipeableRecordCard extends StatelessWidget {
  final RidingRecord record;
  final VoidCallback onViewEvents;
  final VoidCallback onDelete;

  const SwipeableRecordCard({
    super.key,
    required this.record,
    required this.onViewEvents,
    required this.onDelete,
  });

  _RideIntensity get _intensity {
    final maxSpeed = record.maxSpeed;
    if (maxSpeed >= 100) return _RideIntensity.intense;
    if (maxSpeed >= 60) return _RideIntensity.moderate;
    return _RideIntensity.normal;
  }

  Color get _accentColor {
    switch (_intensity) {
      case _RideIntensity.intense:
        return AppTheme.accentRed;
      case _RideIntensity.moderate:
        return AppTheme.accentOrange;
      case _RideIntensity.normal:
        return AppTheme.accentCyan;
    }
  }

  String get _intensityLabel {
    switch (_intensity) {
      case _RideIntensity.intense:
        return '激烈';
      case _RideIntensity.moderate:
        return '活跃';
      case _RideIntensity.normal:
        return '休闲';
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accentColor;

    return Dismissible(
      key: ValueKey(record.id),
      direction: DismissDirection.endToStart,
      // 确认弹窗：取消返回 false，确认返回 true
      confirmDismiss: (_) async {
        bool confirmed = false;
        await CyberDialog.show(
          context: context,
          title: '确认删除',
          icon: Icons.delete_outline,
          accentColor: AppTheme.accentRed,
          content: Text(
            '确定要删除这条骑行记录吗？\n删除后无法恢复。',
            textAlign: TextAlign.center,
            style: AppTheme.labelMedium.copyWith(color: AppTheme.textSecondary),
          ),
          actions: [
            CyberButton.secondary(
              text: '取消',
              onPressed: () {
                confirmed = false;
                Navigator.of(context).pop();
              },
              height: 32,
              fontSize: 12,
            ),
            const SizedBox(width: 10),
            CyberButton.danger(
              text: '删除',
              onPressed: () {
                confirmed = true;
                Navigator.of(context).pop();
              },
              height: 32,
              fontSize: 12,
            ),
          ],
        );
        return confirmed;
      },
      onDismissed: (_) => onDelete(),
      // 右侧滑出背景：红色删除按钮
      background: Container(
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          color: AppTheme.accentRed,
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.delete_outline, color: Colors.white, size: 20),
            SizedBox(height: 2),
            Text(
              '删除',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      child: _buildCard(context, accent),
    );
  }

  Widget _buildCard(BuildContext context, Color accent) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        border: Border(
          left: BorderSide(color: accent, width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 第一行：强度标签 + 时间 + 查看事件按钮 ──
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  border: Border.all(
                      color: accent.withValues(alpha: 0.4), width: 1),
                ),
                child: Text(
                  _intensityLabel,
                  style: TextStyle(
                    color: accent,
                    fontSize: 7,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${record.formattedStartTime} → ${record.formattedEndTime}',
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              // 查看事件按钮
              GestureDetector(
                onTap: onViewEvents,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                    border: Border.all(
                        color: accent.withValues(alpha: 0.35), width: 1),
                  ),
                  child: Text(
                    '查看事件',
                    style: TextStyle(
                      color: accent,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // ── 第二行：地点（左，可点击进入轨迹）+ 4项统计（右）──
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 地点（flex 4）—点击进入轨迹页
              Expanded(
                flex: 4,
                child: GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => RidingTrackScreen(record: record),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.map_outlined,
                          size: 14,
                          color: AppTheme.accentGreen.withValues(alpha: 0.7)),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          '${record.startPlaceName ?? '未知'} → ${record.endPlaceName ?? '未知'}',
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // 统计数据（flex 5，4项均分）
              Expanded(
                flex: 5,
                child: Row(
                  children: [
                    _buildStat(
                        Icons.route,
                        '距离',
                        '${record.distance.toStringAsFixed(1)}',
                        'km',
                        AppTheme.textPrimary),
                    _buildStat(
                        Icons.speed,
                        '均速',
                        '${record.avgSpeed.toStringAsFixed(0)}',
                        'km/h',
                        AppTheme.accentCyan),
                    _buildStat(
                        Icons.flash_on,
                        '极速',
                        '${record.maxSpeed.toStringAsFixed(0)}',
                        'km/h',
                        accent),
                    _buildLeanStat(),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStat(
      IconData icon, String label, String value, String unit, Color color) {
    return Expanded(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 28, color: color.withValues(alpha: 0.5)),
          const SizedBox(width: 3),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label,
                  style:
                      const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: value,
                      style: TextStyle(
                        color: color,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextSpan(
                      text: unit,
                      style: const TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLeanStat() {
    final left = record.maxLeftLean;
    final right = record.maxRightLean;
    final maxLean = left > right ? left : right;
    final direction = left > right ? 'L' : 'R';

    return _buildStat(
      Icons.rotate_right,
      '倾角',
      '${maxLean.toStringAsFixed(0)}°$direction',
      '',
      AppTheme.accentPink,
    );
  }
}
