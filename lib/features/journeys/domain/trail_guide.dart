import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

/// Where the driver is relative to a saved trail.
class TrailGuidance {
  const TrailGuidance({
    required this.distanceToTrailM,
    required this.nearestIndex,
    required this.distanceToEndM,
  });

  /// Shortest distance (metres) from the current position to the trail line.
  final double distanceToTrailM;

  /// Index of the nearest trail vertex (rough progress along the route).
  final int nearestIndex;

  /// Straight-line distance (metres) from the current position to the trail's
  /// final point — used to announce arrival.
  final double distanceToEndM;
}

/// Guides a follower along a saved trail. Direction-agnostic: it measures
/// distance to the trail *line*, so following the route in reverse works too.
///
/// Distances use a local equirectangular projection re-centred on the query
/// point each call — accurate to well under a metre at the scale of a road,
/// with no external routing needed.
class TrailGuide {
  TrailGuide(this.trail)
    : assert(trail.length >= 2, 'a followable trail needs >= 2 points');

  final List<LatLng> trail;

  static const double _mPerLat = 111320;

  TrailGuidance locate(LatLng p) {
    final cosLat = math.cos(p.latitude * math.pi / 180);
    final mPerLng = _mPerLat * cosLat;

    // Project a lat/lng to local metres relative to p (p → origin).
    ({double x, double y}) xy(LatLng q) => (
      x: (q.longitude - p.longitude) * mPerLng,
      y: (q.latitude - p.latitude) * _mPerLat,
    );

    var best = double.infinity;
    var bestIdx = 0;
    for (var i = 0; i < trail.length - 1; i++) {
      final a = xy(trail[i]);
      final b = xy(trail[i + 1]);
      final d = _pointSegmentDist(a, b);
      if (d < best) {
        best = d;
        // Attribute progress to whichever endpoint of the nearest segment is
        // closer to the driver.
        final da = _hypot(a.x, a.y);
        final db = _hypot(b.x, b.y);
        bestIdx = da <= db ? i : i + 1;
      }
    }

    final end = xy(trail.last);
    return TrailGuidance(
      distanceToTrailM: best,
      nearestIndex: bestIdx,
      distanceToEndM: _hypot(end.x, end.y),
    );
  }

  /// Distance from the origin (0,0) to segment a–b, in the local metre plane.
  static double _pointSegmentDist(
    ({double x, double y}) a,
    ({double x, double y}) b,
  ) {
    final dx = b.x - a.x;
    final dy = b.y - a.y;
    final len2 = dx * dx + dy * dy;
    if (len2 == 0) return _hypot(a.x, a.y); // degenerate segment
    // Project origin onto the segment, clamped to [0,1].
    var t = -(a.x * dx + a.y * dy) / len2;
    t = t.clamp(0.0, 1.0);
    final cx = a.x + t * dx;
    final cy = a.y + t * dy;
    return _hypot(cx, cy);
  }

  static double _hypot(double x, double y) => math.sqrt(x * x + y * y);
}
