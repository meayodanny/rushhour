import 'dart:ui';
import 'package:flutter/material.dart';

enum NodeType { restaurant, district }
enum ShapeId { square, triangle, circle }
enum CourierType { foot, bike, auto }

class GridPoint {
  final int x;
  final int y;
  const GridPoint(this.x, this.y);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is GridPoint && other.x == x && other.y == y);

  @override
  int get hashCode => x.hashCode ^ (y.hashCode << 16);

  @override
  String toString() => '($x, $y)';
}

class Node {
  final String id;
  final GridPoint gridPos;
  final NodeType type;
  final ShapeId shapeId;
  List<ShapeId> waitingOrders;
  double overloadTimer; // 30-секундный таймер критического перегруза
  bool hasTrafficJam;

  Node({
    required this.id,
    required this.gridPos,
    required this.type,
    required this.shapeId,
    List<ShapeId>? waitingOrders,
    this.overloadTimer = 30.0,
    this.hasTrafficJam = false,
  }) : waitingOrders = waitingOrders ?? [];

  bool get isOverloaded => waitingOrders.length >= 9;
}

class RouteLine {
  final String id;
  final Color color;
  final List<GridPoint> gridPath;
  final List<String> connectedNodeIds;
  final Path path;
  final Map<String, double> nodeDistancesCache;

  RouteLine({
    required this.id,
    required this.color,
    required this.gridPath,
    required this.connectedNodeIds,
    required this.path,
    required this.nodeDistancesCache,
  });

  RouteLine copyWith({
    String? id,
    Color? color,
    List<GridPoint>? gridPath,
    List<String>? connectedNodeIds,
    Path? path,
    Map<String, double>? nodeDistancesCache,
  }) {
    return RouteLine(
      id: id ?? this.id,
      color: color ?? this.color,
      gridPath: gridPath ?? this.gridPath,
      connectedNodeIds: connectedNodeIds ?? this.connectedNodeIds,
      path: path ?? this.path,
      nodeDistancesCache: nodeDistancesCache ?? this.nodeDistancesCache,
    );
  }
}

class Courier {
  final String id;
  String lineId;
  final CourierType type;
  double distance;
  bool movingForward;
  List<ShapeId> cargo;

  Courier({
    required this.id,
    required this.lineId,
    required this.type,
    this.distance = 0.0,
    this.movingForward = true,
    List<ShapeId>? cargo,
  }) : cargo = cargo ?? [];

  // Баланс скоростей: пеший 40, вело 60, авто 100
  double get baseSpeed {
    switch (type) {
      case CourierType.foot:
        return 40.0;
      case CourierType.bike:
        return 60.0;
      case CourierType.auto:
        return 100.0;
    }
  }

  // Вместимость: пеший 2, вело 3, авто 5
  int get capacity {
    switch (type) {
      case CourierType.foot:
        return 2;
      case CourierType.bike:
        return 3;
      case CourierType.auto:
        return 5;
    }
  }

  // Штраф при дорожных работах и заторах (множитель скорости)
  // Пеший: минимальный штраф (0.75 -> 75% скорости)
  // Велосипед: средний штраф (0.50 -> 50% скорости)
  // Автомобиль: тяжелый штраф (0.25 -> 25% скорости в пробке)
  double get jamPenalty {
    switch (type) {
      case CourierType.foot:
        return 0.75;
      case CourierType.bike:
        return 0.50;
      case CourierType.auto:
        return 0.25;
    }
  }
}

// Дорожный затор / ремонтные работы на ребре графа
class TrafficJam {
  final GridPoint p1;
  final GridPoint p2;
  double remainingSeconds;
  final double totalSeconds;

  TrafficJam({
    required this.p1,
    required this.p2,
    this.remainingSeconds = 25.0,
    this.totalSeconds = 25.0,
  });

  bool matchesEdge(GridPoint a, GridPoint b) {
    return (p1 == a && p2 == b) || (p1 == b && p2 == a);
  }
}

// Игровые часы и календарь
class GameClock {
  int day; // День (1, 2, 3...)
  double timeInMinutes; // Минуты с начала дня (0.0 .. 1440.0)

  GameClock({
    this.day = 1,
    this.timeInMinutes = 8.0 * 60.0, // Начинаем в 08:00
  });

  int get hour => (timeInMinutes ~/ 60) % 24;
  int get minute => (timeInMinutes % 60).toInt();

  // 1 реальная секунда = 10 игровых минут
  void advance(double realDeltaSeconds, double multiplier) {
    if (multiplier <= 0) return;
    timeInMinutes += realDeltaSeconds * 10.0 * multiplier;
    while (timeInMinutes >= 24 * 60) {
      timeInMinutes -= 24 * 60;
      day++;
    }
  }

  String get dayName {
    final days = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    return days[(day - 1) % 7];
  }

  bool get isWeekend => ((day - 1) % 7) >= 5;

  // Вечерний тайм-слот: 18:00 - 21:00
  bool get isEveningPeak => hour >= 18 && hour < 21;

  // Пиковые часы или выходные удваивают объем заказов
  bool get isRushHour => isEveningPeak || isWeekend;

  String get formattedTime {
    final h = hour.toString().padLeft(2, '0');
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
