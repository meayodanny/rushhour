import 'dart:collection';
import 'dart:ui';
import '../models/game_models.dart';

class PathResult {
  final Path path;
  final Map<String, double> nodeDistancesCache;
  PathResult(this.path, this.nodeDistancesCache);
}

class CityGraph {
  static const int cols = 8;
  static const int rows = 16;
  static const double spacing = 50.0;
  static const double offset = 25.0;

  static const int riverRow = 8; // Река находится между строками 7 и 8
  static const List<int> bridgeCols = [2, 5]; // Мосты на координатах X = 2 и 5

  static Offset getScreenPos(GridPoint p) {
    return Offset(p.x * spacing + offset, p.y * spacing + offset);
  }

  static bool isValidPoint(GridPoint p) {
    return p.x >= 0 && p.x < cols && p.y >= 0 && p.y < rows;
  }

  static bool isValidEdge(GridPoint p1, GridPoint p2) {
    if (!isValidPoint(p1) || !isValidPoint(p2)) return false;

    final int dx = (p1.x - p2.x).abs();
    final int dy = (p1.y - p2.y).abs();

    // Движение только по ортогональным прямым (без диагоналей)
    if (dx + dy != 1) return false;

    // Проверка пересечения реки (только по мостам)
    final bool crossingRiver = (p1.y == riverRow - 1 && p2.y == riverRow) ||
        (p2.y == riverRow - 1 && p1.y == riverRow);

    if (crossingRiver) {
      if (!bridgeCols.contains(p1.x)) return false;
    }

    return true;
  }

  static List<GridPoint> getNeighbors(GridPoint p) {
    final List<GridPoint> candidates = [
      GridPoint(p.x + 1, p.y),
      GridPoint(p.x - 1, p.y),
      GridPoint(p.x, p.y + 1),
      GridPoint(p.x, p.y - 1),
    ];

    return candidates.where((n) => isValidEdge(p, n)).toList();
  }

  // Поиск кратчайшего пути по графу дорог через BFS
  static List<GridPoint>? findPath(GridPoint start, GridPoint goal) {
    if (start == goal) return [start];
    if (!isValidPoint(start) || !isValidPoint(goal)) return null;

    final Queue<GridPoint> queue = Queue<GridPoint>()..add(start);
    final Map<GridPoint, GridPoint> parent = {};
    final Set<GridPoint> visited = {start};

    while (queue.isNotEmpty) {
      final current = queue.removeFirst();
      if (current == goal) {
        final List<GridPoint> path = [];
        GridPoint? curr = goal;
        while (curr != null) {
          path.add(curr);
          curr = parent[curr];
        }
        return path.reversed.toList();
      }

      for (final next in getNeighbors(current)) {
        if (!visited.contains(next)) {
          visited.add(next);
          parent[next] = current;
          queue.add(next);
        }
      }
    }

    return null; // Путь не найден
  }

  // Соединение цепочки контрольных точек через BFS
  static List<GridPoint> findMultiPointPath(List<GridPoint> waypoints) {
    if (waypoints.isEmpty) return [];
    if (waypoints.length == 1) return [waypoints.first];

    final List<GridPoint> fullPath = [];
    for (int i = 0; i < waypoints.length - 1; i++) {
      final subPath = findPath(waypoints[i], waypoints[i + 1]);
      if (subPath != null && subPath.isNotEmpty) {
        if (fullPath.isEmpty) {
          fullPath.addAll(subPath);
        } else {
          // Исключаем дублирование точки стыковки
          fullPath.addAll(subPath.skip(1));
        }
      }
    }
    return fullPath;
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
        final metrics = path.computeMetrics().toList();
        if (metrics.isNotEmpty) {
          currentLength = metrics.first.length;
        }
      }

      // Кэшируем дистанцию, если на этой точке расположен узел
      final nodeAtPoint = allNodes.where((n) => n.gridPos == gridPath[i]);
      for (final node in nodeAtPoint) {
        distances[node.id] = currentLength;
      }
    }

    return PathResult(path, distances);
  }

  static GridPoint? getNearestGridPoint(Offset position, {double maxDistance = 30.0}) {
    final int x = ((position.dx - offset) / spacing).round();
    final int y = ((position.dy - offset) / spacing).round();

    if (x >= 0 && x < cols && y >= 0 && y < rows) {
      final p = GridPoint(x, y);
      if ((getScreenPos(p) - position).distance <= maxDistance) {
        return p;
      }
    }
    return null;
  }
}
