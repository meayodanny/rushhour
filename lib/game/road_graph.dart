import 'dart:math' as math;
import 'dart:ui';

import 'package:collection/collection.dart';

import '../models/city.dart';
import '../models/entities.dart';
import 'water_crossing.dart';

class PathResult {
  const PathResult(this.edgeIds, this.distance);
  final List<String> edgeIds;
  final double distance;
}

class GraphProjection {
  const GraphProjection({required this.edgeId, required this.point, required this.distance, required this.along});
  final String edgeId;
  final Offset point;
  final double distance;
  final double along;
}

class _Step {
  const _Step(this.node, this.distance);
  final String node;
  final double distance;
}

class RoadGraph {
  RoadGraph(this.city, {WaterCrossing? water})
      : water = water ?? WaterCrossing(city) {
    for (final edge in city.edges) {
      _adjacency.putIfAbsent(edge.from, () => <RoadEdge>[]).add(edge);
      _adjacency.putIfAbsent(edge.to, () => <RoadEdge>[]).add(edge);
    }
  }

  final CityData city;

  /// Requirement 46: the authority on which edges count as river crossings.
  final WaterCrossing water;

  final Map<String, List<RoadEdge>> _adjacency = <String, List<RoadEdge>>{};

  /// Edges whose geometry carries a street across water where no real bridge
  /// exists (Requirement 46). Routes may not use them.
  Set<String> get waterBlockedEdgeIds => water.blockedEdgeIds;

  List<RoadEdge> _ferryEdges() {
    final list = <RoadEdge>[];
    for (final fp in city.ferryPoints) {
      if (city.nodes.containsKey(fp.nodeA) && city.nodes.containsKey(fp.nodeB)) {
        list.add(RoadEdge(
          id: fp.id,
          from: fp.nodeA,
          to: fp.nodeB,
          points: <Offset>[city.nodes[fp.nodeA]!.point, city.nodes[fp.nodeB]!.point],
          type: RoadType.ferry,
          level: RoadLevel.minor,
          allowCar: true,
          allowBike: true,
          allowWalk: true,
        ));
      }
    }
    return list;
  }

  PathResult? findPath(
    String start,
    String goal, {
    CourierType? mode,
    Set<String> blocked = const <String>{},
    bool allowFerry = false,
    bool respectBridges = true,
  }) {
    if (start == goal) return const PathResult(<String>[], 0);
    if (!city.nodes.containsKey(start) || !city.nodes.containsKey(goal)) return null;

    // Requirement 46: a road that crosses water outside the real bridges is
    // never a valid route, on top of the (event-driven) blocked edges.
    final blockedEdges = respectBridges
        ? <String>{...blocked, ...water.blockedEdgeIds}
        : blocked;

    final distances = <String, double>{start: 0};
    final previousNode = <String, String>{};
    final previousEdge = <String, String>{};
    final queue = HeapPriorityQueue<_Step>((_Step a, _Step b) => a.distance.compareTo(b.distance))
      ..add(_Step(start, 0));

    // Dynamic adjacency list with ferries included only if allowFerry is true
    final extraEdges = allowFerry ? _ferryEdges() : const <RoadEdge>[];

    while (queue.isNotEmpty) {
      final current = queue.removeFirst();
      if (current.distance != distances[current.node]) continue;
      if (current.node == goal) break;

      final nodeEdges = <RoadEdge>[
        ...(_adjacency[current.node] ?? const <RoadEdge>[]),
        ...extraEdges.where((RoadEdge e) => e.from == current.node || e.to == current.node),
      ];

      for (final edge in nodeEdges) {
        if (blockedEdges.contains(edge.id) || !_allowed(edge, mode, allowFerry)) continue;
        final next = edge.from == current.node ? edge.to : edge.from;
        final candidate = current.distance + edge.length;
        if (candidate < (distances[next] ?? double.infinity)) {
          distances[next] = candidate;
          previousNode[next] = current.node;
          previousEdge[next] = edge.id;
          queue.add(_Step(next, candidate));
        }
      }
    }

    if (!distances.containsKey(goal)) return null;
    final edges = <String>[];
    var cursor = goal;
    while (cursor != start) {
      edges.add(previousEdge[cursor]!);
      cursor = previousNode[cursor]!;
    }
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

  String nearestEdgeId(double x, double y) => nearestGraphPoint(Offset(x, y)).edgeId;

  /// Snaps [point] onto the closest road.
  ///
  /// Requirement 46: edges that cross the water outside a real bridge are not
  /// valid snapping targets either - otherwise a free-hand gesture could drag
  /// the draft line straight across the river. When every edge of the city is
  /// a forbidden crossing (degenerate data) the method falls back to plain
  /// nearest-edge behaviour instead of failing.
  GraphProjection nearestGraphPoint(Offset point, {bool respectBridges = true}) {
    if (city.edges.isEmpty) {
      throw StateError('Cannot snap a gesture without roads.');
    }
    final allowed = respectBridges
        ? city.edges.where((RoadEdge e) => !water.blockedEdgeIds.contains(e.id)).toList()
        : city.edges;
    final candidates = allowed.isEmpty ? city.edges : allowed;
    var best = GraphProjection(
      edgeId: candidates.first.id,
      point: candidates.first.points.first,
      distance: double.infinity,
      along: 0,
    );
    for (final edge in candidates) {
      var travelled = 0.0;
      for (var i = 1; i < edge.points.length; i++) {
        final a = edge.points[i - 1];
        final b = edge.points[i];
        final delta = b - a;
        final lengthSquared = delta.dx * delta.dx + delta.dy * delta.dy;
        final segmentLength = delta.distance;
        final t = lengthSquared == 0
            ? 0.0
            : (((point.dx - a.dx) * delta.dx + (point.dy - a.dy) * delta.dy) /
                    lengthSquared)
                .clamp(0.0, 1.0);
        final projection = Offset(
          a.dx + delta.dx * t.toDouble(),
          a.dy + delta.dy * t.toDouble(),
        );
        final distance = (point - projection).distance;
        if (distance < best.distance) {
          best = GraphProjection(
            edgeId: edge.id,
            point: projection,
            distance: distance,
            along: travelled + segmentLength * t.toDouble(),
          );
        }
        travelled += segmentLength;
      }
    }
    return best;
  }
}
