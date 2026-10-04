import 'dart:ui';
import '../models/game_models.dart';
import 'city_graph.dart';

class PathUtils {
  static PathResult buildSmoothPath(List<Node> nodes) {
    if (nodes.isEmpty) return PathResult(Path(), {});
    
    if (nodes.length == 1) {
      final pos = CityGraph.getScreenPos(nodes[0].gridPos);
      return PathResult(Path()..moveTo(pos.dx, pos.dy), {nodes[0].id: 0.0});
    }

    final path = Path();
    final Map<String, double> distances = {};
    
    // Переводим GridPoint в экранные пиксели Offset
    final startPos = CityGraph.getScreenPos(nodes[0].gridPos);
    path.moveTo(startPos.dx, startPos.dy);
    distances[nodes[0].id] = 0.0;

    for (int i = 0; i < nodes.length - 1; i++) {
      // Получаем экранные координаты для следующего узла
      final p2 = CityGraph.getScreenPos(nodes[i + 1].gridPos);
      path.lineTo(p2.dx, p2.dy);
      
      final currentMetrics = path.computeMetrics();
      double currentLength = currentMetrics.isNotEmpty 
          ? currentMetrics.fold(0.0, (prev, metric) => prev + metric.length) 
          : 0.0;
      distances[nodes[i + 1].id] = currentLength;
    }

    return PathResult(path, distances);
  }
}

class PathResult {
  final Path path;
  final Map<String, double> nodeDistancesCache;
  PathResult(this.path, this.nodeDistancesCache);
}