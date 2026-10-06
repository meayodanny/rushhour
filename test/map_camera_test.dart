import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rushhour/core/geo_projection.dart';
import 'package:rushhour/models/city.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MapCamera', () {
    const bounds = GeoBounds(minLat: 51.49, maxLat: 51.51, minLng: -0.02, maxLng: 0.01);
    final projection = GeoProjection.fromBounds(bounds, const Size(860, 1320));

    test('worldToScreen and screenToWorld are exact inverses', () {
      final camera = MapCamera(Matrix4.identity()
        ..translate(120.5, -44.25)
        ..scale(1.7));
      const world = Offset(321.5, 678.25);
      final screen = camera.worldToScreen(world);
      expect((camera.screenToWorld(screen) - world).distance, lessThan(1e-9));
    });

    test('geoToScreen is literally project() followed by the camera transform', () {
      final camera = MapCamera(Matrix4.identity()
        ..translate(30.0, 20.0)
        ..scale(2.5));
      final viaGeoToScreen = projection.geoToScreen(51.501, -0.011, camera);
      final viaProjectThenCamera = camera.worldToScreen(projection.project(51.501, -0.011));
      expect(viaGeoToScreen, viaProjectThenCamera);
    });

    test('a world circle of worldRadiusFor(px) is a screen circle of px radius', () {
      final camera = MapCamera(Matrix4.identity()
        ..translate(-10.0, 10.0)
        ..scale(0.35));
      const worldRadius = 100.0;
      final centre = projection.project(51.5, -0.005);
      final screenCentre = camera.worldToScreen(centre);
      final edge = camera.worldToScreen(centre + const Offset(worldRadius, 0));
      // screen distance must equal worldRadius * scale, i.e. what
      // worldRadiusFor inverts.
      expect(
        (edge - screenCentre).distance,
        closeTo(worldRadius, 1e-6),
      );
      expect(camera.worldRadiusFor(worldRadius * camera.scale), closeTo(worldRadius, 1e-9));
    });

    test('uniform scale keeps screen radii zoom-independent', () {
      for (final scale in <double>[0.25, 0.35, 1.0, 2.4, 3.2]) {
        final camera = MapCamera(Matrix4.identity()
          ..translate(5.0, 5.0)
          ..scale(scale));
        const screenPx = 24.0; // TouchTargets.poiHitRadius
        final worldRadius = camera.worldRadiusFor(screenPx);
        final p0 = const Offset(400, 600);
        final p1 = p0 + Offset(worldRadius, 0);
        expect((camera.worldToScreen(p1) - camera.worldToScreen(p0)).distance,
            closeTo(screenPx, 1e-9),
            reason: 'at zoom $scale a 24px target must stay 24px on screen');
      }
    });
  });

  group('single projection for painting and hit-testing (Requirement 44.5)', () {
    late CityData city;

    setUpAll(() async {
      city = await CityData.load('rivergate');
    });

    test('every POI node paints exactly where geoToScreen places its hit box', () {
      // RoadNode.point is what the painters use (baked at parse time via the
      // very same GeoProjection); re-projecting node.lat/lng must return the
      // identical value bit-for-bit — the two code paths are one function.
      final pois = <CityPoi>[...city.restaurantPois, ...city.customerPois];
      expect(pois.length, greaterThan(50));
      for (final poi in pois) {
        final node = city.nodes[poi.nodeId]!;
        expect(city.projection.project(node.lat, node.lng), node.point,
            reason: 'node ${node.id} must project to its baked point');
      }
    });

    test('geoToScreen composes the same camera matrix that renders the world', () {
      // Simulate the camera the game screen builds (translate + uniform
      // scale, exactly like _matrix() in game_screen.dart).
      final camera = MapCamera(Matrix4.identity()
        ..translate(88.0, 210.5)
        ..scale(0.62));
      for (final poi in city.restaurantPois.take(40)) {
        final node = city.nodes[poi.nodeId]!;
        final hitBoxCentre = city.projection.geoToScreen(node.lat, node.lng, camera);
        final paintedCentre = MatrixUtils.transformPoint(camera.matrix, node.point);
        expect(hitBoxCentre, paintedCentre,
            reason: 'hit box centre must equal painted icon centre');
      }
    });
  });
}
