import 'dart:math';

/// GSX-8S 档位计算器
/// 通过转速和车速反推当前档位
class GSX8SCalculator {
  // =========================================================================
  // ========== 固定参数区域（车辆固有参数）===============================
  // =========================================================================

  /// 初级减速比 - 发动机输出轴到变速箱输入轴的减速比
  static const double primaryRatio = 1.675;

  /// 最终减速比 - 变速箱输出轴到后轮的减速比
  /// 计算：牙盘齿数 ÷ 链轮齿数 = 47 ÷ 17
  static const double finalRatio = 2.764;

  /// 轮胎周长（米）- 对应规格 180/55ZR17
  /// 计算：外径 ≈ 0.63m，周长 ≈ 1.98m
  static const double tireCircumference = 1.97857;

  /// 各档内部齿轮比
  /// 数值越大 = 传动越慢 = 扭矩大 = 速度慢
  static const List<double> internalGearRatios = [
    3.071,  // 1档
    2.200,  // 2档
    1.700,  // 3档
    1.416,  // 4档
    1.230,  // 5档
    1.107,  // 6档
  ];

  // =========================================================================
  // ========== 算法阈值参数 ============================================
  // =========================================================================

  /// 动态阈值基础值
  /// 公式: baseThreshold + k / theoryRatio
  /// 低档位（传动比大）→ 阈值严格，高档位（传动比小）→ 阈值宽松
  static const double _thresholdBase = 0.06;
  static const double _thresholdK = 0.5;

  /// 稳定帧数阈值 - 必须连续多少帧匹配才确认档位
  static const int _stableFramesRequired = 8;

  // =========================================================================
  // ========== 边界判定参数 ==========================================
  // =========================================================================

  /// 空档判定 - 速度低于此值视为空档/停车
  static const int _minSpeed = 3; // km/h

  /// 空档判定 - 转速低于此值视为空档/怠速
  static const int _minRpm = 800;

  // =========================================================================
  // ========== 半离合蠕动检测参数 ====================================
  // =========================================================================

  /// 半离合蠕动速度范围（km/h）
  static const int _creepMinSpeed = 3;
  static const int _creepMaxSpeed = 15;

  /// 半离合判定 - 油门低于此值（%）
  static const int _creepMaxThrottle = 20;

  /// 半离合状态阈值放宽倍数
  static const double _creepThresholdMultiplier = 1.5;

  // =========================================================================
  // ========== 换挡瞬态检测参数 ====================================
  // =========================================================================

  /// 换挡判定 - 转速下降到此比例以下
  static const double _shiftRpmDropRatio = 0.7;

  /// 换挡保持帧数 - 换挡后保持原档位多少帧（约 5 秒，2Hz）
  static const int _shiftHoldFrames = 10;

  // =========================================================================
  // ========== Scale Factor 校准参数 ================================
  // =========================================================================

  /// 校准生效最低速度（km/h）- 高速行驶时校准
  static const int _calibrationMinSpeed = 30;

  /// 校准所需稳定帧数
  static const int _calibrationStableFrames = 10;

  /// 校准误差阈值 - 小于此误差才用于校准
  static const double _calibrationErrorThreshold = 0.10;

  /// 校准采样帧数 - 累计多少帧后更新 scale
  static const int _calibrationSampleFrames = 50;

  // =========================================================================
  // ========== 内部状态变量 ==========================================
  // =========================================================================

  /// 缓存各档位的理论总传动比
  /// 总传动比 = primaryRatio × 齿轮比 × finalRatio
  static final List<double> _theoreticalTotals =
      internalGearRatios.map((g) => primaryRatio * g * finalRatio).toList();

  /// 上次有效档位
  static int _lastValidGear = 0;

  /// 稳定帧数计数
  static int _stableFrames = 0;

  /// 待确认档位
  static int _pendingGear = 0;

  /// 上次转速（用于换挡检测）
  static int _lastRpm = 0;

  /// 上次传动比（用于半离合波动检测）
  static double _lastRatio = 0;

  /// 是否正在换挡
  static bool _isShifting = false;

  /// 换挡保持帧数计数
  static int _shiftHoldFramesCounter = 0;

  /// Scale Factor 轮胎误差补偿因子
  static double _ratioScale = 1.0;

  /// 校准采样帧数计数
  static int _calibrationFrames = 0;

  /// 校准误差累加值
  static double _accumulatedError = 0;

  /// 当前校准档位（用于检测档位变化）
  static int _calibrationGear = 0;

  // =========================================================================
  // ========== 核心计算方法 ==========================================
  // =========================================================================

  /// 动态阈值计算函数
  /// [theoryRatio] 理论传动比
  /// 返回：该档位的误差阈值
  static double _getThreshold(double theoryRatio) {
    // 公式：基础阈值 + k / 理论传动比
    // 低档（~14）→ 阈值 ~14%，高档（~4.4）→ 阈值 ~26%
    return _thresholdBase + _thresholdK / theoryRatio;
  }

  /// 判断是否为半离合蠕动状态
  /// [speed] 当前车速 [throttle] 当前油门 [rpm] 当前转速 [scaledRatio] 当前传动比
  /// 多维度组合判断：ratio过高 + ratio不稳定 + 低油门
  static bool _isCreepingState(int speed, int? throttle, int rpm, double scaledRatio) {
    // 1. 速度过滤（必须条件）
    if (speed < _creepMinSpeed || speed > _creepMaxSpeed) {
      _lastRatio = scaledRatio;
      return false;
    }

    double maxTheoryRatio = _theoreticalTotals[0];

    // 2. ratio 是否明显超过 1档
    bool ratioTooHigh = scaledRatio > maxTheoryRatio * 1.15;

    // 3. ratio 是否不稳定（核心特征：半离合打滑导致波动）
    bool unstable = false;
    if (_lastRatio > 0) {
      double change = (scaledRatio - _lastRatio).abs() / _lastRatio;
      unstable = change > 0.05; // 5% 波动
    }

    // 4. 油门辅助条件（不是单独触发）
    bool lowThrottle = throttle != null && throttle < _creepMaxThrottle;

    _lastRatio = scaledRatio;

    // 5. 最终判定：必须组合条件
    return ratioTooHigh && unstable && lowThrottle;
  }

  /// 计算当前档位
  /// [rpm] 转速, [speed] 时速(km/h), [throttle] 油门开度(0-100), [load] 发动机负载(0-100)
  static int calculateGear(int rpm, int speed, {int? throttle, int? load}) {
    // ==== 1. 边界判定 ====
    // 低于最低速度或转速，视为空档
    if (speed < _minSpeed || rpm < _minRpm) {
      _resetFilter();
      return 0;
    }

    // ==== 2. 换挡瞬态检测 ====
    // 条件：rpm 大幅下降（<70%）且速度 > 0
    if (_lastRpm > 0 && rpm < _lastRpm * _shiftRpmDropRatio && speed > 0) {
      _isShifting = true;
      _shiftHoldFramesCounter = 0;
    }

    // 如果正在换挡，保持原档位
    if (_isShifting) {
      _shiftHoldFramesCounter++;
      if (_shiftHoldFramesCounter < _shiftHoldFrames && _lastValidGear > 0) {
        _lastRpm = rpm;
        return _lastValidGear;
      }
      _isShifting = false;
    }
    _lastRpm = rpm;

    // ==== 3. 计算实时传动比 ====
    // 公式：(rpm × 60 × 轮胎周长) / (速度 × 1000)
    double currentRatio = (rpm * 60 * tireCircumference) / (speed * 1000);

    // ==== 4. 应用 Scale Factor（轮胎误差补偿）====
    double scaledRatio = currentRatio * _ratioScale;

    // ==== 5. 半离合蠕动状态检测 ====
    // 半离合时传动比不稳定（打滑），需要放宽判定条件
    bool isCreeping = _isCreepingState(speed, throttle, rpm, scaledRatio);

    // ==== 6. Log 误差匹配算法 ====
    // 使用 log 误差替代线性误差，对比例误差更敏感
    int bestGear = 0;
    double minLogError = double.infinity;

    for (int i = 0; i < _theoreticalTotals.length; i++) {
      double theory = _theoreticalTotals[i];
      // log 误差：|log(测量值) - log(理论值)|
      double logError = (log(scaledRatio) - log(theory)).abs();

      if (logError < minLogError) {
        minLogError = logError;
        bestGear = i + 1;
      }
    }

    // ==== 7. 动态阈值判定 ====
    if (bestGear > 0) {
      double theory = _theoreticalTotals[bestGear - 1];
      double threshold = _getThreshold(theory);

      // 半离合状态：放宽阈值
      if (isCreeping) {
        threshold *= _creepThresholdMultiplier;
      }

      if (minLogError > threshold) {
        // 误差超过阈值，保持原档位
        if (_lastValidGear > 0) {
          return _lastValidGear;
        }
        return 0;
      }
    }

    // ==== 8. Scale Factor 自动校准 ====
    // 条件：速度 > 30km/h 且稳定 10 帧以上
    if (speed > _calibrationMinSpeed && _stableFrames > _calibrationStableFrames && bestGear > 0) {
      // 检测档位变化：如果档位变化，重置采样
      if (_calibrationGear != 0 && _calibrationGear != bestGear) {
        _calibrationFrames = 0;
        _accumulatedError = 0;
      }
      _calibrationGear = bestGear;

      double theory = _theoreticalTotals[bestGear - 1];
      // 计算线性误差用于校准判断
      double linearError = (scaledRatio - theory).abs() / theory;

      // 误差小于阈值，累加用于校准
      if (linearError < _calibrationErrorThreshold) {
        _accumulatedError += scaledRatio / theory;
        _calibrationFrames++;

        // 每 50 帧更新一次 scale
        if (_calibrationFrames >= _calibrationSampleFrames) {
          _ratioScale = _accumulatedError / _calibrationFrames;
          _accumulatedError = 0;
          _calibrationFrames = 0;
        }
      }
    }

    // ==== 9. 档位平滑滤波 ====
    // 只有连续 N 帧以上匹配才切换档位
    if (bestGear != _pendingGear) {
      _pendingGear = bestGear;
      _stableFrames = 0;
    } else {
      _stableFrames++;
      if (_stableFrames < _stableFramesRequired) {
        // 未稳定，保持上次档位
        return _lastValidGear;
      }
    }

    // ==== 10. 稳定后更新档位 ====
    _lastValidGear = bestGear;
    return bestGear;
  }

  /// 重置滤波状态
  static void _resetFilter() {
    _lastValidGear = 0;
    _stableFrames = 0;
    _pendingGear = 0;
    _isShifting = false;
    _shiftHoldFramesCounter = 0;
  }

  /// 重置档位计算器（用于断开连接后）
  static void reset() {
    _resetFilter();
    _ratioScale = 1.0;
    _calibrationFrames = 0;
    _accumulatedError = 0;
    _calibrationGear = 0;
  }
}
