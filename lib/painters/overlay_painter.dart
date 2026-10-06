import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/palette.dart';
import '../game/game_controller.dart';
import '../models/entities.dart';

class OverlayPainter extends CustomPainter {
  OverlayPainter(this.game, this.manualPoints) : super(repaint: game);
  final GameSessionController game;
  final List<Offset> manualPoints;

  @override
  void paint(Canvas canvas, Size size) {
    if (manualPoints.length > 1) {
      final path = Path()..moveTo(manualPoints.first.dx, manualPoints.first.dy);
      for (final point in manualPoints.skip(1)) { path.lineTo(point.dx, point.dy); }
      canvas.drawPath(path, Paint()..color = Palette.ink.withValues(alpha: .45)..style = PaintingStyle.stroke..strokeWidth = 8..strokeCap = StrokeCap.round);
    }
    for (final courier in game.session.couriers.where((Courier c) => c.state == CourierState.waitingBlocked)) {
      final line = game.lineById(courier.lineId); if (line == null) continue;
      RoadEvent? blocked;
      for (final event in game.session.events) {
        if (event.blocksCar && line.edgeIds.contains(event.edgeId)) { blocked = event; break; }
      }
      if (blocked == null) continue;
      final edge = game.city.edgeById(blocked.edgeId); if (edge == null) continue;
      final alternate = game.graph.findPath(edge.from, edge.to, mode: CourierType.car, blocked: <String>{edge.id}, allowFerry: game.session.ferryTokens > 0);
      if (alternate == null) continue;
      for (final id in alternate.edgeIds) { final alt = game.city.edgeById(id); if (alt != null) _dash(canvas, alt.points); }
    }
    if (game.tutorialVisible && game.session.restaurants.isNotEmpty) {
      final restaurant = game.session.restaurants.firstWhere((Restaurant r) => r.dishes.isNotEmpty, orElse: () => game.session.restaurants.first);
      Customer? target; for (final c in game.session.customers) { if ((c.demand[restaurant.cuisine] ?? 0) > 0) { target = c; break; } }
      if (target != null) _dash(canvas, <Offset>[game.city.nodes[restaurant.nodeId]!.point, game.city.nodes[target.nodeId]!.point], color: Palette.ink.withValues(alpha: .35));
    }
  }

  void _dash(Canvas canvas, List<Offset> points, {Color? color}) {
    for (var i = 1; i < points.length; i++) {
      final a = points[i - 1]; final b = points[i]; final distance = (b - a).distance; final direction = (b - a) / math.max(1, distance);
      for (var d = 0.0; d < distance; d += 18) { canvas.drawLine(a + direction * d, a + direction * math.min(d + 9, distance), Paint()..color = color ?? Palette.danger.withValues(alpha: .55)..strokeWidth = 5..strokeCap = StrokeCap.round); }
    }
  }

  @override bool shouldRepaint(covariant OverlayPainter oldDelegate) => oldDelegate.manualPoints != manualPoints;
}
