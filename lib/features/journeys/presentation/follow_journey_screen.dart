import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:travla_customer_app/app/theme/app_colors.dart';
import 'package:travla_customer_app/core/network/api_failure.dart';
import 'package:travla_customer_app/features/journeys/data/journey_repository.dart';
import 'package:travla_customer_app/features/journeys/domain/journey_models.dart';
import 'package:travla_customer_app/features/journeys/domain/trail_guide.dart';
import 'package:travla_customer_app/features/journeys/presentation/drop_road_tag_sheet.dart';
import 'package:travla_customer_app/features/journeys/presentation/road_tag_sheet.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Follow a saved trail: shows the route + the driver's live position, and
/// warns (voice + vibration) when they drift off the trail, with a softer cue
/// when they rejoin. Direction-agnostic, so following in reverse works too.
class FollowJourneyScreen extends ConsumerStatefulWidget {
  const FollowJourneyScreen({super.key, required this.journeyId});

  final String journeyId;

  @override
  ConsumerState<FollowJourneyScreen> createState() =>
      _FollowJourneyScreenState();
}

class _FollowJourneyScreenState extends ConsumerState<FollowJourneyScreen> {
  // Saved-trail purple (distinct from the orange record trail).
  static const Color _trailColor = Color(0xFF7C4DFF);
  static const Color _meColor = Color(0xFF2F6BFF);

  // Off-route trigger with hysteresis so it doesn't chatter at the boundary.
  static const double _offRouteM = 50;
  static const double _backOnM = 30;
  static const double _arriveM = 40;
  static const double _maxAccuracyM = 60; // ignore very noisy fixes

  // Road-report proximity.
  static const double _corridorM = 60; // keep only reports on the route corridor
  static const double _approachM = 300; // alert this far ahead of a report
  static const Distance _geo = Distance();

  final _map = MapController();
  final _tts = FlutterTts();

  StreamSubscription<Position>? _sub;
  TrailGuide? _guide;
  List<LatLng> _trail = const [];

  List<NearbyRoadReport> _reports = const [];
  final Set<String> _alertedReports = {};

  LatLng? _me;
  double? _distToTrail;
  bool _offRoute = false;
  bool _arrived = false;
  bool _autoFollow = true;

  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _configureTts();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  @override
  void dispose() {
    _sub?.cancel();
    _tts.stop();
    WakelockPlus.disable();
    super.dispose();
  }

  Future<void> _configureTts() async {
    try {
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.48);
      await _tts.setVolume(1);
    } catch (_) {
      // TTS just won't speak; haptics + on-screen banner still work.
    }
  }

  Future<void> _init() async {
    try {
      final journey = await ref.read(
        journeyProvider(widget.journeyId).future,
      );
      final trail = journey.displayTrail
          .map((p) => LatLng(p.lat, p.lng))
          .toList(growable: false);
      if (trail.length < 2) {
        setState(() {
          _loading = false;
          _error = 'This journey has no trail to follow.';
        });
        return;
      }
      if (!await _ensurePermission()) return;
      _trail = trail;
      _guide = TrailGuide(trail);
      unawaited(_loadReports()); // best-effort; following doesn't wait on it
      _sub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 0,
        ),
      ).listen(_onPosition);
      setState(() => _loading = false);
    } on ApiFailure catch (f) {
      setState(() {
        _loading = false;
        _error = f.message;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Could not start following: $e';
      });
    }
  }

  /// Pre-sync ACTIVE road reports around the route, keeping only those that sit
  /// on the route corridor (so a pothole on a parallel street doesn't alert).
  Future<void> _loadReports() async {
    final trail = _trail;
    final guide = _guide;
    if (trail.length < 2 || guide == null) return;

    var minLat = trail.first.latitude, maxLat = trail.first.latitude;
    var minLng = trail.first.longitude, maxLng = trail.first.longitude;
    for (final p in trail) {
      minLat = math.min(minLat, p.latitude);
      maxLat = math.max(maxLat, p.latitude);
      minLng = math.min(minLng, p.longitude);
      maxLng = math.max(maxLng, p.longitude);
    }
    final center = LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2);
    var reach = 0.0;
    for (final p in trail) {
      reach = math.max(reach, _geo.as(LengthUnit.Meter, center, p));
    }
    final radiusKm = ((reach + 500) / 1000).clamp(1.0, 25.0);

    try {
      final all = await ref
          .read(journeyRepositoryProvider)
          .nearbyReports(
            lat: center.latitude,
            lng: center.longitude,
            radius: radiusKm,
          );
      final onCorridor = all
          .where(
            (r) =>
                guide
                    .locate(LatLng(r.latitude, r.longitude))
                    .distanceToTrailM <=
                _corridorM,
          )
          .toList(growable: false);
      if (mounted) setState(() => _reports = onCorridor);
    } catch (_) {
      // Advisory layer only — following still works without it.
    }
  }

  Future<bool> _ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      setState(() {
        _loading = false;
        _error = 'Turn on location (GPS), then try again.';
      });
      return false;
    }
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
    if (p == LocationPermission.denied ||
        p == LocationPermission.deniedForever) {
      setState(() {
        _loading = false;
        _error = 'Location permission is required to follow a journey.';
      });
      return false;
    }
    return true;
  }

  void _onPosition(Position pos) {
    if (pos.accuracy > 0 && pos.accuracy > _maxAccuracyM) return;
    final guide = _guide;
    if (guide == null) return;

    final me = LatLng(pos.latitude, pos.longitude);
    final g = guide.locate(me);

    // Arrival — announce once when close to the trail's end.
    if (!_arrived && g.distanceToEndM < _arriveM) {
      _arrived = true;
      _announce("You've arrived at the end of the journey.");
      HapticFeedback.mediumImpact();
    }

    // Off-route state machine with hysteresis.
    if (!_offRoute && g.distanceToTrailM > _offRouteM) {
      _offRoute = true;
      _announce('You are off the trail. Turn back to rejoin the route.');
      HapticFeedback.heavyImpact();
    } else if (_offRoute && g.distanceToTrailM < _backOnM) {
      _offRoute = false;
      _announce('Back on the trail.');
      HapticFeedback.lightImpact();
    }

    _checkRoadReports(me);

    setState(() {
      _me = me;
      _distToTrail = g.distanceToTrailM;
    });
    if (_autoFollow) {
      _map.move(me, _map.camera.zoom < 14 ? 16.5 : _map.camera.zoom);
    }
  }

  /// Audio + haptic when approaching an ACTIVE non-directional report. Each
  /// report alerts once per session. Directional restrictions are advisory
  /// markers only (no auto wrong-way alert in v1).
  void _checkRoadReports(LatLng me) {
    for (final r in _reports) {
      if (r.isDirectional || _alertedReports.contains(r.id)) continue;
      final d = _geo.as(LengthUnit.Meter, me, LatLng(r.latitude, r.longitude));
      if (d <= _approachM) {
        _alertedReports.add(r.id);
        final approx = ((d / 50).round() * 50).clamp(50, _approachM.toInt());
        _announce('${r.typeLabel} in about $approx metres ahead.');
        HapticFeedback.mediumImpact();
        if (mounted) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(
              duration: const Duration(seconds: 6),
              content: Text('${r.typeLabel} in ~$approx m ahead'),
              action: SnackBarAction(
                label: 'View',
                onPressed: () =>
                    showRoadTagSheet(context, report: r, onVoted: _loadReports),
              ),
            ));
        }
      }
    }
  }

  Future<void> _announce(String text) async {
    try {
      await _tts.stop();
      await _tts.speak(text);
    } catch (_) {
      // Non-fatal — the banner + haptic already conveyed it.
    }
  }

  void _recenter() {
    final me = _me;
    if (me == null) return;
    setState(() => _autoFollow = true);
    _map.move(me, 16.5);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(title: const Text('Following journey')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _errorView(_error!)
          : _followView(),
    );
  }

  Widget _errorView(String message) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wrong_location_rounded,
              color: AppColors.orange, size: 34),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted)),
          const SizedBox(height: 16),
          FilledButton(onPressed: () => context.pop(), child: const Text('Back')),
        ],
      ),
    ),
  );

  Widget _followView() {
    return Stack(
      children: [
        FlutterMap(
          mapController: _map,
          options: MapOptions(
            initialCameraFit: CameraFit.coordinates(
              coordinates: _trail,
              padding: const EdgeInsets.all(60),
            ),
            // Rotation is allowed — some drivers prefer turning the map.
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all,
            ),
            // Any manual gesture pauses auto-follow until "recenter".
            onPointerDown: (_, _) {
              if (_autoFollow) setState(() => _autoFollow = false);
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'ng.com.travla.customer',
            ),
            PolylineLayer(
              polylines: [
                Polyline(points: _trail, strokeWidth: 6, color: _trailColor),
              ],
            ),
            if (_reports.isNotEmpty)
              MarkerLayer(markers: [for (final r in _reports) _reportMarker(r)]),
            MarkerLayer(
              markers: [
                _pin(_trail.first, AppColors.forest700),
                _pin(_trail.last, AppColors.danger),
                if (_me != null)
                  Marker(
                    point: _me!,
                    width: 26,
                    height: 26,
                    child: Container(
                      decoration: BoxDecoration(
                        color: _offRoute ? AppColors.danger : _meColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3.5),
                        boxShadow: const [
                          BoxShadow(color: Color(0x55000000), blurRadius: 8),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
        Positioned(top: 12, left: 12, right: 12, child: _statusBanner()),
        if (_me != null)
          Positioned(
            right: 14,
            bottom: 204,
            child: FloatingActionButton.small(
              heroTag: 'drop-tag',
              backgroundColor: AppColors.orange,
              foregroundColor: Colors.white,
              onPressed: () => showDropRoadTagSheet(
                context,
                position: _me!,
                onDone: _loadReports,
              ),
              child: const Icon(Icons.add_location_alt_outlined),
            ),
          ),
        Positioned(
          right: 14,
          bottom: 150,
          child: FloatingActionButton.small(
            heroTag: 'reset-north',
            backgroundColor: AppColors.white,
            foregroundColor: AppColors.ink,
            onPressed: () => _map.rotate(0),
            child: const Icon(Icons.explore_outlined),
          ),
        ),
        Positioned(
          right: 14,
          bottom: 96,
          child: FloatingActionButton.small(
            heroTag: 'recenter',
            backgroundColor: AppColors.white,
            foregroundColor: _autoFollow ? _meColor : AppColors.ink,
            onPressed: _recenter,
            child: const Icon(Icons.my_location_rounded),
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 20,
          child: FilledButton.icon(
            onPressed: () => context.pop(),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              backgroundColor: AppColors.danger,
            ),
            icon: const Icon(Icons.stop_rounded),
            label: const Text('Stop following'),
          ),
        ),
      ],
    );
  }

  Widget _statusBanner() {
    final onRoute = !_offRoute;
    final color = _arrived
        ? AppColors.forest700
        : onRoute
        ? AppColors.forest700
        : AppColors.danger;
    final icon = _arrived
        ? Icons.flag_rounded
        : onRoute
        ? Icons.check_circle_rounded
        : Icons.warning_amber_rounded;
    final text = _arrived
        ? 'You have arrived'
        : _distToTrail == null
        ? 'Locating you…'
        : onRoute
        ? 'On route'
        : 'Off route by ${_distToTrail!.round()} m — turn back to rejoin';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: .5), width: 1.4),
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
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: color,
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Marker _reportMarker(NearbyRoadReport r) {
    // Directional restrictions are advisory (grey-blue); conditions/hazards
    // are amber — the ones that also trigger an approach alert.
    final color = r.isDirectional ? const Color(0xFF6B7A99) : AppColors.orange;
    return Marker(
      point: LatLng(r.latitude, r.longitude),
      width: 30,
      height: 30,
      child: GestureDetector(
        onTap: () => showRoadTagSheet(context, report: r, onVoted: _loadReports),
        child: Container(
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: const [BoxShadow(color: Color(0x44000000), blurRadius: 5)],
          ),
          child: Icon(
            r.isDirectional
                ? Icons.do_not_disturb_on_outlined
                : Icons.warning_amber_rounded,
            color: Colors.white,
            size: 16,
          ),
        ),
      ),
    );
  }

  Marker _pin(LatLng at, Color color) => Marker(
    point: at,
    width: 18,
    height: 18,
    child: Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
      ),
    ),
  );
}
