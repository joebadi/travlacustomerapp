import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:travla_customer_app/app/theme/app_colors.dart';
import 'package:travla_customer_app/core/network/api_failure.dart';
import 'package:travla_customer_app/features/journeys/data/journey_repository.dart';

class JourneyDetailScreen extends ConsumerWidget {
  const JourneyDetailScreen({super.key, required this.journeyId});

  final String journeyId;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete this journey?'),
        content: const Text('This permanently removes the saved trail.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(c).pop(false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(c).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(journeyRepositoryProvider).delete(journeyId);
      ref.invalidate(journeysProvider);
      if (context.mounted) context.pop();
    } on ApiFailure catch (f) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(f.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(journeyProvider(journeyId));

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: Text(async.value?.title ?? 'Journey'),
        actions: [
          IconButton(
            onPressed: () => _delete(context, ref),
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(error is ApiFailure ? error.message : 'This journey could not be loaded.', textAlign: TextAlign.center),
          ),
        ),
        data: (journey) {
          final points = journey.trail.map((p) => LatLng(p.lat, p.lng)).toList();
          return Column(
            children: [
              Expanded(
                child: points.isEmpty
                    ? const Center(child: Text('No trail was recorded.', style: TextStyle(color: AppColors.muted)))
                    : FlutterMap(
                        options: MapOptions(
                          initialCameraFit: CameraFit.coordinates(
                            coordinates: points,
                            padding: const EdgeInsets.all(48),
                          ),
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'ng.com.travla.customer',
                          ),
                          PolylineLayer(polylines: [Polyline(points: points, strokeWidth: 5, color: AppColors.orange)]),
                          MarkerLayer(markers: [
                            _pin(points.first, AppColors.forest700),
                            if (points.length > 1) _pin(points.last, AppColors.danger),
                          ]),
                        ],
                      ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                decoration: const BoxDecoration(
                  color: AppColors.white,
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (journey.transportModeLabel != null || journey.vehiclePlate != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          [journey.transportModeLabel, journey.vehiclePlate].where((s) => s != null).join(' · '),
                          style: const TextStyle(color: AppColors.muted, fontSize: 12.5),
                        ),
                      ),
                    Row(
                      children: [
                        _stat('${journey.distanceKm.toStringAsFixed(2)} km', 'Distance'),
                        _stat(journey.durationLabel, 'Duration'),
                        _stat('${journey.pointCount}', 'Points'),
                      ],
                    ),
                    if (journey.description != null && journey.description!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(journey.description!, style: const TextStyle(color: AppColors.ink, height: 1.4)),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Marker _pin(LatLng at, Color color) => Marker(
        point: at,
        width: 20,
        height: 20,
        child: Container(
          decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3)),
        ),
      );

  Widget _stat(String value, String label) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppColors.ink)),
            Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 11)),
          ],
        ),
      );
}
