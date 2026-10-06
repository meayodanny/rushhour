import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:rushhour/game/road_graph.dart';
import 'package:rushhour/core/geo_projection.dart';
import 'package:rushhour/models/city.dart';
import 'package:rushhour/models/entities.dart';

void main() {
  final nodes = <String, RoadNode>{
    'a': const RoadNode(id: 'a', lat: 51.50, lng: -0.12, point: Offset.zero),
    'b': const RoadNode(id: 'b', lat: 51.50, lng: -0.11, point: Offset(10, 0)),
    'c': const RoadNode(id: 'c', lat: 51.50, lng: -0.10, point: Offset(20, 0)),
    'd': const RoadNode(id: 'd', lat: 51.51, lng: -0.11, point: Offset(10, 20)),
    'island_a': const RoadNode(id: 'island_a', lat: 51.52, lng: -0.12, point: Offset(0, 40)),
    'island_b': const RoadNode(id: 'island_b', lat: 51.52, lng: -0.10, point: Offset(20, 40)),
  };

  RoadEdge edge(String id, String from, String to, {bool car = true}) => RoadEdge(
        id: id,
        from: from,
        to: to,
        points: <Offset>[nodes[from]!.point, nodes[to]!.point],
        type: RoadType.street,
        level: RoadLevel.minor,
        allowCar: car,
        allowBike: true,
        allowWalk: true,
      );

  final ferryPoints = <FerryPoint>[
    const FerryPoint(id: 'ferry_ad', nodeA: 'a', nodeB: 'island_a', unlockedByDefault: false),
  ];

  final city = CityData(
    cityId: 'test',
    displayName: 'Test',
    attribution: '',
    boundingBox: const GeoBounds(minLat: 51.49, maxLat: 51.53, minLng: -0.13, maxLng: -0.09),
    startViewport: const GeoBounds(minLat: 51.50, maxLat: 51.51, minLng: -0.12, maxLng: -0.10),
    revealStages: const <RevealStage>[],
    nodes: nodes,
    edges: <RoadEdge>[
      edge('ab', 'a', 'b'),
      edge('bc', 'b', 'c', car: false),
      edge('bd', 'b', 'd'),
      edge('dc', 'd', 'c'),
      edge('isl', 'island_a', 'island_b'),
    ],
    riverSegments: const <List<Offset>>[],
    restaurantPois: const <CityPoi>[],
    customerPois: const <CityPoi>[],
    ferryPoints: ferryPoints,
    availableCuisines: const <String>['pizza'],
    holidays: const <Holiday>[],
    projection: GeoProjection.fromBounds(
      const GeoBounds(minLat: 51.49, maxLat: 51.53, minLng: -0.13, maxLng: -0.09),
      const Size(860, 1320),
    ),
  );

  test('Dijkstra uses the shortest compatible route', () {
    final graph = RoadGraph(city);
    expect(graph.findPath('a', 'c', mode: CourierType.walk)!.edgeIds, <String>['ab', 'bc']);
    expect(graph.findPath('a', 'c', mode: CourierType.car)!.edgeIds, <String>['ab', 'bd', 'dc']);
  });

  test('blocked roads are excluded', () {
    final route = RoadGraph(city).findPath('a', 'c', mode: CourierType.walk, blocked: <String>{'bc'});
    expect(route!.edgeIds, <String>['ab', 'bd', 'dc']);
  });

  // Requirement 23.2: Ferry is not traversable until unlocked
  test('route cannot be built through an unlocked ferry', () {
    final graph = RoadGraph(city);
    // When allowFerry is false (locked)
    final lockedRoute = graph.findPath('a', 'island_b', allowFerry: false);
    expect(lockedRoute, isNull);

    // When allowFerry is true (unlocked)
    final unlockedRoute = graph.findPath('a', 'island_b', allowFerry: true);
    expect(unlockedRoute, isNotNull);
    expect(unlockedRoute!.edgeIds, <String>['ferry_ad', 'isl']);
  });
}
