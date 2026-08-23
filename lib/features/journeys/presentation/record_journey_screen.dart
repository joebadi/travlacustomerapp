import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:travla_customer_app/app/theme/app_colors.dart';
import 'package:travla_customer_app/features/journeys/presentation/journey_vector_map.dart';
import 'package:travla_customer_app/core/auth/secure_token_store.dart';
import 'package:travla_customer_app/core/config/app_config.dart';
import 'package:travla_customer_app/core/network/api_failure.dart';
import 'package:travla_customer_app/features/journeys/data/journey_record_task_handler.dart';
import 'package:travla_customer_app/features/journeys/data/journey_repository.dart';
import 'package:travla_customer_app/features/journeys/domain/journey_models.dart';
import 'package:travla_customer_app/features/journeys/presentation/drop_road_tag_sheet.dart';

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
  Timer? _ticker;
  DateTime? _startedAt;
  int _elapsed = 0;

  final List<LatLng> _trail = [];
  double _distanceM = 0;
  double? _speed;

  // Recording runs in a foreground-service isolate (see
  // journey_record_task_handler) so it keeps going — and keeps saving points —
  // when the app is backgrounded or the screen is locked, behind a persistent
  // notification. The UI just presents what the service streams back.

  // The stable position shown on the map (anchor while parked, accepted fix
  // while moving) — kept separate from the recorded trail so the live marker
  // never jitters even during a hold.
  LatLng? _live;

  // Camera keeps the user centred until they pan; the locate button re-arms it.
  bool _autoFollow = true;

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
    FlutterForegroundTask.addTaskDataCallback(_onServiceData);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _start();
    });
  }

  @override
  void dispose() {
    FlutterForegroundTask.removeTaskDataCallback(_onServiceData);
    _ticker?.cancel();
    // If the screen is torn down while still recording, stop the service too so
    // we don't orphan a headless recording.
    if (_recording) FlutterForegroundTask.stopService();
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
      // Seed the camera on the user's current spot so recording opens centred
      // on them (not the middle of Nigeria) before the first service fix lands.
      _live = await _quickFix();
      await _startRecordingService(id);
      setState(() => _recording = true);
    } on ApiFailure catch (f) {
      setState(() => _error = f.message);
    } catch (e) {
      setState(() => _error = 'Could not start recording: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// A fast best-effort current position for seeding the camera at start —
  /// last-known first (instant), then a short live read.
  Future<LatLng?> _quickFix() async {
    try {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) return LatLng(last.latitude, last.longitude);
    } catch (_) {}
    try {
      final now = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );
      return LatLng(now.latitude, now.longitude);
    } catch (_) {
      return null;
    }
  }

  /// Recenter the map on the user and re-enable follow.
  void _recenter() {
    final at = _live;
    if (at == null) return;
    setState(() => _autoFollow = true);
    _mapController.move(at, 15);
  }

  /// Start the foreground recording service, handing it the points endpoint +
  /// bearer token so its isolate can upload while the app is backgrounded.
  Future<void> _startRecordingService(String journeyId) async {
    await FlutterForegroundTask.requestNotificationPermission();
    final token = await SecureTokenStore(const FlutterSecureStorage()).read();

    await FlutterForegroundTask.saveData(
      key: kJourneyPointsUrl,
      value: '${AppConfig.apiBaseUrl}/journeys/$journeyId/points',
    );
    await FlutterForegroundTask.saveData(key: kJourneyBearer, value: token ?? '');
    await FlutterForegroundTask.saveData(key: kJourneyAppType, value: AppConfig.appType);

    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'travla_journeys',
        channelName: 'Journey recording',
        channelDescription: 'Shown while a journey is being recorded.',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(2000),
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );

    final result = await FlutterForegroundTask.startService(
      serviceTypes: [ForegroundServiceTypes.location],
      notificationTitle: 'Recording journey',
      notificationText: '0.00 km',
      callback: journeyRecordCallback,
    );
    if (result is ServiceRequestFailure) {
      throw ApiFailure('Could not start recording: ${result.error}');
    }
  }

  Future<void> _stopRecordingService() async {
    _recording = false;
    try {
      await FlutterForegroundTask.stopService();
    } catch (_) {
      // Already stopped — nothing to do.
    }
  }

  /// Progress streamed from the recording isolate (foreground or background).
  void _onServiceData(Object data) {
    if (data is! Map) return;
    final lat = (data['lat'] as num?)?.toDouble();
    final lng = (data['lng'] as num?)?.toDouble();
    if (lat == null || lng == null) return;

    final point = LatLng(lat, lng);
    final moved = data['decision']?.toString() == 'moved';
    final dist = (data['distance_m'] as num?)?.toDouble();
    final speed = (data['speed_kmh'] as num?)?.toDouble();

    setState(() {
      _live = point;
      if (dist != null) _distanceM = dist;
      _speed = speed;
      if (moved) _trail.add(point);
    });
    if (_autoFollow) {
      _mapController.move(point, _mapController.camera.zoom);
    }
  }

  /// A journey worth saving needs at least two recorded points *and* enough
  /// real ground covered — the movement filter only appends points on genuine
  /// movement, so this reliably separates "I actually went somewhere" from "I
  /// stood still and GPS jittered". Saving a no-movement trail produced a
  /// single-point journey that then errored when opened.
  static const double _minSaveDistanceM = 25;
  bool get _hasRealTrail =>
      _trail.length >= 2 && _distanceM >= _minSaveDistanceM;

  /// The "Stop & save" button. Saves when there's a real trail; otherwise
  /// there's nothing to save, so we offer to discard or keep recording.
  Future<void> _stop() async {
    if (_busy) return;
    if (_hasRealTrail) {
      await _saveAndLeave();
      return;
    }
    final action = await _askNoMovement();
    if (action == 'discard') await _discardAndLeave();
  }

  /// Road modes get their trace snapped to the road network on save.
  static const _roadModes = {'DRIVING', 'BUS', 'MOTORCYCLE'};

  Future<void> _saveAndLeave() async {
    setState(() => _busy = true);
    _ticker?.cancel();
    // Stopping the service triggers its final flush of any buffered points.
    await _stopRecordingService();
    final id = _journeyId;
    // Snap to roads before showing the result, so the saved journey opens
    // already road-matched. Best-effort — the raw trail stands if it fails.
    if (id != null && id.isNotEmpty && _roadModes.contains(_mode)) {
      try {
        await ref.read(journeyRepositoryProvider).match(id);
      } catch (_) {
        // Keep the raw trail if matching is unavailable/offline.
      }
    }
    ref.invalidate(journeysProvider);
    if (!mounted) return;
    if (id != null && id.isNotEmpty) {
      context.pushReplacement('/journeys/$id');
    } else {
      context.pop();
    }
  }

  /// Cancel recording and remove the draft journey created at start, so we
  /// never leave an empty, unopenable journey behind.
  Future<void> _discardAndLeave() async {
    setState(() => _busy = true);
    _ticker?.cancel();
    await _stopRecordingService();
    final id = _journeyId;
    if (id != null && id.isNotEmpty) {
      try {
        await ref.read(journeyRepositoryProvider).delete(id);
      } catch (_) {
        // Best-effort cleanup — a leftover empty draft is filtered from the
        // list anyway.
      }
    }
    ref.invalidate(journeysProvider);
    if (mounted) context.pop();
  }

  /// Returns 'discard', 'keep', or null (dismissed).
  Future<String?> _askNoMovement() {
    return showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('No movement recorded'),
        content: const Text(
          "We haven't detected any real movement yet, so there's nothing to "
          'save. Keep recording once you start moving, or discard this journey.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop('keep'),
            child: const Text('Keep recording'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(c).pop('discard'),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
  }

  /// Handles hardware-back / swipe-back while the screen is up, so exiting
  /// never silently drops a real trail or leaves an empty draft behind.
  Future<void> _onPopInvoked(bool didPop) async {
    if (didPop || _busy) return;
    if (!_recording) {
      // Still connecting or errored — bin any draft that was created.
      await _discardAndLeave();
      return;
    }
    if (_hasRealTrail) {
      final action = await showDialog<String>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Finish this journey?'),
          content: const Text('Save what you have recorded so far, or keep going.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(c).pop('keep'),
              child: const Text('Keep recording'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(c).pop('save'),
              child: const Text('Save & exit'),
            ),
          ],
        ),
      );
      if (action == 'save') await _saveAndLeave();
      return;
    }
    final action = await _askNoMovement();
    if (action == 'discard') await _discardAndLeave();
  }

  /// Drop a rich road-report tag (photo/audio/video) at the current position.
  void _dropTag() {
    final at = _live;
    if (at == null) {
      _snackWaiting();
      return;
    }
    showDropRoadTagSheet(context, position: at);
  }

  void _snackWaiting() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Waiting for your GPS position…')));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) => _onPopInvoked(didPop),
      child: !_recording
          ? _startingView()
          : Scaffold(
              backgroundColor: AppColors.canvas,
              appBar: AppBar(title: const Text('Recording…')),
              body: _recordingView(),
            ),
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
              travlaVectorTileLayer(),
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
          options: MapOptions(
            initialCenter: center,
            initialZoom: 13,
            // Rotation is enabled; panning pauses auto-follow until "locate".
            onPointerDown: (_, _) {
              if (_autoFollow) setState(() => _autoFollow = false);
            },
          ),
          children: [
            travlaVectorTileLayer(),
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    _liveStat((_distanceM / 1000).toStringAsFixed(2), 'km'),
                    _div(),
                    _liveStat(_hms(_elapsed), 'time'),
                    _div(),
                    _liveStat(
                      _speed != null ? '${_speed!.round()}' : '—',
                      'km/h',
                    ),
                  ],
                ),
                if (!_hasRealTrail) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.forest600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Waiting for movement…',
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        Positioned(
          right: 14,
          bottom: 88,
          child: FloatingActionButton.small(
            heroTag: 'record-locate',
            backgroundColor: AppColors.white,
            foregroundColor: _autoFollow ? AppColors.forest700 : AppColors.ink,
            onPressed: _recenter,
            child: const Icon(Icons.my_location_rounded),
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
                  onPressed: _dropTag,
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
