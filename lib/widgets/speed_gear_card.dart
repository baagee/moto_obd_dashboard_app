import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/obd_data_provider.dart';
import '../theme/app_theme.dart';

/// 速度和档位显示卡片
class SpeedGearCard extends StatelessWidget {
  const SpeedGearCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<OBDDataProvider>(
      builder: (context, provider, child) {
        final data = provider.data;

        return Container(
          padding: const EdgeInsets.all(10),
          decoration: AppTheme.surfaceBorder(
            borderColor: AppTheme.primary,
            opacity: 0.3,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // 根据可用空间计算字体大小
              final speedFontSize = constraints.maxHeight * 0.55;
              final gearBoxSize = constraints.maxHeight * 0.45;

              return Stack(
                children: [
                  // 背景图标
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Transform.rotate(
                      angle: 0.2,
                      child: Icon(
                        Icons.speed,
                        color: AppTheme.primary10,
                        size: constraints.maxHeight * 0.6,
                      ),
                    ),
                  ),

                  // 主内容
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // 顶部：速度和档位
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 速度显示
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    Text(
                                      '${data.speed}',
                                      style: AppTheme.headingLarge.copyWith(
                                        fontSize: speedFontSize,
                                        letterSpacing: -3,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'km/h',
                                      style: TextStyle(
                                        color: AppTheme.primary,
                                        fontSize: speedFontSize * 0.2,
                                        fontWeight: FontWeight.w500,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // 档位显示
                          Container(
                            width: gearBoxSize,
                            height: gearBoxSize,
                            decoration: BoxDecoration(
                              color: AppTheme.primary10,
                              border: Border.all(
                                color: AppTheme.primary.withOpacity(0.4),
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '档位',
                                  style: AppTheme.labelTiny.copyWith(
                                    color: AppTheme.primary60,
                                    fontSize: gearBoxSize * 0.1,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${data.gear}',
                                  style: AppTheme.titleMedium.copyWith(
                                    fontSize: gearBoxSize * 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
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