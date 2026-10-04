import 'dart:ui';
import '../models/game_models.dart';

class CityGraph {
  static const int cols = 8;
  static const int rows = 16;
  static const double spacing = 50.0;
  
  static const int riverRow = 8; // Река находится между 7 и 8 строками
  static const List<int> bridgeCols = [2, 5]; // Мосты только на этих X

  static Offset getScreenPos(GridPoint p) {
    return Offset(p.x * spacing + 25.0, p.y * spacing + 25.0);
  }

  static bool isValidEdge(GridPoint p1, GridPoint p2) {
    int dx = (p1.x - p2.x).abs();
    int dy = (p1.y - p2.y).abs();
    
    // Движение только по прямым (без диагоналей)
    if (dx + dy != 1) return false;

    // Проверка пересечения реки (только по мостам)
    if ((p1.y == riverRow - 1 && p2.y == riverRow) || (p2.y == riverRow - 1 && p1.y == riverRow)) {
      if (!bridgeCols.contains(p1.x)) return false;
    }

    return true;
  }

  static PathResult buildVisualPath(List<GridPoint> gridPath, List<Node> allNodes) {
    if (gridPath.isEmpty) return PathResult(Path(), {});

    final path = Path();
    final Map<String, double> distances = {};
    
    final startPos = getScreenPos(gridPath[0]);
    path.moveTo(startPos.dx, startPos.dy);

    double currentLength = 0.0;

    for (int i = 0; i < gridPath.length; i++) {
      final pos = getScreenPos(gridPath[i]);
      if (i > 0) {
        path.lineTo(pos.dx, pos.dy);
        currentLength = path.computeMetrics().first.length;
      }
      
      // Кэшируем дистанцию, если на этой точке есть узел
      final nodeAtPoint = allNodes.where((n) => n.gridPos == gridPath[i]).toList();
      if (nodeAtPoint.isNotEmpty) {
        distances[nodeAtPoint.first.id] = currentLength;
      }
    }

    return PathResult(path, distances);
  }
}

class PathResult {
  final Path path;
  final Map<String, double> nodeDistancesCache;
  PathResult(this.path, this.nodeDistancesCache);
}