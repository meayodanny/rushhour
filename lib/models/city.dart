import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/services.dart';
import '../core/game_config.dart';

enum RoadType { street, bridge, restrictedCar, ferry }
enum RoadLevel { major, minor }
enum BuildingType { residential, office, park, other }

class GeoBounds {
  const GeoBounds({
    required this.minLat,
    required this.maxLat,
    required this.minLng,
    required this.maxLng,
  });

  final double minLat;
  final double maxLat;
  final double minLng;
  final double maxLng;

  bool containsLat(double lat, double lng) =>
      lat >= minLat && lat <= maxLat && lng >= minLng && lng <= maxLng;

  factory GeoBounds.fromJson(Map<String, Object?> json) => GeoBounds(
        minLat: (json['minLat']! as num).toDouble(),
        maxLat: (json['maxLat']! as num).toDouble(),
        minLng: (json['minLng']! as num).toDouble(),
        maxLng: (json['maxLng']! as num).toDouble(),
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'minLat': minLat,
        'maxLat': maxLat,
        'minLng': minLng,
        'maxLng': maxLng,
      };
}

class RevealStage {
  const RevealStage({
    required this.stageIndex,
    required this.bounds,
    required this.unlockAfterLevel,
  });

  final int stageIndex;
  final GeoBounds bounds;
  final int unlockAfterLevel;

  factory RevealStage.fromJson(Map<String, Object?> json) => RevealStage(
        stageIndex: (json['stageIndex']! as num).toInt(),
        bounds: GeoBounds.fromJson(json['bounds']! as Map<String, Object?>),
        unlockAfterLevel: (json['unlockAfterLevel']! as num).toInt(),
      );
}

class CityBuilding {
  const CityBuilding({
    required this.id,
    required this.type,
    required this.geoFootprint,
    required this.footprint,
  });

  final String id;
  final BuildingType type;
  final List<List<double>> geoFootprint;
  final List<Offset> footprint;

  factory CityBuilding.fromJson(Map<String, Object?> json, Offset Function(double lat, double lng) project) {
    final raw = json['footprint'] as List<Object?>? ?? const <Object?>[];
    final geo = raw.map((Object? point) {
      final pair = point! as List<Object?>;
      return [(pair[0]! as num).toDouble(), (pair[1]! as num).toDouble()];
    }).toList();

    return CityBuilding(
      id: json['id']! as String,
      type: BuildingType.values.byName((json['type'] as String?) ?? 'other'),
      geoFootprint: geo,
      footprint: geo.map((pair) => project(pair[0], pair[1])).toList(),
    );
  }
}

class RoadNode {
  const RoadNode({
    required this.id,
    required this.lat,
    required this.lng,
    required this.point,
  });

  final String id;
  final double lat;
  final double lng;
  final Offset point;

  factory RoadNode.fromJson(Map<String, Object?> json, Offset Function(double lat, double lng) project) {
    final lat = (json['lat']! as num).toDouble();
    final lng = ((json['lng'] ?? json['lon'])! as num).toDouble();
    return RoadNode(
      id: json['id']! as String,
      lat: lat,
      lng: lng,
      point: project(lat, lng),
    );
  }
}

class RoadEdge {
  const RoadEdge({
    required this.id,
    required this.from,
    required this.to,
    required this.points,
    required this.type,
    required this.level,
    required this.allowCar,
    required this.allowBike,
    required this.allowWalk,
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

  factory RoadEdge.fromJson(
    Map<String, Object?> json,
    Map<String, RoadNode> nodes,
    Offset Function(double lat, double lng) project,
  ) {
    final from = json['from']! as String;
    final to = json['to']! as String;
    final raw = (json['polyline'] as List<Object?>?) ?? const <Object?>[];
    final points = raw.isEmpty
        ? <Offset>[nodes[from]!.point, nodes[to]!.point]
        : raw.map((Object? p) {
            final pair = p! as List<Object?>;
            return project((pair[0]! as num).toDouble(), (pair[1]! as num).toDouble());
          }).toList();

    return RoadEdge(
      id: json['id']! as String,
      from: from,
      to: to,
      points: points,
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
  const FerryPoint({
    required this.id,
    required this.nodeA,
    required this.nodeB,
    required this.unlockedByDefault,
  });

  final String id;
  final String nodeA;
  final String nodeB;
  final bool unlockedByDefault;
}

class Holiday {
  const Holiday({
    required this.day,
    required this.durationDays,
    required this.multiplier,
    required this.label,
  });

  final int day;
  final int durationDays;
  final double multiplier;
  final String label;
}

class CityData {
  const CityData({
    required this.cityId,
    required this.displayName,
    required this.attribution,
    required this.boundingBox,
    required this.startViewport,
    required this.revealStages,
    required this.nodes,
    required this.edges,
    required this.riverSegments,
    required this.restaurantPois,
    required this.customerPois,
    required this.ferryPoints,
    required this.availableCuisines,
    required this.holidays,
    this.buildings = const <CityBuilding>[],
  });

  final String cityId;
  final String displayName;
  final String attribution;
  final GeoBounds boundingBox;
  final GeoBounds startViewport;
  final List<RevealStage> revealStages;
  final Map<String, RoadNode> nodes;
  final List<RoadEdge> edges;
  final List<List<Offset>> riverSegments;
  final List<CityPoi> restaurantPois;
  final List<CityPoi> customerPois;
  final List<FerryPoint> ferryPoints;
  final List<String> availableCuisines;
  final List<Holiday> holidays;
  final List<CityBuilding> buildings;

  List<Offset> get river => riverSegments.isNotEmpty ? riverSegments.first : const <Offset>[];

  static Offset projectCoordinate(
    double lat,
    double lng,
    GeoBounds bounds,
    Size worldSize, {
    double padding = 48.0,
  }) {
    final latSpan = math.max(1e-7, bounds.maxLat - bounds.minLat);
    final lngSpan = math.max(1e-7, bounds.maxLng - bounds.minLng);

    final normX = (lng - bounds.minLng) / lngSpan;
    final normY = (bounds.maxLat - lat) / latSpan;

    final effectiveW = worldSize.width - 2 * padding;
    final effectiveH = worldSize.height - 2 * padding;

    return Offset(
      padding + normX * effectiveW,
      padding + normY * effectiveH,
    );
  }

  factory CityData.fromJson(Map<String, Object?> json, {Size worldSize = GameConfig.worldSize}) {
    final roads = json['roads']! as Map<String, Object?>;
    final rawNodes = roads['nodes']! as List<Object?>;

    // Calculate actual bounds from nodes
    var minLat = double.infinity;
    var maxLat = double.negativeInfinity;
    var minLng = double.infinity;
    var maxLng = double.negativeInfinity;

    for (final raw in rawNodes) {
      final map = raw! as Map<String, Object?>;
      final lat = (map['lat']! as num).toDouble();
      final lng = ((map['lng'] ?? map['lon'])! as num).toDouble();
      minLat = math.min(minLat, lat);
      maxLat = math.max(maxLat, lat);
      minLng = math.min(minLng, lng);
      maxLng = math.max(maxLng, lng);
    }

    final latPad = (maxLat - minLat) * 0.04;
    final lngPad = (maxLng - minLng) * 0.04;
    final boundingBox = json.containsKey('boundingBox')
        ? GeoBounds.fromJson(json['boundingBox']! as Map<String, Object?>)
        : GeoBounds(
            minLat: minLat - latPad,
            maxLat: maxLat + latPad,
            minLng: minLng - lngPad,
            maxLng: maxLng + lngPad,
          );

    Offset project(double lat, double lng) =>
        projectCoordinate(lat, lng, boundingBox, worldSize);

    final nodes = <String, RoadNode>{};
    for (final raw in rawNodes) {
      final node = RoadNode.fromJson(raw! as Map<String, Object?>, project);
      nodes[node.id] = node;
    }

    final poi = json['poiPool']! as Map<String, Object?>;
    List<CityPoi> parsePois(String key, PoiKind kind) =>
        (poi[key]! as List<Object?>).map((Object? raw) {
          final map = raw! as Map<String, Object?>;
          return CityPoi(id: map['id']! as String, nodeId: map['nodeId']! as String, kind: kind);
        }).toList();

    // River segments (Requirement 39.1)
    final riverMap = json['river'] as Map<String, Object?>?;
    final riverSegments = <List<Offset>>[];
    if (riverMap != null) {
      if (riverMap.containsKey('segments')) {
        final segmentsRaw = riverMap['segments'] as List<Object?>? ?? const <Object?>[];
        for (final segRaw in segmentsRaw) {
          final ptsRaw = segRaw! as List<Object?>;
          riverSegments.add(ptsRaw.map((Object? p) {
            final pair = p! as List<Object?>;
            return project((pair[0]! as num).toDouble(), (pair[1]! as num).toDouble());
          }).toList());
        }
      } else if (riverMap.containsKey('polyline')) {
        final ptsRaw = riverMap['polyline'] as List<Object?>? ?? const <Object?>[];
        riverSegments.add(ptsRaw.map((Object? p) {
          final pair = p! as List<Object?>;
          return project((pair[0]! as num).toDouble(), (pair[1]! as num).toDouble());
        }).toList());
      }
    }

    // Viewports and reveal stages (Requirement 40.1)
    final startViewport = json.containsKey('startViewport')
        ? GeoBounds.fromJson(json['startViewport']! as Map<String, Object?>)
        : boundingBox;

    final revealStages = ((json['revealStages'] as List<Object?>?) ?? const <Object?>[])
        .map((Object? raw) => RevealStage.fromJson(raw! as Map<String, Object?>))
        .toList();

    return CityData(
      cityId: json['cityId']! as String,
      displayName: json['displayName']! as String,
      attribution: (json['attribution'] as String?) ?? '© OpenStreetMap contributors',
      boundingBox: boundingBox,
      startViewport: startViewport,
      revealStages: revealStages,
      nodes: nodes,
      edges: (roads['edges']! as List<Object?>)
          .map((Object? e) => RoadEdge.fromJson(e! as Map<String, Object?>, nodes, project))
          .toList(),
      buildings: ((json['buildings'] as List<Object?>?) ?? const <Object?>[])
          .map((Object? raw) => CityBuilding.fromJson(raw! as Map<String, Object?>, project))
          .where((CityBuilding building) => building.footprint.length >= 3)
          .toList(),
      riverSegments: riverSegments,
      restaurantPois: parsePois('restaurants', PoiKind.restaurant),
      customerPois: parsePois('customers', PoiKind.customer),
      ferryPoints: ((json['ferryPoints'] as List<Object?>?) ?? const <Object?>[]).map((Object? raw) {
        final map = raw! as Map<String, Object?>;
        return FerryPoint(
          id: map['id']! as String,
          nodeA: map['nodeA']! as String,
          nodeB: map['nodeB']! as String,
          unlockedByDefault: (map['unlockedByDefault'] as bool?) ?? false,
        );
      }).toList(),
      availableCuisines: (json['availableCuisines']! as List<Object?>).cast<String>(),
      holidays: ((json['holidays'] as List<Object?>?) ?? const <Object?>[]).map((Object? raw) {
        final map = raw! as Map<String, Object?>;
        return Holiday(
          day: (map['day']! as num).toInt(),
          durationDays: (map['durationDays']! as num).toInt(),
          multiplier: (map['orderMultiplier']! as num).toDouble(),
          label: map['label']! as String,
        );
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

  Rect projectBounds(GeoBounds bounds) {
    final pTopLeft = projectCoordinate(bounds.maxLat, bounds.minLng, boundingBox, GameConfig.worldSize);
    final pBottomRight = projectCoordinate(bounds.minLat, bounds.maxLng, boundingBox, GameConfig.worldSize);
    return Rect.fromLTRB(
      math.min(pTopLeft.dx, pBottomRight.dx),
      math.min(pTopLeft.dy, pBottomRight.dy),
      math.max(pTopLeft.dx, pBottomRight.dx),
      math.max(pTopLeft.dy, pBottomRight.dy),
    );
  }

  String nearestNode(Offset point, {double maxDistance = double.infinity}) {
    var best = nodes.values.first;
    var distance = double.infinity;
    for (final node in nodes.values) {
      final d = (node.point - point).distance;
      if (d < distance) {
        best = node;
        distance = d;
      }
    }
    return distance <= maxDistance ? best.id : '';
  }

  RoadEdge? edgeById(String id) {
    for (final edge in edges) {
      if (edge.id == id) return edge;
    }
    // Check dynamic ferries
    for (final fp in ferryPoints) {
      if (fp.id == id && nodes.containsKey(fp.nodeA) && nodes.containsKey(fp.nodeB)) {
        final a = nodes[fp.nodeA]!;
        final b = nodes[fp.nodeB]!;
        return RoadEdge(
          id: fp.id,
          from: fp.nodeA,
          to: fp.nodeB,
          points: <Offset>[a.point, b.point],
          type: RoadType.ferry,
          level: RoadLevel.minor,
          allowCar: true,
          allowBike: true,
          allowWalk: true,
        );
      }
    }
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
