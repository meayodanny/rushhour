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
  int get hashCode => x.hashCode ^ y.hashCode;
}

class Node {
  final String id;
  final GridPoint gridPos;
  final NodeType type;
  final ShapeId shapeId;
  List<ShapeId> waitingOrders;
  double overloadTimer;
  bool hasTrafficJam;

  Node({
    required this.id,
    required this.gridPos,
    required this.type,
    required this.shapeId,
    List<ShapeId>? waitingOrders,
    this.overloadTimer = 30.0, // Таймер критического перегруза[cite: 1]
    this.hasTrafficJam = false,
  }) : waitingOrders = waitingOrders ?? [];
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
}

class Courier {
  final String id;
  final String lineId;
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

  // Баланс скоростей и вместимости[cite: 1]
  double get baseSpeed {
    switch (type) {
      case CourierType.foot: return 40.0;
      case CourierType.bike: return 60.0;
      case CourierType.auto: return 100.0;
    }
  }

  int get capacity {
    switch (type) {
      case CourierType.foot: return 2;
      case CourierType.bike: return 3;
      case CourierType.auto: return 5;
    }
  }

  double get jamPenalty {
    switch (type) {
      case CourierType.foot: return 0.75; // -25%
      case CourierType.bike: return 0.50; // -50%
      case CourierType.auto: return 0.50; // -50%
    }
  }
}