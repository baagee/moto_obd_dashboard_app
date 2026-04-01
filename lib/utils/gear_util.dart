import '../providers/settings_provider.dart';

/// 车辆传动参数配置对象
///
/// [theoreticalTotals] 为实例 getter，根据当前 gearRatios/primaryRatio/finalRatio
/// 动态计算，避免原 static final 在类加载时固化导致参数注入无效的问题。
class GearConfig {
  final double primaryRatio;
  final double finalRatio;
  final double tireCircumference;
  final List<double> gearRatios;
  final int neutralSpeedThreshold;
  final int neutralRpmThreshold;

  const GearConfig({
    required this.primaryRatio,
    required this.finalRatio,
    required this.tireCircumference,
    required this.gearRatios,
    required this.neutralSpeedThreshold,
    required this.neutralRpmThreshold,
  });

  factory GearConfig.fromSettings(SettingsProvider s) => GearConfig(
        primaryRatio: s.primaryRatio,
        finalRatio: s.finalRatio,
        tireCircumference: s.tireCircumference,
        gearRatios: s.gearRatios,
        neutralSpeedThreshold: s.neutralSpeedThreshold,
        neutralRpmThreshold: s.neutralRpmThreshold,
      );

  /// GSX-8S 默认配置
  static const GearConfig defaults = GearConfig(
    primaryRatio: 1.675,
    finalRatio: 2.764,
    tireCircumference: 1.97857,
    gearRatios: [3.071, 2.200, 1.700, 1.416, 1.230, 1.107],
    neutralSpeedThreshold: 3,
    neutralRpmThreshold: 1200,
  );

  /// 根据当前配置计算各档位理论传动比（实例 getter，随参数动态生成）
  ///
  /// ⚠️ 原 GSX8SCalculator._theoreticalTotals 为 static final，在类加载时固化，
  /// 无法响应 GearConfig 注入。改为此处按需计算，每次 calculateGear 调用时传入。
  List<double> get theoreticalTotals =>
      gearRatios.map((g) => primaryRatio * g * finalRatio).toList();
}

class GSX8SCalculator {
  // ==================== 阈值优化 ====================
  // 采用非线性递减策略
  static const List<double> _gearThresholds = [
    0.18, // 1档: 传动比差异大，可严格
    0.15, // 2档
    0.10, // 3档 todo 测试下 原来0.12
    0.10, // 4档
    0.08, // 5档: 传动比接近6档，加严区分度
    0.12, // 6档: 放宽阈值减少误判
  ];

  // 半离合专用阈值（放宽）
  static const double _creepThreshold = 0.25;

  // ==================== 状态管理 ====================
  static int _lastValidGear = 0;
  static int _stableFrames = 0;
  static int _pendingGear = 0;
  static double _lastRatio = 0;
  static bool _isInCreepMode = false; // 新增：半离合模式标记

  // ==================== 边界检测优化 ====================
  static const int _minValidSpeed = 5; // 最低有效速度
  // codeflicker-fix: OPT-Issue-5/omvh7ni7j93qpiynr7sw — _minValidRpm 未被使用，已删除

  // ==================== 半离合检测 ====================
  static const int _creepMinSpeed = 3;
  static const int _creepMaxSpeed = 20;
  static const int _creepMaxThrottle = 35;

  static bool _isCreepingState(
      int speed, int? throttle, int rpm, double scaledRatio,
      List<double> theoreticalTotals) {
    // 速度范围过滤
    if (speed < _creepMinSpeed || speed > _creepMaxSpeed) {
      _lastRatio = scaledRatio;
      return false;
    }

    // 转速过低（怠速以下）
    if (rpm < 1200) {
      _lastRatio = scaledRatio;
      return false;
    }

    double maxTheoryRatio = theoreticalTotals[0];

    // 1. 传动比异常高（超过1档理论值 20%）
    bool ratioTooHigh = scaledRatio > maxTheoryRatio * 1.20;

    // 2. 传动比波动检测（半离合打滑特征）
    bool unstable = false;
    if (_lastRatio > 0) {
      double change = (scaledRatio - _lastRatio).abs() / _lastRatio;
      unstable = change > 0.08; // 提高到 8% 避免误判
    }

    // 3. 油门条件
    bool lowThrottle = throttle != null && throttle < _creepMaxThrottle;

    _lastRatio = scaledRatio;

    // 多条件组合判定
    return ratioTooHigh && unstable && lowThrottle;
  }

  // ==================== 核心计算逻辑 ====================

  /// 计算当前档位
  ///
  /// [config] 车辆传动配置，默认使用 [GearConfig.defaults]（GSX-8S 出厂参数）。
  /// 调用处从 SettingsProvider 获取最新配置后传入：
  /// ```dart
  /// final config = GearConfig.fromSettings(context.read<SettingsProvider>());
  /// final gear = GSX8SCalculator.calculateGear(rpm, speed, config: config);
  /// ```
  static int calculateGear(int rpm, int speed,
      {int? throttle, int? load, GearConfig config = GearConfig.defaults}) {
    // 通过 config.theoreticalTotals 获取动态计算的理论传动比列表
    // ⚠️ 不再使用原来的 static final _theoreticalTotals，避免参数固化问题
    final theoreticalTotals = config.theoreticalTotals;
    final neutralSpeedThreshold = config.neutralSpeedThreshold;
    final neutralRpmThreshold = config.neutralRpmThreshold;
    final tireCircumference = config.tireCircumference;

    // ===== 阶段1: 边界条件判定 =====
    // 同时满足低速+低转才判定为空档
    if (speed <= neutralSpeedThreshold && rpm < neutralRpmThreshold) {
      _resetFilter();
      return 0;
    }

    // 单独低速但转速正常 → 可能是半离合蠕动
    if (speed < _minValidSpeed) {
      // 不直接返回0，交给后续判断
    }

    // ===== 阶段2: 传动比计算 =====
    double currentRatio = (rpm * 60 * tireCircumference) / (speed * 1000);

    // ===== 阶段3: 半离合检测 =====
    _isInCreepMode =
        _isCreepingState(speed, throttle, rpm, currentRatio, theoreticalTotals);

    if (_isInCreepMode) {
      // 半离合状态：使用放宽阈值重新匹配
      return _matchGearWithThreshold(
          currentRatio, _creepThreshold, theoreticalTotals);
    }

    // ===== 阶段4: 正常档位匹配 =====
    int bestGear = 0;
    double minRelativeError = double.infinity;

    for (int i = 0; i < theoreticalTotals.length; i++) {
      double theory = theoreticalTotals[i];
      double relativeError = (currentRatio - theory).abs() / theory;

      if (relativeError < minRelativeError) {
        minRelativeError = relativeError;
        bestGear = i + 1;
      }
    }

    // ===== 阶段5: 动态阈值验证 =====
    if (bestGear > 0) {
      double threshold = _gearThresholds[bestGear - 1];

      if (minRelativeError > threshold) {
        // 误差过大，但不立即返回0
        // 检查是否接近相邻档位（换挡过渡区）
        if (_isNearShifting(currentRatio, bestGear, theoreticalTotals)) {
          return _smoothTransition(bestGear);
        }

        // 真正无法匹配时才返回上次档位
        return _lastValidGear > 0 ? _lastValidGear : 0;
      }
    }

    // ===== 阶段6: 平滑滤波 =====
    return _applyFilter(bestGear);
  }

  // ==================== 辅助方法 ====================

  /// 使用指定阈值匹配档位（半离合专用）
  static int _matchGearWithThreshold(
      double ratio, double threshold, List<double> theoreticalTotals) {
    int bestGear = 0;
    double minError = double.infinity;

    for (int i = 0; i < theoreticalTotals.length; i++) {
      double error =
          (ratio - theoreticalTotals[i]).abs() / theoreticalTotals[i];
      if (error < minError && error < threshold) {
        minError = error;
        bestGear = i + 1;
      }
    }

    return bestGear > 0 ? bestGear : _lastValidGear;
  }

  /// 检查是否在换挡过渡区（传动比介于两档之间）
  static bool _isNearShifting(
      double ratio, int gear, List<double> theoreticalTotals) {
    if (gear <= 0 || gear > 6) return false;

    double currentTheory = theoreticalTotals[gear - 1];

    // 检查与相邻档位的距离
    if (gear > 1) {
      double lowerTheory = theoreticalTotals[gear - 2]; // 更高档位（传动比更小）
      if (ratio < currentTheory && ratio > lowerTheory) {
        return true;
      }
    }

    if (gear < 6) {
      double upperTheory = theoreticalTotals[gear]; // 更低档位（传动比更大）
      if (ratio > currentTheory && ratio < upperTheory) {
        return true;
      }
    }

    return false;
  }

  /// 平滑换挡过渡（减少抖动）
  static int _smoothTransition(int newGear) {
    // 只在相邻档位之间才允许快速切换
    if ((_lastValidGear - newGear).abs() == 1) {
      return _applyFilter(newGear, requiredFrames: 2); // 减少到2帧
    }

    // 跨档换挡需要更多确认
    return _applyFilter(newGear, requiredFrames: 4);
  }

  /// 改进的平滑滤波器
  static int _applyFilter(int gear, {int requiredFrames = 3}) {
    // 5<->6档切换：需要更多稳定帧防止抖动
    if ((_lastValidGear == 5 && gear == 6) ||
        (_lastValidGear == 6 && gear == 5)) {
      requiredFrames = 5; // 5帧约250ms，比普通档位切换更慢确认
    }

    if (gear != _pendingGear) {
      _pendingGear = gear;
      _stableFrames = 1; // 从1开始计数
    } else {
      _stableFrames++;
    }

    if (_stableFrames >= requiredFrames) {
      _lastValidGear = gear;
      return gear;
    }

    // 未稳定时的策略：
    // - 如果是相邻档位切换，显示新档位（响应快）
    // - 如果是跳档，保持旧档位（避免误判）
    // - 5<->6档除外，即使相邻也必须等待稳定
    if ((_lastValidGear == 5 && gear == 6) ||
        (_lastValidGear == 6 && gear == 5)) {
      return _lastValidGear; // 保持稳定档位
    }

    if ((_lastValidGear - gear).abs() == 1) {
      return gear;
    }

    return _lastValidGear;
  }

  static void _resetFilter() {
    _lastValidGear = 0;
    _stableFrames = 0;
    _pendingGear = 0;
    _isInCreepMode = false;
  }

  static void reset() {
    _resetFilter();
    _lastRatio = 0;
  }

  // ==================== 调试接口 ====================
  static Map<String, dynamic> getDebugInfo(int rpm, int speed,
      {GearConfig config = GearConfig.defaults}) {
    final theoreticalTotals = config.theoreticalTotals;
    double ratio =
        (rpm * 60 * config.tireCircumference) / (speed * 1000);
    return {
      'currentRatio': ratio.toStringAsFixed(3),
      'isCreepMode': _isInCreepMode,
      'pendingGear': _pendingGear,
      'stableFrames': _stableFrames,
      'theoreticalRatios':
          theoreticalTotals.map((r) => r.toStringAsFixed(3)).toList(),
    };
  }
}
