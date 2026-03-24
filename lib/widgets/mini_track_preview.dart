import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/riding_record.dart';
import '../theme/app_theme.dart';

/// 缩略轨迹图组件
class MiniTrackPreview extends StatelessWidget {
  final List<TrackPoint> trackPoints;

  const MiniTrackPreview({super.key, required this.trackPoints});

  @override
  Widget build(BuildContext context) {
    if (trackPoints.isEmpty) {
      return Container(
        decoration: AppTheme.surfaceBorder(
          borderColor: AppTheme.primary,
          opacity: 0.1,
        ),
        child: const Center(
          child: Text('--', style: AppTheme.labelSmall),
        ),
      );
    }

    final points = trackPoints.map((p) => p.toLatLng()).toList();
    final bounds = LatLngBounds.fromPoints(points);

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: FlutterMap(
        options: MapOptions(
          initialCameraFit: CameraFit.bounds(
            bounds: bounds,
            padding: const EdgeInsets.all(8),
          ),
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.none,
          ),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.obd_dashboard',
          ),
          PolylineLayer(
            polylines: [
              Polyline(
                points: points,
                strokeWidth: 2,
                color: AppTheme.primary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
