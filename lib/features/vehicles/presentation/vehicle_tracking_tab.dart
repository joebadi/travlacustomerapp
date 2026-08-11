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
        data: (data) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (data.latest?.hasPosition == true || data.trail.isNotEmpty) ...[
              _TrackingMiniMap(workspace: data),
              const SizedBox(height: 13),
            ],
            _LivePositionCard(vehicle: vehicle, workspace: data),
            const SizedBox(height: 13),
            if (!data.hasActiveSource) ...[
              _StartTrackingCard(
                onPhone: () =>
                    context.push('/more/tracking/phone?vehicle=${vehicle.id}'),
                onDevice: () => _addSource(context, ref),
              ),
              const SizedBox(height: 13),
              _TrackerInstallCard(onTap: onOrderTracker, prominent: true),
              const SizedBox(height: 13),
            ],
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
            if (data.sources.isEmpty)
              _TrackingEmpty(
                icon: Icons.sensors_off_outlined,
                title: 'No tracking sources yet',
                body:
                    'Connect a supported GPS/API source or order professional tracker installation.',
                actionLabel: 'Add source',
                onAction: () => _addSource(context, ref),
              )
            else
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
            if (data.hasActiveSource) ...[
              const SizedBox(height: 3),
              _TrackerInstallCard(onTap: onOrderTracker),
            ],
          ],
        ),
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

/// In-app map of the vehicle's latest position and recent trail — so the
/// Tracking tab reflects the live tracking for this vehicle without leaving the app.
class _TrackingMiniMap extends StatelessWidget {
  const _TrackingMiniMap({required this.workspace});

  final VehicleTrackingWorkspace workspace;

  @override
  Widget build(BuildContext context) {
    final trail = workspace.trail
        .map((p) => LatLng(p.latitude, p.longitude))
        .toList(growable: false);
    final latest = workspace.latest;
    final latestPoint = latest?.hasPosition == true
        ? LatLng(latest!.lastLatitude!, latest.lastLongitude!)
        : (trail.isNotEmpty ? trail.last : null);
    if (latestPoint == null) return const SizedBox.shrink();

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        height: 200,
        child: FlutterMap(
          options: MapOptions(
            initialCenter: latestPoint,
            initialZoom: 15,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'ng.com.travla.customer',
            ),
            if (trail.length >= 2)
              PolylineLayer(
                polylines: [
                  Polyline(points: trail, strokeWidth: 4, color: AppColors.orange),
                ],
              ),
            MarkerLayer(
              markers: [
                Marker(
                  point: latestPoint,
                  width: 40,
                  height: 40,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.forest700,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: .3), blurRadius: 6, offset: const Offset(0, 2)),
                      ],
                    ),
                    child: const Icon(Icons.directions_car_filled_rounded, color: Colors.white, size: 18),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LivePositionCard extends StatelessWidget {
  const _LivePositionCard({required this.vehicle, required this.workspace});

  final VehicleDetail vehicle;
  final VehicleTrackingWorkspace workspace;

  @override
  Widget build(BuildContext context) {
    final latest = workspace.latest;
    final stale =
        latest?.lastPositionAt == null ||
        DateTime.now().difference(latest!.lastPositionAt!).inMinutes > 10;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.forest950,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 43,
                height: 43,
                decoration: BoxDecoration(
                  color: AppColors.orange,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.near_me_outlined,
                  color: AppColors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'LIVE VEHICLE POSITION',
                      style: TextStyle(
                        color: AppColors.orange,
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .8,
                      ),
                    ),
                    Text(
                      vehicle.displayName,
                      style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              _LivePill(stale: stale, hasPosition: latest?.hasPosition == true),
            ],
          ),
          const SizedBox(height: 16),
          if (latest?.hasPosition == true) ...[
            Text(
              '${latest!.lastLatitude!.toStringAsFixed(5)}, ${latest.lastLongitude!.toStringAsFixed(5)}',
              style: const TextStyle(
                color: AppColors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              '${_relative(latest.lastPositionAt)} · ${latest.typeLabel}${latest.lastSpeed == null ? '' : ' · ${latest.lastSpeed!.toStringAsFixed(0)} km/h'}',
              style: const TextStyle(color: Color(0x99FFFFFF), fontSize: 10),
            ),
            const SizedBox(height: 13),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.white,
                side: const BorderSide(color: Color(0x44FFFFFF)),
              ),
              onPressed: () =>
                  _openMap(latest.lastLatitude!, latest.lastLongitude!),
              icon: const Icon(Icons.map_outlined),
              label: const Text('Open live position in Maps'),
            ),
          ] else
            const Text(
              'No position received yet. Connect a tracking source below or have Travla install a GPS tracker.',
              style: TextStyle(
                color: Color(0xAFFFFFFF),
                fontSize: 11,
                height: 1.5,
              ),
            ),
          if (workspace.trail.isNotEmpty) ...[
            const SizedBox(height: 13),
            Text(
              '${workspace.trail.length} recent location points retained in this live trail.',
              style: const TextStyle(color: Color(0x77FFFFFF), fontSize: 9),
            ),
          ],
        ],
      ),
    );
  }
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
                onChanged: (_) => onToggle,
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

/// Primary call-to-action for an untracked vehicle: start tracking it with this
/// phone (free, instant) or connect a GPS device (push key / Traccar IMEI).
class _StartTrackingCard extends StatelessWidget {
  const _StartTrackingCard({required this.onPhone, required this.onDevice});

  final VoidCallback onPhone;
  final VoidCallback onDevice;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.forest950, AppColors.forest700],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Start tracking this vehicle',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15),
          ),
          const SizedBox(height: 3),
          Text(
            'Use this phone as a live tracker, or connect a GPS device.',
            style: TextStyle(color: Colors.white.withValues(alpha: .78), fontSize: 11.5, height: 1.4),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: onPhone,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.orange,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(46),
                  ),
                  icon: const Icon(Icons.my_location_rounded, size: 18),
                  label: const Text('Use this phone'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onDevice,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Color(0x55FFFFFF)),
                    minimumSize: const Size.fromHeight(46),
                  ),
                  icon: const Icon(Icons.gps_fixed_rounded, size: 18),
                  label: const Text('Add device'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TrackerInstallCard extends StatelessWidget {
  const _TrackerInstallCard({required this.onTap, this.prominent = false});
  final VoidCallback onTap;
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: prominent ? AppColors.orangeSoft : null,
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
                  color: prominent ? AppColors.orange : AppColors.forest100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.gps_fixed_rounded,
                  color: prominent ? AppColors.white : AppColors.forest700,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      prominent
                          ? 'No tracker in this vehicle yet?'
                          : 'Need another tracker?',
                      style: const TextStyle(
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
