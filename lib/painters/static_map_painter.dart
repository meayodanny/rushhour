import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/palette.dart';
import '../models/city.dart';

/// Enable with `--dart-define=FLOWLINE_DEBUG_ROADS=true`. In this mode every
/// edge and graph node is overdrawn, with no viewport culling, so malformed or
/// incorrectly projected geometry is immediately visible.
const bool debugDrawWholeRoadGraph = bool.fromEnvironment(
  'FLOWLINE_DEBUG_ROADS',
  defaultValue: false,
);

class StaticMapPainter extends CustomPainter {
  const StaticMapPainter(this.city, {this.debugAllRoads = debugDrawWholeRoadGraph});
  final CityData city;
  final bool debugAllRoads;

  @override
  void paint(Canvas canvas, Size size) {
    // BlendMode.clear used here previously. CustomPaint siblings can share a
    // canvas, so that operation could erase composited content on some GPUs.
    // Painting an opaque map base is deterministic on all Flutter backends.
    canvas.drawRect(Offset.zero & size, Paint()..color = Palette.paper);

    // Decorative city fabric is deliberately painted first. Buildings never
    // participate in hit testing and roads/POIs remain the dominant layer.
    _drawBuildings(canvas);

    final river = Path();
    if (city.river.isNotEmpty) {
      river.moveTo(city.river.first.dx, city.river.first.dy);
      for (final p in city.river.skip(1)) {
        river.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(
        river,
        Paint()
          ..color = Palette.water
          ..style = PaintingStyle.stroke
          ..strokeWidth = 110
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
      canvas.drawPath(
        river,
        Paint()
          ..color = const Color(0x88ffffff)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }

    // This painter intentionally draws the complete graph. The map viewport
    // clips only after geometry has been projected into world coordinates,
    // avoiding accidental data-space culling.
    for (final edge in city.edges.where((RoadEdge e) => e.type != RoadType.bridge && e.type != RoadType.ferry)) {
      _drawRoad(canvas, edge);
    }
    for (final edge in city.edges.where((RoadEdge e) => e.type == RoadType.bridge)) {
      _drawRoad(canvas, edge, bridge: true);
    }
    for (final ferry in city.ferryPoints) {
      final a = city.nodes[ferry.nodeA]?.point;
      final b = city.nodes[ferry.nodeB]?.point;
      if (a == null || b == null) continue;
      canvas.drawLine(
        a,
        b,
        Paint()
          ..color = Palette.muted.withValues(alpha: .5)
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round,
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

  void _drawBuildings(Canvas canvas) {
    for (final building in city.buildings) {
      if (building.footprint.length < 3) continue;
      final path = Path()..moveTo(building.footprint.first.dx, building.footprint.first.dy);
      for (final point in building.footprint.skip(1)) path.lineTo(point.dx, point.dy);
      path.close();
      final fill = switch (building.type) {
        BuildingType.residential => const Color(0xffeadfd0),
        BuildingType.office => const Color(0xffd8e1e2),
        BuildingType.park => Palette.grass,
        BuildingType.other => const Color(0xffe7e2d5),
      };
      canvas.drawPath(path, Paint()..color = fill);
      canvas.drawPath(path, Paint()..color = Palette.ink.withValues(alpha: .10)..style = PaintingStyle.stroke..strokeWidth = 2);
      if (building.type == BuildingType.park) {
        final bounds = path.getBounds();
        final dots = Paint()..color = const Color(0x6680a96b)..strokeWidth = 2;
        for (var x = bounds.left + 8; x < bounds.right; x += 15) {
          for (var y = bounds.top + 8; y < bounds.bottom; y += 15) {
            if (path.contains(Offset(x, y))) canvas.drawCircle(Offset(x, y), 2.2, dots);
          }
        }
      } else {
        // Minimal facade marks make rectangles read as blocks without turning
        // the background into another interactive visual layer.
        final bounds = path.getBounds().deflate(7);
        final facade = Paint()..color = Palette.paper.withValues(alpha: .32)..strokeWidth = 2;
        for (var x = bounds.left; x < bounds.right; x += 13) {
          canvas.drawLine(Offset(x, bounds.top), Offset(x, bounds.bottom), facade);
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
          ..color = Palette.ink.withValues(alpha: .16)
          ..style = PaintingStyle.stroke
          ..strokeWidth = width + 9
          ..strokeCap = StrokeCap.round,
      );
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = edge.level == RoadLevel.major ? Palette.majorRoad : Palette.road
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = Palette.paper.withValues(alpha: .7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant StaticMapPainter oldDelegate) =>
      oldDelegate.city != city || oldDelegate.debugAllRoads != debugAllRoads;
}
