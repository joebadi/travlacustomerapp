import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:travla_customer_app/app/theme/app_colors.dart';
import 'package:travla_customer_app/core/network/api_failure.dart';
import 'package:travla_customer_app/features/tracking/data/tracking_map_repository.dart';
import 'package:travla_customer_app/features/tracking/domain/live_position.dart';
import 'package:travla_customer_app/features/vehicles/data/garage_repository.dart';

const _nigeriaCenter = LatLng(9.0820, 8.6753);

class LiveMapScreen extends ConsumerStatefulWidget {
  const LiveMapScreen({super.key});

  @override
  ConsumerState<LiveMapScreen> createState() => _LiveMapScreenState();
}

class _LiveMapScreenState extends ConsumerState<LiveMapScreen> {
  final MapController _map = MapController();
  Timer? _poll;
  bool _fitted = false;
  String? _selectedId;

  @override
  void initState() {
    super.initState();
    // Refresh positions every 12s while the map is open.
    _poll = Timer.periodic(const Duration(seconds: 12), (_) {
      ref.invalidate(livePositionsProvider);
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  void _openAddTracking() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.white,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _AddOption(
              icon: Icons.my_location_rounded,
              title: 'Track with this phone',
              subtitle: 'Use this phone as a live GPS source',
              onTap: () {
                Navigator.of(sheetContext).pop();
                context.push('/more/tracking/phone');
              },
            ),
            _AddOption(
              icon: Icons.gps_fixed_rounded,
              title: 'Add a GPS device (Traccar)',
              subtitle: 'Connect a hardware tracker to a vehicle',
              onTap: () {
                Navigator.of(sheetContext).pop();
                _pickVehicleForDevice();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _pickVehicleForDevice() {
    final vehicles = ref.read(garageProvider).value?.vehicles ?? const [];
    if (vehicles.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Add a vehicle first, then attach a device.')),
        );
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.white,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 2, 20, 8),
              child: Text(
                'Which vehicle is the device in?',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: vehicles
                    .map(
                      (v) => ListTile(
                        leading: const Icon(Icons.directions_car_outlined, color: AppColors.forest700),
                        title: Text(v.displayName, style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: v.plateNumber?.isNotEmpty == true ? Text(v.plateNumber!) : null,
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () {
                          Navigator.of(sheetContext).pop();
                          context.push('/vehicles/${v.id}?tab=tracking');
                        },
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _fit(List<LivePosition> positions) {
    if (_fitted || positions.isEmpty) return;
    _fitted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final points = positions.map((p) => LatLng(p.latitude, p.longitude)).toList();
      if (points.length == 1) {
        _map.move(points.first, 15);
      } else {
        _map.fitCamera(
          CameraFit.coordinates(
            coordinates: points,
            padding: const EdgeInsets.all(64),
            maxZoom: 15,
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(livePositionsProvider);
    final positions = async.value ?? const <LivePosition>[];
    if (async.hasValue) _fit(positions);
    final selected = positions.where((p) => p.vehicleId == _selectedId).firstOrNull;

    // Selected vehicle's recent trail, drawn as a polyline.
    final trailPoints = selected == null
        ? const <LatLng>[]
        : (ref.watch(vehicleTrailProvider(selected.vehicleId)).value ?? const [])
              .map((p) => LatLng(p.latitude, p.longitude))
              .toList();

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: const Text('Live map'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(livePositionsProvider),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.orange,
        onPressed: _openAddTracking,
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text('Add tracking'),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: positions.isNotEmpty
                  ? LatLng(positions.first.latitude, positions.first.longitude)
                  : _nigeriaCenter,
              initialZoom: positions.isNotEmpty ? 13 : 5.6,
              onTap: (_, _) => setState(() => _selectedId = null),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'ng.com.travla.customer',
              ),
              if (trailPoints.length >= 2)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: trailPoints,
                      strokeWidth: 4,
                      color: AppColors.orange.withValues(alpha: .85),
                    ),
                  ],
                ),
              MarkerLayer(
                markers: positions
                    .map(
                      (p) => Marker(
                        point: LatLng(p.latitude, p.longitude),
                        width: 46,
                        height: 56,
                        alignment: Alignment.topCenter,
                        child: _VehicleMarker(
                          selected: p.vehicleId == _selectedId,
                          onTap: () => setState(() => _selectedId = p.vehicleId),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),

          if (async.isLoading && !async.hasValue)
            const Center(child: CircularProgressIndicator()),

          if (async.hasError && !async.hasValue)
            Center(
              child: _Panel(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      async.error is ApiFailure
                          ? (async.error as ApiFailure).message
                          : 'The live map could not be loaded.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => ref.invalidate(livePositionsProvider),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            ),

          if (async.hasValue && positions.isEmpty)
            const Center(
              child: _Panel(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.location_off_outlined, size: 36, color: AppColors.muted),
                    SizedBox(height: 10),
                    Text(
                      'No vehicle is reporting a position yet.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Add a tracker to a vehicle, or use this phone as a tracker below.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.muted, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
            ),

          if (selected != null)
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: _PositionCard(
                position: selected,
                onClose: () => setState(() => _selectedId = null),
                onOpen: () => context.push('/vehicles/${selected.vehicleId}?tab=tracking'),
              ),
            ),
        ],
      ),
    );
  }
}

class _VehicleMarker extends StatelessWidget {
  const _VehicleMarker({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.orange : AppColors.forest700;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .3),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.directions_car_filled_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          Transform.translate(
            offset: const Offset(0, -4),
            child: Icon(Icons.arrow_drop_down, color: color, size: 22),
          ),
        ],
      ),
    );
  }
}

class _PositionCard extends StatelessWidget {
  const _PositionCard({
    required this.position,
    required this.onClose,
    required this.onOpen,
  });

  final LivePosition position;
  final VoidCallback onClose;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(18),
      shadowColor: Colors.black26,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    position.displayName,
                    style: const TextStyle(
                      color: AppColors.ink,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: onClose,
                  icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.muted),
                ),
              ],
            ),
            Wrap(
              spacing: 14,
              runSpacing: 4,
              children: [
                if (position.plateNumber?.isNotEmpty == true)
                  _Fact(icon: Icons.pin_outlined, text: position.plateNumber!),
                if (position.speed != null)
                  _Fact(icon: Icons.speed_rounded, text: '${position.speed!.round()} km/h'),
                _Fact(icon: Icons.schedule_rounded, text: _ago(position.lastPositionAt)),
                if (position.sourceLabel != null)
                  _Fact(icon: Icons.sensors_rounded, text: position.sourceLabel!),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onOpen,
                style: FilledButton.styleFrom(backgroundColor: AppColors.forest700),
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: const Text('Open vehicle tracking'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.muted),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(color: AppColors.ink, fontSize: 12.5, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _AddOption extends StatelessWidget {
  const _AddOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.forest50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: AppColors.forest700),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: const Icon(Icons.chevron_right_rounded),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(28),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: .08), blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      child: child,
    );
  }
}

String _ago(DateTime? time) {
  if (time == null) return 'unknown';
  final diff = DateTime.now().difference(time.toLocal());
  if (diff.inSeconds < 60) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}
