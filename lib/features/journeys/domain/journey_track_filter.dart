import 'dart:math' as math;

import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// What the filter decided about a single incoming GPS fix.
enum TrackDecision {
  /// Unusable fix (accuracy too poor, or a physically impossible jump).
  /// Ignore it completely — don't even move the live marker.
  rejected,

  /// The phone is (still) parked. Keep the live marker on the stable anchor,
  /// but do **not** grow the trail or add to the distance. This is what stops
  /// stationary jitter from being recorded as fake movement.
  holding,

  /// Genuine movement. Append [TrackSample.point] to the trail and add
  /// [TrackSample.movedMeters] to the total distance.
  moved,
}

/// The outcome of feeding one [Position] to a [JourneyTrackFilter].
class TrackSample {
  const TrackSample({
    required this.decision,
    required this.point,
    required this.movedMeters,
    required this.speedKmh,
  });

  final TrackDecision decision;

  /// The best position to *display* right now (the stable anchor while
  /// holding, or the accepted fix while moving).
  final LatLng point;

  /// Metres to add to the journey distance (0 unless [decision] is
  /// [TrackDecision.moved]).
  final double movedMeters;

  /// Filtered speed for the HUD in km/h — `0` while confidently parked,
  /// `null` when the device reports no usable speed.
  final double? speedKmh;
}

/// Turns a noisy GPS stream into a clean, movement-only track.
///
/// The problem it solves: even while a phone sits still, the OS keeps emitting
/// fixes that wander several metres (GPS multipath near buildings, fused-sensor
/// noise). Naively appending them draws a zig-zag and inflates the distance.
///
/// How it stays still when you're still:
///  1. **Stable anchor.** We hold an anchor at the phone's believed resting
///     spot and, while parked, gently re-centre it on the *running mean* of the
///     fixes. A single wild fix can no longer hijack the anchor (the bug in the
///     old "last accepted point" approach), so noise never accumulates.
///  2. **Doppler-speed veto.** When the device reports a tight `speedAccuracy`
///     and the speed is confidently below a walking pace, the fix is treated as
///     stationary *no matter how far the reported position jumped* — killing
///     multipath spikes outright. Doppler speed is far more reliable than
///     differencing positions.
///  3. **Uncertainty-aware gate.** To count as movement, a fix must clear
///     `moveFactor × accuracy` (not just `1 × accuracy`) from the anchor, with a
///     hard floor, so lone spikes rarely escape even on devices that don't
///     report speed.
///  4. **Teleport guard.** Fixes implying an impossible speed are dropped.
///
/// Because the anchor stays put while parked, genuine slow movement still gets
/// recorded: the displacement from the fixed anchor keeps growing fix after fix
/// until it clears the gate, so you get a (coarser) point instead of nothing.
class JourneyTrackFilter {
  JourneyTrackFilter({
    this.maxAccuracyM = 30,
    this.minMoveM = 12,
    this.moveFactor = 2.0,
    this.speedFloorMps = 0.8,
    this.maxSpeedMps = 70,
    this.speedAccuracyCapMps = 2.5,
    this.recenterAlpha = 0.2,
  });

  /// Drop fixes worse than this many metres of accuracy — the biggest single
  /// source of drift.
  final double maxAccuracyM;

  /// Absolute displacement floor: never treat sub-[minMoveM] steps as movement.
  final double minMoveM;

  /// A fix must clear `moveFactor × accuracy` from the anchor to count as
  /// movement (so it must escape its own uncertainty circle, not just touch it).
  final double moveFactor;

  /// Speeds below this (m/s) are treated as "not moving" (~2.9 km/h).
  final double speedFloorMps;

  /// Teleport guard — reject implied speeds above this (m/s, ~252 km/h).
  final double maxSpeedMps;

  /// Only trust the Doppler speed when `speedAccuracy` is at least this tight.
  final double speedAccuracyCapMps;

  /// EMA weight for re-centring the anchor on the running mean while parked.
  final double recenterAlpha;

  static const Distance _distance = Distance();

  LatLng? _anchor;
  double _anchorAccuracy = double.infinity;
  DateTime? _anchorTime;

  /// True once a first usable fix has seeded the anchor.
  bool get hasFix => _anchor != null;

  /// The current stable position, or null before the first usable fix.
  LatLng? get anchor => _anchor;

  TrackSample add(Position p) {
    final acc = p.accuracy;
    final raw = LatLng(p.latitude, p.longitude);

    // 1) Hard quality gate. Unknown (<= 0) or hopeless accuracy is pure noise.
    if (acc <= 0 || acc > maxAccuracyM) {
      return TrackSample(
        decision: TrackDecision.rejected,
        point: _anchor ?? raw,
        movedMeters: 0,
        speedKmh: null,
      );
    }

    final now = p.timestamp;

    // 2) Seed on the first good fix — the journey's start point.
    if (_anchor == null) {
      _anchor = raw;
      _anchorAccuracy = acc;
      _anchorTime = now;
      return TrackSample(
        decision: TrackDecision.moved,
        point: raw,
        movedMeters: 0,
        speedKmh: _speedKmh(p),
      );
    }

    final moved = _distance.as(LengthUnit.Meter, _anchor!, raw);
    final gate = math.max(minMoveM, moveFactor * math.max(_anchorAccuracy, acc));

    // 3) Doppler-speed signal — only trusted when reported tightly.
    final hasSpeed =
        p.speed >= 0 && p.speedAccuracy > 0 && p.speedAccuracy <= speedAccuracyCapMps;
    final speedStationary = hasSpeed && (p.speed + p.speedAccuracy) < speedFloorMps;
    final speedMoving = hasSpeed && (p.speed - p.speedAccuracy) > speedFloorMps;

    final movedFar = moved > gate;

    final bool isMovement;
    if (speedStationary) {
      // Doppler says parked — veto positional spikes outright.
      isMovement = false;
    } else if (movedFar) {
      isMovement = true;
    } else if (speedMoving && moved > minMoveM * 0.5) {
      // Clearly moving (Doppler) but a small step — e.g. a slow walk.
      isMovement = true;
    } else {
      isMovement = false;
    }

    if (!isMovement) {
      // Parked: re-centre the anchor on the running mean (snap to a strictly
      // better fix), but never grow the trail.
      if (acc < _anchorAccuracy) {
        _anchor = raw;
        _anchorAccuracy = acc;
      } else {
        _anchor = LatLng(
          _anchor!.latitude + (raw.latitude - _anchor!.latitude) * recenterAlpha,
          _anchor!.longitude + (raw.longitude - _anchor!.longitude) * recenterAlpha,
        );
        _anchorAccuracy =
            _anchorAccuracy + (acc - _anchorAccuracy) * recenterAlpha;
      }
      _anchorTime = now;
      return TrackSample(
        decision: TrackDecision.holding,
        point: _anchor!,
        movedMeters: 0,
        speedKmh: hasSpeed ? _speedKmh(p) : 0,
      );
    }

    // 4) Teleport guard.
    final dt = _anchorTime == null
        ? 0.0
        : now.difference(_anchorTime!).inMilliseconds / 1000.0;
    if (dt > 0 && moved / dt > maxSpeedMps) {
      return TrackSample(
        decision: TrackDecision.rejected,
        point: _anchor!,
        movedMeters: 0,
        speedKmh: null,
      );
    }

    _anchor = raw;
    _anchorAccuracy = acc;
    _anchorTime = now;
    return TrackSample(
      decision: TrackDecision.moved,
      point: raw,
      movedMeters: moved,
      speedKmh: _speedKmh(p),
    );
  }

  double? _speedKmh(Position p) => p.speed >= 0 ? p.speed * 3.6 : null;
}
