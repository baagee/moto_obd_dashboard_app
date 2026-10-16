import 'package:flutter/material.dart';
import 'combined_gauge_card.dart';

/// APP 启动自检：只扫转速与速度，温度由右上车辆健康卡显示。
class SelfCheckOverlay extends StatefulWidget {
  final VoidCallback onComplete;
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
  late final AnimationController _controller;
  late final Animation<double> _rpmRiseAnim;
  late final Animation<double> _speedRiseAnim;
  late final Animation<double> _rpmFallAnim;
  late final Animation<double> _speedFallAnim;
  late final Animation<double> _opacityAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    final riseCurve = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );
    final fallCurve = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.6, 1.0, curve: Curves.easeIn),
    );
    _rpmRiseAnim = Tween<double>(begin: 0, end: widget.maxRpm.toDouble())
        .animate(riseCurve);
    _speedRiseAnim = Tween<double>(begin: 0, end: widget.maxSpeed.toDouble())
        .animate(riseCurve);
    _rpmFallAnim = Tween<double>(begin: widget.maxRpm.toDouble(), end: 0)
        .animate(fallCurve);
    _speedFallAnim = Tween<double>(begin: widget.maxSpeed.toDouble(), end: 0)
        .animate(fallCurve);
    _opacityAnim = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.8, 1.0, curve: Curves.easeIn),
      ),
    );

    Future.delayed(const Duration(milliseconds: 200), () {
      if (!mounted) return;
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

  int get _currentRpm =>
      (_controller.value <= 0.6 ? _rpmRiseAnim.value : _rpmFallAnim.value)
          .round();

  int get _currentSpeed =>
      (_controller.value <= 0.6 ? _speedRiseAnim.value : _speedFallAnim.value)
          .round();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => Opacity(
        opacity: _opacityAnim.value,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              const Expanded(flex: 2, child: SizedBox()),
              const SizedBox(width: 8),
              Expanded(
                flex: 4,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final size = Size(
                        constraints.maxWidth,
                        constraints.maxHeight,
                      );
                      return Stack(
                        children: [
                          CustomPaint(
                            size: size,
                            painter: GaugeStaticPainter(
                              maxRpm: widget.maxRpm,
                              warnRpm: widget.warnRpm,
                              dangerRpm: widget.dangerRpm,
                              maxSpeed: widget.maxSpeed,
                              warnSpeed: widget.warnSpeed,
                              dangerSpeed: widget.dangerSpeed,
                            ),
                          ),
                          CustomPaint(
                            size: size,
                            painter: CombinedGaugePainter(
                              rpm: _currentRpm,
                              speed: _currentSpeed,
                              gear: 0,
                              maxRpm: widget.maxRpm,
                              warnRpm: widget.warnRpm,
                              dangerRpm: widget.dangerRpm,
                              maxSpeed: widget.maxSpeed,
                              warnSpeed: widget.warnSpeed,
                              dangerSpeed: widget.dangerSpeed,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(flex: 3, child: SizedBox()),
            ],
          ),
        ),
      ),
    );
  }
}
