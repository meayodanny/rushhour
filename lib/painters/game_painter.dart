import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/game_config.dart';
import '../core/palette.dart';
import '../game/game_controller.dart';
import '../models/entities.dart';

class GamePainter extends CustomPainter {
  GamePainter(this.game) : super(repaint: game);
  final GameSessionController game;

  @override
  void paint(Canvas canvas, Size size) {
    _drawEvents(canvas);
    for (final line in game.session.lines) { _drawLine(canvas, line); }
    for (final restaurant in game.session.restaurants) { _drawRestaurant(canvas, restaurant); }
    for (final customer in game.session.customers) { _drawCustomer(canvas, customer); }
    for (final courier in game.session.couriers) { _drawCourier(canvas, courier); }
    if (game.session.weather == WeatherType.rain) _drawRain(canvas, size);
  }

  List<Offset> _routePoints(DeliveryLine line) {
    final result = <Offset>[];
    var current = game.nodeForEntity(line.stopIds.first);
    for (final id in line.edgeIds) {
      final edge = game.city.edgeById(id); if (edge == null) continue;
      final forward = edge.from == current;
      final points = forward ? edge.points : edge.points.reversed;
      if (result.isEmpty) { result.addAll(points); } else { result.addAll(points.skip(1)); }
      current = forward ? edge.to : edge.from;
    }
    return result;
  }

  void _drawLine(Canvas canvas, DeliveryLine line) {
    final points = _routePoints(line); if (points.length < 2) return;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) { path.lineTo(p.dx, p.dy); }
    canvas.drawPath(path, Paint()..color = Palette.paper.withValues(alpha: .85)..style = PaintingStyle.stroke..strokeWidth = 15..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round);
    canvas.drawPath(path, Paint()..color = GameConfig.lineColors[line.colorIndex]..style = PaintingStyle.stroke..strokeWidth = 8..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round);
  }

  void _drawRestaurant(Canvas canvas, Restaurant restaurant) {
    final p = game.city.nodes[restaurant.nodeId]!.point;
    final selected = game.selectedEntityId == restaurant.id;
    canvas.drawCircle(p, selected ? 27 : 23, Paint()..color = Palette.paper);
    canvas.drawCircle(p, 20, Paint()..color = Palette.ink);
    _shape(canvas, restaurant.cuisine, p, 12, Palette.paper);
    for (var i = 0; i < restaurant.dishes.length; i++) {
      final dish = restaurant.dishes[i];
      final angle = -math.pi / 2 + i * math.pi / 3;
      final pulse = 1 + math.sin(game.animation * (2 + dish.coolingStage) * 2) * .08 * dish.coolingStage;
      final offset = Offset(math.cos(angle), math.sin(angle)) * 32;
      _shape(canvas, dish.cuisine, p + offset, 7 * pulse, Palette.ink.withValues(alpha: 1 - dish.coolingStage * .14));
    }
  }

  void _drawCustomer(Canvas canvas, Customer customer) {
    final p = game.city.nodes[customer.nodeId]!.point;
    final appearance = Curves.easeOutBack.transform(game.customerAppearance(customer));
    final opacity = Curves.easeIn.transform(game.customerAppearance(customer));
    canvas.save();
    canvas.translate(p.dx, p.dy);
    canvas.scale(appearance);
    canvas.translate(-p.dx, -p.dy);
    canvas.saveLayer(
      Rect.fromCircle(center: p, radius: 90),
      Paint()..color = Colors.white.withValues(alpha: opacity),
    );
    final selected = game.selectedEntityId == customer.id;
    if (customer.demandSuspended) {
      canvas.drawCircle(p, 29 + math.sin(game.animation * 5) * 3, Paint()..color = Palette.warning.withValues(alpha: .65)..style = PaintingStyle.stroke..strokeWidth = 5);
    }
    if (customer.overloadRemaining != null && !customer.demandSuspended) {
      final max = game.session.difficulty == Difficulty.realism ? GameConfig.realismOverloadSeconds : GameConfig.normalOverloadSeconds;
      final fraction = (customer.overloadRemaining! / max).clamp(0.0, 1.0);
      final color = Color.lerp(Palette.danger, Palette.warning, fraction)!;
      canvas.drawArc(Rect.fromCircle(center: p, radius: 31 + math.sin(game.animation * 8) * 2), -math.pi / 2, math.pi * 2 * fraction, false, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 7..strokeCap = StrokeCap.round);
    }
    canvas.drawCircle(p, selected ? 25 : 21, Paint()..color = Palette.paper..style = PaintingStyle.fill);
    canvas.drawCircle(p, 18, Paint()..color = customer.houseApplied ? const Color(0xff6a9c78) : Palette.ink..style = PaintingStyle.stroke..strokeWidth = 4);
    var index = 0;
    for (final entry in customer.demand.entries) {
      for (var i = 0; i < entry.value; i++) {
        final col = index % 4; final row = index ~/ 4;
        _shape(canvas, entry.key, p + Offset((col - 1.5) * 11, 29 + row * 12), 5, Palette.ink);
        index++;
      }
    }
    canvas.restore();
    canvas.restore();
  }

  void _drawCourier(Canvas canvas, Courier courier) {
    final line = game.lineById(courier.lineId); if (line == null) return;
    final points = _routePoints(line); if (points.length < 2) return;
    final p = _pointOnPolyline(points, courier.progress);
    final radius = switch (courier.type) { CourierType.walk => 6.0, CourierType.bike => 9.0, CourierType.car => 12.0 };
    final pulse = courier.state == CourierState.waitingBlocked ? 1 + math.sin(game.animation * 8) * .25 : 1.0;
    canvas.drawCircle(p, (radius + 4) * pulse, Paint()..color = Palette.paper);
    canvas.drawCircle(p, radius * pulse, Paint()..color = GameConfig.lineColors[line.colorIndex]);
    if (courier.cargo.isNotEmpty) canvas.drawCircle(p.translate(radius, -radius), 4, Paint()..color = Palette.ink);
  }

  Offset _pointOnPolyline(List<Offset> points, double progress) {
    var length = 0.0; for (var i = 1; i < points.length; i++) { length += (points[i] - points[i - 1]).distance; }
    var target = progress.clamp(0, 1) * length;
    for (var i = 1; i < points.length; i++) { final d = (points[i] - points[i - 1]).distance; if (target <= d) return Offset.lerp(points[i - 1], points[i], target / math.max(1, d))!; target -= d; }
    return points.last;
  }

  void _drawEvents(Canvas canvas) {
    for (final event in game.session.events) {
      final edge = game.city.edgeById(event.edgeId); if (edge == null) continue;
      final path = Path()..moveTo(edge.points.first.dx, edge.points.first.dy); for (final p in edge.points.skip(1)) { path.lineTo(p.dx, p.dy); }
      if (event.phase == EventPhase.warning) {
        final p = edge.points[edge.points.length ~/ 2];
        canvas.drawArc(Rect.fromCircle(center: p, radius: 18), -math.pi / 2, math.pi * 2 * event.fraction, false, Paint()..color = Palette.warning..style = PaintingStyle.stroke..strokeWidth = 5);
      } else if (event.type == RoadEventType.roadworks) {
        canvas.drawPath(path, Paint()..color = const Color(0xffffc928)..style = PaintingStyle.stroke..strokeWidth = 15);
        final metric = path.computeMetrics().first; for (var d = 0.0; d < metric.length; d += 18) { final tangent = metric.getTangentForOffset(d); if (tangent != null) canvas.drawLine(tangent.position.translate(-5, -7), tangent.position.translate(5, 7), Paint()..color = Palette.ink..strokeWidth = 4); }
      } else {
        canvas.drawPath(path, Paint()..color = event.type == RoadEventType.accident ? Palette.danger : const Color(0xffdc7d4d)..style = PaintingStyle.stroke..strokeWidth = 13..strokeCap = StrokeCap.round);
        if (event.type == RoadEventType.accident) { final p = edge.points[edge.points.length ~/ 2]; canvas.drawCircle(p, 12, Paint()..color = Palette.paper); _text(canvas, '!', p.translate(-3, -9), 16, Palette.danger); }
      }
    }
  }

  void _drawRain(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0x5578aeb8)..strokeWidth = 2;
    for (var i = 0; i < 70; i++) { final x = (i * 97.0 + game.animation * 150) % size.width; final y = (i * 173.0 + game.animation * 410) % size.height; canvas.drawLine(Offset(x, y), Offset(x - 6, y + 18), paint); }
  }

  void _shape(Canvas canvas, Cuisine cuisine, Offset p, double r, Color color) {
    final paint = Paint()..color = color;
    switch (cuisine) {
      case Cuisine.pizza:
        canvas.drawPath(Path()..moveTo(p.dx, p.dy - r)..lineTo(p.dx - r, p.dy + r)..lineTo(p.dx + r, p.dy + r)..close(), paint);
      case Cuisine.asian:
        canvas.drawRect(Rect.fromCenter(center: p, width: r * 1.7, height: r * 1.7), paint);
      case Cuisine.burger:
        canvas.drawCircle(p, r, paint);
      case Cuisine.dessert:
        canvas.save(); canvas.translate(p.dx, p.dy); canvas.rotate(math.pi / 4); canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: r * 1.5, height: r * 1.5), paint); canvas.restore();
      case Cuisine.healthy:
        canvas.drawOval(Rect.fromCenter(center: p, width: r * 1.4, height: r * 2), paint);
    }
  }

  void _text(Canvas canvas, String value, Offset p, double size, Color color) { final painter = TextPainter(text: TextSpan(text: value, style: TextStyle(fontSize: size, fontWeight: FontWeight.w900, color: color)), textDirection: TextDirection.ltr)..layout(); painter.paint(canvas, p); }
  @override bool shouldRepaint(covariant GamePainter oldDelegate) => false;
}
