import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/palette.dart';
import '../game/game_controller.dart';
import '../models/entities.dart';

class OverlayPainter extends CustomPainter {
  OverlayPainter(
    this.game,
    this.manualPoints, {
    required this.hintAnimation,
  }) : super(repaint: Listenable.merge(<Listenable>[game, hintAnimation]));

  final GameSessionController game;
  final List<Offset> manualPoints;
  final Animation<double> hintAnimation;

  @override
  void paint(Canvas canvas, Size size) {
    if (manualPoints.length > 1) {
      final path = Path()..moveTo(manualPoints.first.dx, manualPoints.first.dy);
      for (final point in manualPoints.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = Palette.ink.withValues(alpha: .45)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8
          ..strokeCap = StrokeCap.round,
      );
    }

    for (final courier in game.session.couriers.where((Courier c) => c.state == CourierState.waitingBlocked)) {
      final line = game.lineById(courier.lineId);
      if (line == null) continue;
      RoadEvent? blocked;
      for (final event in game.session.events) {
        if (event.blocksCar && line.edgeIds.contains(event.edgeId)) {
          blocked = event;
          break;
        }
      }
      if (blocked == null) continue;
      final edge = game.city.edgeById(blocked.edgeId);
      if (edge == null) continue;
      final alternate = game.graph.findPath(
        edge.from,
        edge.to,
        mode: CourierType.car,
        blocked: <String>{edge.id},
        allowFerry: game.session.ferryTokens > 0,
      );
      if (alternate == null) continue;
      for (final id in alternate.edgeIds) {
        final alt = game.city.edgeById(id);
        if (alt != null) _dashPolyline(canvas, alt.points, color: Palette.danger.withValues(alpha: .55));
      }
    }

    if (game.tutorialVisible) _drawGestureRoute(canvas);
  }

  void _drawGestureRoute(Canvas canvas) {
    final points = game.tutorialRoutePoints;
    if (points.length < 2) return;
    final completePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      completePath.lineTo(point.dx, point.dy);
    }

    final timeline = hintAnimation.value;
    final rawDraw = (timeline / .24).clamp(0.0, 1.0);
    final drawProgress = Curves.easeInOutCubic.transform(rawDraw);
    final fadeIn = (timeline / .06).clamp(0.0, 1.0);
    final fadeOut = timeline < .74 ? 1.0 : (1 - (timeline - .74) / .26).clamp(0.0, 1.0);
    final opacity = fadeIn * fadeOut;

    final visible = Path();
    for (final metric in completePath.computeMetrics()) {
      visible.addPath(metric.extractPath(0, metric.length * drawProgress), Offset.zero);
    }
    _dashPath(
      canvas,
      visible,
      Paint()
        ..color = Palette.blue.withValues(alpha: .72 * opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round,
    );

    final metrics = completePath.computeMetrics().toList();
    final metric = metrics.isEmpty ? null : metrics.first;
    final tangent = metric == null
        ? null
        : metric.getTangentForOffset((metric.length * drawProgress - .1).clamp(0.0, metric.length));
    if (tangent != null && drawProgress > .03) {
      canvas.drawCircle(tangent.position, 11, Paint()..color = Palette.paper.withValues(alpha: opacity));
      canvas.drawCircle(tangent.position, 6, Paint()..color = Palette.blue.withValues(alpha: opacity));
    }
  }

  void _dashPath(Canvas canvas, Path path, Paint paint) {
    for (final metric in path.computeMetrics()) {
      for (var distance = 0.0; distance < metric.length; distance += 24) {
        canvas.drawPath(metric.extractPath(distance, math.min(distance + 13, metric.length)), paint);
      }
    }
  }

  void _dashPolyline(Canvas canvas, List<Offset> points, {required Color color}) {
    if (points.length < 2) return;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    _dashPath(
      canvas,
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant OverlayPainter oldDelegate) =>
      oldDelegate.game != game || oldDelegate.manualPoints != manualPoints || oldDelegate.hintAnimation != hintAnimation;
}
