import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../engine/game_engine.dart';
import '../engine/city_graph.dart';
import '../models/game_models.dart';

class GamePainter extends CustomPainter {
  final GameEngine engine;
  GamePainter(this.engine) : super(repaint: engine);

  void _drawShape(Canvas canvas, ShapeId shape, Paint paint, double size) {
    if (shape == ShapeId.square) {
      canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: size, height: size), paint);
    } else if (shape == ShapeId.circle) {
      canvas.drawCircle(Offset.zero, size / 2, paint);
    } else if (shape == ShapeId.triangle) {
      final path = Path()
        ..moveTo(0, -size / 2)
        ..lineTo(size / 2, size / 2)
        ..lineTo(-size / 2, size / 2)
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Отрисовка активных маршрутов (полупрозрачные для наложения)
    for (var line in engine.lines) {
      canvas.drawPath(line.path, Paint()
        ..color = line.color.withOpacity(0.7)
        ..strokeWidth = 12
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round);
    }

    // 2. Отрисовка линии, которую рисует пользователь прямо сейчас
    if (engine.isDrawing && engine.currentDrawingPath.isNotEmpty) {
      final dragPath = Path();
      dragPath.moveTo(CityGraph.getScreenPos(engine.currentDrawingPath.first).dx, 
                      CityGraph.getScreenPos(engine.currentDrawingPath.first).dy);
      for (int i = 1; i < engine.currentDrawingPath.length; i++) {
        final pos = CityGraph.getScreenPos(engine.currentDrawingPath[i]);
        dragPath.lineTo(pos.dx, pos.dy);
      }
      canvas.drawPath(dragPath, Paint()
        ..color = Colors.white70
        ..strokeWidth = 12
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round);
    }

    // 3. Отрисовка узлов
    for (var node in engine.nodes) {
      canvas.save();
      final pos = CityGraph.getScreenPos(node.gridPos);
      canvas.translate(pos.dx, pos.dy);
      
      final paint = Paint()..color = Colors.white;
      
      if (node.type == NodeType.restaurant) {
        paint.style = PaintingStyle.stroke;
        paint.strokeWidth = 6;
        // Ресторан - контурная фигура
        _drawShape(canvas, node.shapeId, paint, 32);
      } else {
        // Район - сплошной круг-подложка с мягким пульсом
        paint.color = Colors.white24;
        canvas.drawCircle(Offset.zero, 22, paint);
        paint.color = Colors.white;
        canvas.drawCircle(Offset.zero, 12, paint);
        
        // Отрисовка заказов над районом (сетка 2x4)
        canvas.translate(20, -25);
        for (int i = 0; i < node.waitingOrders.length; i++) {
          final dx = (i % 4) * 12.0;
          final dy = (i ~/ 4) * -12.0;
          canvas.save();
          canvas.translate(dx, dy);
          _drawShape(canvas, node.waitingOrders[i], Paint()..color = Colors.white, 8);
          canvas.restore();
        }
        
        // Индикатор перегруза[cite: 1]
        if (node.waitingOrders.length >= 8) {
          final timerPaint = Paint()..color = Colors.redAccent;
          canvas.drawRect(Rect.fromLTWH(0, 15, 48 * (node.overloadTimer / 30.0), 4), timerPaint);
        }
        canvas.translate(-20, 25);
      }
      canvas.restore();
    }

    // 4. Отрисовка курьеров
    for (var courier in engine.couriers) {
      final lineMatches = engine.lines.where((l) => l.id == courier.lineId);
      if (lineMatches.isEmpty) continue;
      final line = lineMatches.first;

      final metricsList = line.path.computeMetrics().toList();
      if (metricsList.isEmpty) continue;
      
      final tangent = metricsList.first.getTangentForOffset(courier.distance);
      if (tangent != null) {
        canvas.save();
        canvas.translate(tangent.position.dx, tangent.position.dy);
        canvas.rotate(tangent.angle + (courier.movingForward ? 0 : math.pi));
        
        canvas.drawRect(const Rect.fromLTRB(-12, -8, 12, 8), Paint()..color = line.color);
        
        // Груз курьера
        canvas.translate(-6, 0);
        for (var item in courier.cargo) {
          _drawShape(canvas, item, Paint()..color = Colors.black87, 6);
          canvas.translate(6, 0);
        }
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant GamePainter oldDelegate) => true;
}