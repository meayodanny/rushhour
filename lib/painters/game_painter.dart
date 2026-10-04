import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../engine/city_graph.dart';
import '../engine/game_engine.dart';
import '../models/game_models.dart';

class GamePainter extends CustomPainter {
  final GameEngine engine;

  GamePainter(this.engine) : super(repaint: engine);

  void _drawShape(Canvas canvas, ShapeId shape, Paint paint, double size) {
    switch (shape) {
      case ShapeId.square:
        canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: size, height: size),
          paint,
        );
        break;
      case ShapeId.circle:
        canvas.drawCircle(Offset.zero, size / 2, paint);
        break;
      case ShapeId.triangle:
        final path = Path()
          ..moveTo(0, -size / 2)
          ..lineTo(size / 2, size / 2)
          ..lineTo(-size / 2, size / 2)
          ..close();
        canvas.drawPath(path, paint);
        break;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    _paintTrafficJams(canvas);
    _paintActiveLines(canvas);
    _paintDrawingPath(canvas);
    _paintNodes(canvas);
    _paintCouriers(canvas);
  }

  // 1. Отрисовка дорожных заторов и ремонтных работ
  void _paintTrafficJams(Canvas canvas) {
    for (final jam in engine.trafficJams) {
      final p1 = CityGraph.getScreenPos(jam.p1);
      final p2 = CityGraph.getScreenPos(jam.p2);

      // Оранжево-красная подсветка аварийного участка
      final jamPaint = Paint()
        ..color = const Color(0xFFFF5722).withOpacity(0.8)
        ..strokeWidth = 14.0
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      canvas.drawLine(p1, p2, jamPaint);

      // Предупреждающие диагональные штрихи
      final stripePaint = Paint()
        ..color = const Color(0xFFFFD600)
        ..strokeWidth = 6.0
        ..strokeCap = StrokeCap.butt
        ..style = PaintingStyle.stroke;
      canvas.drawLine(p1, p2, stripePaint);

      // Иконка ремонта по центру участка
      final mid = Offset((p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2);
      canvas.save();
      canvas.translate(mid.dx, mid.dy);
      final iconBg = Paint()..color = const Color(0xFFD32F2F);
      canvas.drawCircle(Offset.zero, 9, iconBg);

      final iconBorder = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawCircle(Offset.zero, 9, iconBorder);

      // Маленький знак "!"
      final textPainter = TextPainter(
        text: const TextSpan(
          text: '!',
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        Offset(-textPainter.width / 2, -textPainter.height / 2),
      );
      canvas.restore();
    }
  }

  // 2. Отрисовка активных маршрутных линий
  void _paintActiveLines(Canvas canvas) {
    for (final line in engine.lines) {
      final bool isSelected = line.id == engine.selectedLineId;

      // Если линия выбрана, рисуем акцентное свечение
      if (isSelected) {
        final glowPaint = Paint()
          ..color = Colors.white.withOpacity(0.4)
          ..strokeWidth = 16.0
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;
        canvas.drawPath(line.path, glowPaint);
      }

      // Основная линия маршрута
      final linePaint = Paint()
        ..color = line.color.withOpacity(0.85)
        ..strokeWidth = 10.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(line.path, linePaint);

      // Точки остановок на узлах
      for (final pt in line.gridPath) {
        final pos = CityGraph.getScreenPos(pt);
        canvas.drawCircle(pos, 4.0, Paint()..color = Colors.white70);
      }
    }
  }

  // 3. Отрисовка пути, который игрок рисует прямо сейчас
  void _paintDrawingPath(Canvas canvas) {
    if (!engine.isDrawing || engine.currentDrawingPath.isEmpty) return;

    final dragPath = Path();
    final firstPos = CityGraph.getScreenPos(engine.currentDrawingPath.first);
    dragPath.moveTo(firstPos.dx, firstPos.dy);

    for (int i = 1; i < engine.currentDrawingPath.length; i++) {
      final pos = CityGraph.getScreenPos(engine.currentDrawingPath[i]);
      dragPath.lineTo(pos.dx, pos.dy);
    }

    final previewPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 10.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(dragPath, previewPaint);

    // Курсор на кончике пальца
    final lastPos = CityGraph.getScreenPos(engine.currentDrawingPath.last);
    canvas.drawCircle(
      lastPos,
      8.0,
      Paint()..color = Colors.cyanAccent,
    );
  }

  // 4. Отрисовка узлов (Рестораны и Жилые Районы)
  void _paintNodes(Canvas canvas) {
    for (final node in engine.nodes) {
      canvas.save();
      final pos = CityGraph.getScreenPos(node.gridPos);
      canvas.translate(pos.dx, pos.dy);

      if (node.type == NodeType.restaurant) {
        // РЕСТОРАН: контурная геометрическая фигура
        final bgPaint = Paint()..color = const Color(0xFF222226);
        _drawShape(canvas, node.shapeId, bgPaint, 32);

        final strokePaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5.0;
        _drawShape(canvas, node.shapeId, strokePaint, 32);

        // Внутренний акцент
        final innerPaint = Paint()..color = Colors.white70;
        _drawShape(canvas, node.shapeId, innerPaint, 10);
      } else {
        // ЖИЛОЙ РАЙОН: круговой хаб с индикатором требуемой формы
        final bool overloaded = node.isOverloaded;

        // Внешнее кольцо (пульсация при перегрузе)
        final haloPaint = Paint()
          ..color = overloaded
              ? const Color(0xFFFF1744).withOpacity(0.6)
              : Colors.white.withOpacity(0.15);
        canvas.drawCircle(Offset.zero, overloaded ? 24 : 20, haloPaint);

        // Основное тело станции
        final bodyPaint = Paint()..color = Colors.white;
        canvas.drawCircle(Offset.zero, 13, bodyPaint);

        // Иконка формы района внутри узла
        final iconPaint = Paint()..color = Colors.black87;
        _drawShape(canvas, node.shapeId, iconPaint, 12);

        // СЕТКА ОЖИДАЮЩИХ ЗАКАЗОВ 2x4
        // Позиционируем панель заказов чуть выше/правее узла
        canvas.save();
        canvas.translate(18, -28);

        // Подложка для сетки 2х4
        final gridBgPaint = Paint()
          ..color = const Color(0xCC111114)
          ..style = PaintingStyle.fill;
        final gridBorderPaint = Paint()
          ..color = overloaded ? const Color(0xFFFF1744) : const Color(0xFF44444C)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0;

        final gridRect = RRect.fromRectAndRadius(
          const Rect.fromLTWH(-4, -22, 54, 28),
          const Radius.circular(4),
        );
        canvas.drawRRect(gridRect, gridBgPaint);
        canvas.drawRRect(gridRect, gridBorderPaint);

        // 8 слотов (2 строки по 4 слота)
        for (int slot = 0; slot < 8; slot++) {
          final int col = slot % 4;
          final int row = slot ~/ 4;
          final double sx = col * 12.0 + 3.0;
          final double sy = -16.0 + row * 11.0;

          // Пустой слот
          final slotPaint = Paint()
            ..color = const Color(0xFF333338)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0;
          canvas.drawRect(
            Rect.fromCenter(center: Offset(sx, sy), width: 8, height: 8),
            slotPaint,
          );

          // Если в этом слоте есть заказ
          if (slot < node.waitingOrders.length) {
            final orderShape = node.waitingOrders[slot];
            final orderPaint = Paint()..color = Colors.amberAccent;
            canvas.save();
            canvas.translate(sx, sy);
            _drawShape(canvas, orderShape, orderPaint, 7);
            canvas.restore();
          }
        }

        // Если есть заказы сверх вместимости (9-й и выше)
        if (node.waitingOrders.length > 8) {
          final overflowCount = node.waitingOrders.length - 8;
          final badgePaint = Paint()..color = const Color(0xFFFF1744);
          canvas.drawCircle(const Offset(52, -20), 7, badgePaint);

          final overflowText = TextPainter(
            text: TextSpan(
              text: '+$overflowCount',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          overflowText.paint(
            canvas,
            Offset(52 - overflowText.width / 2, -20 - overflowText.height / 2),
          );
        }

        // ТАЙМЕР КОЛЛАПСА (если >= 9 заказов)
        if (overloaded) {
          final double progress = (node.overloadTimer / 30.0).clamp(0.0, 1.0);

          // Прогресс-бар перегруза
          final timerBg = Paint()..color = Colors.black87;
          final timerFill = Paint()..color = const Color(0xFFFF1744);

          canvas.drawRect(const Rect.fromLTWH(-4, 8, 54, 5), timerBg);
          canvas.drawRect(Rect.fromLTWH(-4, 8, 54 * progress, 5), timerFill);

          // Текст обратного отсчета
          final timerText = TextPainter(
            text: TextSpan(
              text: '⚠️ ${node.overloadTimer.toStringAsFixed(1)}s',
              style: const TextStyle(
                color: Color(0xFFFF5252),
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          timerText.paint(canvas, const Offset(-4, 15));
        }

        canvas.restore();
      }

      canvas.restore();
    }
  }

  // 5. Отрисовка курьеров
  void _paintCouriers(Canvas canvas) {
    for (final courier in engine.couriers) {
      final lineMatches = engine.lines.where((l) => l.id == courier.lineId);
      if (lineMatches.isEmpty) continue;
      final line = lineMatches.first;

      final metricsList = line.path.computeMetrics().toList();
      if (metricsList.isEmpty) continue;

      final tangent = metricsList.first.getTangentForOffset(courier.distance);
      if (tangent == null) continue;

      canvas.save();
      canvas.translate(tangent.position.dx, tangent.position.dy);
      // Поворот по направлению движения
      final double rotationAngle = tangent.angle + (courier.movingForward ? 0 : math.pi);
      canvas.rotate(rotationAngle);

      // Отрисовка корпуса курьера в зависимости от типа транспорта
      switch (courier.type) {
        case CourierType.foot:
          // Пеший курьер (компактный капсульный значок)
          final footPaint = Paint()..color = line.color;
          final borderPaint = Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5;
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              const Rect.fromCenter(center: Offset.zero, width: 16, height: 12),
              const Radius.circular(6),
            ),
            footPaint,
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              const Rect.fromCenter(center: Offset.zero, width: 16, height: 12),
              const Radius.circular(6),
            ),
            borderPaint,
          );
          break;

        case CourierType.bike:
          // Велокурьер (вытянутый обтекаемый корпус)
          final bikePaint = Paint()..color = line.color;
          final borderPaint = Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5;
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              const Rect.fromCenter(center: Offset.zero, width: 22, height: 14),
              const Radius.circular(4),
            ),
            bikePaint,
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              const Rect.fromCenter(center: Offset.zero, width: 22, height: 14),
              const Radius.circular(4),
            ),
            borderPaint,
          );
          break;

        case CourierType.auto:
          // Автомобиль (крупный кузов)
          final carPaint = Paint()..color = line.color;
          final borderPaint = Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0;
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              const Rect.fromCenter(center: Offset.zero, width: 28, height: 16),
              const Radius.circular(4),
            ),
            carPaint,
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              const Rect.fromCenter(center: Offset.zero, width: 28, height: 16),
              const Radius.circular(4),
            ),
            borderPaint,
          );

          // Лобовое стекло авто
          final glassPaint = Paint()..color = Colors.black45;
          canvas.drawRect(const Rect.fromLTWH(6, -5, 4, 10), glassPaint);
          break;
      }

      // Отрисовка груза в курьере (маленькие фигуры)
      if (courier.cargo.isNotEmpty) {
        final double spacing = 6.0;
        final double startX = -((courier.cargo.length - 1) * spacing) / 2;

        for (int i = 0; i < courier.cargo.length; i++) {
          final shape = courier.cargo[i];
          final cargoPaint = Paint()..color = Colors.black87;
          canvas.save();
          canvas.translate(startX + i * spacing, 0);
          _drawShape(canvas, shape, cargoPaint, 5.0);
          canvas.restore();
        }
      }

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant GamePainter oldDelegate) => true;
}
