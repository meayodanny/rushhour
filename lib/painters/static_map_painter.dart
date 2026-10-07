import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/palette.dart';
import '../models/city.dart';

const bool debugDrawWholeRoadGraph = bool.fromEnvironment(
  'FLOWLINE_DEBUG_ROADS',
  defaultValue: false,
);

class StaticMapPainter extends CustomPainter {
  const StaticMapPainter(
    this.city, {
    this.palette = FlowlinePalette.light,
    this.activeBoundsRect,
    this.debugAllRoads = debugDrawWholeRoadGraph,
  });

  final CityData city;
  final FlowlinePalette palette;
  final Rect? activeBoundsRect;
  final bool debugAllRoads;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = palette.paper);

    // Decorative building fabric
    _drawBuildings(canvas);

    // Requirement 46 / schemaVersion 3: the water consists of two different
    // kinds of features and each one is painted the way it is stored.
    _drawWaterAreas(canvas);
    _drawWaterSegments(canvas);

    // Roads
    for (final edge in city.edges.where((RoadEdge e) => e.type != RoadType.bridge && e.type != RoadType.ferry)) {
      _drawRoad(canvas, edge);
    }
    for (final edge in city.edges.where((RoadEdge e) => e.type == RoadType.bridge)) {
      _drawRoad(canvas, edge, bridge: true);
    }

    // Ferries
    for (final ferry in city.ferryPoints) {
      final a = city.nodes[ferry.nodeA]?.point;
      final b = city.nodes[ferry.nodeB]?.point;
      if (a == null || b == null) continue;
      canvas.drawLine(
        a,
        b,
        Paint()
          ..color = palette.muted.withValues(alpha: .5)
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round,
      );
    }

    // Requirement 40.4: Dimmed rendering / Fog of War for unopened map regions
    if (activeBoundsRect != null) {
      final mapRect = city.contentBounds.inflate(50);
      final activeRRect = RRect.fromRectAndRadius(activeBoundsRect!.inflate(12), const Radius.circular(24));

      final fogPath = Path()
        ..addRect(mapRect)
        ..addRRect(activeRRect)
        ..fillType = PathFillType.evenOdd;

      canvas.drawPath(
        fogPath,
        Paint()
          ..color = palette.fogOfWar
          ..style = PaintingStyle.fill,
      );
    }

    if (debugAllRoads && kDebugMode) {
      final debugRoad = Paint()
        ..color = const Color(0xaaef476f)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      for (final edge in city.edges) {
        canvas.drawPath(_edgePath(edge), debugRoad);
      }
      final debugNode = Paint()..color = const Color(0xff118ab2);
      for (final node in city.nodes.values) {
        canvas.drawCircle(node.point, 5, debugNode);
      }
    }
  }

  /// Wide water bodies (`river.areas`) are stored as closed polygons and are
  /// painted as **fills** with a translucent water colour, so the road fabric
  /// drawn on top keeps reading as a coherent map (Requirement 46).
  void _drawWaterAreas(Canvas canvas) {
    if (city.riverAreas.isEmpty) return;
    final fill = Paint()
      ..color = palette.water.withValues(alpha: palette.isDark ? .72 : .62)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    final shoreline = Paint()
      ..color = palette.water.withValues(alpha: palette.isDark ? .95 : .85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..isAntiAlias = true;

    for (final area in city.riverAreas) {
      if (area.length < 3) continue;
      final path = Path()
        // evenOdd keeps self-intersecting OSM outlines visually stable and
        // renders nested rings as islands instead of double-painting them.
        ..fillType = PathFillType.evenOdd
        ..moveTo(area.first.dx, area.first.dy);
      for (final point in area.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      path.close();
      canvas.drawPath(path, fill);
      canvas.drawPath(path, shoreline);
    }
  }

  /// Narrow stretches (`river.segments`) stay polylines and are painted as
  /// thin outlines in the very same water colour (Requirement 46).
  void _drawWaterSegments(Canvas canvas) {
    if (city.riverSegments.isEmpty) return;
    final line = Paint()
      ..color = palette.water.withValues(alpha: palette.isDark ? .95 : .85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    for (final segment in city.riverSegments) {
      if (segment.length < 2) continue;
      final path = Path()..moveTo(segment.first.dx, segment.first.dy);
      for (final point in segment.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path, line);
    }
  }

  void _drawBuildings(Canvas canvas) {
    for (final building in city.buildings) {
      if (building.footprint.length < 3) continue;
      final path = Path()..moveTo(building.footprint.first.dx, building.footprint.first.dy);
      for (final point in building.footprint.skip(1)) path.lineTo(point.dx, point.dy);
      path.close();

      final fill = switch (building.type) {
        BuildingType.residential => palette.buildingResidential,
        BuildingType.office => palette.buildingOffice,
        BuildingType.park => palette.buildingPark,
        BuildingType.other => palette.buildingOther,
      };

      canvas.drawPath(path, Paint()..color = fill);
      canvas.drawPath(
        path,
        Paint()
          ..color = palette.ink.withValues(alpha: palette.isDark ? .20 : .10)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );

      if (building.type == BuildingType.park) {
        final bounds = path.getBounds();
        final dotColor = palette.isDark ? const Color(0x4480a96b) : const Color(0x6680a96b);
        final dots = Paint()..color = dotColor..strokeWidth = 2;
        for (var x = bounds.left + 8; x < bounds.right; x += 15) {
          for (var y = bounds.top + 8; y < bounds.bottom; y += 15) {
            if (path.contains(Offset(x, y))) canvas.drawCircle(Offset(x, y), 2.2, dots);
          }
        }
      }
    }
  }

  Path _edgePath(RoadEdge edge) {
    final path = Path()..moveTo(edge.points.first.dx, edge.points.first.dy);
    for (final p in edge.points.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    return path;
  }

  void _drawRoad(Canvas canvas, RoadEdge edge, {bool bridge = false}) {
    final path = _edgePath(edge);
    final width = edge.level == RoadLevel.major ? 12.0 : 7.0;
    if (bridge) {
      canvas.drawPath(
        path,
        Paint()
          ..color = palette.ink.withValues(alpha: palette.isDark ? .35 : .16)
          ..style = PaintingStyle.stroke
          ..strokeWidth = width + 8
          ..strokeCap = StrokeCap.round,
      );
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = edge.level == RoadLevel.major ? palette.majorRoad : palette.road
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = palette.paper.withValues(alpha: palette.isDark ? .12 : .6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant StaticMapPainter oldDelegate) =>
      oldDelegate.city != city ||
      oldDelegate.palette != palette ||
      oldDelegate.activeBoundsRect != activeBoundsRect ||
      oldDelegate.debugAllRoads != debugAllRoads;
}
