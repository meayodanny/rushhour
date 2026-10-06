import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/game_config.dart';
import '../core/palette.dart';
import '../game/game_controller.dart';
import '../game/line_geometry.dart';
import '../models/entities.dart';

class GamePainter extends CustomPainter {
  GamePainter(this.game, {this.palette = FlowlinePalette.light}) : super(repaint: game);
  final GameSessionController game;
  final FlowlinePalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    _drawEvents(canvas);
    for (final line in game.session.lines) {
      _drawLine(canvas, line);
    }
    for (final restaurant in game.session.restaurants) {
      _drawRestaurant(canvas, restaurant);
    }
    for (final customer in game.session.customers) {
      _drawCustomer(canvas, customer);
    }
    for (final courier in game.session.couriers) {
      _drawCourier(canvas, courier);
    }
    if (game.session.weather == WeatherType.rain) _drawRain(canvas, size);
  }

  LineGeometry get _geometry => LineGeometry(
        game.city,
        game.session.lines,
        nodeForEntity: game.nodeForEntity,
      );

  List<Offset> _routePoints(DeliveryLine line) =>
      _geometry.offsetRoutePointsFor(line, game.nodeForEntity);

  void _drawLine(Canvas canvas, DeliveryLine line) {
    final points = _routePoints(line);
    if (points.length < 2) return;
    final path = LineGeometry.buildSmoothPath(points, cornerRadius: 16);

    canvas.drawPath(
      path,
      Paint()
        ..color = palette.paper.withValues(alpha: .94)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 17
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = GameConfig.lineColors[line.colorIndex]
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  void _drawRestaurant(Canvas canvas, Restaurant restaurant) {
    final p = game.city.nodes[restaurant.nodeId]!.point;
    final progress = game.restaurantAppearance(restaurant);
    final scale = Curves.elasticOut.transform(progress.clamp(0.0, 1.0).toDouble());
    final opacity = Curves.easeIn.transform(progress.clamp(0.0, 1.0).toDouble());

    canvas.save();
    canvas.translate(p.dx, p.dy);
    canvas.scale(scale);
    canvas.translate(-p.dx, -p.dy);

    final selected = game.selectedEntityId == restaurant.id;
    canvas.drawCircle(p, selected ? 27 : 23, Paint()..color = palette.paper.withValues(alpha: opacity));
    canvas.drawCircle(p, 20, Paint()..color = palette.ink.withValues(alpha: opacity));
    _shape(canvas, restaurant.cuisine, p, 12, palette.paper.withValues(alpha: opacity));

    for (var i = 0; i < restaurant.dishes.length; i++) {
      final dish = restaurant.dishes[i];
      final dishScale = Curves.elasticOut.transform(dish.appearance.clamp(0.0, 1.0).toDouble());

      // Requirement 36: Subtle ±3-5% scale pulse and gentle quiver on late stages
      final pulse = 1 + math.sin(game.animation * (1.6 + dish.coolingStage * 0.4)) * (0.01 + dish.coolingStage * 0.006);
      final jitter = dish.coolingStage >= 4
          ? Offset(math.sin(game.animation * 12) * 0.45, math.cos(game.animation * 12) * 0.45)
          : Offset.zero;

      final angle = -math.pi / 2 + i * math.pi / 3;
      final offset = Offset(math.cos(angle), math.sin(angle)) * 32 + jitter;

      _shape(
        canvas,
        dish.cuisine,
        p + offset,
        7 * pulse * dishScale,
        palette.ink.withValues(alpha: opacity * (1 - dish.coolingStage * .14)),
      );
    }
    canvas.restore();
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
      canvas.drawCircle(
        p,
        29 + math.sin(game.animation * 5) * 3,
        Paint()
          ..color = palette.warning.withValues(alpha: .65)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5,
      );
    }
    if (customer.overloadRemaining != null && !customer.demandSuspended) {
      final max = game.session.difficulty == Difficulty.realism
          ? GameConfig.realismOverloadSeconds
          : GameConfig.normalOverloadSeconds;
      final fraction = (customer.overloadRemaining! / max).clamp(0.0, 1.0).toDouble();
      final color = Color.lerp(palette.danger, palette.warning, fraction)!;
      canvas.drawArc(
        Rect.fromCircle(center: p, radius: 31 + math.sin(game.animation * 8) * 2),
        -math.pi / 2,
        math.pi * 2 * fraction,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7
          ..strokeCap = StrokeCap.round,
      );
    }

    canvas.drawCircle(p, selected ? 25 : 21, Paint()..color = palette.paper..style = PaintingStyle.fill);
    canvas.drawCircle(
      p,
      18,
      Paint()
        ..color = customer.houseApplied ? const Color(0xff6a9c78) : palette.ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );

    var index = 0;
    for (final entry in customer.demand.entries) {
      for (var i = 0; i < entry.value; i++) {
        final col = index % 4;
        final row = index ~/ 4;
        final demandProgress = game.demandAppearance(customer, entry.key, i);
        final demandScale = Curves.elasticOut.transform(demandProgress.clamp(0.0, 1.0).toDouble());
        _shape(
          canvas,
          entry.key,
          p + Offset((col - 1.5) * 11, 29 + row * 12),
          5 * demandScale,
          palette.ink.withValues(alpha: opacity * demandProgress.clamp(0.0, 1.0).toDouble()),
        );
        index++;
      }
    }
    canvas.restore();
    canvas.restore();
  }

  void _drawCourier(Canvas canvas, Courier courier) {
    final line = game.lineById(courier.lineId);
    if (line == null) return;
    final points = _routePoints(line);
    if (points.length < 2) return;
    final p = _pointOnPolyline(points, courier.progress);
    final radius = switch (courier.type) {
      CourierType.walk => 6.0,
      CourierType.bike => 9.0,
      CourierType.car => 12.0,
    };
    final pulse = courier.state == CourierState.waitingBlocked ? 1 + math.sin(game.animation * 8) * .25 : 1.0;

    canvas.drawCircle(p, (radius + 8) * pulse, Paint()..color = palette.paper);
    canvas.drawCircle(p, radius * pulse, Paint()..color = GameConfig.lineColors[line.colorIndex]);
    if (courier.cargo.isNotEmpty) {
      canvas.drawCircle(p.translate(radius, -radius), 4, Paint()..color = palette.ink);
    }
  }

  Offset _pointOnPolyline(List<Offset> points, double progress) {
    var length = 0.0;
    for (var i = 1; i < points.length; i++) {
      length += (points[i] - points[i - 1]).distance;
    }
    var target = progress.clamp(0, 1).toDouble() * length;
    for (var i = 1; i < points.length; i++) {
      final d = (points[i] - points[i - 1]).distance;
      if (target <= d) {
        return Offset.lerp(points[i - 1], points[i], target / math.max(1, d))!;
      }
      target -= d;
    }
    return points.last;
  }

  void _drawEvents(Canvas canvas) {
    for (final event in game.session.events) {
      final edge = game.city.edgeById(event.edgeId);
      if (edge == null) continue;
      final path = Path()..moveTo(edge.points.first.dx, edge.points.first.dy);
      for (final p in edge.points.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }

      if (event.phase == EventPhase.warning) {
        final p = edge.points[edge.points.length ~/ 2];
        canvas.drawArc(
          Rect.fromCircle(center: p, radius: 18),
          -math.pi / 2,
          math.pi * 2 * event.fraction,
          false,
          Paint()
            ..color = palette.warning
            ..style = PaintingStyle.stroke
            ..strokeWidth = 5,
        );
      } else if (event.type == RoadEventType.roadworks) {
        canvas.drawPath(
          path,
          Paint()
            ..color = const Color(0xffffc928)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 15,
        );
        final metric = path.computeMetrics().first;
        for (var d = 0.0; d < metric.length; d += 18) {
          final tangent = metric.getTangentForOffset(d);
          if (tangent != null) {
            canvas.drawLine(
              tangent.position.translate(-5, -7),
              tangent.position.translate(5, 7),
              Paint()
                ..color = palette.ink
                ..strokeWidth = 4,
            );
          }
        }
      } else {
        canvas.drawPath(
          path,
          Paint()
            ..color = event.type == RoadEventType.accident ? palette.danger : const Color(0xffdc7d4d)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 13
            ..strokeCap = StrokeCap.round,
        );
        if (event.type == RoadEventType.accident) {
          final p = edge.points[edge.points.length ~/ 2];
          canvas.drawCircle(p, 12, Paint()..color = palette.paper);
          _text(canvas, '!', p.translate(-3, -9), 16, palette.danger);
        }
      }
    }
  }

  void _drawRain(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = palette.isDark ? const Color(0x446098a8) : const Color(0x5578aeb8)
      ..strokeWidth = 2;
    for (var i = 0; i < 70; i++) {
      final x = (i * 97.0 + game.animation * 150) % size.width;
      final y = (i * 173.0 + game.animation * 410) % size.height;
      canvas.drawLine(Offset(x, y), Offset(x - 6, y + 18), paint);
    }
  }

  void _shape(Canvas canvas, Cuisine cuisine, Offset p, double r, Color color) {
    final paint = Paint()..color = color;
    switch (cuisine) {
      case Cuisine.pizza:
        canvas.drawPath(
          Path()
            ..moveTo(p.dx, p.dy - r)
            ..lineTo(p.dx - r, p.dy + r)
            ..lineTo(p.dx + r, p.dy + r)
            ..close(),
          paint,
        );
      case Cuisine.asian:
        canvas.drawRect(Rect.fromCenter(center: p, width: r * 1.7, height: r * 1.7), paint);
      case Cuisine.burger:
        canvas.drawCircle(p, r, paint);
      case Cuisine.dessert:
        canvas.save();
        canvas.translate(p.dx, p.dy);
        canvas.rotate(math.pi / 4);
        canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: r * 1.5, height: r * 1.5), paint);
        canvas.restore();
      case Cuisine.healthy:
        canvas.drawOval(Rect.fromCenter(center: p, width: r * 1.4, height: r * 2), paint);
    }
  }

  void _text(Canvas canvas, String value, Offset p, double size, Color color) {
    final painter = TextPainter(
      text: TextSpan(text: value, style: TextStyle(fontSize: size, fontWeight: FontWeight.w900, color: color)),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, p);
  }

  @override
  bool shouldRepaint(covariant GamePainter oldDelegate) =>
      oldDelegate.palette != palette || false;
}
