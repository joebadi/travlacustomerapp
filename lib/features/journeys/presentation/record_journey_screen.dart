import 'dart:async';
import 'dart:math' as math;

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
import 'package:travla_customer_app/features/journeys/domain/journey_track_filter.dart';

class RecordJourneyScreen extends ConsumerStatefulWidget {
  const RecordJourneyScreen({
    super.key,
    this.initialTitle,
    this.initialMode = 'DRIVING',
    this.initialVehicleId,
  });

  final String? initialTitle;
  final String initialMode;
  final String? initialVehicleId;

  @override
  ConsumerState<RecordJourneyScreen> createState() =>
      _RecordJourneyScreenState();
}

class _RecordJourneyScreenState extends ConsumerState<RecordJourneyScreen> {
  final _mapController = MapController();

  late final TextEditingController _titleCtrl;
  late String _mode;
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

  // The OS keeps emitting jittery fixes even while parked, which naively pile
  // up as fake zig-zag movement. This filter holds a stable anchor and only
  // leaves it on confirmed movement (see JourneyTrackFilter). Recreated per
  // recording session in _start().
  JourneyTrackFilter _filter = JourneyTrackFilter();

  // The stable position shown on the map (anchor while parked, accepted fix
  // while moving) — kept separate from the recorded trail so the live marker
  // never jitters even during a hold.
  LatLng? _live;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _titleCtrl = TextEditingController(
      text: widget.initialTitle?.trim().isNotEmpty == true
          ? widget.initialTitle!.trim()
          : 'Journey ${now.day}/${now.month}',
    );
    _mode =
        transportModeOptions.any((option) => option.value == widget.initialMode)
        ? widget.initialMode
        : 'DRIVING';
    _vehicleId = widget.initialVehicleId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _start();
    });
  }

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
    if (p == LocationPermission.denied) {
      p = await Geolocator.requestPermission();
    }
    if (p == LocationPermission.denied ||
        p == LocationPermission.deniedForever) {
      setState(
        () => _error = 'Location permission is required to record a journey.',
      );
      return false;
    }
    return true;
  }

  Future<void> _start() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (!await _ensurePermission()) return;
      final id = await ref
          .read(journeyRepositoryProvider)
          .create(
            title: _titleCtrl.text,
            transportMode: _mode,
            vehicleId: _vehicleId,
          );
      if (id.isEmpty) {
        throw const ApiFailure('The journey could not be started.');
      }
      _journeyId = id;
      _startedAt = DateTime.now();
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) {
          setState(
            () => _elapsed = DateTime.now().difference(_startedAt!).inSeconds,
          );
        }
      });
      _filter = JourneyTrackFilter();
      _live = null;
      // distanceFilter: 0 — let our own filter be the sole authority on what
      // counts as movement. The OS distance filter keys off raw jitter, so it
      // would emit erratically while parked and add nothing but noise.
      _sub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 0,
        ),
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
    final sample = _filter.add(pos);

    // Unusable fix — leave everything (marker included) exactly as it was.
    if (sample.decision == TrackDecision.rejected) return;

    // Keep the live marker/camera on the stable point (anchor while parked),
    // so the map holds steady even when we're not recording anything.
    final movedMarker = _live == null || _live != sample.point;
    _live = sample.point;
    if (movedMarker) {
      _mapController.move(sample.point, _mapController.camera.zoom);
    }

    // Parked: update the speed readout to 0 but don't record a thing.
    if (sample.decision == TrackDecision.holding) {
      if (mounted) setState(() => _speed = sample.speedKmh);
      return;
    }

    // Confirmed movement — grow the trail and the recorded distance.
    _distanceM += sample.movedMeters;
    _trail.add(sample.point);
    _pending.add({
      'latitude': sample.point.latitude,
      'longitude': sample.point.longitude,
      'sequence': _seq++,
      if (pos.speed >= 0) 'speed': pos.speed,
      if (pos.heading >= 0) 'heading': pos.heading,
      if (pos.accuracy >= 0) 'accuracy': pos.accuracy,
      'recorded_at': pos.timestamp.toUtc().toIso8601String(),
    });
    setState(() => _speed = sample.speedKmh);
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
    final catalogue = await ref
        .read(roadReportCatalogueProvider.future)
        .catchError((_) => <RoadReportType>[]);
    if (!mounted || catalogue.isEmpty) return;
    final descCtrl = TextEditingController();
    final type = await showModalBottomSheet<RoadReportType>(
      context: context,
      backgroundColor: AppColors.white,
      showDragHandle: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 2, 20, 4),
                child: Text(
                  'Report a road condition',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                child: TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Note (optional)',
                  ),
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: catalogue
                      .map(
                        (t) => ListTile(
                          leading: const Icon(
                            Icons.warning_amber_rounded,
                            color: AppColors.orangeDark,
                          ),
                          title: Text(
                            t.label,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: t.category != null
                              ? Text(t.category!)
                              : null,
                          onTap: () => Navigator.of(sheetContext).pop(t),
                        ),
                      )
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
      await ref
          .read(journeyRepositoryProvider)
          .createRoadReport(
            type: type.value,
            latitude: at.latitude,
            longitude: at.longitude,
            description: descCtrl.text,
          );
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text('Road report submitted. Thank you!')),
          );
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
    if (!_recording) return _startingView();
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(title: const Text('Recording…')),
      body: _recordingView(),
    );
  }

  Widget _startingView() {
    return Scaffold(
      backgroundColor: AppColors.forest950,
      body: Stack(
        fit: StackFit.expand,
        children: [
          FlutterMap(
            options: const MapOptions(
              initialCenter: LatLng(9.0820, 8.6753),
              initialZoom: 5.7,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'ng.com.travla.customer',
              ),
            ],
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.forest950.withValues(alpha: .22),
            ),
          ),
          Center(
            child: Container(
              width: math.min(MediaQuery.sizeOf(context).width - 32, 360),
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xE805100C),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.forest600),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x66000000),
                    blurRadius: 30,
                    offset: Offset(0, 14),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_error == null)
                    const SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        color: Color(0xFF6DE4B0),
                        strokeWidth: 2.4,
                      ),
                    )
                  else
                    const Icon(
                      Icons.location_off_rounded,
                      color: AppColors.orange,
                      size: 30,
                    ),
                  const SizedBox(height: 14),
                  Text(
                    _error == null
                        ? 'Preparing your journey'
                        : 'Journey not started',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    _error ?? 'Connecting to GPS and preparing live recording…',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFB8CEC5),
                      fontSize: 12.5,
                      height: 1.45,
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 17),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => context.pop(),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(
                                color: AppColors.forest600,
                              ),
                            ),
                            child: const Text('Back'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            onPressed: _start,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.orange,
                            ),
                            child: const Text('Try again'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _recordingView() {
    final center =
        _live ?? (_trail.isNotEmpty ? _trail.last : const LatLng(9.0820, 8.6753));
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
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: _trail,
                    strokeWidth: 5,
                    color: AppColors.orange,
                  ),
                ],
              ),
            if (_live != null || _trail.isNotEmpty)
              MarkerLayer(
                markers: [
                  Marker(
                    point: _live ?? _trail.last,
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
                ],
              ),
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
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .12),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
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
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    backgroundColor: AppColors.danger,
                  ),
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
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 17,
            color: AppColors.ink,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: AppColors.muted, fontSize: 10.5),
        ),
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
