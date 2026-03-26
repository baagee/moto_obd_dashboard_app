import 'package:flutter/material.dart';
import '../models/riding_record.dart';
import '../theme/app_theme.dart';
import 'delete_confirm_dialog.dart';

/// 可滑动删除的骑行记录卡片
class SwipeableRecordCard extends StatefulWidget {
  final RidingRecord record;
  final VoidCallback onViewEvents;
  final VoidCallback onDelete;

  const SwipeableRecordCard({
    super.key,
    required this.record,
    required this.onViewEvents,
    required this.onDelete,
  });

  @override
  State<SwipeableRecordCard> createState() => _SwipeableRecordCardState();
}

class _SwipeableRecordCardState extends State<SwipeableRecordCard> {
  double _dragExtent = 0;
  static const double _deleteButtonWidth = 80;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        setState(() {
          _dragExtent = (_dragExtent + details.delta.dx).clamp(-_deleteButtonWidth, 0);
        });
      },
      onHorizontalDragEnd: (details) {
        if (_dragExtent < -_deleteButtonWidth / 2) {
          setState(() => _dragExtent = -_deleteButtonWidth);
        } else {
          setState(() => _dragExtent = 0);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        child: Stack(
          children: [
            // 删除按钮（在卡片下面）
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: GestureDetector(
                onTap: () => _showDeleteConfirm(),
                child: Container(
                  width: _deleteButtonWidth,
                  decoration: BoxDecoration(
                    color: AppTheme.accentRed,
                    borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                  ),
                  child: const Center(
                    child: Text(
                      '删除',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // 卡片主体
            AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              transform: Matrix4.translationValues(_dragExtent, 0, 0),
              child: _buildCard(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard() {
    final record = widget.record;
    final showDeleteButton = _dragExtent < -10;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: AppTheme.primary20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 第一行：时间和查看事件按钮
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${record.formattedStartTime} → ${record.formattedEndTime}',
                style: AppTheme.valueMedium.copyWith(color: AppTheme.textPrimary),
              ),
              if (!showDeleteButton)
                GestureDetector(
                  onTap: widget.onViewEvents,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.slateGray,
                      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                    ),
                    child: Text(
                      '查看事件',
                      style: AppTheme.labelSmall.copyWith(color: AppTheme.primary),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          // 第二行：地点
          Text(
            '${record.startPlaceName ?? '未知'} → ${record.endPlaceName ?? '未知'}',
            style: AppTheme.labelMedium.copyWith(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 8),
          // 第三行：统计数据
          Row(
            children: [
              _buildStat('距离', '${record.distance.toStringAsFixed(1)}km'),
              _buildStat('均速', '${record.avgSpeed.toStringAsFixed(0)}km/h'),
              _buildStat('极速', '${record.maxSpeed.toStringAsFixed(0)}km/h'),
              _buildLeanAngle(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String label, String value) {
    return Expanded(
      child: Text(
        '$label:$value',
        style: AppTheme.labelMedium.copyWith(color: AppTheme.textMuted),
      ),
    );
  }

  Widget _buildLeanAngle() {
    final record = widget.record;
    final left = record.maxLeftLean;
    final right = record.maxRightLean;
    final maxLean = left > right ? left : right;
    final direction = left > right ? '左' : '右';

    return Expanded(
      child: Text(
        '倾角:${maxLean.toStringAsFixed(0)}°$direction',
        style: AppTheme.labelMedium.copyWith(color: AppTheme.accentPink),
      ),
    );
  }

  void _showDeleteConfirm() {
    showDialog(
      context: context,
      builder: (ctx) => DeleteConfirmDialog(onConfirm: widget.onDelete),
    );
  }
}
