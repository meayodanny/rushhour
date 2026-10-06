import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/game_config.dart';
import '../core/palette.dart';
import '../game/game_controller.dart';
import '../game/line_geometry.dart';
import '../models/entities.dart';

class OverlayPainter extends CustomPainter {
  OverlayPainter(
    this.game,
    this.manualPoints, {
    required this.hintAnimation,
    this.palette = FlowlinePalette.light,
  }) : super(repaint: Listenable.merge(<Listenable>[game, hintAnimation]));

  final GameSessionController game;
  final List<Offset> manualPoints;
  final Animation<double> hintAnimation;
  final FlowlinePalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final draft = game.lineDraft;
    if (draft != null && draft.points.length > 1) {
      final activePoints = List<Offset>.of(draft.points);
      // Requirement 25: Extension animation (reachProgress 0.0 -> 1.0) for newly added segment
      if (draft.reachProgress < 1.0 && activePoints.length >= 2) {
        final lastIdx = activePoints.length - 1;
        final pPrev = activePoints[lastIdx - 1];
        final pTarget = activePoints[lastIdx];
        activePoints[lastIdx] = Offset.lerp(pPrev, pTarget, draft.reachProgress)!;
      }

      final path = LineGeometry.buildSmoothPath(activePoints, cornerRadius: 16);

      canvas.drawPath(
        path,
        Paint()
          ..color = palette.paper.withValues(alpha: .72)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 17
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = GameConfig.lineColors[draft.colorIndex].withValues(alpha: .5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 9
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    if (manualPoints.length > 1 && draft == null) {
      final path = LineGeometry.buildSmoothPath(manualPoints, cornerRadius: 16);
      canvas.drawPath(
        path,
        Paint()
          ..color = palette.ink.withValues(alpha: .2)
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
        if (alt != null) _dashPolyline(canvas, alt.points, color: palette.danger.withValues(alpha: .55));
      }
    }

    if (game.tutorialVisible) _drawGestureRoute(canvas);
  }

  void _drawGestureRoute(Canvas canvas) {
    final points = game.tutorialRoutePoints;
    if (points.length < 2) return;
    final completePath = LineGeometry.buildSmoothPath(points, cornerRadius: 16);

    final timeline = hintAnimation.value;
    final rawDraw = (timeline / .24).clamp(0.0, 1.0);
    final drawProgress = Curves.easeInOutCubic.transform(rawDraw);
    final fadeIn = (timeline / .06).clamp(0.0, 1.0);
    final fadeOut = timeline < .74 ? 1.0 : (1 - (timeline - .74) / .26).clamp(0.0, 1.0);
    final opacity = fadeIn * fadeOut;
    if (opacity <= 0.001) return;

    final metrics = completePath.computeMetrics().toList();
    if (metrics.isEmpty) return;
    final metric = metrics.first;
    final animatedPath = metric.extractPath(0, metric.length * drawProgress);

    canvas.drawPath(
      animatedPath,
      Paint()
        ..color = palette.blue.withValues(alpha: .75 * opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round,
    );

    final tangent = metric.getTangentForOffset(metric.length * drawProgress);
    if (tangent != null) {
      canvas.drawCircle(tangent.position, 10, Paint()..color = palette.paper.withValues(alpha: opacity));
      canvas.drawCircle(tangent.position, 6, Paint()..color = palette.blue.withValues(alpha: opacity));
    }
  }

  void _dashPolyline(Canvas canvas, List<Offset> points, {required Color color}) {
    if (points.length < 2) return;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    final metrics = path.computeMetrics().toList();
    for (final m in metrics) {
      var d = 0.0;
      while (d < m.length) {
        final end = math.min(d + 10, m.length);
        canvas.drawPath(m.extractPath(d, end), paint);
        d += 18;
      }
    }
  }

  @override
  bool shouldRepaint(covariant OverlayPainter oldDelegate) =>
      oldDelegate.palette != palette || true;
}
