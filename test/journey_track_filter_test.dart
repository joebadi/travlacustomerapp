import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:travla_customer_app/features/journeys/domain/journey_track_filter.dart';

/// A Lagos-ish base point for the synthetic fixes.
const _base = LatLng(6.5244, 3.3792);
const _geo = Distance();

Position _fix(
  LatLng at, {
  double accuracy = 6,
  double speed = 0,
  double speedAccuracy = 0.5,
  required DateTime t,
}) {
  return Position(
    latitude: at.latitude,
    longitude: at.longitude,
    timestamp: t,
    accuracy: accuracy,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: speed,
    speedAccuracy: speedAccuracy,
  );
}

void main() {
  group('JourneyTrackFilter', () {
    test('seeds the first good fix as a movement (journey start)', () {
      final f = JourneyTrackFilter();
      final s = f.add(_fix(_base, t: DateTime(2026, 1, 1, 8)));
      expect(s.decision, TrackDecision.moved);
      expect(s.movedMeters, 0);
      expect(f.hasFix, isTrue);
    });

    test('drops hopeless-accuracy fixes', () {
      final f = JourneyTrackFilter();
      final s = f.add(_fix(_base, accuracy: 55, t: DateTime(2026, 1, 1, 8)));
      expect(s.decision, TrackDecision.rejected);
      expect(f.hasFix, isFalse);
    });

    test(
      'stationary jitter records nothing — Doppler veto even on big spikes',
      () {
        final f = JourneyTrackFilter();
        var t = DateTime(2026, 1, 1, 8);
        f.add(_fix(_base, t: t)); // seed

        var moves = 0;
        var distance = 0.0;
        // 60 parked fixes that wander up to ~14 m (beyond the distance gate),
        // but the device reports a confident near-zero speed.
        const bearings = [0.0, 90, 180, 270, 45, 135, 225, 315];
        for (var i = 0; i < 60; i++) {
          t = t.add(const Duration(seconds: 1));
          final jittered = _geo.offset(_base, 14.0, bearings[i % bearings.length]);
          final s = f.add(
            _fix(jittered, accuracy: 6, speed: 0, speedAccuracy: 0.5, t: t),
          );
          if (s.decision == TrackDecision.moved) moves++;
          distance += s.movedMeters;
        }

        expect(moves, 0, reason: 'no jitter fix should count as movement');
        expect(distance, 0);
      },
    );

    test(
      'stationary jitter records nothing without usable speed — distance gate',
      () {
        final f = JourneyTrackFilter();
        var t = DateTime(2026, 1, 1, 8);
        f.add(_fix(_base, t: t)); // seed

        var moves = 0;
        // Jitter stays under the ~12 m gate; speed is reported too loosely to
        // trust, so the distance gate alone must hold the line.
        const bearings = [0.0, 90, 180, 270, 30, 150, 210, 330];
        for (var i = 0; i < 60; i++) {
          t = t.add(const Duration(seconds: 1));
          final jittered = _geo.offset(_base, 7.0, bearings[i % bearings.length]);
          final s = f.add(
            _fix(jittered, accuracy: 6, speed: 0, speedAccuracy: 9, t: t),
          );
          if (s.decision == TrackDecision.moved) moves++;
        }

        expect(moves, 0);
      },
    );

    test('genuine straight-line travel records and accumulates distance', () {
      final f = JourneyTrackFilter();
      var t = DateTime(2026, 1, 1, 8);
      f.add(_fix(_base, speed: 15, speedAccuracy: 1, t: t)); // seed, moving

      var moves = 0;
      var distance = 0.0;
      var here = _base;
      // Drive due east ~15 m/s: a fix every second, each 15 m further on.
      for (var i = 0; i < 20; i++) {
        t = t.add(const Duration(seconds: 1));
        here = _geo.offset(here, 15.0, 90); // 90° = east
        final s = f.add(
          _fix(here, accuracy: 5, speed: 15, speedAccuracy: 1, t: t),
        );
        if (s.decision == TrackDecision.moved) moves++;
        distance += s.movedMeters;
      }

      expect(moves, 20, reason: 'every real step should record');
      expect(distance, closeTo(300, 15)); // 20 × 15 m ≈ 300 m
    });

    test('rejects physically impossible teleports', () {
      final f = JourneyTrackFilter();
      var t = DateTime(2026, 1, 1, 8);
      f.add(_fix(_base, t: t)); // seed

      t = t.add(const Duration(seconds: 1));
      // 5 km away one second later, with speed reported too loosely to veto —
      // so it reaches the teleport guard, which must reject it.
      final far = _geo.offset(_base, 5000, 90);
      final s = f.add(_fix(far, accuracy: 6, speed: 0, speedAccuracy: 9, t: t));
      expect(s.decision, TrackDecision.rejected);
    });
  });
}
