import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:travla_customer_app/app/theme/app_colors.dart';
import 'package:travla_customer_app/core/network/api_failure.dart';
import 'package:travla_customer_app/features/journeys/data/journey_repository.dart';
import 'package:travla_customer_app/features/journeys/domain/journey_models.dart';
import 'package:travla_customer_app/features/vehicles/data/garage_repository.dart';

class RecordJourneyScreen extends ConsumerStatefulWidget {
  const RecordJourneyScreen({super.key});

  @override
  ConsumerState<RecordJourneyScreen> createState() => _RecordJourneyScreenState();
}

class _RecordJourneyScreenState extends ConsumerState<RecordJourneyScreen> {
  final _mapController = MapController();
  final _distance = const Distance();

  final _titleCtrl = TextEditingController(
    text: 'Journey ${DateTime.now().day}/${DateTime.now().month}',
  );
  String _mode = 'DRIVING';
  String? _vehicleId;

  bool _recording = false;
  bool _busy = false;
  String? _error;

  String? _journeyId;
  StreamSubscription<Position>? _sub;
  Timer? _ticker;
  DateTime? _startedAt;
  int _elapsed = 0;

  final List<LatLng> _trail = [];
  final List<Map<String, dynamic>> _pending = []; // not-yet-uploaded points
  int _seq = 0;
  double _distanceM = 0;
  double? _speed;

  @override
  void dispose() {
    _sub?.cancel();
    _ticker?.cancel();
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<bool> _ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      setState(() => _error = 'Turn on location (GPS), then try again.');
      return false;
    }
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
    if (p == LocationPermission.denied || p == LocationPermission.deniedForever) {
      setState(() => _error = 'Location permission is required to record a journey.');
      return false;
    }
    return true;
  }

  Future<void> _start() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (!await _ensurePermission()) return;
      final id = await ref.read(journeyRepositoryProvider).create(
            title: _titleCtrl.text,
            transportMode: _mode,
            vehicleId: _vehicleId,
          );
      if (id.isEmpty) throw const ApiFailure('The journey could not be started.');
      _journeyId = id;
      _startedAt = DateTime.now();
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _elapsed = DateTime.now().difference(_startedAt!).inSeconds);
      });
      _sub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 5),
      ).listen(_onPosition);
      setState(() => _recording = true);
    } on ApiFailure catch (f) {
      setState(() => _error = f.message);
    } catch (e) {
      setState(() => _error = 'Could not start recording: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _onPosition(Position pos) {
    final point = LatLng(pos.latitude, pos.longitude);
    if (_trail.isNotEmpty) {
      _distanceM += _distance.as(LengthUnit.Meter, _trail.last, point);
    }
    _trail.add(point);
    _pending.add({
      'latitude': pos.latitude,
      'longitude': pos.longitude,
      'sequence': _seq++,
      if (pos.speed >= 0) 'speed': pos.speed,
      if (pos.heading >= 0) 'heading': pos.heading,
      if (pos.accuracy >= 0) 'accuracy': pos.accuracy,
      'recorded_at': DateTime.now().toUtc().toIso8601String(),
    });
    setState(() => _speed = pos.speed >= 0 ? pos.speed * 3.6 : null);
    _mapController.move(point, _mapController.camera.zoom);
    if (_pending.length >= 8) _flush();
  }

  Future<void> _flush() async {
    final id = _journeyId;
    if (id == null || _pending.isEmpty) return;
    final batch = List<Map<String, dynamic>>.from(_pending);
    _pending.clear();
    try {
      await ref.read(journeyRepositoryProvider).addPoints(id, batch);
    } on ApiFailure {
      // Re-queue so the next flush retries.
      _pending.insertAll(0, batch);
    }
  }

  Future<void> _stop() async {
    setState(() => _busy = true);
    await _sub?.cancel();
    _ticker?.cancel();
    await _flush();
    ref.invalidate(journeysProvider);
    if (!mounted) return;
    final id = _journeyId;
    if (id != null && id.isNotEmpty) {
      context.pushReplacement('/journeys/$id');
    } else {
      context.pop();
    }
  }

  Future<void> _reportRoadCondition() async {
    if (_trail.isEmpty) return;
    final catalogue = await ref.read(roadReportCatalogueProvider.future).catchError((_) => <RoadReportType>[]);
    if (!mounted || catalogue.isEmpty) return;
    final descCtrl = TextEditingController();
    final type = await showModalBottomSheet<RoadReportType>(
      context: context,
      backgroundColor: AppColors.white,
      showDragHandle: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheetContext).bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 2, 20, 4),
                child: Text('Report a road condition', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                child: TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(hintText: 'Note (optional)'),
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: catalogue
                      .map((t) => ListTile(
                            leading: const Icon(Icons.warning_amber_rounded, color: AppColors.orangeDark),
                            title: Text(t.label, style: const TextStyle(fontWeight: FontWeight.w700)),
                            subtitle: t.category != null ? Text(t.category!) : null,
                            onTap: () => Navigator.of(sheetContext).pop(t),
                          ))
                      .toList(),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
    if (type == null) return;
    final at = _trail.last;
    try {
      await ref.read(journeyRepositoryProvider).createRoadReport(
            type: type.value,
            latitude: at.latitude,
            longitude: at.longitude,
            description: descCtrl.text,
          );
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('Road report submitted. Thank you!')));
      }
    } on ApiFailure catch (f) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(f.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(title: Text(_recording ? 'Recording…' : 'Record a journey')),
      body: _recording ? _recordingView() : _setupView(),
    );
  }

  Widget _setupView() {
    final garage = ref.watch(garageProvider);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [
        if (_error != null) ...[
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(color: const Color(0xFFFFE3E1), borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              const Icon(Icons.error_outline_rounded, color: AppColors.danger),
              const SizedBox(width: 10),
              Expanded(child: Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 12.5))),
            ]),
          ),
          const SizedBox(height: 14),
        ],
        TextField(
          controller: _titleCtrl,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Journey title'),
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(
          initialValue: _mode,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Transport mode'),
          items: transportModeOptions.map((o) => DropdownMenuItem(value: o.value, child: Text(o.label))).toList(),
          onChanged: (v) => setState(() => _mode = v ?? 'DRIVING'),
        ),
        const SizedBox(height: 14),
        garage.maybeWhen(
          data: (snapshot) => DropdownButtonFormField<String>(
            initialValue: _vehicleId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Vehicle (optional)'),
            items: snapshot.vehicles
                .map((v) => DropdownMenuItem(value: v.id, child: Text(v.displayName, overflow: TextOverflow.ellipsis)))
                .toList(),
            onChanged: (v) => setState(() => _vehicleId = v),
          ),
          orElse: () => const SizedBox.shrink(),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: _busy ? null : _start,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54), backgroundColor: AppColors.orange),
          icon: _busy
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.fiber_manual_record_rounded),
          label: Text(_busy ? 'Starting…' : 'Start recording', style: const TextStyle(fontWeight: FontWeight.w900)),
        ),
      ],
    );
  }

  Widget _recordingView() {
    final center = _trail.isNotEmpty ? _trail.last : const LatLng(9.0820, 8.6753);
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(initialCenter: center, initialZoom: 16),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'ng.com.travla.customer',
            ),
            if (_trail.length >= 2)
              PolylineLayer(polylines: [Polyline(points: _trail, strokeWidth: 5, color: AppColors.orange)]),
            if (_trail.isNotEmpty)
              MarkerLayer(markers: [
                Marker(
                  point: _trail.last,
                  width: 24,
                  height: 24,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.forest700,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                  ),
                ),
              ]),
          ],
        ),
        Positioned(
          top: 12,
          left: 12,
          right: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .12), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: Row(
              children: [
                _liveStat((_distanceM / 1000).toStringAsFixed(2), 'km'),
                _div(),
                _liveStat(_hms(_elapsed), 'time'),
                _div(),
                _liveStat(_speed != null ? '${_speed!.round()}' : '—', 'km/h'),
              ],
            ),
          ),
        ),
        Positioned(
          bottom: 20,
          left: 16,
          right: 16,
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _reportRoadCondition,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    backgroundColor: AppColors.white,
                  ),
                  icon: const Icon(Icons.add_alert_outlined),
                  label: const Text('Report'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _busy ? null : _stop,
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52), backgroundColor: AppColors.danger),
                  icon: const Icon(Icons.stop_rounded),
                  label: const Text('Stop & save'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _liveStat(String value, String label) => Expanded(
        child: Column(
          children: [
            Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: AppColors.ink)),
            Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 10.5)),
          ],
        ),
      );

  Widget _div() => Container(width: 1, height: 26, color: AppColors.border);

  String _hms(int s) {
    final h = s ~/ 3600, m = (s % 3600) ~/ 60, sec = s % 60;
    String two(int n) => n.toString().padLeft(2, '0');
    return h > 0 ? '${two(h)}:${two(m)}:${two(sec)}' : '${two(m)}:${two(sec)}';
  }
}
