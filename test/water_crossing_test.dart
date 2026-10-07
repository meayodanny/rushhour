import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rushhour/core/game_config.dart';
import 'package:rushhour/core/geo_projection.dart';
import 'package:rushhour/game/road_graph.dart';
import 'package:rushhour/game/water_crossing.dart';
import 'package:rushhour/models/city.dart';

/// Requirement 46: "does this road cross water" has to look at **both**
/// shapes the river is stored in - the filled `river.areas` polygons and the
/// `river.segments` polylines - and it has to keep streets that cross the
/// water outside a real bridge out of every route.
const GeoBounds _bounds = GeoBounds(minLat: 51.49, maxLat: 51.53, minLng: -0.13, maxLng: -0.09);

GeoProjection _projection() => GeoProjection.fromBounds(_bounds, GameConfig.worldSize);

/// Builds a test city whose geometry is written in **metres**, so the
/// thresholds of [WaterCrossing] can be read directly from the test.
CityData _city({
  required List<List<Offset>> areas,
  required List<List<Offset>> segments,
  required List<RoadEdge> edges,
  required Map<String, RoadNode> nodes,
}) =>
    CityData(
      cityId: 'water-test',
      displayName: 'Water test',
      attribution: '',
      boundingBox: _bounds,
      startViewport: _bounds,
      revealStages: const <RevealStage>[],
      nodes: nodes,
      edges: edges,
      riverSegments: segments,
      riverAreas: areas,
      restaurantPois: const <CityPoi>[],
      customerPois: const <CityPoi>[],
      ferryPoints: const <FerryPoint>[],
      availableCuisines: const <String>['pizza'],
      holidays: const <Holiday>[],
      projection: _projection(),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final metres = _projection().pixelsPerMeter;
  Offset m(double xMetres, double yMetres) => Offset(xMetres * metres, yMetres * metres);

  RoadNode node(String id, double xMetres, double yMetres) => RoadNode(
        id: id,
        lat: _bounds.minLat,
        lng: _bounds.minLng,
        point: m(xMetres, yMetres),
      );

  RoadEdge edge(
    String id,
    String from,
    String to,
    Map<String, RoadNode> nodes, {
    RoadType type = RoadType.street,
  }) =>
      RoadEdge(
        id: id,
        from: from,
        to: to,
        points: <Offset>[nodes[from]!.point, nodes[to]!.point],
        type: type,
        level: RoadLevel.minor,
        allowCar: true,
        allowBike: true,
        allowWalk: true,
      );

  RoadEdge byId(CityData city, String id) =>
      city.edges.firstWhere((RoadEdge e) => e.id == id);

  group('river.areas - filled polygons', () {
    // A 20 m wide river band running north-south, stored as a polygon.
    final riverPolygon = <Offset>[m(-10, -100), m(10, -100), m(10, 100), m(-10, 100)];
    final nodes = <String, RoadNode>{
      'west': node('west', -100, 0),
      'east': node('east', 100, 0),
      'graze_west': node('graze_west', -100, 99.5),
      'graze_east': node('graze_east', 100, 99.5),
      'land_south': node('land_south', -100, -40),
      'land_north': node('land_north', -100, 40),
      'in_water': node('in_water', 0, 0),
    };
    final city = _city(
      areas: <List<Offset>>[riverPolygon],
      segments: const <List<Offset>>[],
      nodes: nodes,
      edges: <RoadEdge>[
        edge('cross', 'west', 'east', nodes),
        edge('graze', 'graze_west', 'graze_east', nodes),
        edge('bridge', 'west', 'east', nodes, type: RoadType.bridge),
        edge('docks', 'in_water', 'east', nodes),
        edge('land', 'land_south', 'land_north', nodes),
      ],
    );
    final water = WaterCrossing(city);

    test('a street that passes through the polygon counts as a crossing', () {
      expect(water.crossesWater(byId(city, 'cross').points), isTrue);
      expect(water.blockedEdgeIds, contains('cross'));
      expect(water.isForbiddenCrossing(byId(city, 'cross')), isTrue);
    });

    test('a street that merely grazes the shoreline (0.5 m) stays usable', () {
      expect(water.blockedEdgeIds, isNot(contains('graze')));
    });

    test('a real bridge is allowed to cross', () {
      expect(water.isForbiddenCrossing(byId(city, 'bridge')), isFalse);
      expect(water.blockedEdgeIds, isNot(contains('bridge')));
    });

    test('a street that runs inside the water is a crossing too', () {
      expect(water.blockedEdgeIds, contains('docks'));
    });

    test('roads on land are untouched', () {
      expect(water.blockedEdgeIds, isNot(contains('land')));
      expect(water.blockedEdgeIds, <String>{'cross', 'docks'});
    });

    test('tolerance is read in metres, not in world pixels', () {
      // The very same geometry with a 0.1 m tolerance must now flag the
      // shoreline-grazing street as well.
      final strict = WaterCrossing(city, toleranceMeters: 0.1, sampleStepMeters: 0.05);
      expect(strict.blockedEdgeIds, contains('graze'));
    });

    test('routing refuses to use the crossing, but uses the bridge', () {
      final graph = RoadGraph(city);
      final route = graph.findPath('west', 'east');
      expect(route, isNotNull);
      expect(route!.edgeIds, <String>['bridge']);
    });
  });

  group('river.segments - polylines', () {
    // The same channel, this time stored as a line (narrow stretch).
    final riverLine = <Offset>[m(0, -100), m(0, 0), m(0, 100)];
    final nodes = <String, RoadNode>{
      'west': node('west', -100, 0),
      'east': node('east', 100, 0),
      'south_tip': node('south_tip', 0, 150),
      'bank': node('bank', 0, 0),
    };
    final city = _city(
      areas: const <List<Offset>>[],
      segments: <List<Offset>>[riverLine],
      nodes: nodes,
      edges: <RoadEdge>[
        edge('cross', 'west', 'east', nodes),
        edge('touch', 'bank', 'east', nodes),
        edge('away', 'west', 'south_tip', nodes),
      ],
    );
    final water = WaterCrossing(city);

    test('a street that intersects the water line counts as a crossing', () {
      expect(water.crossesWater(byId(city, 'cross').points), isTrue);
      expect(water.blockedEdgeIds, contains('cross'));
      expect(water.blockedEdgeIds, <String>{'cross'});
    });

    test('merely touching the water line is not a crossing', () {
      expect(water.blockedEdgeIds, isNot(contains('touch')));
      expect(water.blockedEdgeIds, isNot(contains('away')));
    });

    test('a route may not be built across the water line', () {
      final graph = RoadGraph(city);
      expect(graph.findPath('west', 'east'), isNull);
      expect(graph.findPath('west', 'bank'), isNull,
          reason: 'the only land route to the bank needs the crossing');
      expect(graph.findPath('west', 'south_tip')!.edgeIds, <String>['away'],
          reason: 'roads that stay on land keep working');
    });
  });

  test('both water shapes are consulted at the same time', () {
    final nodes = <String, RoadNode>{
      'west': node('west', -100, 0),
      'east': node('east', 100, 0),
      'far_west': node('far_west', -100, 500),
      'far_east': node('far_east', 100, 500),
      'south': node('south', 0, 700),
    };
    // Only a polygon crosses the 'west -> east' street; only a line crosses
    // the 'far_west -> far_east' street.
    final city = _city(
      areas: <List<Offset>>[
        <Offset>[m(-10, -50), m(10, -50), m(10, 50), m(-10, 50)],
      ],
      segments: <List<Offset>>[
        <Offset>[m(0, 400), m(0, 600)],
      ],
      nodes: nodes,
      edges: <RoadEdge>[
        edge('through_area', 'west', 'east', nodes),
        edge('through_line', 'far_west', 'far_east', nodes),
        edge('plain', 'south', 'east', nodes),
      ],
    );
    final water = WaterCrossing(city);
    expect(water.blockedEdgeIds, contains('through_area'));
    expect(water.blockedEdgeIds, contains('through_line'));
    expect(water.blockedEdgeIds, isNot(contains('plain')));
  });

  group('Rivergate map data (Requirement 46 regression)', () {
    late CityData city;
    late WaterCrossing water;

    setUpAll(() async {
      city = await CityData.load('rivergate');
      water = WaterCrossing(city);
    });

    test('the map stores both kinds of water', () {
      expect(city.riverAreas, isNotEmpty);
      expect(city.riverSegments, isNotEmpty);
    });

    test('streets that cross the water outside a real bridge are found', () {
      final blocked = water.blockedEdgeIds.toList()..sort();
      // Printed so the CI log carries the exact evidence of this run.
      debugPrint('Requirement 46: ${blocked.length} street edges cross water outside bridges.');
      debugPrint('Requirement 46: blocked = $blocked');

      // Known river crossings of the Rivergate map (cross-checked against the
      // reference implementation in tools/water_geometry.py): a road cutting
      // through a filled area and roads cutting through water lines.
      expect(blocked, containsAll(<String>['e220', 'e1256', 'e1685']));
      expect(blocked.length, greaterThanOrEqualTo(30));
      expect(blocked.length, lessThan(60));
    });

    test('no bridge edge is blocked', () {
      final bridges = city.edges.where((RoadEdge e) => e.type == RoadType.bridge).toList();
      expect(bridges, isNotEmpty);
      for (final bridge in bridges) {
        expect(water.blockedEdgeIds, isNot(contains(bridge.id)),
            reason: 'bridge ${bridge.id} must stay usable');
      }
    });

    test('every POI stays reachable when the crossings are forbidden', () {
      final blocked = RoadGraph(city).waterBlockedEdgeIds;
      final adjacency = <String, List<String>>{};
      for (final edge in city.edges) {
        if (blocked.contains(edge.id)) continue;
        adjacency.putIfAbsent(edge.from, () => <String>[]).add(edge.to);
        adjacency.putIfAbsent(edge.to, () => <String>[]).add(edge.from);
      }

      final pois = <String>[
        for (final poi in city.restaurantPois) poi.nodeId,
        for (final poi in city.customerPois) poi.nodeId,
      ];
      final reached = <String>{pois.first};
      final queue = <String>[pois.first];
      while (queue.isNotEmpty) {
        for (final next in adjacency[queue.removeLast()] ?? const <String>[]) {
          if (reached.add(next)) queue.add(next);
        }
      }
      for (final poi in pois) {
        expect(reached, contains(poi),
            reason: 'POI node $poi is cut off from the network by water crossings');
      }
    });

    test('a route across the river keeps to the bridges', () {
      final graph = RoadGraph(city);
      final blocked = graph.waterBlockedEdgeIds;
      final route = graph.findPath(
        city.restaurantPois.first.nodeId,
        city.customerPois.last.nodeId,
      );
      expect(route, isNotNull);
      for (final edgeId in route!.edgeIds) {
        expect(blocked, isNot(contains(edgeId)),
            reason: 'route used a forbidden river crossing: $edgeId');
      }
    });

    test('snapping never targets a forbidden river crossing', () {
      final graph = RoadGraph(city);
      final crossing = city.edgeById('e1685')!;
      final snap = graph.nearestGraphPoint(crossing.points.first);
      expect(graph.waterBlockedEdgeIds, isNot(contains(snap.edgeId)));
    });
  });
}
