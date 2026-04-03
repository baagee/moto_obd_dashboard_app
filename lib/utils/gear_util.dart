import 'package:shared_preferences/shared_preferences.dart';
import '../providers/settings_provider.dart';

/// 车辆传动参数配置对象
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

  /// 根据当前配置计算各档位理论传动比
  List<double> get theoreticalTotals =>
      gearRatios.map((g) => primaryRatio * g * finalRatio).toList();
}

class GSX8SCalculator {
  // ==================== 阈值配置 ====================
  // 按文档建议值调整（收窄高档区间距，避免5/6档重叠区）
  static const List<double> _gearThresholds = [
    0.18, // 1档: 间距28.4%，充足
    0.13, // 2档: 间距22.7%，收窄
    0.11, // 3档: 间距16.7%，合理
    0.09, // 4档: 间距16.7%(上)/13.1%(下)，取下界70%
    0.07, // 5档: 间距10.8%，严格防止与6档重叠
    0.08, // 6档: 最高档，收窄无意义放宽
  ];

  // 半离合专用阈值（放宽）
  static const double _creepThreshold = 0.25;

  // 换挡瞬间传动比变化率阈值（A2）
  static const double _shiftingRatioChangeRate = 0.15;

  // ==================== A1: RPM/Speed 中值滤波缓冲区 ====================
  static const int _filterBufferSize = 3;
  static final List<int> _rpmBuffer = [];
  static final List<int> _speedBuffer = [];

  // ==================== 状态管理 ====================
  static int _lastValidGear = 0;
  static int _stableFrames = 0;
  static int _pendingGear = 0;
  static double _lastRatio = 0;
  static bool _isInCreepMode = false;

  // A2: 换挡状态
  static bool _isShifting = false;

  // B2: 方向约束
  static int _lastShiftDirection = 0; // -1降档, 0中立, +1升档

  // ==================== C1: 自适应传动比学习 ====================
  static final List<double?> _learnedRatios = List.filled(6, null);
  static const double _learningRate = 0.05;

  // 稳态检测缓冲（用于触发学习）
  static final List<double> _recentRatios = [];
  static final List<int> _recentSpeeds = [];
  static final List<int> _recentThrottles = [];
  static const int _steadyBufferSize = 3;
  static int _lastLearnGear = 0; // Bug4修复：感知档位切换，切换时清空缓冲
  static const String _prefsKeyPrefix = 'gear_learned_ratio_';

  // ==================== 边界检测 ====================
  static const int _minValidSpeed = 5;

  // ==================== 半离合检测参数 ====================
  static const int _creepMinSpeed = 3;
  static const int _creepMaxSpeed = 20;
  static const int _creepMaxThrottle = 35;

  // ==================== 初始化：从持久化存储加载学习值 ====================
  static Future<void> loadLearnedRatios() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (int i = 0; i < 6; i++) {
        final key = '$_prefsKeyPrefix$i';
        final value = prefs.getDouble(key);
        if (value != null && value > 0) {
          _learnedRatios[i] = value;
        }
      }
    } catch (_) {
      // 读取失败时静默忽略，使用理论值
    }
  }

  /// 重置学习值（由外部调用，如用户手动重置）
  static Future<void> resetLearnedRatios() async {
    for (int i = 0; i < 6; i++) {
      _learnedRatios[i] = null;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      for (int i = 0; i < 6; i++) {
        await prefs.remove('$_prefsKeyPrefix$i');
      }
    } catch (_) {}
  }

  // ==================== A1: 中值滤波 ====================

  static int _medianFilter(List<int> buffer) {
    if (buffer.isEmpty) return 0;
    final sorted = List<int>.from(buffer)..sort();
    return sorted[sorted.length ~/ 2];
  }

  static void _pushToBuffer(List<int> buffer, int value, int maxSize) {
    buffer.add(value);
    if (buffer.length > maxSize) buffer.removeAt(0);
  }

  // ==================== 半离合检测 ====================

  static bool _isCreepingState(int speed, int? throttle, int rpm,
      double scaledRatio, List<double> theoreticalTotals) {
    if (speed < _creepMinSpeed || speed > _creepMaxSpeed) {
      _lastRatio = scaledRatio;
      return false;
    }
    if (rpm < 1200) {
      _lastRatio = scaledRatio;
      return false;
    }

    double maxTheoryRatio = theoreticalTotals[0];
    bool ratioTooHigh = scaledRatio > maxTheoryRatio * 1.20;

    bool unstable = false;
    if (_lastRatio > 0) {
      double change = (scaledRatio - _lastRatio).abs() / _lastRatio;
      unstable = change > 0.08;
    }

    bool lowThrottle = throttle != null && throttle < _creepMaxThrottle;

    _lastRatio = scaledRatio;
    return ratioTooHigh && unstable && lowThrottle;
  }

  // ==================== B2: 方向约束 ====================

  /// 判断档位跳变是否物理合理
  static bool _isPhysicallyReasonable(int fromGear, int toGear, int speed) {
    if (fromGear <= 0) return true; // 首次识别，无约束
    final diff = (toGear - fromGear).abs();
    // 超过2档的跳变视为不合理
    if (diff > 2) return false;
    // 高速时不允许突然出现1档（> 30 km/h）
    if (toGear == 1 && speed > 30) return false;
    return true;
  }

  // ==================== D1: 分级滤波 ====================

  /// 根据传动比误差和上下文计算所需稳定帧数
  static int _computeRequiredFrames(
      int gear, double relativeError, double threshold,
      {int? throttle}) {
    // 5↔6档：始终需要5帧（间距最小）
    if ((_lastValidGear == 5 && gear == 6) ||
        (_lastValidGear == 6 && gear == 5)) {
      return 5;
    }

    final errorRatio = relativeError / threshold;

    // 高置信度：误差 < 40% 阈值 → 1帧直接切换
    if (errorRatio < 0.40) return 1;

    // 中等置信度：误差 40%~80% 阈值 → 3帧
    if (errorRatio < 0.80) return 3;

    // 低置信度：误差 > 80% 阈值 → 5帧
    return 5;
  }

  // ==================== C1: 自适应传动比学习 ====================

  static void _tryLearnRatio(
      int gear, double measuredRatio, int speed, int? throttle, int rpm) {
    if (gear <= 0 || gear > 6) return;
    if (rpm < 2000) return; // 排除怠速抖动

    // Bug4修复：档位切换时清空缓冲，防止混入上一档的传动比样本
    if (gear != _lastLearnGear) {
      _recentRatios.clear();
      _recentSpeeds.clear();
      _recentThrottles.clear();
      _lastLearnGear = gear;
    }

    // 推入稳态缓冲
    _recentRatios.add(measuredRatio);
    _recentSpeeds.add(speed);
    if (throttle != null) _recentThrottles.add(throttle);

    if (_recentRatios.length > _steadyBufferSize) {
      _recentRatios.removeAt(0);
    }
    if (_recentSpeeds.length > _steadyBufferSize) {
      _recentSpeeds.removeAt(0);
    }
    if (_recentThrottles.length > _steadyBufferSize) {
      _recentThrottles.removeAt(0);
    }

    if (_recentRatios.length < _steadyBufferSize) return;

    // 稳态判定：速度变化 < 2 km/h，传动比变化 < 1%，油门变化 < 5%
    final maxSpd = _recentSpeeds.reduce((a, b) => a > b ? a : b);
    final minSpd = _recentSpeeds.reduce((a, b) => a < b ? a : b);
    final speedVariance = maxSpd - minSpd;
    final ratioMax = _recentRatios.reduce((a, b) => a > b ? a : b);
    final ratioMin = _recentRatios.reduce((a, b) => a < b ? a : b);
    final ratioVariance = ratioMax - ratioMin;

    bool speedStable = speedVariance.abs() <= 2;
    bool ratioStable = ratioMin > 0 && (ratioVariance / ratioMin) < 0.01;
    bool throttleStable = _recentThrottles.length < _steadyBufferSize ||
        (_recentThrottles.reduce((a, b) => a > b ? a : b) -
                    _recentThrottles.reduce((a, b) => a < b ? a : b))
                .abs() <=
            5;

    if (!speedStable || !ratioStable || !throttleStable) return;

    // EMA 更新学习值
    final avgRatio =
        _recentRatios.reduce((a, b) => a + b) / _recentRatios.length;
    if (_learnedRatios[gear - 1] == null) {
      _learnedRatios[gear - 1] = avgRatio;
    } else {
      _learnedRatios[gear - 1] =
          _learnedRatios[gear - 1]! * (1 - _learningRate) +
              avgRatio * _learningRate;
    }

    // 异步持久化（不阻塞计算）
    _persistLearnedRatio(gear - 1, _learnedRatios[gear - 1]!);
  }

  static Future<void> _persistLearnedRatio(int index, double value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('$_prefsKeyPrefix$index', value);
    } catch (_) {}
  }

  // ==================== 核心计算逻辑 ====================

  /// 计算当前档位（含所有优化）
  static int calculateGear(int rpm, int speed,
      {int? throttle, int? load, GearConfig config = GearConfig.defaults}) {
    final theoreticalTotals = config.theoreticalTotals;
    final neutralSpeedThreshold = config.neutralSpeedThreshold;
    final neutralRpmThreshold = config.neutralRpmThreshold;
    final tireCircumference = config.tireCircumference;

    // ===== 阶段1: 边界条件判定 =====
    if (speed <= neutralSpeedThreshold && rpm < neutralRpmThreshold) {
      _resetFilter();
      return 0;
    }

    // ===== A1: 中值滤波 RPM/Speed =====
    _pushToBuffer(_rpmBuffer, rpm, _filterBufferSize);
    _pushToBuffer(_speedBuffer, speed, _filterBufferSize);

    final smoothRpm = _medianFilter(_rpmBuffer);
    final smoothSpeed = _medianFilter(_speedBuffer);

    // 速度为0时跳过（避免除零）
    if (smoothSpeed <= 0) return _lastValidGear;

    // ===== 阶段2: 传动比计算（使用平滑值）=====
    double currentRatio =
        (smoothRpm * 60.0 * tireCircumference) / (smoothSpeed * 1000.0);

    // ===== A2: 换挡瞬间检测 =====
    if (_lastRatio > 0) {
      final changeRate = (currentRatio - _lastRatio).abs() / _lastRatio;
      if (changeRate > _shiftingRatioChangeRate) {
        _isShifting = true;
        _lastRatio = currentRatio;
        return _lastValidGear; // 换挡中，冻结显示
      }
    }
    _isShifting = false;
    _lastRatio = currentRatio;

    // ===== 阶段3: 半离合检测 =====
    _isInCreepMode = _isCreepingState(
        smoothSpeed, throttle, smoothRpm, currentRatio, theoreticalTotals);

    if (_isInCreepMode) {
      return _matchGearWithThreshold(
          currentRatio, _creepThreshold, theoreticalTotals);
    }

    // 低速边界但非半离合（不直接返回0，交给后续判断）
    if (smoothSpeed < _minValidSpeed) {
      // pass
    }

    // ===== 阶段4: 最近邻匹配（优先使用学习值）=====
    int bestGear = 0;
    double minRelativeError = double.infinity;

    for (int i = 0; i < theoreticalTotals.length; i++) {
      // C1: 有学习值时混合使用（70% 学习值 + 30% 理论值）
      final effectiveTheory = _learnedRatios[i] != null
          ? _learnedRatios[i]! * 0.7 + theoreticalTotals[i] * 0.3
          : theoreticalTotals[i];

      final relativeError =
          (currentRatio - effectiveTheory).abs() / effectiveTheory;

      if (relativeError < minRelativeError) {
        minRelativeError = relativeError;
        bestGear = i + 1;
      }
    }

    // ===== B2: 方向约束验证（第一道防线）=====
    if (bestGear > 0 &&
        !_isPhysicallyReasonable(_lastValidGear, bestGear, smoothSpeed)) {
      return _lastValidGear > 0 ? _lastValidGear : 0;
    }

    // ===== 阶段5: 动态阈值验证 =====
    if (bestGear > 0) {
      final threshold = _gearThresholds[bestGear - 1];

      if (minRelativeError > threshold) {
        if (_isNearShifting(currentRatio, bestGear, theoreticalTotals)) {
          return _smoothTransition(bestGear, minRelativeError, threshold);
        }
        return _lastValidGear > 0 ? _lastValidGear : 0;
      }

      // B2: 方向约束（档位跳变合理性检查）
      if (!_isPhysicallyReasonable(_lastValidGear, bestGear, smoothSpeed)) {
        // 不合理跳变，需要更多帧确认才允许
        return _applyFilter(bestGear, requiredFrames: 6);
      }
    }

    // ===== C1: 稳态学习 =====
    if (bestGear > 0) {
      _tryLearnRatio(bestGear, currentRatio, smoothSpeed, throttle, smoothRpm);
    }

    // ===== 阶段6: D1 分级滤波 =====
    if (bestGear > 0) {
      final threshold = _gearThresholds[bestGear - 1];
      final requiredFrames = _computeRequiredFrames(
          bestGear, minRelativeError, threshold,
          throttle: throttle);
      return _applyFilter(bestGear, requiredFrames: requiredFrames);
    }

    return _applyFilter(bestGear);
  }

  // ==================== 辅助方法 ====================

  static int _matchGearWithThreshold(
      double ratio, double threshold, List<double> theoreticalTotals) {
    int bestGear = 0;
    double minError = double.infinity;

    for (int i = 0; i < theoreticalTotals.length; i++) {
      final effectiveTheory = _learnedRatios[i] != null
          ? _learnedRatios[i]! * 0.7 + theoreticalTotals[i] * 0.3
          : theoreticalTotals[i];
      final error = (ratio - effectiveTheory).abs() / effectiveTheory;
      if (error < minError && error < threshold) {
        minError = error;
        bestGear = i + 1;
      }
    }

    return bestGear > 0 ? bestGear : _lastValidGear;
  }

  static bool _isNearShifting(
      double ratio, int gear, List<double> theoreticalTotals) {
    if (gear <= 0 || gear > 6) return false;

    final currentTheory = theoreticalTotals[gear - 1];

    if (gear > 1) {
      final lowerTheory = theoreticalTotals[gear - 2];
      if (ratio < currentTheory && ratio > lowerTheory) return true;
    }

    if (gear < 6) {
      final upperTheory = theoreticalTotals[gear];
      if (ratio > currentTheory && ratio < upperTheory) return true;
    }

    return false;
  }

  static int _smoothTransition(
      int newGear, double relativeError, double threshold) {
    // 相邻档位过渡：根据误差分级
    if ((_lastValidGear - newGear).abs() == 1) {
      final frames = _computeRequiredFrames(newGear, relativeError, threshold);
      return _applyFilter(newGear, requiredFrames: frames);
    }
    return _applyFilter(newGear, requiredFrames: 4);
  }

  /// D1 分级平滑滤波器
  static int _applyFilter(int gear, {int requiredFrames = 3}) {
    // 5↔6档切换：强制5帧
    if ((_lastValidGear == 5 && gear == 6) ||
        (_lastValidGear == 6 && gear == 5)) {
      requiredFrames = requiredFrames < 5 ? 5 : requiredFrames;
    }

    if (gear != _pendingGear) {
      _pendingGear = gear;
      _stableFrames = 1;
    } else {
      _stableFrames++;
    }

    if (_stableFrames >= requiredFrames) {
      // 更新方向记忆（B2）
      if (_lastValidGear > 0 && gear != _lastValidGear) {
        _lastShiftDirection = gear > _lastValidGear ? 1 : -1;
      }
      _lastValidGear = gear;
      return gear;
    }

    // 未稳定时的策略
    if ((_lastValidGear == 5 && gear == 6) ||
        (_lastValidGear == 6 && gear == 5)) {
      return _lastValidGear;
    }

    // 高置信度（1帧）：直接返回新档
    if (requiredFrames == 1) return gear;

    // 相邻档位切换：乐观显示
    if ((_lastValidGear - gear).abs() == 1) return gear;

    return _lastValidGear;
  }

  static void _resetFilter() {
    _lastValidGear = 0;
    _stableFrames = 0;
    _pendingGear = 0;
    _isInCreepMode = false;
    _isShifting = false;
    _lastShiftDirection = 0;
    _lastLearnGear = 0;
    _lastRatio = 0;
    _rpmBuffer.clear();
    _speedBuffer.clear();
    _recentRatios.clear();
    _recentSpeeds.clear();
    _recentThrottles.clear();
  }

  static void reset() {
    _resetFilter();
    _lastRatio = 0;
  }

  // ==================== 调试接口 ====================
  static Map<String, dynamic> getDebugInfo(int rpm, int speed,
      {GearConfig config = GearConfig.defaults}) {
    final theoreticalTotals = config.theoreticalTotals;
    final ratio = speed > 0
        ? (rpm * 60.0 * config.tireCircumference) / (speed * 1000.0)
        : 0.0;
    return {
      'currentRatio': ratio.toStringAsFixed(3),
      'smoothRpm': _rpmBuffer.isNotEmpty ? _medianFilter(_rpmBuffer) : rpm,
      'smoothSpeed':
          _speedBuffer.isNotEmpty ? _medianFilter(_speedBuffer) : speed,
      'isCreepMode': _isInCreepMode,
      'isShifting': _isShifting,
      'pendingGear': _pendingGear,
      'stableFrames': _stableFrames,
      'lastShiftDirection': _lastShiftDirection,
      'learnedRatios':
          _learnedRatios.map((r) => r?.toStringAsFixed(3) ?? 'null').toList(),
      'theoreticalRatios':
          theoreticalTotals.map((r) => r.toStringAsFixed(3)).toList(),
    };
  }
}
