import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:travla_customer_app/features/journeys/domain/trail_guide.dart';

const _geo = Distance();

void main() {
  group('TrailGuide', () {
    // A ~straight trail heading east across Lagos Island, points ~40 m apart.
    final trail = <LatLng>[
      for (var i = 0; i < 10; i++) _geo.offset(const LatLng(6.4531, 3.3915), i * 40.0, 90),
    ];
    final guide = TrailGuide(trail);

    test('a point on the trail reads ~0 m off', () {
      final g = guide.locate(trail[4]);
      expect(g.distanceToTrailM, lessThan(1));
    });

    test('a point beside the trail reads its perpendicular offset', () {
      // 60 m north (bearing 0) of a mid-trail point.
      final off = _geo.offset(trail[5], 60, 0);
      final g = guide.locate(off);
      expect(g.distanceToTrailM, closeTo(60, 6));
    });

    test('distance-to-end shrinks as you move along the trail', () {
      final atStart = guide.locate(trail.first).distanceToEndM;
      final nearEnd = guide.locate(trail[8]).distanceToEndM;
      expect(nearEnd, lessThan(atStart));
      expect(nearEnd, closeTo(40, 8)); // one 40 m segment from the end
    });

    test('nearest index tracks progress along the trail', () {
      expect(guide.locate(trail.first).nearestIndex, 0);
      final mid = guide.locate(trail[5]).nearestIndex;
      expect(mid, inInclusiveRange(4, 6));
      expect(guide.locate(trail.last).nearestIndex, trail.length - 1);
    });

    test('off-trail beyond a 50 m gate is detected', () {
      final off = _geo.offset(trail[3], 80, 0); // 80 m off
      expect(guide.locate(off).distanceToTrailM, greaterThan(50));
    });
  });
}
