import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:rushhour/game/road_graph.dart';
import 'package:rushhour/models/city.dart';
import 'package:rushhour/models/entities.dart';

void main() {
  final nodes = <String, RoadNode>{
    'a': const RoadNode(id: 'a', point: Offset.zero),
    'b': const RoadNode(id: 'b', point: Offset(10, 0)),
    'c': const RoadNode(id: 'c', point: Offset(20, 0)),
    'd': const RoadNode(id: 'd', point: Offset(10, 20)),
  };
  RoadEdge edge(String id, String from, String to, {bool car = true}) => RoadEdge(id: id, from: from, to: to, points: <Offset>[nodes[from]!.point, nodes[to]!.point], type: RoadType.street, level: RoadLevel.minor, allowCar: car, allowBike: true, allowWalk: true);
  final city = CityData(cityId: 'test', displayName: 'Test', attribution: '', nodes: nodes, edges: <RoadEdge>[edge('ab', 'a', 'b'), edge('bc', 'b', 'c', car: false), edge('bd', 'b', 'd'), edge('dc', 'd', 'c')], river: const <Offset>[], restaurantPois: const <CityPoi>[], customerPois: const <CityPoi>[], ferryPoints: const <FerryPoint>[], availableCuisines: const <String>['pizza'], holidays: const <Holiday>[]);

  test('Dijkstra uses the shortest compatible route', () {
    final graph = RoadGraph(city);
    expect(graph.findPath('a', 'c', mode: CourierType.walk)!.edgeIds, <String>['ab', 'bc']);
    expect(graph.findPath('a', 'c', mode: CourierType.car)!.edgeIds, <String>['ab', 'bd', 'dc']);
  });

  test('blocked roads are excluded', () {
    final route = RoadGraph(city).findPath('a', 'c', mode: CourierType.walk, blocked: <String>{'bc'});
    expect(route!.edgeIds, <String>['ab', 'bd', 'dc']);
  });
}
