import 'package:flutter/material.dart';
import 'combined_gauge_card.dart';

/// APP启动自检动画覆盖层
/// 在 DashboardScreen 首次显示时叠加在仪表盘上方，
/// 模拟仪表盘指针扫至最大值再归零的自检效果，总时长 1500ms。
class SelfCheckOverlay extends StatefulWidget {
  final VoidCallback onComplete;

  // 量程参数（与 CombinedGaugeCard 保持一致）
  final int maxRpm;
  final int warnRpm;
  final int dangerRpm;
  final int maxSpeed;
  final int warnSpeed;
  final int dangerSpeed;

  const SelfCheckOverlay({
    super.key,
    required this.onComplete,
    required this.maxRpm,
    required this.warnRpm,
    required this.dangerRpm,
    required this.maxSpeed,
    required this.warnSpeed,
    required this.dangerSpeed,
  });

  @override
  State<SelfCheckOverlay> createState() => _SelfCheckOverlayState();
}

class _SelfCheckOverlayState extends State<SelfCheckOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  // ── Phase 1: 上升 (0.0 → 0.6, easeOut) ──
  late Animation<double> _rpmRiseAnim;
  late Animation<double> _speedRiseAnim;
  late Animation<double> _coolantRiseAnim;
  late Animation<double> _intakeRiseAnim;

  // ── Phase 2: 下降 (0.6 → 1.0, easeIn) ──
  late Animation<double> _rpmFallAnim;
  late Animation<double> _speedFallAnim;
  late Animation<double> _coolantFallAnim;
  late Animation<double> _intakeFallAnim;

  // ── 整体淡出 (0.8 → 1.0) ──
  late Animation<double> _opacityAnim;

  static const double _maxCoolantTemp = 120.0;
  static const double _maxIntakeTemp = 80.0;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    // ── 上升阶段：0.0 → 0.6，easeOut（先快后慢，快速扫到顶）──
    final riseCurve = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );

    _rpmRiseAnim = Tween<double>(begin: 0, end: widget.maxRpm.toDouble())
        .animate(riseCurve);
    _speedRiseAnim = Tween<double>(begin: 0, end: widget.maxSpeed.toDouble())
        .animate(riseCurve);
    _coolantRiseAnim =
        Tween<double>(begin: 0, end: _maxCoolantTemp).animate(riseCurve);
    _intakeRiseAnim =
        Tween<double>(begin: 0, end: _maxIntakeTemp).animate(riseCurve);

    // ── 下降阶段：0.6 → 1.0，easeIn（先慢后快，快速归零）──
    final fallCurve = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.6, 1.0, curve: Curves.easeIn),
    );

    _rpmFallAnim = Tween<double>(begin: widget.maxRpm.toDouble(), end: 0)
        .animate(fallCurve);
    _speedFallAnim = Tween<double>(begin: widget.maxSpeed.toDouble(), end: 0)
        .animate(fallCurve);
    _coolantFallAnim =
        Tween<double>(begin: _maxCoolantTemp, end: 0).animate(fallCurve);
    _intakeFallAnim =
        Tween<double>(begin: _maxIntakeTemp, end: 0).animate(fallCurve);

    // ── 淡出：0.8 → 1.0 ──
    _opacityAnim = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.8, 1.0, curve: Curves.easeIn),
      ),
    );

    // 播放动画，完成后通知父组件移除覆盖层
    Future.delayed(const Duration(milliseconds: 200), () {
      _controller.forward().whenComplete(() {
        if (mounted) widget.onComplete();
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // 当前帧 RPM 值（上升阶段取上升值，下降阶段取下降值）
  int get _currentRpm {
    if (_controller.value <= 0.6) return _rpmRiseAnim.value.round();
    return _rpmFallAnim.value.round();
  }

  // 当前帧 Speed 值
  int get _currentSpeed {
    if (_controller.value <= 0.6) return _speedRiseAnim.value.round();
    return _speedFallAnim.value.round();
  }

  // 当前帧冷却水温
  int get _currentCoolantTemp {
    if (_controller.value <= 0.6) return _coolantRiseAnim.value.round();
    return _coolantFallAnim.value.round();
  }

  // 当前帧进气温度
  int get _currentIntakeTemp {
    if (_controller.value <= 0.6) return _intakeRiseAnim.value.round();
    return _intakeFallAnim.value.round();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Opacity(
          opacity: _opacityAnim.value,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                // 左侧占位（与 SideStatsPanel flex:2 等宽）
                Expanded(flex: 2, child: Container()),
                const SizedBox(width: 8),

                // 中间：自检仪表盘（与 CombinedGaugeCard flex:4 等宽）
                Expanded(
                  flex: 4,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return CustomPaint(
                          size: Size(
                            constraints.maxWidth,
                            constraints.maxHeight,
                          ),
                          painter: CombinedGaugePainter(
                            rpm: _currentRpm,
                            speed: _currentSpeed,
                            gear: 0,
                            coolantTemp: _currentCoolantTemp,
                            intakeTemp: _currentIntakeTemp,
                            maxRpm: widget.maxRpm,
                            warnRpm: widget.warnRpm,
                            dangerRpm: widget.dangerRpm,
                            maxSpeed: widget.maxSpeed,
                            warnSpeed: widget.warnSpeed,
                            dangerSpeed: widget.dangerSpeed,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // 右侧占位（与右侧面板 flex:3 等宽）
                Expanded(flex: 3, child: Container()),
              ],
            ),
          ),
        );
      },
    );
  }
}
