import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../providers/riding_record_provider.dart';
import '../theme/app_theme.dart';

/// 实时骑行记录页面
class RidingRecordScreen extends StatefulWidget {
  const RidingRecordScreen({super.key});

  @override
  State<RidingRecordScreen> createState() => _RidingRecordScreenState();
}

class _RidingRecordScreenState extends State<RidingRecordScreen> {
  final MapController _mapController = MapController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<RidingRecordProvider>(
        builder: (context, provider, _) {
          final record = provider.currentRecord;
          final trackPoints = record?.trackPoints ?? [];

          return Stack(
            children: [
              // 地图
              if (trackPoints.isNotEmpty)
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCameraFit: CameraFit.bounds(
                      bounds: LatLngBounds.fromPoints(
                        trackPoints.map((p) => p.toLatLng()).toList(),
                      ),
                      padding: const EdgeInsets.all(32),
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.obd_dashboard',
                    ),
                    // 轨迹线
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: trackPoints.map((p) => p.toLatLng()).toList(),
                          strokeWidth: 4,
                          color: AppTheme.primary,
                        ),
                      ],
                    ),
                    // 起点标记
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: trackPoints.first.toLatLng(),
                          child: const Icon(
                            Icons.circle,
                            color: AppTheme.accentGreen,
                            size: 16,
                          ),
                        ),
                      ],
                    ),
                  ],
                )
              else
                const Center(
                  child: Text(
                    '等待 GPS 信号...',
                    style: AppTheme.labelMedium,
                  ),
                ),

              // 底部统计面板
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _StatsPanel(provider: provider),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }
}

class _StatsPanel extends StatelessWidget {
  final RidingRecordProvider provider;

  const _StatsPanel({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: AppTheme.surface.withOpacity(0.9),
        border: const Border(
          top: BorderSide(color: AppTheme.primary20, width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // 当前速度
          _SpeedDisplay(speed: provider.currentSpeed),
          const SizedBox(width: 32),

          // 时长 | 里程
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_formatDuration(provider.duration), style: AppTheme.valueMedium),
              const SizedBox(height: 4),
              Text('${provider.totalDistance.toStringAsFixed(2)} km',
                  style: AppTheme.labelSmall),
            ],
          ),
          const SizedBox(width: 32),

          // 最高/平均速度
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Icons.arrow_upward, size: 14, color: AppTheme.accentOrange),
                  const SizedBox(width: 4),
                  Text(
                    '${provider.maxSpeed.toStringAsFixed(1)} km/h',
                    style: AppTheme.valueMedium.copyWith(color: AppTheme.accentOrange),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.trending_flat, size: 14, color: AppTheme.textMuted),
                  const SizedBox(width: 4),
                  Text(
                    '${(provider.totalDistance / provider.duration.inMinutes * 60).toStringAsFixed(1)} km/h',
                    style: AppTheme.labelSmall,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(width: 32),

          // 倾角
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Icons.rotate_left, size: 14, color: AppTheme.accentCyan),
                  const SizedBox(width: 4),
                  Text('${provider.maxLeanLeft}', style: AppTheme.valueMedium),
                  const SizedBox(width: 16),
                  const Icon(Icons.rotate_right, size: 14, color: AppTheme.accentCyan),
                  const SizedBox(width: 4),
                  Text('${provider.maxLeanRight}', style: AppTheme.valueMedium),
                ],
              ),
              const SizedBox(height: 4),
              const Text('倾角', style: AppTheme.labelSmall),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}

class _SpeedDisplay extends StatelessWidget {
  final double speed;

  const _SpeedDisplay({required this.speed});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              speed.toStringAsFixed(0),
              style: AppTheme.headingLarge.copyWith(
                color: AppTheme.primary,
                fontSize: 72,
              ),
            ),
            const SizedBox(width: 4),
            const Text('km/h', style: AppTheme.labelMedium),
          ],
        ),
        const SizedBox(height: 4),
        const Text('当前速度', style: AppTheme.labelSmall),
      ],
    );
  }
}
