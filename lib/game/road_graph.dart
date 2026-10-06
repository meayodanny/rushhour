import 'dart:math' as math;

import 'package:collection/collection.dart';

import '../models/city.dart';
import '../models/entities.dart';

class PathResult {
  const PathResult(this.edgeIds, this.distance);
  final List<String> edgeIds;
  final double distance;
}

class _Step {
  const _Step(this.node, this.distance);
  final String node;
  final double distance;
}

class RoadGraph {
  RoadGraph(this.city) {
    for (final edge in city.edges) {
      _adjacency.putIfAbsent(edge.from, () => <RoadEdge>[]).add(edge);
      _adjacency.putIfAbsent(edge.to, () => <RoadEdge>[]).add(edge);
    }
  }
  final CityData city;
  final Map<String, List<RoadEdge>> _adjacency = <String, List<RoadEdge>>{};

  PathResult? findPath(String start, String goal, {CourierType? mode, Set<String> blocked = const <String>{}, bool allowFerry = false}) {
    if (start == goal) return const PathResult(<String>[], 0);
    final distances = <String, double>{start: 0};
    final previousNode = <String, String>{};
    final previousEdge = <String, String>{};
    final queue = HeapPriorityQueue<_Step>((_Step a, _Step b) => a.distance.compareTo(b.distance))..add(_Step(start, 0));
    while (queue.isNotEmpty) {
      final current = queue.removeFirst();
      if (current.distance != distances[current.node]) continue;
      if (current.node == goal) break;
      for (final edge in _adjacency[current.node] ?? const <RoadEdge>[]) {
        if (blocked.contains(edge.id) || !_allowed(edge, mode, allowFerry)) continue;
        final next = edge.from == current.node ? edge.to : edge.from;
        final candidate = current.distance + edge.length;
        if (candidate < (distances[next] ?? double.infinity)) {
          distances[next] = candidate; previousNode[next] = current.node; previousEdge[next] = edge.id;
          queue.add(_Step(next, candidate));
        }
      }
    }
    if (!distances.containsKey(goal)) return null;
    final edges = <String>[];
    var cursor = goal;
    while (cursor != start) { edges.add(previousEdge[cursor]!); cursor = previousNode[cursor]!; }
    return PathResult(edges.reversed.toList(), distances[goal]!);
  }

  bool _allowed(RoadEdge edge, CourierType? mode, bool allowFerry) {
    if (edge.type == RoadType.ferry && !allowFerry) return false;
    return switch (mode) {
      CourierType.walk => edge.allowWalk,
      CourierType.bike => edge.allowBike,
      CourierType.car => edge.allowCar,
      null => edge.allowWalk && edge.allowBike && edge.allowCar,
    };
  }

  String nearestEdgeId(double x, double y) {
    var result = city.edges.first.id;
    var best = double.infinity;
    for (final edge in city.edges) {
      for (var i = 1; i < edge.points.length; i++) {
        final a = edge.points[i - 1]; final b = edge.points[i];
        final abx = b.dx - a.dx; final aby = b.dy - a.dy;
        final length2 = abx * abx + aby * aby;
        final t = length2 == 0 ? 0.0 : (((x - a.dx) * abx + (y - a.dy) * aby) / length2).clamp(0.0, 1.0);
        final d = math.sqrt(math.pow(x - (a.dx + abx * t), 2) + math.pow(y - (a.dy + aby * t), 2));
        if (d < best) { best = d; result = edge.id; }
      }
    }
    return result;
  }
}
