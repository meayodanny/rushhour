import 'package:flutter/material.dart';

import '../core/geo_projection.dart';
import '../core/touch_targets.dart';
import '../game/game_controller.dart';
import '../game/line_geometry.dart';

/// One POI hit box in screen space, shared between the positioned hit-area
/// widgets (Requirement 44.2) and this debug painter (Requirement 44.5).
///
/// The rect is computed once per build by the game screen from
/// `GeoProjection.geoToScreen` — the very same projection chain that paints
/// the icon — and handed to both consumers, so the debug overlay physically
/// cannot drift away from the real touch zones.
typedef PoiHitRect = ({String entityId, Rect rect, bool isCustomer});

/// Temporary QA overlay (Requirement 44.5): paints every touch target on top
/// of the live map:
///
/// * red translucent 48x48 squares (+ inscribed 24 px circles) — POI hit
///   areas, centred exactly where the icon is painted;
/// * blue translucent 44 px-wide strips — touch zones along existing lines;
/// * amber 36 px circles — courier grab zones.
///
/// Enabled through `GameScreen.debugHitBoxes`
/// (`--dart-define=FLOWLINE_DEBUG_HITBOXES=true`). Never shown in release
/// builds.
class HitBoxDebugPainter extends CustomPainter {
  HitBoxDebugPainter({
    required this.game,
    required this.camera,
    required this.poiHitRects,
  });

  final GameSessionController game;
  final MapCamera camera;
  final List<PoiHitRect> poiHitRects;

  @override
  void paint(Canvas canvas, Size size) {
    _drawLineStrips(canvas);
    _drawCourierZones(canvas);
    _drawPoiHitBoxes(canvas);
  }

  void _drawLineStrips(Canvas canvas) {
    final geometry = LineGeometry(game.city, game.session.lines, nodeForEntity: game.nodeForEntity);
    final outline = Paint()
      ..color = const Color(0xAA2196F3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final fill = Paint()
      ..color = const Color(0x162196F3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = TouchTargets.lineHitWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final line in game.session.lines) {
      final route = geometry.offsetRoutePointsFor(line, game.nodeForEntity);
      if (route.length < 2) continue;
      final screenRoute = route.map(camera.worldToScreen).toList();
      final path = LineGeometry.buildSmoothPath(screenRoute, cornerRadius: 16);
      canvas.drawPath(path, fill);
      canvas.drawPath(path, outline);
    }
  }

  void _drawCourierZones(Canvas canvas) {
    final geometry = LineGeometry(game.city, game.session.lines, nodeForEntity: game.nodeForEntity);
    final circle = Paint()
      ..color = const Color(0x99FFB300)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final dot = Paint()..color = const Color(0x66FFB300);
    for (final courier in game.session.couriers) {
      final line = game.lineById(courier.lineId);
      if (line == null) continue;
      final world = geometry.pointOnRoute(line, courier.progress);
      final screen = camera.worldToScreen(world);
      canvas.drawCircle(screen, TouchTargets.courierHitRadius, circle);
      canvas.drawCircle(screen, 3, dot);
    }
  }

  void _drawPoiHitBoxes(Canvas canvas) {
    final fill = Paint()..color = const Color(0x2BFF0000);
    final border = Paint()
      ..color = const Color(0xE6FF0000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    final inscribed = Paint()
      ..color = const Color(0x99FF0000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    final cross = Paint()
      ..color = const Color(0xE6FF0000)
      ..strokeWidth = 1.6;
    for (final hit in poiHitRects) {
      final rect = hit.rect;
      canvas.drawRect(rect, fill);
      canvas.drawRect(rect, border);
      canvas.drawCircle(rect.center, TouchTargets.poiHitRadius, inscribed);
      final c = rect.center;
      canvas.drawLine(c - const Offset(5, 0), c + const Offset(5, 0), cross);
      canvas.drawLine(c - const Offset(0, 5), c + const Offset(0, 5), cross);
    }
  }

  @override
  bool shouldRepaint(covariant HitBoxDebugPainter oldDelegate) => true;
}
