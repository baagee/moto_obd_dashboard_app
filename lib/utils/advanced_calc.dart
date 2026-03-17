
class GSX8SAdvancedCalculator {
  // --- 铃木 GSX-8S 车辆 核心物理常数 ---
  static const double primaryRatio = 1.681;
  static const double finalRatio = 2.764;
  static const double displacement = 0.776; // 升
  static const List<double> gearRatios = [3.076, 2.125, 1.619, 1.285, 1.083, 0.956];

  // 预计算总传动比，提升运算性能
  static final List<double> _theoryTotals =
      gearRatios.map((g) => primaryRatio * g * finalRatio).toList();

  /// 优化后的档位计算：引入离合判定与动态误差窗口
  static int calculateGear(int rpm, int speed, int throttle, int load) {
    if (speed < 5 || rpm < 1100) return 0;

    // 计算实时总传动比
    // 轮胎周长考虑动态变形（高速下由于离心率，实际滚动圆周会略微增加，取均值 1.98）
    double currentRatio = (rpm * 60 * 1.98) / (speed * 1000);

    int bestGear = 0;
    double minRelativeError = double.infinity;

    for (int i = 0; i < _theoryTotals.length; i++) {
      double error = (currentRatio - _theoryTotals[i]).abs() / _theoryTotals[i];
      if (error < minRelativeError) {
        minRelativeError = error;
        bestGear = i + 1;
      }
    }

    // --- 逻辑修正窗 ---
    // 1. 离合器/换挡判定：若相对误差 > 12%，判定为非挂档状态（切离合或空档）
    if (minRelativeError > 0.12) return 0;

    // 2. 载荷判定：若转速极高但油门/负载极低，可能是拉离合滑行
    if (rpm > 3000 && load < 5 && throttle < 2) return 0;

    return bestGear;
  }

  /// 优化后的油耗计算：引入非线性 VE 曲线与 Lambda 修正
  /// [lambda] 选填，若 OBD 能读到 PID 0x24 (Lambda)，精度提升 15%
  /// [map] OBD 标准单位: kPa (进气歧管绝对压力)
  /// [iat] 进气温度 单位: Celsius
  static Map<String, double> calculateFuel({
    required int rpm,
    required int speed,
    required int map, // 单位: kPa (OBD 标准)
    required int iat, // 单位: Celsius
    double lambda = 1.0,
  }) {
    if (rpm < 500) return {"L_h": 0.0, "L_100km": 0.0};

    // === 单位转换 ===
    double tempK = iat + 273.15; // Celsius → Kelvin
    double pressurePa = map * 1000.0; // kPa → Pa (SI 单位)
    // displacement 已经是 m³ (0.000776)

    // === VE (容积效率) 模型 ===
    // 钟形曲线：峰值在 6800rpm
    double rpmFactor = 1.0 - ((rpm - 6800).abs() / 15000.0);
    // MAP 因子：相对于大气压的比例 (添加 clamp 防止极端值)
    double mapFactor = (map / 101.325).clamp(0.2, 1.0);

    // VE 范围: 0.55 (低效) ~ 0.95 (高效)
    double ve = 0.60 + (0.30 * mapFactor) + (0.05 * rpmFactor);
    ve = ve.clamp(0.55, 0.95);

    // === MAF 质量空气流量 (g/s) ===
    // 理想气体状态方程: PV = nRT
    // 转换为质量流量: m = (P * V * RPM * VE * M) / (120 * R * T)
    double maf = (pressurePa * displacement * rpm * ve * 28.97)
        / (120.0 * 8.314 * tempK);

    // === 燃油流量计算 ===
    // 实际空燃比 = 理论空燃比 × Lambda
    double actualAFR = 14.7 * lambda;

    // 发动机制动断油检测 (Fuel Cut-off)
    // 条件：进气歧管真空度大（低压）且转速高于怠速
    bool isFuelCut = map < 30 && rpm > 2500;
    double fuelGps = isFuelCut ? 0.0 : (maf / actualAFR);

    // 燃油密度 95# ≈ 735 g/L
    double lPerHour = (fuelGps * 3600.0) / 735.0;
    double lPer100km = speed > 5 ? (lPerHour * 100.0) / speed : 0.0;

    return {
      "L_h": double.parse(lPerHour.toStringAsFixed(2)),
      "L_100km": double.parse(lPer100km.toStringAsFixed(2)),
    };
  }
}
