import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/obd_data_provider.dart';
import '../theme/app_theme.dart';
import 'rpm_gauge_card.dart';

/// 速度半圆表盘卡片（带档位显示）
class SpeedGaugeCard extends StatelessWidget {
  const SpeedGaugeCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<OBDDataProvider>(
      builder: (context, provider, child) {
        final data = provider.data;

        return Container(
          padding: const EdgeInsets.all(16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // 占满整个区域
              final width = constraints.maxWidth;
              final height = constraints.maxHeight;

              return Stack(
                children: [
                  // 左上角档位显示
                  Positioned(
                    left: 0,
                    top: 0,
                    child: _GearIndicator(gear: data.gear),
                  ),

                  // 速度仪表盘居中
                  Center(
                    child: SizedBox(
                      width: width,
                      height: height,
                      child: CustomPaint(
                        painter: SemiCircleGaugePainter(
                          value: data.speed,
                          maxValue: 250,
                          warnThreshold: 150,
                          dangerThreshold: 200,
                          tickInterval: 25,
                          unit: 'km/h',
                          gaugeWidth: width,
                          gaugeHeight: height,
                        ),
                        child: Center(
                          child: Padding(
                            padding: EdgeInsets.only(top: height * 0.18),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${data.speed}',
                                  style: AppTheme.valueMedium.copyWith(
                                    fontSize: height * 0.28,
                                    letterSpacing: -1,
                                  ),
                                ),
                                Text(
                                  'km/h',
                                  style: AppTheme.labelTinyPrimary.copyWith(
                                    fontSize: height * 0.09,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

/// 档位指示器
class _GearIndicator extends StatelessWidget {
  final int gear;

  const _GearIndicator({required this.gear});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: AppTheme.primary10,
        border: Border.all(
          color: AppTheme.primary.withValues(alpha: 0.4),
          width: 2,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'N',
            style: TextStyle(
              color: AppTheme.primary60,
              fontSize: 10,
            ),
          ),
          Text(
            '$gear',
            style: AppTheme.titleMedium.copyWith(
              fontSize: 24,
            ),
          ),
        ],
      ),
    );
  }
}
