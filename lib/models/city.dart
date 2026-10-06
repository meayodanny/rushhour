import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/services.dart';

enum RoadType { street, bridge, restrictedCar, ferry }
enum RoadLevel { major, minor }
enum BuildingType { residential, office, park, other }

class CityBuilding {
  const CityBuilding({required this.id, required this.type, required this.footprint});
  final String id;
  final BuildingType type;
  final List<Offset> footprint;

  factory CityBuilding.fromJson(Map<String, Object?> json) {
    final raw = json['footprint'] as List<Object?>? ?? const <Object?>[];
    return CityBuilding(
      id: json['id']! as String,
      type: BuildingType.values.byName((json['type'] as String?) ?? 'other'),
      footprint: raw.map((Object? point) {
        final pair = point! as List<Object?>;
        return Offset((pair[0]! as num).toDouble(), (pair[1]! as num).toDouble());
      }).toList(),
    );
  }
}

class RoadNode {
  const RoadNode({required this.id, required this.point});
  final String id;
  final Offset point;

  factory RoadNode.fromJson(Map<String, Object?> json) => RoadNode(
        id: json['id']! as String,
        point: Offset((json['x']! as num).toDouble(), (json['y']! as num).toDouble()),
      );
}

class RoadEdge {
  const RoadEdge({
    required this.id, required this.from, required this.to,
    required this.points, required this.type, required this.level,
    required this.allowCar, required this.allowBike, required this.allowWalk,
  });
  final String id;
  final String from;
  final String to;
  final List<Offset> points;
  final RoadType type;
  final RoadLevel level;
  final bool allowCar;
  final bool allowBike;
  final bool allowWalk;

  double get length {
    var result = 0.0;
    for (var i = 1; i < points.length; i++) {
      result += (points[i] - points[i - 1]).distance;
    }
    return result;
  }

  factory RoadEdge.fromJson(Map<String, Object?> json, Map<String, RoadNode> nodes) {
    final from = json['from']! as String;
    final to = json['to']! as String;
    final raw = (json['polyline'] as List<Object?>?) ?? const <Object?>[];
    final points = raw.isEmpty
        ? <Offset>[nodes[from]!.point, nodes[to]!.point]
        : raw.map((Object? p) {
            final pair = p! as List<Object?>;
            return Offset((pair[0]! as num).toDouble(), (pair[1]! as num).toDouble());
          }).toList();
    return RoadEdge(
      id: json['id']! as String, from: from, to: to, points: points,
      type: RoadType.values.byName((json['type'] as String?) ?? 'street'),
      level: RoadLevel.values.byName((json['roadLevel'] as String?) ?? 'minor'),
      allowCar: (json['allowCar'] as bool?) ?? true,
      allowBike: (json['allowBike'] as bool?) ?? true,
      allowWalk: (json['allowWalk'] as bool?) ?? true,
    );
  }
}

enum PoiKind { restaurant, customer }
class CityPoi {
  const CityPoi({required this.id, required this.nodeId, required this.kind});
  final String id;
  final String nodeId;
  final PoiKind kind;
}

class FerryPoint {
  const FerryPoint({required this.id, required this.nodeA, required this.nodeB, required this.unlockedByDefault});
  final String id;
  final String nodeA;
  final String nodeB;
  final bool unlockedByDefault;
}

class Holiday {
  const Holiday({required this.day, required this.durationDays, required this.multiplier, required this.label});
  final int day;
  final int durationDays;
  final double multiplier;
  final String label;
}

class CityData {
  const CityData({
    required this.cityId, required this.displayName, required this.attribution,
    required this.nodes, required this.edges, required this.river,
    required this.restaurantPois, required this.customerPois,
    required this.ferryPoints, required this.availableCuisines, required this.holidays,
    this.buildings = const <CityBuilding>[],
  });
  final String cityId;
  final String displayName;
  final String attribution;
  final Map<String, RoadNode> nodes;
  final List<RoadEdge> edges;
  final List<Offset> river;
  final List<CityPoi> restaurantPois;
  final List<CityPoi> customerPois;
  final List<FerryPoint> ferryPoints;
  final List<String> availableCuisines;
  final List<Holiday> holidays;
  final List<CityBuilding> buildings;

  factory CityData.fromJson(Map<String, Object?> json) {
    final roads = json['roads']! as Map<String, Object?>;
    final nodes = <String, RoadNode>{};
    for (final raw in roads['nodes']! as List<Object?>) {
      final node = RoadNode.fromJson(raw! as Map<String, Object?>);
      nodes[node.id] = node;
    }
    final poi = json['poiPool']! as Map<String, Object?>;
    List<CityPoi> parsePois(String key, PoiKind kind) =>
      (poi[key]! as List<Object?>).map((Object? raw) {
        final map = raw! as Map<String, Object?>;
        return CityPoi(id: map['id']! as String, nodeId: map['nodeId']! as String, kind: kind);
      }).toList();
    return CityData(
      cityId: json['cityId']! as String,
      displayName: json['displayName']! as String,
      attribution: (json['attribution'] as String?) ?? '© OpenStreetMap contributors',
      nodes: nodes,
      edges: (roads['edges']! as List<Object?>).map((Object? e) => RoadEdge.fromJson(e! as Map<String, Object?>, nodes)).toList(),
      buildings: ((json['buildings'] as List<Object?>?) ?? const <Object?>[])
          .map((Object? raw) => CityBuilding.fromJson(raw! as Map<String, Object?>))
          .where((CityBuilding building) => building.footprint.length >= 3)
          .toList(),
      river: (json['river']! as Map<String, Object?>)['polyline'] is List<Object?>
        ? ((json['river']! as Map<String, Object?>)['polyline']! as List<Object?>).map((Object? p) {
            final pair = p! as List<Object?>; return Offset((pair[0]! as num).toDouble(), (pair[1]! as num).toDouble());
          }).toList() : const <Offset>[],
      restaurantPois: parsePois('restaurants', PoiKind.restaurant),
      customerPois: parsePois('customers', PoiKind.customer),
      ferryPoints: ((json['ferryPoints'] as List<Object?>?) ?? const <Object?>[]).map((Object? raw) {
        final map = raw! as Map<String, Object?>;
        return FerryPoint(id: map['id']! as String, nodeA: map['nodeA']! as String, nodeB: map['nodeB']! as String, unlockedByDefault: (map['unlockedByDefault'] as bool?) ?? false);
      }).toList(),
      availableCuisines: (json['availableCuisines']! as List<Object?>).cast<String>(),
      holidays: ((json['holidays'] as List<Object?>?) ?? const <Object?>[]).map((Object? raw) {
        final map = raw! as Map<String, Object?>;
        return Holiday(day: (map['day']! as num).toInt(), durationDays: (map['durationDays']! as num).toInt(), multiplier: (map['orderMultiplier']! as num).toDouble(), label: map['label']! as String);
      }).toList(),
    );
  }

  static Future<CityData> load(String cityId) async {
    final path = 'assets/cities/$cityId/map.json';
    final source = await rootBundle.loadString(path);
    final data = CityData.fromJson(jsonDecode(source) as Map<String, Object?>);
    if (data.nodes.isEmpty || data.edges.isEmpty) {
      throw FormatException('City map $path has no drawable road graph.');
    }
    for (final edge in data.edges) {
      if (!data.nodes.containsKey(edge.from) || !data.nodes.containsKey(edge.to) || edge.points.length < 2) {
        throw FormatException('City map $path contains invalid edge ${edge.id}.');
      }
    }
    for (final building in data.buildings) {
      if (building.footprint.length < 3) {
        throw FormatException('City map $path contains invalid building ${building.id}.');
      }
    }
    return data;
  }

  Rect get contentBounds {
    if (nodes.isEmpty) return Rect.zero;
    var left = double.infinity;
    var top = double.infinity;
    var right = double.negativeInfinity;
    var bottom = double.negativeInfinity;
    for (final node in nodes.values) {
      left = math.min(left, node.point.dx);
      top = math.min(top, node.point.dy);
      right = math.max(right, node.point.dx);
      bottom = math.max(bottom, node.point.dy);
    }
    return Rect.fromLTRB(left, top, right, bottom);
  }

  String nearestNode(Offset point, {double maxDistance = double.infinity}) {
    var best = nodes.values.first;
    var distance = double.infinity;
    for (final node in nodes.values) {
      final d = (node.point - point).distance;
      if (d < distance) { best = node; distance = d; }
    }
    return distance <= maxDistance ? best.id : '';
  }

  RoadEdge? edgeById(String id) {
    for (final edge in edges) { if (edge.id == id) return edge; }
    return null;
  }

  Offset pointAlong(List<String> edgeIds, double normalized) {
    final route = edgeIds.map(edgeById).whereType<RoadEdge>().toList();
    if (route.isEmpty) return Offset.zero;
    final total = route.fold<double>(0, (double v, RoadEdge e) => v + e.length);
    var target = normalized.clamp(0.0, 1.0) * total;
    for (final edge in route) {
      for (var i = 1; i < edge.points.length; i++) {
        final length = (edge.points[i] - edge.points[i - 1]).distance;
        if (target <= length) return Offset.lerp(edge.points[i - 1], edge.points[i], target / math.max(1, length))!;
        target -= length;
      }
    }
    return route.last.points.last;
  }
}
