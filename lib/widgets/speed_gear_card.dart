import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

/// 档位显示卡片
class SpeedGearCard extends StatelessWidget {
  const SpeedGearCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final colors = themeProvider.currentColors;

        return Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: colors.primary.withValues(alpha: 0.3),
              width: 1,
            ),
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
                        color: colors.primary.withValues(alpha: 0.1),
                        border: Border.all(
                          color: colors.primary.withValues(alpha: 0.4),
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'N',
                            style: TextStyle(
                              color: colors.primary.withValues(alpha: 0.6),
                              fontSize: gearBoxSize * 0.12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '0', // gear 字段暂时不可用
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: gearBoxSize * 0.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'GEAR',
                      style: TextStyle(
                        color: colors.primary.withValues(alpha: 0.6),
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
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
