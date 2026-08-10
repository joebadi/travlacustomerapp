import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:travla_customer_app/app/theme/app_colors.dart';
import 'package:travla_customer_app/core/config/app_config.dart';
import 'package:travla_customer_app/core/network/api_failure.dart';
import 'package:travla_customer_app/features/tracking/data/tracking_task_handler.dart';
import 'package:travla_customer_app/features/vehicles/data/garage_repository.dart';
import 'package:travla_customer_app/features/vehicles/data/vehicle_tracking_repository.dart';
import 'package:travla_customer_app/features/vehicles/domain/garage_snapshot.dart';

/// Turns this phone into a GPS tracker for one of the user's vehicles. Streaming
/// runs inside a foreground service so it continues while the app is backgrounded
/// or the screen is off, and reports status back to this screen.
class PhoneTrackerScreen extends ConsumerStatefulWidget {
  const PhoneTrackerScreen({super.key});

  @override
  ConsumerState<PhoneTrackerScreen> createState() => _PhoneTrackerScreenState();
}

class _PhoneTrackerScreenState extends ConsumerState<PhoneTrackerScreen> {
  static const _storage = FlutterSecureStorage();
  static const _vehicleKey = 'tracker_vehicle_id';

  String? _vehicleId;
  bool _busy = false;
  bool _tracking = false;
  int _pointsSent = 0;
  double? _lastLat;
  double? _lastLng;
  double? _lastAccuracy;
  double? _lastSpeed;
  String? _error;
  String? _status;

  @override
  void initState() {
    super.initState();
    FlutterForegroundTask.addTaskDataCallback(_onData);
    // Reflect an already-running service (e.g. returning to this screen).
    FlutterForegroundTask.isRunningService.then((running) async {
      if (!running || !mounted) return;
      final vid = await FlutterForegroundTask.getData<String>(key: _vehicleKey);
      if (!mounted) return;
      setState(() {
        _tracking = true;
        _vehicleId ??= vid;
        _status = 'Tracking in progress.';
      });
    });
  }

  @override
  void dispose() {
    FlutterForegroundTask.removeTaskDataCallback(_onData);
    super.dispose();
  }

  void _onData(Object data) {
    if (data is! Map || !mounted) return;
    setState(() {
      _pointsSent = (data['sent'] as num?)?.toInt() ?? _pointsSent;
      _lastLat = (data['lat'] as num?)?.toDouble() ?? _lastLat;
      _lastLng = (data['lng'] as num?)?.toDouble() ?? _lastLng;
      _lastAccuracy = (data['accuracy'] as num?)?.toDouble() ?? _lastAccuracy;
      _lastSpeed = (data['speed'] as num?)?.toDouble() ?? _lastSpeed;
    });
  }

  String _keyName(String vehicleId) => 'phone_tracker_key_$vehicleId';

  Future<void> _start() async {
    final vehicleId = _vehicleId;
    if (vehicleId == null) {
      setState(() => _error = 'Choose which vehicle this phone is tracking.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _status = 'Checking location permission…';
    });

    try {
      if (!await _ensurePermission()) return;
      await FlutterForegroundTask.requestNotificationPermission();

      setState(() => _status = 'Preparing tracker…');
      final key = await _ensureKey(vehicleId);

      await FlutterForegroundTask.saveData(key: kTrackerApiKey, value: key);
      await FlutterForegroundTask.saveData(
        key: kTrackerIngestUrl,
        value: '${AppConfig.apiBaseUrl}/track/ingest',
      );
      await FlutterForegroundTask.saveData(key: _vehicleKey, value: vehicleId);

      FlutterForegroundTask.init(
        androidNotificationOptions: AndroidNotificationOptions(
          channelId: 'travla_tracking',
          channelName: 'Vehicle tracking',
          channelDescription: 'Shown while your phone is sharing its location.',
          channelImportance: NotificationChannelImportance.LOW,
          priority: NotificationPriority.LOW,
        ),
        iosNotificationOptions: const IOSNotificationOptions(),
        foregroundTaskOptions: ForegroundTaskOptions(
          eventAction: ForegroundTaskEventAction.repeat(15000),
          allowWakeLock: true,
          allowWifiLock: true,
        ),
      );

      final result = await FlutterForegroundTask.startService(
        serviceTypes: [ForegroundServiceTypes.location],
        notificationTitle: 'Travla tracking active',
        notificationText: 'Sharing this phone\'s location.',
        callback: trackerTaskCallback,
      );
      if (result is ServiceRequestFailure) {
        throw ApiFailure('Could not start the tracking service: ${result.error}');
      }

      setState(() {
        _tracking = true;
        _pointsSent = 0;
        _status = 'Tracking — you can minimise the app or lock the screen.';
      });
    } on ApiFailure catch (failure) {
      setState(() => _error = failure.message);
    } catch (e) {
      setState(() => _error = 'Could not start tracking: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _stop() async {
    await FlutterForegroundTask.stopService();
    if (mounted) {
      setState(() {
        _tracking = false;
        _status = 'Stopped.';
      });
    }
  }

  Future<bool> _ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      setState(() => _error = 'Turn on location (GPS) on your device, then try again.');
      return false;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      setState(() => _error = 'Location permission is required to share this phone\'s position.');
      return false;
    }
    return true;
  }

  /// Returns a usable ingest key for the vehicle's PHONE tracker — cached, else
  /// created (or the existing one re-keyed).
  Future<String> _ensureKey(String vehicleId) async {
    final cached = await _storage.read(key: _keyName(vehicleId));
    if (cached != null && cached.isNotEmpty) return cached;

    final trackingRepo = ref.read(vehicleTrackingRepositoryProvider);
    final workspace = await trackingRepo.load(vehicleId);
    final existing = workspace.sources.where((s) => s.type == 'PHONE').firstOrNull;

    final String key;
    if (existing != null) {
      key = await trackingRepo.regenerateKey(existing.id);
    } else {
      final created = await trackingRepo.create(
        vehicleId: vehicleId,
        type: 'PHONE',
        label: 'This phone',
        uniqueId: '',
      );
      key = created.apiKey ?? '';
    }
    if (key.isEmpty) {
      throw const ApiFailure('The tracker key could not be prepared.');
    }
    await _storage.write(key: _keyName(vehicleId), value: key);
    return key;
  }

  @override
  Widget build(BuildContext context) {
    final garage = ref.watch(garageProvider);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(title: const Text('Track with this phone')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.forest50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.forest100),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded, color: AppColors.forest700),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Your phone becomes a live GPS source for the chosen vehicle. Tracking keeps running in the background behind a notification.',
                    style: TextStyle(color: AppColors.forest800, fontSize: 12.5, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (_error != null) ...[
            _ErrorBanner(_error!),
            const SizedBox(height: 14),
          ],
          garage.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text(
              e is ApiFailure ? e.message : 'Vehicles could not be loaded.',
            ),
            data: (snapshot) => _VehiclePicker(
              vehicles: snapshot.vehicles,
              value: _vehicleId,
              enabled: !_tracking,
              onChanged: (v) => setState(() => _vehicleId = v),
            ),
          ),
          const SizedBox(height: 18),
          _StatusCard(
            tracking: _tracking,
            pointsSent: _pointsSent,
            lat: _lastLat,
            lng: _lastLng,
            accuracy: _lastAccuracy,
            speed: _lastSpeed,
            status: _status,
          ),
          const SizedBox(height: 20),
          if (!_tracking)
            FilledButton.icon(
              onPressed: _busy ? null : _start,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                backgroundColor: AppColors.orange,
              ),
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.play_arrow_rounded),
              label: Text(_busy ? 'Starting…' : 'Start tracking'),
            )
          else
            FilledButton.icon(
              onPressed: _stop,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                backgroundColor: AppColors.danger,
              ),
              icon: const Icon(Icons.stop_rounded),
              label: const Text('Stop tracking'),
            ),
        ],
      ),
    );
  }
}

class _VehiclePicker extends StatelessWidget {
  const _VehiclePicker({
    required this.vehicles,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final List<VehicleSummary> vehicles;
  final String? value;
  final bool enabled;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    if (vehicles.isEmpty) {
      return const Text(
        'Add a vehicle first to track it with your phone.',
        style: TextStyle(color: AppColors.muted),
      );
    }
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Vehicle this phone is in',
        prefixIcon: Icon(Icons.directions_car_outlined),
      ),
      items: vehicles
          .map(
            (v) => DropdownMenuItem(
              value: v.id,
              child: Text(
                v.plateNumber?.isNotEmpty == true
                    ? '${v.displayName} · ${v.plateNumber}'
                    : v.displayName,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      onChanged: enabled ? onChanged : null,
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.tracking,
    required this.pointsSent,
    required this.lat,
    required this.lng,
    required this.accuracy,
    required this.speed,
    required this.status,
  });

  final bool tracking;
  final int pointsSent;
  final double? lat;
  final double? lng;
  final double? accuracy;
  final double? speed;
  final String? status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
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
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: tracking ? AppColors.forest600 : AppColors.muted,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                tracking ? 'Live' : 'Idle',
                style: TextStyle(
                  color: tracking ? AppColors.forest700 : AppColors.muted,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              Text(
                '$pointsSent sent',
                style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700, fontSize: 12),
              ),
            ],
          ),
          if (status != null) ...[
            const SizedBox(height: 10),
            Text(status!, style: const TextStyle(color: AppColors.ink, fontSize: 12.5)),
          ],
          if (lat != null && lng != null) ...[
            const Divider(height: 22),
            _Line(label: 'Latitude', value: lat!.toStringAsFixed(5)),
            _Line(label: 'Longitude', value: lng!.toStringAsFixed(5)),
            if (speed != null && speed! >= 0)
              _Line(label: 'Speed', value: '${(speed! * 3.6).round()} km/h'),
            if (accuracy != null && accuracy! >= 0)
              _Line(label: 'Accuracy', value: '±${accuracy!.round()} m'),
          ],
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
          const Spacer(),
          Text(value, style: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.w700, fontSize: 12.5)),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE3E1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.danger),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: const TextStyle(color: AppColors.danger, fontSize: 12.5)),
          ),
        ],
      ),
    );
  }
}
