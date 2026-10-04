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
  List<TrafficJam> trafficJams = [];

  // Пул свободных курьеров в резерве
  Map<CourierType, int> courierReserve = {
    CourierType.foot: 2,
    CourierType.bike: 2,
    CourierType.auto: 1,
  };

  int maxLines = 3;
  int score = 0;
  int totalDeliveries = 0;
  bool isGameOver = false;

  final GameClock gameClock = GameClock();
  double timeMultiplier = 1.0; // 0.0 = пауза, 1.0 = норма, 2.5 = ускорение

  double _orderSpawnTimer = 0.0;
  double _trafficJamSpawnTimer = 0.0;
  final Random _rnd = Random();

  // Выбранная линия для инспекции и управления флотом
  String? selectedLineId;
  String? bannerMessage;
  double _bannerTimer = 0.0;

  // Логика рисования и редактирования линий
  bool isDrawing = false;
  String? editingLineId; // Если редактируем существующую линию
  bool isExtendingFromStart = false; // Тянем за начало или за конец
  List<GridPoint> currentDrawingPath = [];

  final List<Color> _linePalette = [
    const Color(0xFFE53935), // Красный
    const Color(0xFF1E88E5), // Синий
    const Color(0xFF43A047), // Зеленый
    const Color(0xFFFB8C00), // Оранжевый
    const Color(0xFF8E24AA), // Фиолетовый
    const Color(0xFF00ACC1), // Бирюзовый
    const Color(0xFFFFD600), // Желтый
  ];

  // Сгенерированные ID для прогрессии карт
  final Set<int> _unlockedMilestones = {};

  GameEngine() {
    _initMap();
    _ticker = Ticker(_onTick);
  }

  void start() {
    if (!_ticker.isActive) {
      _ticker.start();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void setTimeMultiplier(double mult) {
    timeMultiplier = mult;
    notifyListeners();
  }

  void selectLine(String? lineId) {
    selectedLineId = lineId;
    notifyListeners();
  }

  void _showBanner(String message) {
    bannerMessage = message;
    _bannerTimer = 4.0;
  }

  // Назначение курьера из резерва на линию
  bool assignCourierToLine(String lineId, CourierType type) {
    final available = courierReserve[type] ?? 0;
    if (available <= 0) return false;

    final lineMatches = lines.where((l) => l.id == lineId);
    if (lineMatches.isEmpty) return false;

    courierReserve[type] = available - 1;

    final newCourier = Courier(
      id: 'c_${DateTime.now().microsecondsSinceEpoch}_${_rnd.nextInt(1000)}',
      lineId: lineId,
      type: type,
      distance: 0.0,
      movingForward: true,
    );

    // Равномерно распределяем курьеров по дистанции линии
    final lineCouriers = couriers.where((c) => c.lineId == lineId).toList();
    final totalCouriersOnLine = lineCouriers.length + 1;
    final metrics = lineMatches.first.path.computeMetrics().toList();
    final double pathLength = metrics.isNotEmpty ? metrics.first.length : 0.0;

    couriers.add(newCourier);

    if (pathLength > 0 && totalCouriersOnLine > 1) {
      final allOnLine = couriers.where((c) => c.lineId == lineId).toList();
      for (int i = 0; i < allOnLine.length; i++) {
        allOnLine[i].distance = (pathLength / allOnLine.length) * i;
      }
    }

    notifyListeners();
    return true;
  }

  // Возврат курьера с линии в резерв
  bool unassignCourier(String courierId) {
    final idx = couriers.indexWhere((c) => c.id == courierId);
    if (idx == -1) return false;

    final courier = couriers.removeAt(idx);
    courierReserve[courier.type] = (courierReserve[courier.type] ?? 0) + 1;
    notifyListeners();
    return true;
  }

  // Удаление линии и возврат всех ее курьеров в резерв
  void deleteLine(String lineId) {
    final lineCouriers = couriers.where((c) => c.lineId == lineId).toList();
    for (final c in lineCouriers) {
      courierReserve[c.type] = (courierReserve[c.type] ?? 0) + 1;
    }
    couriers.removeWhere((c) => c.lineId == lineId);
    lines.removeWhere((l) => l.id == lineId);

    if (selectedLineId == lineId) {
      selectedLineId = lines.isNotEmpty ? lines.first.id : null;
    }
    notifyListeners();
  }

  void restartGame() {
    nodes.clear();
    lines.clear();
    couriers.clear();
    trafficJams.clear();
    _unlockedMilestones.clear();

    courierReserve = {
      CourierType.foot: 2,
      CourierType.bike: 2,
      CourierType.auto: 1,
    };

    maxLines = 3;
    score = 0;
    totalDeliveries = 0;
    isGameOver = false;
    timeMultiplier = 1.0;
    gameClock.day = 1;
    gameClock.timeInMinutes = 8.0 * 60.0;
    _orderSpawnTimer = 0.0;
    _trafficJamSpawnTimer = 0.0;
    selectedLineId = null;
    bannerMessage = null;

    _initMap();
    notifyListeners();
  }

  void _onTick(Duration elapsed) {
    if (_lastTime == Duration.zero) {
      _lastTime = elapsed;
      return;
    }

    final double realDt = (elapsed - _lastTime).inMicroseconds / 1000000.0;
    _lastTime = elapsed;

    if (_bannerTimer > 0) {
      _bannerTimer -= realDt;
      if (_bannerTimer <= 0) {
        bannerMessage = null;
      }
    }

    if (isGameOver) {
      notifyListeners();
      return;
    }

    // Если игра на паузе, анимации интерфейса продолжаются, но время симуляции не идет
    if (timeMultiplier == 0.0) {
      notifyListeners();
      return;
    }

    final double simDt = realDt * timeMultiplier;

    // Продвижение игровых часов (1 реальная секунда = 10 игровых минут)
    gameClock.advance(realDt, timeMultiplier);

    _updateSpawns(simDt);
    _updateOverloadTimers(simDt);
    _updateTrafficJams(simDt);
    _updateCouriers(simDt);

    notifyListeners();
  }

  void _updateSpawns(double simDt) {
    _orderSpawnTimer += simDt;

    // В пиковые часы (18:00 - 21:00) или выходные дни объем заказов удваивается (интервал 2.0с вместо 4.0с)
    final double spawnInterval = gameClock.isRushHour ? 2.0 : 4.0;

    if (_orderSpawnTimer >= spawnInterval) {
      _orderSpawnTimer = 0.0;
      final districts = nodes.where((n) => n.type == NodeType.district).toList();
      final restaurants = nodes.where((n) => n.type == NodeType.restaurant).toList();

      if (districts.isNotEmpty && restaurants.isNotEmpty) {
        final targetDistrict = districts[_rnd.nextInt(districts.length)];

        // Выбираем форму, которую производит хотя бы один доступный ресторан
        final availableShapes = restaurants.map((r) => r.shapeId).toSet().toList();
        final requestedShape = availableShapes[_rnd.nextInt(availableShapes.length)];

        // Добавляем заказ в район
        targetDistrict.waitingOrders.add(requestedShape);
      }
    }
  }

  void _updateOverloadTimers(double simDt) {
    for (final node in nodes.where((n) => n.type == NodeType.district)) {
      // Вместимость района — до 8 заказов (сетка 2х4). При появлении 9-го заказа включается 30с таймер коллапса
      if (node.isOverloaded) {
        node.overloadTimer -= simDt;
        if (node.overloadTimer <= 0.0) {
          node.overloadTimer = 0.0;
          isGameOver = true;
          _showBanner('КОЛЛАПС: Район перегружен заказами!');
        }
      } else {
        node.overloadTimer = 30.0; // Сброс таймера при возврате в норму (<= 8 заказов)
      }
    }
  }

  void _updateTrafficJams(double simDt) {
    // Обновление оставшегося времени дорожных работ
    for (int i = trafficJams.length - 1; i >= 0; i--) {
      trafficJams[i].remainingSeconds -= simDt;
      if (trafficJams[i].remainingSeconds <= 0) {
        trafficJams.removeAt(i);
      }
    }

    // Синхронизация флагов пробок на узлах
    for (final node in nodes) {
      node.hasTrafficJam = trafficJams.any((jam) =>
          (jam.p1 == node.gridPos) || (jam.p2 == node.gridPos));
    }

    // Случайное появление дорожных заторов каждые 15-20 секунд (максимум 3 одновременно)
    _trafficJamSpawnTimer += simDt;
    if (_trafficJamSpawnTimer >= 18.0) {
      _trafficJamSpawnTimer = 0.0;
      if (trafficJams.length < 3) {
        _spawnRandomTrafficJam();
      }
    }
  }

  void _spawnRandomTrafficJam() {
    // Ищем случайное валидное ребро графа
    final List<TrafficJam> candidates = [];
    for (int x = 0; x < CityGraph.cols; x++) {
      for (int y = 0; y < CityGraph.rows; y++) {
        final p1 = GridPoint(x, y);
        for (final p2 in CityGraph.getNeighbors(p1)) {
          if (p1.x < p2.x || (p1.x == p2.x && p1.y < p2.y)) {
            final alreadyExists = trafficJams.any((j) => j.matchesEdge(p1, p2));
            if (!alreadyExists) {
              candidates.add(TrafficJam(p1: p1, p2: p2, remainingSeconds: 25.0, totalSeconds: 25.0));
            }
          }
        }
      }
    }

    if (candidates.isNotEmpty) {
      trafficJams.add(candidates[_rnd.nextInt(candidates.length)]);
    }
  }

  bool _isCourierInJam(Courier courier, RouteLine line) {
    if (line.gridPath.length < 2) return false;

    // Определяем отрезок дороги, на котором сейчас находится курьер
    int edgeIndex = (courier.distance / CityGraph.spacing).floor();
    if (edgeIndex < 0) edgeIndex = 0;
    if (edgeIndex >= line.gridPath.length - 1) edgeIndex = line.gridPath.length - 2;

    final p1 = line.gridPath[edgeIndex];
    final p2 = line.gridPath[edgeIndex + 1];

    return trafficJams.any((j) => j.matchesEdge(p1, p2));
  }

  void _updateCouriers(double simDt) {
    for (final courier in couriers) {
      final lineMatches = lines.where((l) => l.id == courier.lineId);
      if (lineMatches.isEmpty) continue;
      final line = lineMatches.first;

      final metricsList = line.path.computeMetrics().toList();
      if (metricsList.isEmpty) continue;

      final pathLength = metricsList.first.length;
      if (pathLength <= 0) continue;

      // Применяем штраф скорости, если на участке дороги пробка / ремонтные работы
      final bool inJam = _isCourierInJam(courier, line);
      final double jamMultiplier = inJam ? courier.jamPenalty : 1.0;

      // d_new = d_old +- (V_base * M_jam * dt)
      final double deltaDistance = courier.baseSpeed * jamMultiplier * simDt;
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

      // Проверка прибытия курьера на узел через предрассчитанный кэш дистанций (nodeDistancesCache)
      line.nodeDistancesCache.forEach((nodeId, nodeDist) {
        final bool crossedForward = courier.movingForward &&
            prevDist <= nodeDist &&
            courier.distance >= nodeDist;
        final bool crossedBackward = !courier.movingForward &&
            prevDist >= nodeDist &&
            courier.distance <= nodeDist;

        if (crossedForward || crossedBackward) {
          final targetNodeMatch = nodes.where((n) => n.id == nodeId);
          if (targetNodeMatch.isNotEmpty) {
            _processNodeInteraction(courier, line, targetNodeMatch.first);
          }
        }
      });
    }
  }

  // ПРАВИЛО ПРЯМОЙ ДОСТАВКИ (БЕЗ ПЕРЕСАДОК)
  void _processNodeInteraction(Courier courier, RouteLine line, Node node) {
    if (node.type == NodeType.restaurant) {
      // Ищем, есть ли на этой конкретной линии районы, которым требуется форма данного ресторана
      final List<ShapeId> lineDemands = [];
      for (final dId in line.connectedNodeIds) {
        final dNode = nodes.where((n) => n.id == dId).firstOrNull;
        if (dNode != null && dNode.type == NodeType.district) {
          lineDemands.addAll(dNode.waitingOrders);
        }
      }

      final int totalNeededOnLine = lineDemands.where((s) => s == node.shapeId).length;
      int currentlyCarrying = courier.cargo.where((s) => s == node.shapeId).length;

      // Забираем заказ из ресторана ТОЛЬКО если линия напрямую ведет в район с такой потребностью
      while (courier.cargo.length < courier.capacity && currentlyCarrying < totalNeededOnLine) {
        courier.cargo.add(node.shapeId);
        currentlyCarrying++;
      }
    } else if (node.type == NodeType.district) {
      // Разгружаем только те заказы, которые ожидает этот район
      final List<ShapeId> deliveredItems = [];
      for (final item in courier.cargo) {
        if (node.waitingOrders.contains(item)) {
          node.waitingOrders.remove(item);
          deliveredItems.add(item);
          score++;
          totalDeliveries++;
          _checkProgression();
        }
      }

      for (final item in deliveredItems) {
        courier.cargo.remove(item);
      }
    }
  }

  // Прогрессия: разблокировка новых линий, курьеров и районов
  void _checkProgression() {
    if (totalDeliveries >= 10 && !_unlockedMilestones.contains(10)) {
      _unlockedMilestones.add(10);
      courierReserve[CourierType.bike] = (courierReserve[CourierType.bike] ?? 0) + 1;
      _showBanner('🎉 Награда: +1 Велокурьер в резерв!');
    }

    if (totalDeliveries >= 15 && !_unlockedMilestones.contains(15)) {
      _unlockedMilestones.add(15);
      maxLines = 4;
      // Добавляем новые точки на карту
      nodes.add(Node(
        id: 'r4',
        gridPos: const GridPoint(1, 13),
        type: NodeType.restaurant,
        shapeId: ShapeId.square,
      ));
      nodes.add(Node(
        id: 'd4',
        gridPos: const GridPoint(6, 9),
        type: NodeType.district,
        shapeId: ShapeId.triangle,
      ));
      _showBanner('🚀 Прогресс: Открыт 4-й слот линии + новые районы города!');
    }

    if (totalDeliveries >= 25 && !_unlockedMilestones.contains(25)) {
      _unlockedMilestones.add(25);
      courierReserve[CourierType.auto] = (courierReserve[CourierType.auto] ?? 0) + 1;
      _showBanner('🚗 Награда: +1 Автомобиль курьера!');
    }

    if (totalDeliveries >= 35 && !_unlockedMilestones.contains(35)) {
      _unlockedMilestones.add(35);
      maxLines = 5;
      nodes.add(Node(
        id: 'r5',
        gridPos: const GridPoint(4, 1),
        type: NodeType.restaurant,
        shapeId: ShapeId.circle,
      ));
      nodes.add(Node(
        id: 'd5',
        gridPos: const GridPoint(0, 7),
        type: NodeType.district,
        shapeId: ShapeId.square,
      ));
      _showBanner('🌟 Прогресс: Открыт 5-й слот линии + новые заказы!');
    }

    if (totalDeliveries >= 50 && !_unlockedMilestones.contains(50)) {
      _unlockedMilestones.add(50);
      courierReserve[CourierType.foot] = (courierReserve[CourierType.foot] ?? 0) + 1;
      courierReserve[CourierType.bike] = (courierReserve[CourierType.bike] ?? 0) + 1;
      _showBanner('🏆 Награда: +1 Пеший и +1 Велокурьер!');
    }

    if (totalDeliveries >= 70 && !_unlockedMilestones.contains(70)) {
      _unlockedMilestones.add(70);
      maxLines = 6;
      courierReserve[CourierType.auto] = (courierReserve[CourierType.auto] ?? 0) + 1;
      _showBanner('👑 Мастер логистики: 6-й слот линии + Автомобиль!');
    }
  }

  // --- ЖЕСТЫ И РЕДАКТИРОВАНИЕ ЛИНИЙ НА ЛЕТУ (Mini Metro style) ---

  void onPanStart(DragStartDetails details) {
    if (isGameOver) return;

    final gp = CityGraph.getNearestGridPoint(details.localPosition);
    if (gp == null) return;

    // 1. Проверяем, нажал ли пользователь на конечную точку существующей линии (для ее продления/редактирования)
    for (final line in lines) {
      if (line.gridPath.isNotEmpty) {
        if (line.gridPath.first == gp) {
          isDrawing = true;
          editingLineId = line.id;
          isExtendingFromStart = true;
          currentDrawingPath = List.from(line.gridPath.reversed);
          notifyListeners();
          return;
        } else if (line.gridPath.last == gp) {
          isDrawing = true;
          editingLineId = line.id;
          isExtendingFromStart = false;
          currentDrawingPath = List.from(line.gridPath);
          notifyListeners();
          return;
        }
      }
    }

    // 2. Если нажал на узел (или рядом) и есть свободный слот линии — начинаем новую линию
    final nodeMatch = nodes.where((n) => n.gridPos == gp);
    if (nodeMatch.isNotEmpty && lines.length < maxLines) {
      isDrawing = true;
      editingLineId = null;
      currentDrawingPath = [gp];
      notifyListeners();
      return;
    }

    // 3. Если нажал на свободную клетку сетки при наличии слотов — разрешаем начать рисовать оттуда
    if (lines.length < maxLines) {
      isDrawing = true;
      editingLineId = null;
      currentDrawingPath = [gp];
      notifyListeners();
    }
  }

  void onPanUpdate(DragUpdateDetails details) {
    if (!isDrawing || currentDrawingPath.isEmpty) return;

    final gp = CityGraph.getNearestGridPoint(details.localPosition);
    if (gp == null || gp == currentDrawingPath.last) return;

    // Шаг назад по нарисованной линии отменяет последний сегмент
    if (currentDrawingPath.length > 1 && gp == currentDrawingPath[currentDrawingPath.length - 2]) {
      currentDrawingPath.removeLast();
      notifyListeners();
      return;
    }

    // Если соседняя клетка доступна напрямую по графу улиц
    if (CityGraph.isValidEdge(currentDrawingPath.last, gp)) {
      if (!currentDrawingPath.contains(gp)) {
        currentDrawingPath.add(gp);
        notifyListeners();
      }
    } else {
      // Иначе соединяем через BFS-поиск пути по графу дорог!
      final subPath = CityGraph.findPath(currentDrawingPath.last, gp);
      if (subPath != null && subPath.length > 1) {
        for (final pt in subPath.skip(1)) {
          if (!currentDrawingPath.contains(pt)) {
            currentDrawingPath.add(pt);
          }
        }
        notifyListeners();
      }
    }
  }

  void onPanEnd(DragEndDetails details) {
    if (isDrawing && currentDrawingPath.length > 1) {
      // Определяем все узлы, через которые проходит нарисованный путь
      final List<String> connectedIds = [];
      int lastNodeIndex = -1;

      for (int i = 0; i < currentDrawingPath.length; i++) {
        final gp = currentDrawingPath[i];
        final nodeMatch = nodes.where((n) => n.gridPos == gp).firstOrNull;
        if (nodeMatch != null) {
          if (!connectedIds.contains(nodeMatch.id)) {
            connectedIds.add(nodeMatch.id);
          }
          lastNodeIndex = i;
        }
      }

      // Линия действительна, если соединяет хотя бы 2 узла
      if (connectedIds.length >= 2 && lastNodeIndex > 0) {
        // Обрезаем лишний хвост после последнего узла
        final finalGridPath = currentDrawingPath.sublist(0, lastNodeIndex + 1);
        final pathResult = CityGraph.buildVisualPath(finalGridPath, nodes);

        if (editingLineId != null) {
          // Обновляем отредактированную существующую линию
          final lineIdx = lines.indexWhere((l) => l.id == editingLineId);
          if (lineIdx != -1) {
            final oldLine = lines[lineIdx];
            lines[lineIdx] = oldLine.copyWith(
              gridPath: List.from(finalGridPath),
              connectedNodeIds: connectedIds,
              path: pathResult.path,
              nodeDistancesCache: pathResult.nodeDistancesCache,
            );

            // Клампим дистанции курьеров на этой линии к новой длине
            final metrics = pathResult.path.computeMetrics().toList();
            final double newLen = metrics.isNotEmpty ? metrics.first.length : 0.0;
            for (final c in couriers.where((c) => c.lineId == editingLineId)) {
              if (c.distance > newLen) c.distance = newLen;
            }
          }
        } else if (lines.length < maxLines) {
          // Создаем новую линию
          final newLineId = 'line_${DateTime.now().millisecondsSinceEpoch}';
          final lineIdx = lines.length;
          final color = _linePalette[lineIdx % _linePalette.length];

          lines.add(RouteLine(
            id: newLineId,
            color: color,
            gridPath: List.from(finalGridPath),
            connectedNodeIds: connectedIds,
            path: pathResult.path,
            nodeDistancesCache: pathResult.nodeDistancesCache,
          ));

          selectedLineId = newLineId;

          // Автоматически назначаем первого доступного курьера из резерва (велосипед -> авто -> пеший)
          if ((courierReserve[CourierType.bike] ?? 0) > 0) {
            assignCourierToLine(newLineId, CourierType.bike);
          } else if ((courierReserve[CourierType.auto] ?? 0) > 0) {
            assignCourierToLine(newLineId, CourierType.auto);
          } else if ((courierReserve[CourierType.foot] ?? 0) > 0) {
            assignCourierToLine(newLineId, CourierType.foot);
          }
        }
      }
    }

    isDrawing = false;
    editingLineId = null;
    isExtendingFromStart = false;
    currentDrawingPath.clear();
    notifyListeners();
  }

  void _initMap() {
    nodes = [
      // Рестораны (генераторы еды определенных форм)
      Node(id: 'r1', gridPos: const GridPoint(1, 2), type: NodeType.restaurant, shapeId: ShapeId.square),
      Node(id: 'r2', gridPos: const GridPoint(5, 4), type: NodeType.restaurant, shapeId: ShapeId.triangle),
      Node(id: 'r3', gridPos: const GridPoint(3, 11), type: NodeType.restaurant, shapeId: ShapeId.circle),

      // Жилые районы (пункты назначения, запрашивающие конкретные формы)
      Node(id: 'd1', gridPos: const GridPoint(6, 1), type: NodeType.district, shapeId: ShapeId.circle),
      Node(id: 'd2', gridPos: const GridPoint(2, 6), type: NodeType.district, shapeId: ShapeId.triangle),
      Node(id: 'd3', gridPos: const GridPoint(5, 13), type: NodeType.district, shapeId: ShapeId.square),
    ];
  }
}
