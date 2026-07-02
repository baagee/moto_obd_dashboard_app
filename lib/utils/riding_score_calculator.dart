import 'package:flutter/material.dart';
import '../models/riding_record.dart';
import '../theme/app_theme.dart';

/// 骑行评分结果
class RidingScoreResult {
  final int totalScore;
  final String gradeLabel;
  final Color gradeColor;

  const RidingScoreResult({
    required this.totalScore,
    required this.gradeLabel,
    required this.gradeColor,
  });
}

/// 骑行评分计算器
/// 基于 RidingRecord 已有字段，纯同步计算，无需 DB 查询
class RidingScoreCalculator {
  /// 计算骑行评分（满分 100）
  ///
  /// 评分维度：
  ///   - 速度管理（40分）：最高速度相对合理水平
  ///   - 均速效率（33分）：均速是否在高效巡航区间
  ///   - 完整性（27分）：距离和时长基础分
  static RidingScoreResult calculate(RidingRecord record) {
    // ── 1. 速度管理（30分）──
    // 最高速度越低越安全，但也要有合理的骑行速度
    int speedScore;
    final maxSpeed = record.maxSpeed;
    if (maxSpeed <= 0) {
      speedScore = 0; // 无有效数据
    } else if (maxSpeed < 60) {
      speedScore = 28; // 低速骑行，较安全
    } else if (maxSpeed < 100) {
      speedScore = 30; // 合理速度区间，满分
    } else if (maxSpeed < 140) {
      speedScore = 22; // 偏快
    } else if (maxSpeed < 180) {
      speedScore = 14; // 较危险
    } else {
      speedScore = 6; // 超高速
    }

    // ── 2. 均速效率（25分）──
    // 均速在 40-100km/h 之间得满分（高效巡航），过低或过高扣分
    int avgSpeedScore;
    final avgSpeed = record.avgSpeed;
    if (avgSpeed <= 0) {
      avgSpeedScore = 0;
    } else if (avgSpeed < 20) {
      avgSpeedScore = 10; // 极低均速（走走停停）
    } else if (avgSpeed < 40) {
      avgSpeedScore = 18; // 市区低速
    } else if (avgSpeed <= 100) {
      avgSpeedScore = 25; // 高效巡航区间，满分
    } else if (avgSpeed <= 130) {
      avgSpeedScore = 18; // 高速路
    } else {
      avgSpeedScore = 10; // 持续高速
    }

    // ── 3. 完整性（20分）──
    // 有足够的骑行距离和时长才是有效骑行
    int completionScore = 0;
    if (record.distance >= 1.0) completionScore += 6;
    if (record.distance >= 5.0) completionScore += 4;
    if (record.duration >= 300) completionScore += 5; // 5 分钟以上
    if (record.duration >= 1800) completionScore += 3; // 30 分钟以上
    if (record.endTime != null) completionScore += 2; // 正常结束骑行（非崩溃）

    final total = ((speedScore + avgSpeedScore + completionScore) / 75 * 100)
        .round()
        .clamp(0, 100);

    return RidingScoreResult(
      totalScore: total,
      gradeLabel: _gradeLabel(total),
      gradeColor: _gradeColor(total),
    );
  }

  static String _gradeLabel(int score) {
    if (score >= 90) return '赛道高手';
    if (score >= 75) return '稳健骑士';
    if (score >= 60) return '通勤老手';
    if (score >= 40) return '新手上路';
    return '危险骑行';
  }

  static Color _gradeColor(int score) {
    if (score >= 90) return AppTheme.accentGreen;
    if (score >= 75) return AppTheme.accentCyan;
    if (score >= 60) return AppTheme.accentOrange;
    return AppTheme.accentRed;
  }
}
