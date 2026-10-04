import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../models/game_models.dart';
import 'city_graph.dart';

class GameEngine extends ChangeNotifier {
  late Ticker _ticker;
  Duration _lastTime = Duration.zero;

  List<Node> nodes = [];
  List<RouteLine> lines = [];
  List<Courier> couriers = [];
  
  int score = 0;
  bool isGameOver = false;

  double _orderSpawnTimer = 0.0;
  final Random _rnd = Random();

  // Логика рисования линий
  bool isDrawing = false;
  List<GridPoint> currentDrawingPath = [];
  final List<Color> _availableColors = [
    Colors.redAccent, Colors.blueAccent, Colors.greenAccent, Colors.orangeAccent
  ];

  GameEngine() {
    _initMap();
    _ticker = Ticker(_onTick);
  }

  void start() => _ticker.start();
  
  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void deleteLine(String lineId) {
    lines.removeWhere((l) => l.id == lineId);
    couriers.removeWhere((c) => c.lineId == lineId);
    notifyListeners();
  }

  void _onTick(Duration elapsed) {
    if (isGameOver) return;
    if (_lastTime == Duration.zero) { _lastTime = elapsed; return; }
    final double dt = (elapsed - _lastTime).inMicroseconds / 1000000.0;
    _lastTime = elapsed;

    _updateSpawns(dt);
    _updateOverloadTimers(dt);
    _updateCouriers(dt);
    notifyListeners();
  }

  void _updateSpawns(double dt) {
    _orderSpawnTimer += dt;
    if (_orderSpawnTimer >= 4.0) {
      _orderSpawnTimer = 0;
      final districts = nodes.where((n) => n.type == NodeType.district).toList();
      if (districts.isNotEmpty) {
        final target = districts[_rnd.nextInt(districts.length)];
        final shapes = [ShapeId.square, ShapeId.triangle, ShapeId.circle];
        if (target.waitingOrders.length < 9) {
          target.waitingOrders.add(shapes[_rnd.nextInt(shapes.length)]);
        }
      }
    }
  }

  void _updateOverloadTimers(double dt) {
    for (var node in nodes.where((n) => n.type == NodeType.district)) {
      if (node.waitingOrders.length >= 8) { // Максимальная вместимость 8[cite: 1]
        node.overloadTimer -= dt;
        if (node.overloadTimer <= 0) isGameOver = true;
      } else {
        node.overloadTimer = 30.0;
      }
    }
  }

  void _updateCouriers(double dt) {
    for (var courier in couriers) {
      final lineMatches = lines.where((l) => l.id == courier.lineId);
      if (lineMatches.isEmpty) continue;
      final line = lineMatches.first;

      final metricsList = line.path.computeMetrics().toList();
      if (metricsList.isEmpty) continue;
      
      final pathLength = metricsList.first.length;
      if (pathLength <= 0) continue;
      
      final double deltaDistance = courier.baseSpeed * dt;
      final double prevDist = courier.distance;
      
      if (courier.movingForward) {
        courier.distance += deltaDistance;
        if (courier.distance >= pathLength) {
          courier.distance = pathLength;
          courier.movingForward = false;
        }
      } else {
        courier.distance -= deltaDistance;
        if (courier.distance <= 0) {
          courier.distance = 0;
          courier.movingForward = true;
        }
      }

      line.nodeDistancesCache.forEach((nodeId, nodeDist) {
        bool crossedForward = courier.movingForward && prevDist <= nodeDist && courier.distance >= nodeDist;
        bool crossedBackward = !courier.movingForward && prevDist >= nodeDist && courier.distance <= nodeDist;
        
        if (crossedForward || crossedBackward) {
          final targetNodeMatch = nodes.where((n) => n.id == nodeId);
          if (targetNodeMatch.isNotEmpty) {
            _processNodeInteraction(courier, line, targetNodeMatch.first);
          }
        }
      });
    }
  }

  void _processNodeInteraction(Courier courier, RouteLine line, Node node) {
    if (node.type == NodeType.restaurant) {
      // Ищем, есть ли на этой линии районы, которым нужна эта фигура
      List<ShapeId> lineDemands = [];
      for (var dId in line.connectedNodeIds) {
        final dNode = nodes.firstWhere((n) => n.id == dId);
        if (dNode.type == NodeType.district) {
          lineDemands.addAll(dNode.waitingOrders);
        }
      }

      int countNeeded = lineDemands.where((s) => s == node.shapeId).length;
      int currentlyCarrying = courier.cargo.where((s) => s == node.shapeId).length;

      // Берем заказ только если он кому-то нужен на маршруте
      while (courier.cargo.length < courier.capacity && currentlyCarrying < countNeeded) {
        courier.cargo.add(node.shapeId);
        currentlyCarrying++;
      }
    } else if (node.type == NodeType.district) {
      // Сбрасываем только те заказы, которые ждет этот район
      List<ShapeId> toRemoveFromCargo = [];
      for (var item in courier.cargo) {
        if (node.waitingOrders.contains(item)) {
          node.waitingOrders.remove(item);
          toRemoveFromCargo.add(item);
          score++;
        }
      }
      for (var item in toRemoveFromCargo) courier.cargo.remove(item);
    }
  }

  // --- ЛОГИКА РИСОВАНИЯ ПО СЕТКЕ ---
  
  GridPoint? _getNearestGridPoint(Offset position) {
    int x = ((position.dx - 25.0) / CityGraph.spacing).round();
    int y = ((position.dy - 25.0) / CityGraph.spacing).round();
    if (x >= 0 && x < CityGraph.cols && y >= 0 && y < CityGraph.rows) {
      final p = GridPoint(x, y);
      if ((CityGraph.getScreenPos(p) - position).distance < 25.0) return p;
    }
    return null;
  }

  void onPanStart(DragStartDetails details) {
    if (isGameOver) return;
    final gp = _getNearestGridPoint(details.localPosition);
    if (gp != null) {
      final nodeMatch = nodes.where((n) => n.gridPos == gp);
      if (nodeMatch.isNotEmpty) {
        isDrawing = true;
        currentDrawingPath = [gp];
        notifyListeners();
      }
    }
  }

  void onPanUpdate(DragUpdateDetails details) {
    if (!isDrawing || currentDrawingPath.isEmpty) return;
    final gp = _getNearestGridPoint(details.localPosition);
    
    if (gp != null && gp != currentDrawingPath.last) {
      // Возврат назад по линии отменяет последний шаг
      if (currentDrawingPath.length > 1 && gp == currentDrawingPath[currentDrawingPath.length - 2]) {
        currentDrawingPath.removeLast();
      } 
      // Добавление новой точки, если это легальный соседний участок дороги
      else if (CityGraph.isValidEdge(currentDrawingPath.last, gp)) {
        if (!currentDrawingPath.contains(gp)) {
          currentDrawingPath.add(gp);
        }
      }
    }
    notifyListeners();
  }

  void onPanEnd(DragEndDetails details) {
    if (isDrawing && currentDrawingPath.length > 1) {
      // Ищем все узлы на нарисованном пути
      List<String> connectedIds = [];
      int lastValidNodeIndex = 0;

      for (int i = 0; i < currentDrawingPath.length; i++) {
        final gp = currentDrawingPath[i];
        final nodeMatch = nodes.where((n) => n.gridPos == gp);
        if (nodeMatch.isNotEmpty) {
          connectedIds.add(nodeMatch.first.id);
          lastValidNodeIndex = i;
        }
      }

      // Линия сохраняется только если соединяет минимум 2 узла
      if (connectedIds.length >= 2) {
        // Обрезаем хвост линии, если она закончилась в пустоте
        final finalPath = currentDrawingPath.sublist(0, lastValidNodeIndex + 1);
        final pathResult = CityGraph.buildVisualPath(finalPath, nodes);
        
        final newLineId = 'line_${lines.length}_${DateTime.now().millisecondsSinceEpoch}';
        lines.add(RouteLine(
          id: newLineId,
          color: _availableColors[lines.length % _availableColors.length],
          gridPath: List.from(finalPath),
          connectedNodeIds: connectedIds,
          path: pathResult.path,
          nodeDistancesCache: pathResult.nodeDistancesCache,
        ));

        // Назначаем курьера (чередуем типы для тестов)
        final cType = lines.length % 2 == 0 ? CourierType.auto : CourierType.bike;
        couriers.add(Courier(id: 'c_${couriers.length}', lineId: newLineId, type: cType));
      }
    }
    isDrawing = false;
    currentDrawingPath.clear();
    notifyListeners();
  }

  void _initMap() {
    nodes = [
      Node(id: 'r1', gridPos: const GridPoint(1, 2), type: NodeType.restaurant, shapeId: ShapeId.square),
      Node(id: 'r2', gridPos: const GridPoint(5, 4), type: NodeType.restaurant, shapeId: ShapeId.triangle),
      Node(id: 'r3', gridPos: const GridPoint(3, 11), type: NodeType.restaurant, shapeId: ShapeId.circle),
      
      Node(id: 'd1', gridPos: const GridPoint(6, 1), type: NodeType.district, shapeId: ShapeId.circle),
      Node(id: 'd2', gridPos: const GridPoint(2, 6), type: NodeType.district, shapeId: ShapeId.triangle),
      Node(id: 'd3', gridPos: const GridPoint(5, 13), type: NodeType.district, shapeId: ShapeId.square),
    ];
  }
}