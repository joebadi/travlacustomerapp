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
  final _distance = const Distance();

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

  // GPS quality gates — the OS emits jittery fixes even while parked, which
  // otherwise pile up as fake movement. We reject low-accuracy fixes, ignore
  // drift smaller than our own uncertainty, and discard impossible teleports.
  static const double _maxAccuracyM = 30; // drop fixes worse than this
  static const double _minMoveM = 8; // movement floor below which we hold still
  static const double _maxSpeedMps = 70; // ~252 km/h — reject glitch jumps
  LatLng? _lastAccepted;
  DateTime? _lastAcceptedAt;

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
      _lastAccepted = null;
      _lastAcceptedAt = null;
      _sub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 4,
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
    // 1) Drop low-quality fixes outright — these are the main source of drift.
    if (pos.accuracy > 0 && pos.accuracy > _maxAccuracyM) return;

    final point = LatLng(pos.latitude, pos.longitude);
    final now = DateTime.now();

    if (_lastAccepted != null) {
      final moved = _distance.as(LengthUnit.Meter, _lastAccepted!, point);

      // 2) Stationary drift: if we haven't moved farther than our own GPS
      // uncertainty (or the floor), it's noise — refresh speed but don't grow
      // the trail or distance.
      final threshold = math.max(
        _minMoveM,
        pos.accuracy > 0 ? pos.accuracy : 0,
      );
      if (moved < threshold) {
        if (mounted) setState(() => _speed = pos.speed >= 0 ? 0 : null);
        return;
      }

      // 3) Teleport guard: reject physically impossible jumps between fixes.
      final dt = now.difference(_lastAcceptedAt ?? now).inMilliseconds / 1000.0;
      if (dt > 0 && moved / dt > _maxSpeedMps) return;

      _distanceM += moved;
    }

    _lastAccepted = point;
    _lastAcceptedAt = now;
    _trail.add(point);
    _pending.add({
      'latitude': pos.latitude,
      'longitude': pos.longitude,
      'sequence': _seq++,
      if (pos.speed >= 0) 'speed': pos.speed,
      if (pos.heading >= 0) 'heading': pos.heading,
      if (pos.accuracy >= 0) 'accuracy': pos.accuracy,
      'recorded_at': now.toUtc().toIso8601String(),
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
    final center = _trail.isNotEmpty
        ? _trail.last
        : const LatLng(9.0820, 8.6753);
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
            if (_trail.isNotEmpty)
              MarkerLayer(
                markers: [
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
