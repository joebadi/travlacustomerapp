import 'package:dio/dio.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';
import 'package:travla_customer_app/features/journeys/domain/journey_track_filter.dart';

/// Keys shared between the UI and the recording isolate.
const kJourneyPointsUrl = 'journey_points_url';
const kJourneyBearer = 'journey_bearer';
const kJourneyAppType = 'journey_app_type';

/// Entry point for the isolate that keeps recording GPS to the journey while
/// the app is backgrounded or the screen is locked, behind a persistent
/// foreground-service notification (like a maps app minimised).
@pragma('vm:entry-point')
void journeyRecordCallback() {
  FlutterForegroundTask.setTaskHandler(_JourneyRecordTaskHandler());
}

class _JourneyRecordTaskHandler extends TaskHandler {
  final Dio _dio = Dio();
  final JourneyTrackFilter _filter = JourneyTrackFilter();
  final List<Map<String, dynamic>> _pending = [];

  String? _url;
  String? _bearer;
  String? _appType;

  int _seq = 0;
  double _distanceM = 0;
  DateTime _lastFlush = DateTime.now();

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    _url = await FlutterForegroundTask.getData<String>(key: kJourneyPointsUrl);
    _bearer = await FlutterForegroundTask.getData<String>(key: kJourneyBearer);
    _appType = await FlutterForegroundTask.getData<String>(key: kJourneyAppType);
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    _tick(); // fire-and-forget; onRepeatEvent is synchronous
  }

  Future<void> _tick() async {
    Position pos;
    try {
      pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
        ),
      );
    } catch (_) {
      return;
    }

    final sample = _filter.add(pos);
    if (sample.decision == TrackDecision.rejected) return;

    if (sample.decision == TrackDecision.moved) {
      _distanceM += sample.movedMeters;
      _pending.add({
        'latitude': sample.point.latitude,
        'longitude': sample.point.longitude,
        'sequence': _seq++,
        if (pos.speed >= 0) 'speed': pos.speed,
        if (pos.heading >= 0) 'heading': pos.heading,
        if (pos.accuracy >= 0) 'accuracy': pos.accuracy,
        'recorded_at': pos.timestamp.toUtc().toIso8601String(),
      });
    }

    FlutterForegroundTask.sendDataToMain({
      'decision': sample.decision.name, // moved | holding
      'lat': sample.point.latitude,
      'lng': sample.point.longitude,
      'distance_m': _distanceM,
      'speed_kmh': sample.speedKmh,
    });

    FlutterForegroundTask.updateService(
      notificationTitle: 'Recording journey',
      notificationText: '${(_distanceM / 1000).toStringAsFixed(2)} km',
    );

    // Flush on batch size or every ~10 s so the isolate can never lose more
    // than a few seconds of trail if it's killed.
    final due = DateTime.now().difference(_lastFlush).inSeconds >= 10;
    if (_pending.length >= 5 || (due && _pending.isNotEmpty)) {
      await _flush();
    }
  }

  Future<void> _flush() async {
    final url = _url;
    if (url == null || _pending.isEmpty) return;
    final batch = List<Map<String, dynamic>>.from(_pending);
    _pending.clear();
    _lastFlush = DateTime.now();
    try {
      await _dio.post<dynamic>(
        url,
        data: {'points': batch},
        options: Options(headers: {
          'Accept': 'application/json',
          if (_bearer != null && _bearer!.isNotEmpty) 'Authorization': 'Bearer $_bearer',
          if (_appType != null && _appType!.isNotEmpty) 'X-App-Type': _appType,
        }),
      );
    } catch (_) {
      // Re-queue so the next flush retries (idempotent on (journey, sequence)).
      _pending.insertAll(0, batch);
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    await _flush(); // best-effort final flush on stop
  }
}
