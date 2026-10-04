import 'package:flutter/material.dart';
import 'package:rushhour/models/game_models.dart';
import '../engine/city_graph.dart';

class BackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF1E1E1E));

    // Отрисовка реки
    final riverY = CityGraph.getScreenPos(const GridPoint(0, CityGraph.riverRow)).dy;
    final riverRect = Rect.fromLTWH(0, riverY - CityGraph.spacing / 2, size.width, CityGraph.spacing);
    canvas.drawRect(riverRect, Paint()..color = const Color(0xFF2A4B7C));

    // Отрисовка базовой сетки дорог и мостов
    final roadPaint = Paint()
      ..color = const Color(0xFF333333)
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final bridgePaint = Paint()
      ..color = const Color(0xFF555555)
      ..strokeWidth = 20
      ..strokeCap = StrokeCap.square
      ..style = PaintingStyle.stroke;

    for (int x = 0; x < CityGraph.cols; x++) {
      for (int y = 0; y < CityGraph.rows; y++) {
        final p1 = GridPoint(x, y);
        final pos1 = CityGraph.getScreenPos(p1);

        // Горизонтальные связи
        if (x < CityGraph.cols - 1) {
          final p2 = GridPoint(x + 1, y);
          if (CityGraph.isValidEdge(p1, p2)) {
            canvas.drawLine(pos1, CityGraph.getScreenPos(p2), roadPaint);
          }
        }
        // Вертикальные связи
        if (y < CityGraph.rows - 1) {
          final p2 = GridPoint(x, y + 1);
          if (CityGraph.isValidEdge(p1, p2)) {
            bool isBridge = (y == CityGraph.riverRow - 1 && CityGraph.bridgeCols.contains(x));
            canvas.drawLine(pos1, CityGraph.getScreenPos(p2), isBridge ? bridgePaint : roadPaint);
          }
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false; 
}