import 'package:flutter/material.dart';
import '../engine/city_graph.dart';
import '../models/game_models.dart';

class BackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // 1. Темный фон мегаполиса
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF141416),
    );

    // 2. Река (географическое препятствие между строками 7 и 8)
    final riverY = CityGraph.getScreenPos(const GridPoint(0, CityGraph.riverRow)).dy;
    final riverRect = Rect.fromLTWH(0, riverY - CityGraph.spacing / 2, size.width, CityGraph.spacing);
    
    final riverPaint = Paint()..color = const Color(0xFF1B324D);
    canvas.drawRect(riverRect, riverPaint);

    // Тонкие береговые линии
    final coastPaint = Paint()
      ..color = const Color(0xFF28486E)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(0, riverRect.top), Offset(size.width, riverRect.top), coastPaint);
    canvas.drawLine(Offset(0, riverRect.bottom), Offset(size.width, riverRect.bottom), coastPaint);

    // 3. Дорожная сеть
    final roadPaint = Paint()
      ..color = const Color(0xFF2A2A2E)
      ..strokeWidth = 8.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final bridgePaint = Paint()
      ..color = const Color(0xFF4A4D54)
      ..strokeWidth = 16.0
      ..strokeCap = StrokeCap.square
      ..style = PaintingStyle.stroke;

    final dotPaint = Paint()..color = const Color(0xFF38383E);

    for (int x = 0; x < CityGraph.cols; x++) {
      for (int y = 0; y < CityGraph.rows; y++) {
        final p1 = GridPoint(x, y);
        final pos1 = CityGraph.getScreenPos(p1);

        // Горизонтальные улицы
        if (x < CityGraph.cols - 1) {
          final p2 = GridPoint(x + 1, y);
          if (CityGraph.isValidEdge(p1, p2)) {
            canvas.drawLine(pos1, CityGraph.getScreenPos(p2), roadPaint);
          }
        }

        // Вертикальные улицы и мосты через реку
        if (y < CityGraph.rows - 1) {
          final p2 = GridPoint(x, y + 1);
          if (CityGraph.isValidEdge(p1, p2)) {
            final bool isBridge = (y == CityGraph.riverRow - 1 && CityGraph.bridgeCols.contains(x));
            canvas.drawLine(
              pos1,
              CityGraph.getScreenPos(p2),
              isBridge ? bridgePaint : roadPaint,
            );
          }
        }

        // Точки перекрестков
        canvas.drawCircle(pos1, 2.5, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
