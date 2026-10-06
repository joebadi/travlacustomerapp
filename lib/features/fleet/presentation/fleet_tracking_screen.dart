import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:travla_customer_app/app/theme/app_colors.dart';
import 'package:travla_customer_app/core/network/api_failure.dart';
import 'package:travla_customer_app/features/fleet/data/fleet_repository.dart';
import 'package:travla_customer_app/features/fleet/domain/fleet_models.dart';
import 'package:travla_customer_app/features/journeys/presentation/journey_vector_map.dart';

const _nigeriaCenter = LatLng(9.0820, 8.6753);

class FleetTrackingScreen extends ConsumerStatefulWidget {
  const FleetTrackingScreen({super.key, required this.organisationId});

  final String organisationId;

  @override
  ConsumerState<FleetTrackingScreen> createState() =>
      _FleetTrackingScreenState();
}

class _FleetTrackingScreenState extends ConsumerState<FleetTrackingScreen> {
  final MapController _map = MapController();
  Timer? _poll;
  bool _fitted = false;
  String? _selectedId;

  @override
  void initState() {
    super.initState();
    _poll = Timer.periodic(const Duration(seconds: 15), (_) {
      ref.invalidate(fleetTrackingProvider(widget.organisationId));
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  void _fit(List<FleetTrackingPoint> vehicles, {bool force = false}) {
    final points = vehicles
        .where((vehicle) => vehicle.canPlot)
        .map((vehicle) => LatLng(vehicle.latitude!, vehicle.longitude!))
        .toList(growable: false);
    if (points.isEmpty || (_fitted && !force)) return;
    _fitted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (points.length == 1) {
        _map.move(points.first, 15);
        return;
      }
      _map.fitCamera(
        CameraFit.coordinates(
          coordinates: points,
          padding: const EdgeInsets.fromLTRB(48, 72, 48, 48),
          maxZoom: 15,
        ),
      );
    });
  }

  void _select(FleetTrackingPoint vehicle) {
    setState(() => _selectedId = vehicle.orgVehicleId);
    if (vehicle.canPlot) {
      _map.move(LatLng(vehicle.latitude!, vehicle.longitude!), 15);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tracking = ref.watch(fleetTrackingProvider(widget.organisationId));
    final snapshot = tracking.value;
    final vehicles = snapshot?.vehicles ?? const <FleetTrackingPoint>[];
    if (snapshot != null) _fit(vehicles);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: const Text('Fleet tracking'),
        actions: [
          IconButton(
            tooltip: 'Refresh positions',
            onPressed: () =>
                ref.invalidate(fleetTrackingProvider(widget.organisationId)),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: tracking.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorState(
          message: error is ApiFailure
              ? error.message
              : 'Fleet tracking could not be loaded.',
          onRetry: () =>
              ref.invalidate(fleetTrackingProvider(widget.organisationId)),
        ),
        data: (data) => Column(
          children: [
            _TrackingSummary(snapshot: data),
            Expanded(
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _map,
                    options: MapOptions(
                      initialCenter: vehicles.where((v) => v.canPlot).isNotEmpty
                          ? LatLng(
                              vehicles.firstWhere((v) => v.canPlot).latitude!,
                              vehicles.firstWhere((v) => v.canPlot).longitude!,
                            )
                          : _nigeriaCenter,
                      initialZoom: vehicles.any((v) => v.canPlot) ? 12 : 5.6,
                      onTap: (_, _) => setState(() => _selectedId = null),
                    ),
                    children: [
                      travlaVectorTileLayer(),
                      MarkerLayer(
                        markers: vehicles
                            .where((vehicle) => vehicle.canPlot)
                            .map(
                              (vehicle) => Marker(
                                point: LatLng(
                                  vehicle.latitude!,
                                  vehicle.longitude!,
                                ),
                                width: 48,
                                height: 58,
                                alignment: Alignment.topCenter,
                                child: _FleetMarker(
                                  status: vehicle.status,
                                  selected: vehicle.orgVehicleId == _selectedId,
                                  onTap: () => _select(vehicle),
                                ),
                              ),
                            )
                            .toList(growable: false),
                      ),
                    ],
                  ),
                  const Positioned(top: 10, left: 10, child: _MapLegend()),
                  Positioned(
                    right: 12,
                    bottom: 12,
                    child: FloatingActionButton.small(
                      heroTag: 'fit-fleet-map',
                      tooltip: 'Fit visible vehicles',
                      backgroundColor: AppColors.white,
                      foregroundColor: AppColors.forest700,
                      onPressed: () => _fit(vehicles, force: true),
                      child: const Icon(Icons.center_focus_strong_rounded),
                    ),
                  ),
                  if (vehicles.every((vehicle) => !vehicle.canPlot))
                    const Center(child: _MapEmpty()),
                ],
              ),
            ),
            _VehicleTray(
              vehicles: vehicles,
              selectedId: _selectedId,
              onSelect: _select,
              onOpen: (vehicle) => context.push(
                '/more/fleet/${widget.organisationId}/vehicles/${vehicle.orgVehicleId}',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrackingSummary extends StatelessWidget {
  const _TrackingSummary({required this.snapshot});

  final FleetTrackingSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: _SummaryMetric(
              value: snapshot.liveCount,
              label: 'Live',
              color: AppColors.forest600,
            ),
          ),
          Expanded(
            child: _SummaryMetric(
              value: snapshot.staleCount,
              label: 'Stale',
              color: AppColors.orange,
            ),
          ),
          Expanded(
            child: _SummaryMetric(
              value: snapshot.offlineCount,
              label: 'Offline',
              color: AppColors.muted,
            ),
          ),
          Container(width: 1, height: 34, color: AppColors.border),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                'Auto-refresh',
                style: TextStyle(
                  color: AppColors.ink,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                'Every 15 sec',
                style: TextStyle(
                  color: AppColors.muted.withValues(alpha: .9),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({
    required this.value,
    required this.label,
    required this.color,
  });

  final int value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$value',
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              label,
              style: const TextStyle(color: AppColors.muted, fontSize: 9.5),
            ),
          ],
        ),
      ],
    );
  }
}

class _FleetMarker extends StatelessWidget {
  const _FleetMarker({
    required this.status,
    required this.selected,
    required this.onTap,
  });

  final FleetTrackingStatus status;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.forest950 : _statusColor(status);
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: selected ? 43 : 39,
            height: selected ? 43 : 39,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .24),
                  blurRadius: 7,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(
              Icons.directions_car_filled_rounded,
              color: Colors.white,
              size: 19,
            ),
          ),
          Transform.translate(
            offset: const Offset(0, -5),
            child: Icon(Icons.arrow_drop_down, color: color, size: 23),
          ),
        ],
      ),
    );
  }
}

class _MapLegend extends StatelessWidget {
  const _MapLegend();

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.white.withValues(alpha: .94),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _LegendDot(label: 'Live', color: AppColors.forest600),
            SizedBox(width: 10),
            _LegendDot(label: 'Stale', color: AppColors.orange),
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.ink,
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _MapEmpty extends StatelessWidget {
  const _MapEmpty();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(28),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: .95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.location_off_outlined, color: AppColors.muted, size: 30),
          SizedBox(height: 8),
          Text(
            'No position available yet',
            style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.w900),
          ),
          SizedBox(height: 4),
          Text(
            'Configured and unconfigured vehicles remain listed below.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _VehicleTray extends StatelessWidget {
  const _VehicleTray({
    required this.vehicles,
    required this.selectedId,
    required this.onSelect,
    required this.onOpen,
  });

  final List<FleetTrackingPoint> vehicles;
  final String? selectedId;
  final ValueChanged<FleetTrackingPoint> onSelect;
  final ValueChanged<FleetTrackingPoint> onOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 224,
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              'Vehicles in your scope (${vehicles.length})',
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Expanded(
            child: vehicles.isEmpty
                ? const Center(
                    child: Text(
                      'No vehicles are assigned to this Fleet scope.',
                      style: TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(10, 0, 8, 10),
                    itemCount: vehicles.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, indent: 50),
                    itemBuilder: (context, index) {
                      final vehicle = vehicles[index];
                      final selected = vehicle.orgVehicleId == selectedId;
                      return Material(
                        color: selected
                            ? AppColors.forest50
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        child: ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.only(
                            left: 8,
                            right: 2,
                          ),
                          onTap: () => onSelect(vehicle),
                          leading: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: _statusColor(
                                vehicle.status,
                              ).withValues(alpha: .12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.directions_car_outlined,
                              color: _statusColor(vehicle.status),
                              size: 19,
                            ),
                          ),
                          title: Text(
                            vehicle.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.ink,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          subtitle: Text(
                            _statusCopy(vehicle),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _statusColor(vehicle.status),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          trailing: IconButton(
                            tooltip: 'Open Fleet vehicle',
                            onPressed: () => onOpen(vehicle),
                            icon: const Icon(
                              Icons.chevron_right_rounded,
                              color: AppColors.muted,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.map_outlined, size: 40, color: AppColors.muted),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

Color _statusColor(FleetTrackingStatus status) => switch (status) {
  FleetTrackingStatus.live => AppColors.forest600,
  FleetTrackingStatus.stale => AppColors.orange,
  FleetTrackingStatus.offline => AppColors.muted,
};

String _statusCopy(FleetTrackingPoint vehicle) {
  return switch (vehicle.status) {
    FleetTrackingStatus.live => 'Live · ${_ago(vehicle.lastPositionAt)}',
    FleetTrackingStatus.stale =>
      'Stale · last seen ${_ago(vehicle.lastPositionAt)}',
    FleetTrackingStatus.offline when vehicle.statusReason == 'NO_FIX' =>
      'Offline · awaiting first position',
    FleetTrackingStatus.offline => 'Offline · tracker not configured',
  };
}

String _ago(DateTime? time) {
  if (time == null) return 'time unavailable';
  final difference = DateTime.now().difference(time.toLocal());
  if (difference.inSeconds < 60) return 'just now';
  if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
  if (difference.inHours < 24) return '${difference.inHours}h ago';
  return '${difference.inDays}d ago';
}
