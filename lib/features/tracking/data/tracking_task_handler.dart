import 'package:dio/dio.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';

/// Keys shared between the UI and the background isolate via FlutterForegroundTask.
const kTrackerApiKey = 'tracker_api_key';
const kTrackerIngestUrl = 'tracker_ingest_url';

/// Entry point for the background isolate that keeps streaming GPS to the ingest
/// endpoint while the app is backgrounded, behind a persistent foreground-service
/// notification.
@pragma('vm:entry-point')
void trackerTaskCallback() {
  FlutterForegroundTask.setTaskHandler(_TrackerTaskHandler());
}

class _TrackerTaskHandler extends TaskHandler {
  final Dio _dio = Dio();
  String? _apiKey;
  String? _ingestUrl;
  int _sent = 0;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    _apiKey = await FlutterForegroundTask.getData<String>(key: kTrackerApiKey);
    _ingestUrl = await FlutterForegroundTask.getData<String>(key: kTrackerIngestUrl);
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // onRepeatEvent is synchronous; fire the async report and let it settle.
    _report();
  }

  Future<void> _report() async {
    final key = _apiKey;
    final url = _ingestUrl;
    if (key == null || url == null) return;

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      await _dio.post<dynamic>(
        url,
        data: {
          'latitude': position.latitude,
          'longitude': position.longitude,
          if (position.speed >= 0) 'speed': position.speed * 3.6,
          if (position.heading >= 0) 'heading': position.heading,
          if (position.accuracy >= 0) 'accuracy': position.accuracy,
          'recorded_at': DateTime.now().toUtc().toIso8601String(),
        },
        options: Options(headers: {'x-api-key': key}),
      );

      _sent++;
      FlutterForegroundTask.updateService(
        notificationTitle: 'Travla tracking active',
        notificationText: '$_sent locations shared',
      );
      FlutterForegroundTask.sendDataToMain({
        'sent': _sent,
        'lat': position.latitude,
        'lng': position.longitude,
        'accuracy': position.accuracy,
        'speed': position.speed,
      });
    } catch (_) {
      // Keep the service alive — a transient failure is retried next tick.
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}
}
