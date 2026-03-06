import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/obd_data_provider.dart';
import '../theme/app_theme.dart';

/// 档位显示卡片
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
              // 根据可用空间计算尺寸
              final gearBoxSize = constraints.maxHeight * 0.5;

              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
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
                            'N',
                            style: AppTheme.labelTiny.copyWith(
                              color: AppTheme.primary60,
                              fontSize: gearBoxSize * 0.12,
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
                    const SizedBox(height: 8),
                    Text(
                      'GEAR',
                      style: AppTheme.labelTiny.copyWith(
                        color: AppTheme.primary60,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}
