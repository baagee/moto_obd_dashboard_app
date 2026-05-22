// 发动机声浪风格配置数据模型
// 对应技术方案 engine-sound-design.md §3

/// 单个谐波配置
class HarmonicConfig {
  final double mult; // 谐波倍数（相对于点火基频）
  final double amp; // 谐波幅度 0~1

  const HarmonicConfig({
    required this.mult,
    required this.amp,
  });
}

/// 发动机风格完整配方
class EngineStyleConfig {
  final String id; // 'i4' | 'v4' | 'i6' | 'v8'
  final String name; // 显示名称
  final int cyls; // 气缸数（决定点火频率 = rpm/60 × cyls/2）
  final int maxRpm; // 红线转速
  final List<HarmonicConfig> harmonics; // 谐波组
  final double noiseAM; // 噪声 AM 调制深度 0~1
  final double noiseColor; // 0=白噪声, 1=棕噪声（越大低频越多）
  final double wobbleHz; // 微音高游走 LFO 速率（Hz）
  final double wobbleCents; // 微音高游走幅度（cents）
  final List<double> exhFreqs; // 排气管共振峰频率（Hz）
  final double pulseSharpness; // 点火脉冲锐度 0=圆滑 1=锐利
  final double mechFreq; // 机械底噪截止频率（Hz）
  final double mechAmp; // 机械底噪幅度
  final double distAmt; // 不对称软限幅强度（3~8）

  const EngineStyleConfig({
    required this.id,
    required this.name,
    required this.cyls,
    required this.maxRpm,
    required this.harmonics,
    required this.noiseAM,
    required this.noiseColor,
    required this.wobbleHz,
    required this.wobbleCents,
    required this.exhFreqs,
    required this.pulseSharpness,
    required this.mechFreq,
    required this.mechAmp,
    required this.distAmt,
  });

  /// 点火频率（Hz）= (rpm/60) × (cyls/2)
  double firingHz(int rpm) => (rpm / 60.0) * (cyls / 2.0);
}

/// 四种预设风格
class EngineStyles {
  // ── 直列四缸 (i4) ──
  // 特征：2× 和 4× 谐波为主，均匀点火，清脆高转
  static const i4 = EngineStyleConfig(
    id: 'i4',
    name: '直列四缸',
    cyls: 4,
    maxRpm: 14000,
    harmonics: [
      HarmonicConfig(mult: 2.0, amp: 0.90),
      HarmonicConfig(mult: 4.0, amp: 0.65),
      HarmonicConfig(mult: 6.0, amp: 0.40),
    ],
    noiseAM: 0.68,
    noiseColor: 0.45,
    wobbleHz: 1.2,
    wobbleCents: 6.0,
    exhFreqs: [175.0, 350.0, 700.0],
    pulseSharpness: 0.72,
    mechFreq: 320.0,
    mechAmp: 0.055,
    distAmt: 5.5,
  );

  // ── V型四缸 (v4) ──
  // 特征：0.5× 半次频突出，不均匀点火节奏，更粗犷
  static const v4 = EngineStyleConfig(
    id: 'v4',
    name: 'V型四缸',
    cyls: 4,
    maxRpm: 16000,
    harmonics: [
      HarmonicConfig(mult: 0.5, amp: 0.60),
      HarmonicConfig(mult: 1.0, amp: 0.70),
      HarmonicConfig(mult: 2.0, amp: 0.75),
      HarmonicConfig(mult: 4.0, amp: 0.80),
    ],
    noiseAM: 0.72,
    noiseColor: 0.52,
    wobbleHz: 0.8,
    wobbleCents: 9.0,
    exhFreqs: [130.0, 260.0, 520.0],
    pulseSharpness: 0.65,
    mechFreq: 260.0,
    mechAmp: 0.065,
    distAmt: 5.5,
  );

  // ── 直列六缸 (i6) ──
  // 特征：6× 谐波最强，点火最密（每转3次），丝滑顺畅
  static const i6 = EngineStyleConfig(
    id: 'i6',
    name: '直列六缸',
    cyls: 6,
    maxRpm: 13000,
    harmonics: [
      HarmonicConfig(mult: 3.0, amp: 0.65),
      HarmonicConfig(mult: 6.0, amp: 1.00),
      HarmonicConfig(mult: 9.0, amp: 0.45),
    ],
    noiseAM: 0.55,
    noiseColor: 0.38,
    wobbleHz: 1.8,
    wobbleCents: 4.0,
    exhFreqs: [220.0, 440.0, 880.0],
    pulseSharpness: 0.85,
    mechFreq: 420.0,
    mechAmp: 0.040,
    distAmt: 5.5,
  );

  // ── V8 美式 (v8) ──
  // 特征：0.5× 低频主导，pulseSharpness 最低（最圆滑），低沉咆哮
  static const v8 = EngineStyleConfig(
    id: 'v8',
    name: 'V8 美式',
    cyls: 8,
    maxRpm: 8000,
    harmonics: [
      HarmonicConfig(mult: 0.5, amp: 0.70),
      HarmonicConfig(mult: 1.0, amp: 0.85),
      HarmonicConfig(mult: 2.0, amp: 0.60),
      HarmonicConfig(mult: 4.0, amp: 0.35),
    ],
    noiseAM: 0.75,
    noiseColor: 0.65,
    wobbleHz: 0.5,
    wobbleCents: 12.0,
    exhFreqs: [92.0, 184.0, 368.0],
    pulseSharpness: 0.55,
    mechFreq: 190.0,
    mechAmp: 0.080,
    distAmt: 5.5,
  );

  /// 按 id 查找风格，默认 i4
  static EngineStyleConfig fromId(String id) {
    switch (id) {
      case 'v4':
        return v4;
      case 'i6':
        return i6;
      case 'v8':
        return v8;
      case 'i4':
      default:
        return i4;
    }
  }

  /// 所有风格列表
  static const List<EngineStyleConfig> all = [i4, v4, i6, v8];
}
