import 'dart:math' as math;
import 'dart:typed_data';
import '../models/engine_sound_style.dart';

/// 发动机声浪 PCM 合成器
///
/// 合成原理（对齐 demo.html v5 混合合成）：
///   振荡器（累积相位，避免相位跳变）
///     → 噪声 AM 调制（BPF 带限噪声）
///     → 点火脉冲包络（minVal 保底）
///     → 不对称软限幅（低失真指数公式）
///     → 峰值归一化
class EngineSoundSynthesizer {
  static const int sampleRate = 44100;
  static const int refRpm = 3000;

  static const int toneDurationSec = 2;
  static const int noiseDurationSec = 3;
  static const int exhDurationSec = 2;

  static const double upshiftDurationSec = 0.38;
  static const double downshiftDurationSec = 0.55;

  final math.Random _rng = math.Random(42);

  final Map<String, Uint8List> _toneBuffers = {};
  final Map<String, Uint8List> _noiseBuffers = {};
  final Map<String, Uint8List> _exhBuffers = {};

  Uint8List? _upshiftBuffer;
  Uint8List? _downshiftBuffer;

  Uint8List? getToneBuffer(String styleId) => _toneBuffers[styleId];

  Uint8List? getNoiseBuffer(String styleId) => _noiseBuffers[styleId];

  Uint8List? getExhBuffer(String styleId) => _exhBuffers[styleId];

  Uint8List? get upshiftBuffer => _upshiftBuffer;

  Uint8List? get downshiftBuffer => _downshiftBuffer;

  Future<void> init() async {
    for (final style in EngineStyles.all) {
      _toneBuffers[style.id] = _synthToneBuffer(style);
      _noiseBuffers[style.id] = _synthNoiseBuffer(style);
      _exhBuffers[style.id] = _synthExhBuffer(style);
    }
    _upshiftBuffer = _synthUpshiftSfx();
    _downshiftBuffer = _synthDownshiftSfx();
  }

  // ───────────────────────────────────────────────
  // PCM → WAV 封装
  // ───────────────────────────────────────────────

  Uint8List _pcmToWav(Float64List samples) {
    final numSamples = samples.length;
    final dataSize = numSamples * 2;
    final totalSize = 44 + dataSize;
    final bytes = ByteData(totalSize);
    int o = 0;
    _writeStr(bytes, o, 'RIFF');
    o += 4;
    bytes.setUint32(o, totalSize - 8, Endian.little);
    o += 4;
    _writeStr(bytes, o, 'WAVE');
    o += 4;
    _writeStr(bytes, o, 'fmt ');
    o += 4;
    bytes.setUint32(o, 16, Endian.little);
    o += 4;
    bytes.setUint16(o, 1, Endian.little);
    o += 2; // PCM
    bytes.setUint16(o, 1, Endian.little);
    o += 2; // mono
    bytes.setUint32(o, sampleRate, Endian.little);
    o += 4;
    bytes.setUint32(o, sampleRate * 2, Endian.little);
    o += 4;
    bytes.setUint16(o, 2, Endian.little);
    o += 2;
    bytes.setUint16(o, 16, Endian.little);
    o += 2;
    _writeStr(bytes, o, 'data');
    o += 4;
    bytes.setUint32(o, dataSize, Endian.little);
    o += 4;
    for (int i = 0; i < numSamples; i++) {
      final v = (samples[i] * 32767.0).clamp(-32768.0, 32767.0).toInt();
      bytes.setInt16(o, v, Endian.little);
      o += 2;
    }
    return bytes.buffer.asUint8List();
  }

  void _writeStr(ByteData b, int offset, String s) {
    for (int i = 0; i < s.length; i++) {
      b.setUint8(offset + i, s.codeUnitAt(i));
    }
  }

  // ───────────────────────────────────────────────
  // 噪声生成
  // ───────────────────────────────────────────────

  /// 粉红噪声（Paul Kellett 6-阶递推公式）
  Float64List _pinkNoise(int count) {
    final out = Float64List(count);
    double b0 = 0, b1 = 0, b2 = 0, b3 = 0, b4 = 0, b5 = 0;
    for (int i = 0; i < count; i++) {
      final w = _rng.nextDouble() * 2.0 - 1.0;
      b0 = 0.99886 * b0 + w * 0.0555179;
      b1 = 0.99332 * b1 + w * 0.0750759;
      b2 = 0.96900 * b2 + w * 0.1538520;
      b3 = 0.86650 * b3 + w * 0.3104856;
      b4 = 0.55000 * b4 + w * 0.5329522;
      b5 = -0.7616 * b5 - w * 0.0168980;
      out[i] = (b0 + b1 + b2 + b3 + b4 + b5 + w * 0.5362) * 0.11;
    }
    // 归一化
    double mx = 0.0;
    for (final v in out) {
      if (v.abs() > mx) mx = v.abs();
    }
    if (mx > 1e-9) {
      for (int i = 0; i < count; i++) out[i] /= mx;
    }
    return out;
  }

  /// 着色噪声：noiseColor 0=偏白, 1=偏棕
  /// 实现：白+粉（0.5处最纯粉红），棕化在 >0.5 段通过额外积分实现
  Float64List _coloredNoise(int count, double noiseColor) {
    // 先生成高质量粉红噪声（Paul Kellett 公式）
    final pink = _pinkNoise(count);
    if (noiseColor <= 0.5) {
      // 白噪声 → 粉红噪声线性插值
      final t = noiseColor * 2.0; // 0→1
      final out = Float64List(count);
      for (int i = 0; i < count; i++) {
        final w = _rng.nextDouble() * 2.0 - 1.0;
        out[i] = w * (1.0 - t) + pink[i] * t;
      }
      _normalize(out, 1.0);
      return out;
    } else {
      // 粉红噪声 → 棕噪声：对粉红积分
      final t = (noiseColor - 0.5) * 2.0; // 0→1
      final brown = Float64List(count);
      double acc = 0.0;
      for (int i = 0; i < count; i++) {
        acc = acc * 0.998 + pink[i] * 0.002;
        brown[i] = acc;
      }
      _normalize(brown, 1.0);
      final out = Float64List(count);
      for (int i = 0; i < count; i++) {
        out[i] = pink[i] * (1.0 - t) + brown[i] * t;
      }
      _normalize(out, 1.0);
      return out;
    }
  }

  void _normalize(Float64List buf, double targetPeak) {
    double mx = 0.0;
    for (final v in buf) {
      if (v.abs() > mx) mx = v.abs();
    }
    if (mx > 1e-9) {
      final scale = targetPeak / mx;
      for (int i = 0; i < buf.length; i++) buf[i] *= scale;
    }
  }

  // ───────────────────────────────────────────────
  // 滤波器
  // ───────────────────────────────────────────────

  /// 双二阶带通滤波（标准 Audio EQ Cookbook BPF）
  Float64List _bpf(Float64List input, double centerHz, double q) {
    final out = Float64List(input.length);
    final w0 = 2.0 * math.pi * centerHz / sampleRate;
    final cosW0 = math.cos(w0);
    final sinW0 = math.sin(w0);
    final alpha = sinW0 / (2.0 * q);
    final b0 = sinW0 / 2.0; // = (sinW0/2)*1 = alpha * q / q... 简化
    final b1 = 0.0;
    final b2 = -sinW0 / 2.0;
    final a0 = 1.0 + alpha;
    final a1 = -2.0 * cosW0;
    final a2 = 1.0 - alpha;
    double x1 = 0, x2 = 0, y1 = 0, y2 = 0;
    for (int i = 0; i < input.length; i++) {
      final x0 = input[i];
      final y0 = (b0 * x0 + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2) / a0;
      x2 = x1;
      x1 = x0;
      y2 = y1;
      y1 = y0;
      out[i] = y0;
    }
    return out;
  }

  /// 一阶低通滤波
  Float64List _lpf(Float64List input, double cutoffHz) {
    final out = Float64List(input.length);
    final rc = 1.0 / (2.0 * math.pi * cutoffHz);
    final dt = 1.0 / sampleRate;
    final alpha = dt / (rc + dt);
    double prev = 0.0;
    for (int i = 0; i < input.length; i++) {
      prev += alpha * (input[i] - prev);
      out[i] = prev;
    }
    return out;
  }

  // ───────────────────────────────────────────────
  // 软限幅（对齐 demo.html makeAsymDist）
  // ───────────────────────────────────────────────

  /// 不对称指数软限幅，输出范围严格在 (-1, 1)
  /// distAmt 3~6：轻度谐波染色，无明显失真感
  double _asymSoftClip(double x, double distAmt) {
    final k = math.max(distAmt, 0.5);
    if (x >= 0) {
      return 1.0 - math.exp(-k * x * 0.8);
    } else {
      return -(1.0 - math.exp(k * x * 0.45));
    }
  }

  // ───────────────────────────────────────────────
  // 点火脉冲包络（对齐 demo.html makePulseCurve）
  // ───────────────────────────────────────────────

  /// atkFrac: 上升段占比（极短，0.8%~4%）
  /// decK:    衰减系数（越高间隙越静）
  /// minVal:  冲击间最低音量（保底，防止突变）
  Float64List _buildPulseEnvTable(int size, double sharpness) {
    final table = Float64List(size);
    final atkFrac = 0.04 - sharpness * 0.032; // 0.008~0.040
    final decK = 2.0 + sharpness * 7.0; // 2.0~9.0
    final minVal = (0.28 - sharpness * 0.27).clamp(0.01, 0.28);
    for (int i = 0; i < size; i++) {
      final x = i / (size - 1).toDouble();
      final double v;
      if (x < atkFrac) {
        v = x / atkFrac;
      } else {
        v = math.exp(-(x - atkFrac) / (1.0 - atkFrac) * decK);
      }
      table[i] = minVal + v * (1.0 - minVal);
    }
    return table;
  }

  // ───────────────────────────────────────────────
  // Tone Buffer（核心修复：累积相位 + 噪声 AM BPF）
  // ───────────────────────────────────────────────
  Uint8List _synthToneBuffer(EngineStyleConfig style) {
    final sampleCount = sampleRate * toneDurationSec;
    final firingHz = style.firingHz(refRpm);

    const pulseTableSize = 4096;
    final pulseEnvTable =
        _buildPulseEnvTable(pulseTableSize, style.pulseSharpness);

    // 全局粉红噪声源（供各谐波 BPF 使用）
    final globalPink = _coloredNoise(sampleCount, style.noiseColor);

    // 预计算每个谐波的带限噪声（BPF Q=1.5，中心=谐波基频）
    // 注意：BPF 中心频率使用 refRpm 下的静态频率（buffer 是固定速度的）
    final harmonicNoises = <Float64List>[];
    for (final h in style.harmonics) {
      final centerHz = (firingHz * h.mult).clamp(20.0, 18000.0);
      final filtered = _bpf(globalPink, centerHz, 1.5);
      _normalize(filtered, 1.0);
      harmonicNoises.add(filtered);
    }

    final samples = Float64List(sampleCount);

    // 每个谐波维护独立的累积相位（修复根因1：消除相位跳变）
    // wobble 通过直接修改每帧的角频率增量实现，而非修改频率后乘 t
    final phases = List<double>.filled(style.harmonics.length, 0.0);
    // wobble LFO 状态（每谐波一个，频率略有差异）
    final wobbleLfoPhases = List<double>.filled(style.harmonics.length, 0.0);
    final wobbleLfoRates = List<double>.generate(
      style.harmonics.length,
      (i) => style.wobbleHz * (0.7 + i * 0.4) * 2.0 * math.pi / sampleRate,
    );

    // 点火脉冲包络的累积相位（同样使用相位积分器）
    double pulsePhase = 0.0;
    final pulsePhaseInc = firingHz / sampleRate; // 每采样点增量（0~1）

    for (int i = 0; i < sampleCount; i++) {
      // 点火脉冲包络（查表）
      final pulseIdx = (pulsePhase * pulseTableSize).toInt() % pulseTableSize;
      final pulseEnv = pulseEnvTable[pulseIdx];
      pulsePhase += pulsePhaseInc;
      if (pulsePhase >= 1.0) pulsePhase -= 1.0;

      double toneSample = 0.0;

      for (int k = 0; k < style.harmonics.length; k++) {
        final h = style.harmonics[k];

        // 更新 wobble LFO
        wobbleLfoPhases[k] += wobbleLfoRates[k];
        if (wobbleLfoPhases[k] > 2.0 * math.pi) {
          wobbleLfoPhases[k] -= 2.0 * math.pi;
        }
        final wobbleCents = style.wobbleCents * math.sin(wobbleLfoPhases[k]);

        // 本帧频率（含 wobble 微扰动）
        final baseFreq = firingHz * h.mult;
        final freqHz = baseFreq * math.pow(2.0, wobbleCents / 1200.0);

        // 累积相位（修复根因1：每帧增量 = 2π×f/sr，保证连续性）
        phases[k] += 2.0 * math.pi * freqHz / sampleRate;
        if (phases[k] > 2.0 * math.pi) phases[k] -= 2.0 * math.pi;

        // 振荡器（纯正弦，无额外 phases[k] 初始相位）
        double osc = h.amp * math.sin(phases[k]);

        // 噪声 AM 调制（带限噪声，DC 偏置保证不会静音）
        final bandNoise = harmonicNoises[k][i];
        final dcOffset = 1.0 - style.noiseAM * 0.3;
        // amGain 范围：dcOffset-noiseAM*0.5 ~ dcOffset+noiseAM*0.5
        // 以 i4 为例：noiseAM=0.68 → dcOffset=0.796, 范围 [0.456, 1.136]
        // ★ 钳制到 [0.05, 1.5] 防止 AM 增益过大导致信号溢出
        final amGain =
            (dcOffset + bandNoise * style.noiseAM * 0.5).clamp(0.05, 1.5);
        osc *= amGain;

        // 软限幅之前先限制幅度到合理范围（修复根因4：防止硬削波）
        osc = osc.clamp(-2.0, 2.0);
        osc = _asymSoftClip(osc, style.distAmt);

        toneSample += osc;
      }

      // 应用点火脉冲包络
      toneSample *= pulseEnv;

      samples[i] = toneSample;
    }

    // 二阶低通截频（两次叠加 = -12dB/oct，截止 1500Hz）
    // 充分利用 PCM 动态范围（归一化到 1.0），由前端 masterVolume + globalVolume 控制实际音量
    var lpfSamples = _lpf(samples, 1500.0);
    lpfSamples = _lpf(lpfSamples, 1500.0);
    _normalize(lpfSamples, 1.0);
    return _pcmToWav(lpfSamples);
  }

  // ───────────────────────────────────────────────
  // Noise Buffer（修复根因2：只保留低频成分）
  // ───────────────────────────────────────────────
  Uint8List _synthNoiseBuffer(EngineStyleConfig style) {
    final sampleCount = sampleRate * noiseDurationSec;

    // 机械底噪：粉红噪声 → 低通滤波（截止 = mechFreq）
    // 修复根因2：原来直接用宽带 rawNoise × 0.3，改为只用低通滤波后的版本
    final pink = _pinkNoise(sampleCount);
    final mechNoise = _lpf(pink, style.mechFreq.toDouble());

    // 额外的质感层：粉红噪声 → BPF（中心=mechFreq×2，宽带 Q=0.8）增加些许中低频纹理
    final textureBpf = _bpf(pink, style.mechFreq * 2.0, 0.8);

    final samples = Float64List(sampleCount);
    for (int i = 0; i < sampleCount; i++) {
      // 机械底噪（主体）+ 中低频纹理（少量）
      // 完全去掉宽带白/粉红成分，只保留带限内容
      samples[i] = mechNoise[i] * style.mechAmp * 3.0 +
          textureBpf[i] * style.mechAmp * 1.5;
    }

    _normalize(samples, 0.45);
    return _pcmToWav(samples);
  }

  // ───────────────────────────────────────────────
  // Exh Buffer
  // ───────────────────────────────────────────────
  Uint8List _synthExhBuffer(EngineStyleConfig style) {
    final sampleCount = sampleRate * exhDurationSec;
    final rawNoise = _pinkNoise(sampleCount);
    final mixed = Float64List(sampleCount);

    // 串联 peaking + lpf，对齐 demo 的多共振峰结构
    for (int fi = 0; fi < style.exhFreqs.length; fi++) {
      final freq = style.exhFreqs[fi];
      // Q 越高共振峰越窄，fi=0 最宽（Q=6），fi=2 最窄（Q=12）
      final q = 6.0 + fi * 3.0;
      final ampDecay = math.pow(0.65, fi).toDouble();
      final filtered = _bpf(rawNoise, freq, q);
      // 每个共振峰后面加一个 lpf 截掉高频毛刺（截止=freq×5）
      final smoothed = _lpf(filtered, freq * 5.0);
      for (int i = 0; i < sampleCount; i++) {
        mixed[i] += smoothed[i] * ampDecay;
      }
    }

    _normalize(mixed, 0.65);
    return _pcmToWav(mixed);
  }

  // ───────────────────────────────────────────────
  // SFX
  // ───────────────────────────────────────────────

  Uint8List _synthUpshiftSfx() => _synthSfx(
        durationSec: upshiftDurationSec,
        decK: 11.0,
        toneFreq: EngineStyles.i4.exhFreqs[0],
        toneAmp: 0.12,
      );

  Uint8List _synthDownshiftSfx() => _synthSfx(
        durationSec: downshiftDurationSec,
        decK: 6.5,
        toneFreq: EngineStyles.i4.exhFreqs[0],
        toneAmp: 0.12,
      );

  Uint8List _synthSfx({
    required double durationSec,
    required double decK,
    required double toneFreq,
    required double toneAmp,
  }) {
    final sampleCount = (sampleRate * durationSec).toInt();
    // SFX 也用粉红噪声（不用白噪声），减少高频刺耳感
    final pink = _pinkNoise(sampleCount);
    // BPF 在低频区保留排气感
    final filtered = _bpf(pink, toneFreq * 2.0, 1.2);
    final samples = Float64List(sampleCount);

    double tonePhase = 0.0;
    final toneInc = 2.0 * math.pi * toneFreq / sampleRate;

    for (int i = 0; i < sampleCount; i++) {
      final t = i / sampleRate.toDouble();
      final env = math.exp(-decK * t / durationSec);
      tonePhase += toneInc;
      if (tonePhase > 2.0 * math.pi) tonePhase -= 2.0 * math.pi;
      final tone = toneAmp * math.sin(tonePhase);
      samples[i] = (filtered[i] * (1.0 - toneAmp) + tone) * env;
    }

    _normalize(samples, 0.75);
    return _pcmToWav(samples);
  }
}
