import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:travla_customer_app/app/theme/app_colors.dart';
import 'package:travla_customer_app/core/network/api_failure.dart';
import 'package:travla_customer_app/features/vehicles/data/vehicle_tracking_repository.dart';
import 'package:travla_customer_app/features/vehicles/domain/vehicle_detail.dart';
import 'package:travla_customer_app/features/vehicles/domain/vehicle_tracking.dart';
import 'package:travla_customer_app/features/vehicles/presentation/vehicle_quick_actions.dart';
import 'package:url_launcher/url_launcher.dart';

class VehicleTrackingTab extends ConsumerWidget {
  const VehicleTrackingTab({
    required this.vehicle,
    required this.onOrderTracker,
    super.key,
  });

  final VehicleDetail vehicle;
  final VoidCallback onOrderTracker;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspace = ref.watch(vehicleTrackingWorkspaceProvider(vehicle.id));
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: workspace.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(40),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (error, stackTrace) => _TrackingEmpty(
          icon: Icons.cloud_off_outlined,
          title: 'Tracking is unavailable',
          body: error is ApiFailure
              ? error.message
              : 'The tracking workspace could not be loaded.',
          actionLabel: 'Try again',
          onAction: () =>
              ref.invalidate(vehicleTrackingWorkspaceProvider(vehicle.id)),
        ),
        data: (data) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TrackingMapWorkspace(
                vehicle: vehicle,
                workspace: data,
                onRefresh: () => ref.invalidate(
                  vehicleTrackingWorkspaceProvider(vehicle.id),
                ),
                onPhone: () =>
                    context.push('/more/tracking/phone?vehicle=${vehicle.id}'),
                onAddSource: () => _addSource(context, ref),
              ),
              const SizedBox(height: 16),
              if (data.sources.isEmpty)
                _EmptyTrackingHero(
                  onPhone: () => context.push(
                    '/more/tracking/phone?vehicle=${vehicle.id}',
                  ),
                  onDevice: () => _addSource(context, ref),
                  onOrder: onOrderTracker,
                )
              else ...[
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'TRACKING SOURCES',
                            style: TextStyle(
                              color: AppColors.orangeDark,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: .8,
                            ),
                          ),
                          Text(
                            '${data.sources.length} connected',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: () => _addSource(context, ref),
                      icon: const Icon(Icons.add_rounded, size: 17),
                      label: const Text('Add source'),
                    ),
                  ],
                ),
                const SizedBox(height: 11),
                ...data.sources.map(
                  (source) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _SourceCard(
                      source: source,
                      onToggle: () => _toggle(context, ref, source),
                      onRotate: source.isPush
                          ? () => _rotate(context, ref, source)
                          : null,
                      onDelete: () => _delete(context, ref, source),
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                _TrackerInstallCard(onTap: onOrderTracker),
              ],
              const SizedBox(height: 22),
              VehicleQuickActions(vehicleId: vehicle.id),
              const SizedBox(height: 4),
            ],
          );
        },
      ),
    );
  }

  Future<void> _addSource(BuildContext context, WidgetRef ref) async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: AppColors.canvas,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _AddTrackerSheet(vehicleId: vehicle.id),
    );
    if (created == true) {
      ref.invalidate(vehicleTrackingWorkspaceProvider(vehicle.id));
    }
  }

  Future<void> _toggle(
    BuildContext context,
    WidgetRef ref,
    VehicleTrackerSource source,
  ) async {
    await _mutate(
      context,
      () => ref
          .read(vehicleTrackingRepositoryProvider)
          .setActive(source.id, !source.isActive),
      success: source.isActive
          ? 'Tracking source disabled.'
          : 'Tracking source enabled.',
    );
    ref.invalidate(vehicleTrackingWorkspaceProvider(vehicle.id));
  }

  Future<void> _rotate(
    BuildContext context,
    WidgetRef ref,
    VehicleTrackerSource source,
  ) async {
    final confirmed = await _confirm(
      context,
      'Rotate tracker key?',
      'The old key stops working immediately. Update the connected device with the new key.',
      'Rotate key',
    );
    if (!confirmed || !context.mounted) return;
    try {
      final key = await ref
          .read(vehicleTrackingRepositoryProvider)
          .regenerateKey(source.id);
      if (!context.mounted) return;
      await _showKey(context, key);
      ref.invalidate(vehicleTrackingWorkspaceProvider(vehicle.id));
    } on ApiFailure catch (failure) {
      if (context.mounted) _message(context, failure.message, error: true);
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    VehicleTrackerSource source,
  ) async {
    final confirmed = await _confirm(
      context,
      'Remove tracking source?',
      '${source.displayLabel} will stop sending locations to this vehicle.',
      'Remove source',
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;
    await _mutate(
      context,
      () => ref.read(vehicleTrackingRepositoryProvider).delete(source.id),
      success: 'Tracking source removed.',
    );
    ref.invalidate(vehicleTrackingWorkspaceProvider(vehicle.id));
  }
}

/// Full map workspace merged from the retired standalone Vehicle Tracking
/// page. The map is the visual background; status, live facts, refresh and
/// tracker controls float above it so this tab is now the complete experience.
class _TrackingMapWorkspace extends StatelessWidget {
  const _TrackingMapWorkspace({
    required this.vehicle,
    required this.workspace,
    required this.onRefresh,
    required this.onPhone,
    required this.onAddSource,
  });

  final VehicleDetail vehicle;
  final VehicleTrackingWorkspace workspace;
  final VoidCallback onRefresh;
  final VoidCallback onPhone;
  final VoidCallback onAddSource;

  @override
  Widget build(BuildContext context) {
    final trail = workspace.trail
        .map((p) => LatLng(p.latitude, p.longitude))
        .toList(growable: false);
    final latest = workspace.latest;
    final positionedSource = latest?.hasPosition == true ? latest : null;
    final latestPoint = positionedSource != null
        ? LatLng(
            positionedSource.lastLatitude!,
            positionedSource.lastLongitude!,
          )
        : (trail.isNotEmpty ? trail.last : null);
    const nigeriaCenter = LatLng(9.0820, 8.6753);
    final mapCenter = latestPoint ?? nigeriaCenter;
    final hasPosition = latestPoint != null;
    final stale =
        latest?.lastPositionAt == null ||
        DateTime.now().difference(latest!.lastPositionAt!.toLocal()).inMinutes >
            10;

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: SizedBox(
        height: 430,
        child: Stack(
          children: [
            Positioned.fill(
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: mapCenter,
                  initialZoom: hasPosition ? 15 : 5.5,
                  interactionOptions: const InteractionOptions(
                    flags:
                        InteractiveFlag.pinchZoom |
                        InteractiveFlag.drag |
                        InteractiveFlag.doubleTapZoom,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'ng.com.travla.customer',
                  ),
                  if (trail.length >= 2)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: trail,
                          strokeWidth: 4,
                          color: AppColors.orange.withValues(alpha: .9),
                        ),
                      ],
                    ),
                  if (latestPoint != null)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: latestPoint,
                          width: 50,
                          height: 58,
                          alignment: Alignment.topCenter,
                          child: const _TrackedVehicleMarker(),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              top: 12,
              child: Row(
                children: [
                  Expanded(
                    child: _MapGlassPanel(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          _LivePill(stale: stale, hasPosition: hasPosition),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              vehicle.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.white,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _MapIconButton(
                    tooltip: 'Refresh location',
                    icon: Icons.refresh_rounded,
                    onTap: onRefresh,
                  ),
                  const SizedBox(width: 8),
                  _MapIconButton(
                    tooltip: 'Add tracking source',
                    icon: Icons.add_location_alt_outlined,
                    accent: true,
                    onTap: onAddSource,
                  ),
                ],
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: _MapGlassPanel(
                padding: const EdgeInsets.fromLTRB(14, 13, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      positionedSource != null
                          ? '${positionedSource.lastLatitude!.toStringAsFixed(5)}, ${positionedSource.lastLongitude!.toStringAsFixed(5)}'
                          : 'Waiting for a live position',
                      style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      positionedSource != null
                          ? '${_relative(positionedSource.lastPositionAt)} · ${positionedSource.typeLabel}${positionedSource.lastSpeed == null ? '' : ' · ${positionedSource.lastSpeed!.toStringAsFixed(0)} km/h'}'
                          : 'Connect this phone or a GPS source to place the vehicle on the map.',
                      style: const TextStyle(
                        color: Color(0xBFFFFFFF),
                        fontSize: 10.5,
                        height: 1.35,
                      ),
                    ),
                    if (workspace.trail.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${workspace.trail.length} recent trail points',
                        style: const TextStyle(
                          color: Color(0x88FFFFFF),
                          fontSize: 9,
                        ),
                      ),
                    ],
                    const SizedBox(height: 11),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.white,
                              side: const BorderSide(color: Color(0x55FFFFFF)),
                              visualDensity: VisualDensity.compact,
                            ),
                            onPressed: onPhone,
                            icon: const Icon(
                              Icons.my_location_rounded,
                              size: 16,
                            ),
                            label: const Text('Use this phone'),
                          ),
                        ),
                        if (positionedSource != null) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.orange,
                                visualDensity: VisualDensity.compact,
                              ),
                              onPressed: () => _openMap(
                                positionedSource.lastLatitude!,
                                positionedSource.lastLongitude!,
                              ),
                              icon: const Icon(
                                Icons.open_in_new_rounded,
                                size: 16,
                              ),
                              label: const Text('Open in Maps'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrackedVehicleMarker extends StatelessWidget {
  const _TrackedVehicleMarker();

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: AppColors.forest700,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: const [
            BoxShadow(
              color: Color(0x55000000),
              blurRadius: 8,
              offset: Offset(0, 3),
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
        offset: const Offset(0, -5),
        child: const Icon(
          Icons.arrow_drop_down,
          color: AppColors.forest700,
          size: 24,
        ),
      ),
    ],
  );
}

class _MapGlassPanel extends StatelessWidget {
  const _MapGlassPanel({required this.child, required this.padding});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: AppColors.forest950.withValues(alpha: .92),
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: const Color(0x33FFFFFF)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x33000000),
          blurRadius: 16,
          offset: Offset(0, 6),
        ),
      ],
    ),
    child: child,
  );
}

class _MapIconButton extends StatelessWidget {
  const _MapIconButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
    this.accent = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;
  final bool accent;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Material(
      color: accent
          ? AppColors.orange
          : AppColors.forest950.withValues(alpha: .92),
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: onTap,
        child: SizedBox.square(
          dimension: 42,
          child: Icon(icon, color: AppColors.white, size: 19),
        ),
      ),
    ),
  );
}

class _SourceCard extends StatelessWidget {
  const _SourceCard({
    required this.source,
    required this.onToggle,
    required this.onRotate,
    required this.onDelete,
  });
  final VehicleTrackerSource source;
  final VoidCallback onToggle;
  final VoidCallback? onRotate;
  final VoidCallback onDelete;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(15),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: source.isActive
                      ? AppColors.forest100
                      : AppColors.forest50,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  source.type == 'TRACCAR'
                      ? Icons.router_outlined
                      : Icons.sensors_outlined,
                  color: source.isActive
                      ? AppColors.forest700
                      : AppColors.muted,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      source.displayLabel,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      '${source.typeLabel}${source.uniqueId == null ? '' : ' · IMEI ${source.uniqueId}'}${source.apiKeyLast4 == null ? '' : ' · key ••••${source.apiKeyLast4}'}',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: source.isActive,
                onChanged: (_) => onToggle(),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  source.lastPositionAt == null
                      ? 'No location fix yet'
                      : 'Last fix ${_relative(source.lastPositionAt)}',
                  style: const TextStyle(color: AppColors.muted, fontSize: 9),
                ),
              ),
              if (onRotate != null)
                TextButton(
                  onPressed: onRotate,
                  child: const Text('Rotate key'),
                ),
              IconButton(
                tooltip: 'Remove source',
                onPressed: onDelete,
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.danger,
                  size: 20,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

/// Premium empty state for an untracked vehicle: explains live tracking and
/// offers the two ways to begin (this phone / a GPS device) plus an install
/// option — all in one clean card.
class _EmptyTrackingHero extends StatelessWidget {
  const _EmptyTrackingHero({
    required this.onPhone,
    required this.onDevice,
    required this.onOrder,
  });

  final VoidCallback onPhone;
  final VoidCallback onDevice;
  final VoidCallback onOrder;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.forest950.withValues(alpha: .06),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.forest700, AppColors.forest950],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.forest700.withValues(alpha: .3),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(
                Icons.my_location_rounded,
                color: Colors.white,
                size: 30,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Track this vehicle live',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.ink,
              fontWeight: FontWeight.w900,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'See its position on the map. Turn this phone into a live tracker, or connect a GPS device.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 12.5,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onPhone,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.orange,
              minimumSize: const Size.fromHeight(50),
            ),
            icon: const Icon(Icons.my_location_rounded, size: 19),
            label: const Text(
              'Use this phone',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onDevice,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.forest700,
              side: const BorderSide(color: AppColors.border),
              minimumSize: const Size.fromHeight(50),
            ),
            icon: const Icon(Icons.gps_fixed_rounded, size: 19),
            label: const Text(
              'Add a GPS device',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 14),
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onOrder,
            child: Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: AppColors.forest50,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.build_circle_outlined,
                    color: AppColors.forest700,
                    size: 20,
                  ),
                  const SizedBox(width: 11),
                  const Expanded(
                    child: Text(
                      'Prefer hardware? Order a tracker installed by Travla.',
                      style: TextStyle(
                        color: AppColors.forest800,
                        fontSize: 11.5,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    color: AppColors.forest700,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrackerInstallCard extends StatelessWidget {
  const _TrackerInstallCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.forest100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.gps_fixed_rounded,
                  color: AppColors.forest700,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Need another tracker?',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Order a GPS tracker supplied and professionally installed by Travla.',
                      style: TextStyle(
                        color: AppColors.muted,
                        fontSize: 9,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_rounded,
                color: AppColors.orangeDark,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddTrackerSheet extends ConsumerStatefulWidget {
  const _AddTrackerSheet({required this.vehicleId});
  final String vehicleId;
  @override
  ConsumerState<_AddTrackerSheet> createState() => _AddTrackerSheetState();
}

class _AddTrackerSheetState extends ConsumerState<_AddTrackerSheet> {
  final _label = TextEditingController();
  final _imei = TextEditingController();
  String _type = 'TRAVLA_PUSH';
  bool _saving = false;
  String? _error;
  @override
  void dispose() {
    _label.dispose();
    _imei.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedPadding(
    duration: const Duration(milliseconds: 180),
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 26),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: _saving
                    ? null
                    : () => Navigator.of(context).pop(false),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          Text(
            'Add tracking source',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          const Text(
            'Connect a GPS/API device already available to you.',
            style: TextStyle(color: AppColors.muted, fontSize: 10),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: const Color(0xFFFFE9E7),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(
                _error!,
                style: const TextStyle(color: AppColors.danger, fontSize: 10),
              ),
            ),
          ],
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _type,
            decoration: const InputDecoration(
              labelText: 'Source type',
              prefixIcon: Icon(Icons.sensors_outlined),
            ),
            items: const [
              DropdownMenuItem(
                value: 'TRAVLA_PUSH',
                child: Text('Push API · GPS device/script'),
              ),
              DropdownMenuItem(
                value: 'TRACCAR',
                child: Text('Traccar device · IMEI'),
              ),
            ],
            onChanged: _saving
                ? null
                : (value) => setState(() => _type = value!),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _label,
            enabled: !_saving,
            decoration: const InputDecoration(
              labelText: 'Label · optional',
              hintText: 'For example: Boot GPS box',
            ),
          ),
          if (_type == 'TRACCAR') ...[
            const SizedBox(height: 12),
            TextField(
              controller: _imei,
              enabled: !_saving,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Device IMEI / unique ID',
              ),
            ),
          ],
          const SizedBox(height: 13),
          Text(
            _type == 'TRACCAR'
                ? 'The IMEI must match the device configured on Travla’s Traccar server.'
                : 'A private API key is shown once. Save it immediately and configure the GPS sender with it.',
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 9,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _saving ? null : _submit,
              icon: _saving
                  ? const SizedBox.square(
                      dimension: 17,
                      child: CircularProgressIndicator(
                        color: AppColors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.add_rounded),
              label: Text(_saving ? 'Creating…' : 'Create source'),
            ),
          ),
        ],
      ),
    ),
  );
  Future<void> _submit() async {
    if (_type == 'TRACCAR' && _imei.text.trim().isEmpty) {
      setState(() => _error = 'Enter the device IMEI or unique ID.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(vehicleTrackingRepositoryProvider)
          .create(
            vehicleId: widget.vehicleId,
            type: _type,
            label: _label.text,
            uniqueId: _imei.text,
          );
      if (!mounted) return;
      if (result.apiKey != null) await _showKey(context, result.apiKey!);
      if (mounted) Navigator.of(context).pop(true);
    } on ApiFailure catch (failure) {
      if (mounted) setState(() => _error = failure.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _LivePill extends StatelessWidget {
  const _LivePill({required this.stale, required this.hasPosition});
  final bool stale;
  final bool hasPosition;
  @override
  Widget build(BuildContext context) {
    final label = !hasPosition
        ? 'WAITING'
        : stale
        ? 'STALE'
        : 'LIVE';
    final color = !hasPosition
        ? AppColors.muted
        : stale
        ? AppColors.orange
        : const Color(0xFF47D18C);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .15),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 8,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _TrackingEmpty extends StatelessWidget {
  const _TrackingEmpty({
    required this.icon,
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.onAction,
  });
  final IconData icon;
  final String title;
  final String body;
  final String actionLabel;
  final VoidCallback onAction;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(icon, color: AppColors.muted),
          const SizedBox(height: 9),
          Text(
            title,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            body,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 10,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          TextButton(onPressed: onAction, child: Text(actionLabel)),
        ],
      ),
    ),
  );
}

Future<void> _openMap(double lat, double lng) async {
  final uri = Uri.parse(
    'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
  );
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

String _relative(DateTime? value) {
  if (value == null) return 'never';
  final elapsed = DateTime.now().difference(value.toLocal());
  if (elapsed.inMinutes < 1) return 'just now';
  if (elapsed.inMinutes < 60) return '${elapsed.inMinutes}m ago';
  if (elapsed.inHours < 24) return '${elapsed.inHours}h ago';
  return '${elapsed.inDays}d ago';
}

Future<bool> _confirm(
  BuildContext context,
  String title,
  String body,
  String action, {
  bool destructive = false,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Go back'),
          ),
          FilledButton(
            style: destructive
                ? FilledButton.styleFrom(backgroundColor: AppColors.danger)
                : null,
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(action),
          ),
        ],
      ),
    ) ??
    false;
Future<void> _showKey(BuildContext context, String key) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (context) => AlertDialog(
    title: const Text('Save this tracker key'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'This private key is shown once. Copy it before closing this window.',
        ),
        const SizedBox(height: 12),
        SelectableText(
          key,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ],
    ),
    actions: [
      TextButton.icon(
        onPressed: () async {
          await Clipboard.setData(ClipboardData(text: key));
          if (context.mounted) _message(context, 'Tracker key copied.');
        },
        icon: const Icon(Icons.copy_outlined),
        label: const Text('Copy key'),
      ),
      FilledButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('I saved it'),
      ),
    ],
  ),
);
Future<void> _mutate(
  BuildContext context,
  Future<void> Function() action, {
  required String success,
}) async {
  try {
    await action();
    if (context.mounted) _message(context, success);
  } on ApiFailure catch (failure) {
    if (context.mounted) _message(context, failure.message, error: true);
  }
}

void _message(BuildContext context, String value, {bool error = false}) =>
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(value),
        backgroundColor: error ? AppColors.danger : AppColors.forest800,
      ),
    );
