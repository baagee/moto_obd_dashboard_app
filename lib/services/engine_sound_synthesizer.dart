import 'dart:math' as math;
import 'dart:typed_data';
import '../models/engine_sound_style.dart';

/// 发动机声浪 PCM 合成器
///
/// 在 App 启动时（init()）预先在后台线程合成所有风格的 WAV buffer，
/// 供 EngineSoundEngine 通过 flutter_soloud 加载和播放。
///
/// 每种风格合成 3 个 buffer（在 refRpm=3000 下）：
///   - tone_buffer:  振荡器谐波叠加 PCM（2秒循环，44100Hz，16bit mono）
///   - noise_buffer: 粉红噪声 PCM（3秒循环，44100Hz，16bit mono）
///   - exh_buffer:   排气共振峰噪声 PCM（2秒循环，44100Hz，16bit mono）
///
/// SFX buffer（换挡音效，风格无关）：
///   - upshift_sfx:   升档音效（0.38s）
///   - downshift_sfx: 降档/回火音效（0.55s）
///
/// 合成原理：混合合成架构
///   振荡器 → 噪声 AM 调制 → 点火脉冲包络 → 不对称软限幅
class EngineSoundSynthesizer {
  static const int sampleRate = 44100;
  static const int refRpm = 3000;

  // tone_buffer 2秒，noise_buffer 3秒，exh_buffer 2秒
  static const int toneDurationSec = 2;
  static const int noiseDurationSec = 3;
  static const int exhDurationSec = 2;

  // SFX 时长
  static const double upshiftDurationSec = 0.38;
  static const double downshiftDurationSec = 0.55;

  final math.Random _rng = math.Random(42); // 固定种子保证重现性

  // 各风格的合成 buffer（key = styleId）
  final Map<String, Uint8List> _toneBuffers = {};
  final Map<String, Uint8List> _noiseBuffers = {};
  final Map<String, Uint8List> _exhBuffers = {};

  // SFX（换挡音效，风格无关，使用 i4 exhFreqs[0] 作为默认）
  Uint8List? _upshiftBuffer;
  Uint8List? _downshiftBuffer;

  // ── getter ──
  Uint8List? getToneBuffer(String styleId) => _toneBuffers[styleId];
  Uint8List? getNoiseBuffer(String styleId) => _noiseBuffers[styleId];
  Uint8List? getExhBuffer(String styleId) => _exhBuffers[styleId];
  Uint8List? get upshiftBuffer => _upshiftBuffer;
  Uint8List? get downshiftBuffer => _downshiftBuffer;

  /// 初始化：在后台 Isolate 中合成所有 buffer
  /// 调用方应 await 此方法（约 200~500ms）
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
  // 合成辅助工具
  // ───────────────────────────────────────────────

  /// 将 PCM samples（-1.0~1.0）打包成 16bit mono WAV bytes
  Uint8List _pcmToWav(Float64List samples) {
    final numSamples = samples.length;
    final dataSize = numSamples * 2; // 16bit = 2 bytes/sample
    final totalSize = 44 + dataSize;

    final bytes = ByteData(totalSize);
    int offset = 0;

    // RIFF 头
    _writeStr(bytes, offset, 'RIFF');
    offset += 4;
    bytes.setUint32(offset, totalSize - 8, Endian.little);
    offset += 4;
    _writeStr(bytes, offset, 'WAVE');
    offset += 4;
    _writeStr(bytes, offset, 'fmt ');
    offset += 4;
    bytes.setUint32(offset, 16, Endian.little); // chunk size
    offset += 4;
    bytes.setUint16(offset, 1, Endian.little); // PCM = 1
    offset += 2;
    bytes.setUint16(offset, 1, Endian.little); // mono
    offset += 2;
    bytes.setUint32(offset, sampleRate, Endian.little);
    offset += 4;
    bytes.setUint32(offset, sampleRate * 2, Endian.little); // byte rate
    offset += 4;
    bytes.setUint16(offset, 2, Endian.little); // block align
    offset += 2;
    bytes.setUint16(offset, 16, Endian.little); // bits per sample
    offset += 2;
    _writeStr(bytes, offset, 'data');
    offset += 4;
    bytes.setUint32(offset, dataSize, Endian.little);
    offset += 4;

    // PCM data（clamp 到 int16 范围）
    for (int i = 0; i < numSamples; i++) {
      final v = (samples[i] * 32767.0).clamp(-32768.0, 32767.0).toInt();
      bytes.setInt16(offset, v, Endian.little);
      offset += 2;
    }

    return bytes.buffer.asUint8List();
  }

  void _writeStr(ByteData b, int offset, String s) {
    for (int i = 0; i < s.length; i++) {
      b.setUint8(offset + i, s.codeUnitAt(i));
    }
  }

  /// 生成粉红噪声（Voss-McCartney 算法，6级）
  Float64List _pinkNoise(int count) {
    final out = Float64List(count);
    final rows = List<double>.filled(6, 0.0);
    double running = 0.0;
    for (int i = 0; i < count; i++) {
      final bits = i ^ (i - 1); // 发生变化的 bit
      for (int j = 0; j < 6; j++) {
        if ((bits >> j) & 1 == 1) {
          final newVal = _rng.nextDouble() * 2.0 - 1.0;
          running += newVal - rows[j];
          rows[j] = newVal;
        }
      }
      out[i] = running / 6.0;
    }
    // 归一化
    double mx = out.fold(0.0, (p, e) => e.abs() > p ? e.abs() : p);
    if (mx > 0) {
      for (int i = 0; i < count; i++) {
        out[i] /= mx;
      }
    }
    return out;
  }

  /// 生成"着色"噪声：noiseColor 0=白 1=棕（粉红为 0.5）
  /// 实现：白噪声 + noiseColor 权重的粉红噪声混合，再做简单 LP 滤波实现棕化
  Float64List _coloredNoise(int count, double noiseColor) {
    final white = Float64List(count);
    for (int i = 0; i < count; i++) {
      white[i] = _rng.nextDouble() * 2.0 - 1.0;
    }
    if (noiseColor <= 0.01) return white;

    final pink = _pinkNoise(count);
    final out = Float64List(count);
    // 棕化：累积积分
    double integral = 0.0;
    final brownPow = (noiseColor - 0.5).clamp(0.0, 0.5) / 0.5;
    for (int i = 0; i < count; i++) {
      integral = integral * 0.999 + white[i] * 0.001;
      final brown = integral;
      final pinkMix = pink[i] * noiseColor.clamp(0.0, 1.0);
      final brownMix = brown * brownPow;
      out[i] = white[i] * (1.0 - noiseColor) + pinkMix + brownMix;
    }
    // 归一化
    double mx = out.fold(0.0, (p, e) => e.abs() > p ? e.abs() : p);
    if (mx > 0) {
      for (int i = 0; i < count; i++) {
        out[i] /= mx;
      }
    }
    return out;
  }

  /// 简单双极点带通滤波（Butterworth 近似）
  Float64List _bpf(Float64List input, double centerHz, double qFactor) {
    final out = Float64List(input.length);
    final w0 = 2.0 * math.pi * centerHz / sampleRate;
    final alpha = math.sin(w0) / (2.0 * qFactor);
    final b0 = alpha;
    final b1 = 0.0; // b1 = 0 for BPF
    final b2 = -alpha;
    final a0 = 1.0 + alpha;
    final a1 = -2.0 * math.cos(w0);
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

  /// 简单低通滤波
  Float64List _lpf(Float64List input, double cutoffHz) {
    final out = Float64List(input.length);
    final rc = 1.0 / (2.0 * math.pi * cutoffHz);
    final dt = 1.0 / sampleRate;
    final alpha = dt / (rc + dt);
    double prev = 0.0;
    for (int i = 0; i < input.length; i++) {
      prev = prev + alpha * (input[i] - prev);
      out[i] = prev;
    }
    return out;
  }

  /// 不对称软限幅（对齐 demo.html makeAsymDist 指数公式）
  /// 正半周（爆发冲程）更强限幅，负半周（排气冲程）较弱
  /// distAmt 建议 3~6；atan 在此范围失真过多已弃用
  double _asymSoftClip(double x, double distAmt) {
    final k = math.max(distAmt, 0.5);
    if (x >= 0) {
      return 1.0 - math.exp(-k * x * 0.8);
    } else {
      return -(1.0 - math.exp(k * x * 0.45));
    }
  }

  /// 生成点火脉冲包络表（对齐 demo.html makePulseCurve）
  ///
  /// sharpness: 0=圆滑, 1=极锐利（单缸特征）
  ///
  /// atkFrac = 0.04 - sharpness×0.032  →  上升段占比 0.8%~4%（极短）
  /// decK    = 2.0  + sharpness×7.0    →  衰减速度
  /// minVal  = 0.28 - sharpness×0.27   →  冲击间最低音量（≥0.01，不到 0！）
  ///
  /// 修复：原实现上升段占 15%（太宽），衰减到 0（导致突变爆音）
  Float64List _buildPulseEnvTable(int size, double sharpness) {
    final table = Float64List(size);
    final atkFrac = 0.04 - sharpness * 0.032; // 0.008 ~ 0.040
    final decK = 2.0 + sharpness * 7.0; // 2.0 ~ 9.0
    final minVal = (0.28 - sharpness * 0.27).clamp(0.01, 0.28); // 0.01 ~ 0.28

    for (int i = 0; i < size; i++) {
      final x = i / (size - 1).toDouble();
      double v;
      if (x < atkFrac) {
        v = x / atkFrac; // 快速线性上升到 1.0
      } else {
        // 指数衰减
        v = math.exp(-(x - atkFrac) / (1.0 - atkFrac) * decK);
      }
      // minVal 保底：冲击间保持持续底噪，避免音量突变
      table[i] = minVal + v * (1.0 - minVal);
    }
    return table;
  }

  /// 生成慢速 LFO 游走表（wobbleHz, wobbleCents）
  Float64List _buildWobbleTable(int count, double wobbleHz, double wobbleCents) {
    final table = Float64List(count);
    for (int i = 0; i < count; i++) {
      final t = i / sampleRate;
      // 多层低频 LFO 叠加，模拟随机游走
      table[i] = wobbleCents *
          (math.sin(2 * math.pi * wobbleHz * t) * 0.5 +
              math.sin(2 * math.pi * wobbleHz * 0.37 * t) * 0.3 +
              math.sin(2 * math.pi * wobbleHz * 1.73 * t) * 0.2);
    }
    return table;
  }

  // ───────────────────────────────────────────────
  // Tone Buffer：振荡器谐波叠加 + 噪声 AM 调制 + 点火脉冲包络
  // ───────────────────────────────────────────────
  Uint8List _synthToneBuffer(EngineStyleConfig style) {
    final sampleCount = sampleRate * toneDurationSec;
    final firingHz = style.firingHz(refRpm);

    // 预计算脉冲包络和音高游走表
    const pulseTableSize = 4096;
    final pulseEnvTable = _buildPulseEnvTable(pulseTableSize, style.pulseSharpness);
    final wobbleTable = _buildWobbleTable(sampleCount, style.wobbleHz, style.wobbleCents);

    // 预合成全局粉红噪声（所有谐波共用，各自经独立 BPF 后做 AM）
    // 修复 2A：使用宽带粉红噪声源，每个谐波取各自带限版本
    final globalPink = _coloredNoise(sampleCount, style.noiseColor);

    // 谐波随机相位（固定种子保证可重现）
    final rng2 = math.Random(99);
    final phases = List<double>.generate(
      style.harmonics.length,
      (_) => rng2.nextDouble() * 2.0 * math.pi,
    );

    // 预计算每个谐波的带限噪声（BPF 中心频率 = 谐波频率，Q=1.5）
    // 修复 2A：避免宽带噪声直接乘到各谐波，防止高频噪声边带
    final harmonicNoises = <Float64List>[];
    for (final h in style.harmonics) {
      final centerHz = (firingHz * h.mult).clamp(20.0, 20000.0);
      final filtered = _bpf(globalPink, centerHz, 1.5);
      // 归一化带限噪声，防止 BPF 增益不一致
      double mx = filtered.fold(0.0, (p, e) => e.abs() > p ? e.abs() : p);
      if (mx > 1e-6) {
        for (int i = 0; i < filtered.length; i++) {
          filtered[i] /= mx;
        }
      }
      harmonicNoises.add(filtered);
    }

    final samples = Float64List(sampleCount);

    for (int i = 0; i < sampleCount; i++) {
      final t = i / sampleRate.toDouble();

      // 点火脉冲包络索引（按点火频率在包络表中循环读取）
      final pulseIdx =
          ((i * firingHz / sampleRate * pulseTableSize).toInt()) %
              pulseTableSize;
      final pulseEnv = pulseEnvTable[pulseIdx];

      double toneSample = 0.0;
      for (int k = 0; k < style.harmonics.length; k++) {
        final h = style.harmonics[k];
        final baseFreq = firingHz * h.mult;

        // 微音高游走：cents → 频率偏移
        final wobbleCents = wobbleTable[i];
        final freqHz = baseFreq * math.pow(2.0, wobbleCents / 1200.0);

        // 振荡器信号
        double osc = h.amp * math.sin(2.0 * math.pi * freqHz * t + phases[k]);

        // 噪声 AM 调制（修复 2A）：
        //   AM 增益 = DC_offset + 带限噪声 × noiseAM × 0.5
        //   DC_offset = 1.0 - noiseAM×0.3（保证信号不被完全关断）
        //   带限噪声已经过 BPF 滤到该谐波频段，不含跨频段宽带成分
        final bandNoise = harmonicNoises[k][i];
        final dcOffset = 1.0 - style.noiseAM * 0.3;
        final amGain = dcOffset + bandNoise * style.noiseAM * 0.5;
        osc *= amGain;

        // 不对称软限幅（修复 2C：指数公式，失真极低）
        osc = _asymSoftClip(osc, style.distAmt);

        toneSample += osc;
      }

      // 应用点火脉冲包络（包含 minVal 保底，避免突变）
      toneSample *= pulseEnv;

      samples[i] = toneSample;
    }

    // 峰值归一化到 0.85
    double mx = samples.fold(0.0, (p, e) => e.abs() > p ? e.abs() : p);
    if (mx > 1e-6) {
      for (int i = 0; i < sampleCount; i++) {
        samples[i] = samples[i] / mx * 0.85;
      }
    }

    return _pcmToWav(samples);
  }

  // ───────────────────────────────────────────────
  // Noise Buffer：粉红噪声 + 机械底噪（LPF）
  // ───────────────────────────────────────────────
  Uint8List _synthNoiseBuffer(EngineStyleConfig style) {
    final sampleCount = sampleRate * noiseDurationSec;
    final rawNoise = _coloredNoise(sampleCount, style.noiseColor);
    final mechNoise = _lpf(rawNoise, style.mechFreq);
    final samples = Float64List(sampleCount);

    for (int i = 0; i < sampleCount; i++) {
      // 主噪声 + 机械底噪
      samples[i] = rawNoise[i] * 0.3 + mechNoise[i] * style.mechAmp;
    }

    double mx = samples.fold(0.0, (p, e) => e.abs() > p ? e.abs() : p);
    if (mx > 0) {
      for (int i = 0; i < sampleCount; i++) {
        samples[i] = samples[i] / mx * 0.5;
      }
    }

    return _pcmToWav(samples);
  }

  // ───────────────────────────────────────────────
  // Exh Buffer：排气管共振峰噪声
  // ───────────────────────────────────────────────
  Uint8List _synthExhBuffer(EngineStyleConfig style) {
    final sampleCount = sampleRate * exhDurationSec;
    final rawNoise = _pinkNoise(sampleCount);
    final samples = Float64List(sampleCount);

    // 叠加多个排气共振峰（BPF 滤波）
    final mixed = Float64List(sampleCount);
    for (int fi = 0; fi < style.exhFreqs.length; fi++) {
      final freq = style.exhFreqs[fi];
      final ampDecay = math.pow(0.6, fi).toDouble(); // 高频共振峰幅度递减
      final filtered = _bpf(rawNoise, freq, 4.0);
      for (int i = 0; i < sampleCount; i++) {
        mixed[i] += filtered[i] * ampDecay;
      }
    }

    // 再经 LPF 平滑
    final lpfed = _lpf(mixed, style.exhFreqs.last * 2.0);
    for (int i = 0; i < sampleCount; i++) {
      samples[i] = lpfed[i];
    }

    double mx = samples.fold(0.0, (p, e) => e.abs() > p ? e.abs() : p);
    if (mx > 0) {
      for (int i = 0; i < sampleCount; i++) {
        samples[i] = samples[i] / mx * 0.70;
      }
    }

    return _pcmToWav(samples);
  }

  // ───────────────────────────────────────────────
  // SFX：换挡音效（纯噪声合成）
  // ───────────────────────────────────────────────

  /// 升档音效（0.38s）：粉红噪声 × 快速衰减(decK=11) + 排气最低共振频×0.12
  Uint8List _synthUpshiftSfx() {
    return _synthSfx(
      durationSec: upshiftDurationSec,
      decK: 11.0,
      toneFreq: EngineStyles.i4.exhFreqs[0], // 175 Hz
      toneAmp: 0.12,
    );
  }

  /// 降档/回火音效（0.55s）：粉红噪声 × 慢速衰减(decK=6.5) + 排气最低共振频×0.12
  Uint8List _synthDownshiftSfx() {
    return _synthSfx(
      durationSec: downshiftDurationSec,
      decK: 6.5,
      toneFreq: EngineStyles.i4.exhFreqs[0], // 175 Hz
      toneAmp: 0.12,
    );
  }

  Uint8List _synthSfx({
    required double durationSec,
    required double decK,
    required double toneFreq,
    required double toneAmp,
  }) {
    final sampleCount = (sampleRate * durationSec).toInt();
    final rawNoise = _pinkNoise(sampleCount);
    final samples = Float64List(sampleCount);

    for (int i = 0; i < sampleCount; i++) {
      final t = i / sampleRate.toDouble();
      final env = math.exp(-decK * t / durationSec); // 指数衰减包络
      // 噪声 + 少量音调提示
      final tone = toneAmp * math.sin(2.0 * math.pi * toneFreq * t);
      samples[i] = (rawNoise[i] * (1.0 - toneAmp) + tone) * env;
    }

    double mx = samples.fold(0.0, (p, e) => e.abs() > p ? e.abs() : p);
    if (mx > 0) {
      for (int i = 0; i < sampleCount; i++) {
        samples[i] = samples[i] / mx * 0.80;
      }
    }

    return _pcmToWav(samples);
  }
}
