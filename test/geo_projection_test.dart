import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:rushhour/core/game_config.dart';
import 'package:rushhour/core/geo_projection.dart';
import 'package:rushhour/game/road_graph.dart';
import 'package:rushhour/models/city.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const bounds = GeoBounds(minLat: 51.49, maxLat: 51.53, minLng: -0.13, maxLng: -0.09);
  final projection = GeoProjection.fromBounds(bounds, GameConfig.worldSize);

  test('projection matches the required equidistant formula', () {
    final cosLat0 = math.cos(projection.lat0 * math.pi / 180);
    const lat = 51.515;
    const lng = -0.101;
    final p = projection.project(lat, lng);
    expect(
      p.dx - projection.origin.dx,
      closeTo((lng - projection.lng0) * cosLat0 * projection.scale, 1e-9),
    );
    expect(
      p.dy - projection.origin.dy,
      closeTo((projection.lat0 - lat) * projection.scale, 1e-9),
    );
  });

  test('both axes share one uniform scale (no angle distortion)', () {
    // A 45 degree geographic bearing must stay 45 degrees on screen.
    final cosLat0 = math.cos(projection.lat0 * math.pi / 180);
    final a = projection.project(51.50, -0.12);
    final b = projection.project(51.50 + 0.01, -0.12 + 0.01 / cosLat0);
    final delta = b - a;
    expect(delta.dx, closeTo(-delta.dy, 1e-6));
  });

  test('unproject is the exact inverse of project', () {
    final geo = projection.unproject(projection.project(51.5231, -0.0977));
    expect(geo.lat, closeTo(51.5231, 1e-9));
    expect(geo.lng, closeTo(-0.0977, 1e-9));
  });

  test('projected bounds stay inside the world rect', () {
    final rect = projection.projectSpan(bounds);
    expect(rect.left, greaterThanOrEqualTo(-0.001));
    expect(rect.top, greaterThanOrEqualTo(-0.001));
    expect(rect.right, lessThanOrEqualTo(GameConfig.worldSize.width + 0.001));
    expect(rect.bottom, lessThanOrEqualTo(GameConfig.worldSize.height + 0.001));
  });

  group('real city data', () {
    late CityData city;

    setUpAll(() async {
      city = await CityData.load('rivergate');
    });

    test('rendered node geometry equals the shared projection output', () {
      for (final node in city.nodes.values) {
        final expected = city.projection.project(node.lat, node.lng);
        expect((node.point - expected).distance, lessThan(1e-9),
            reason: 'node ${node.id} is drawn away from its projected position');
      }
    });

    test('snapping sees exactly the drawn road geometry', () {
      final graph = RoadGraph(city);
      for (final edge in city.edges.take(200)) {
        for (final point in edge.points) {
          // The finger is placed exactly on the drawn geometry: the snap must
          // land on it with (near) zero distance. This test is about the
          // projection, not about water, so the Requirement 46 bridge filter
          // (which deliberately skips river-crossing streets) is disabled.
          expect(graph.nearestGraphPoint(point, respectBridges: false).distance, lessThan(0.001),
              reason: 'snap drifted away from drawn edge ${edge.id}');
        }
      }
    });

    test('pathfinding lengths equal the drawn polyline lengths', () {
      for (final edge in city.edges.take(200)) {
        var measured = 0.0;
        for (var i = 1; i < edge.points.length; i++) {
          measured += (edge.points[i] - edge.points[i - 1]).distance;
        }
        expect(edge.length, closeTo(measured, 1e-9));
      }
    });
  });

  test('the projection formula is not duplicated anywhere in lib/', () {
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.path.endsWith('geo_projection.dart')) continue;
      final source = entity.readAsStringSync();
      final hasLngMath = RegExp(r'(lng|lon)\s*-\s*\w*[lL]ng').hasMatch(source);
      final hasLatMath = RegExp(r'[lL]at\w*\s*-\s*lat\b').hasMatch(source);
      if (hasLngMath && hasLatMath) offenders.add(entity.path);
    }
    expect(offenders, isEmpty,
        reason: 'Requirement 43: use GeoProjection instead of re-deriving the formula');
  });
}
