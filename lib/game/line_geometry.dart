import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../models/city.dart';
import '../models/entities.dart';

/// Geometry shared by the renderer and hit testing.
class LineGeometry {
  LineGeometry(this.city, this.lines, {this.nodeForEntity});

  final CityData city;
  final List<DeliveryLine> lines;
  final String? Function(String)? nodeForEntity;

  static const double separation = 22;
  static const double nodeTaper = 34;

  List<DeliveryLine> linesOnEdge(String edgeId) => lines
      .where((DeliveryLine line) => line.edgeIds.contains(edgeId))
      .toList()
    ..sort((DeliveryLine a, DeliveryLine b) {
      final color = a.colorIndex.compareTo(b.colorIndex);
      return color != 0 ? color : a.id.compareTo(b.id);
    });

  int trackIndex(DeliveryLine line, String edgeId) {
    final shared = linesOnEdge(edgeId);
    final index = shared.indexWhere((DeliveryLine value) => value.id == line.id);
    return index < 0 ? 0 : index;
  }

  double trackOffset(DeliveryLine line, String edgeId) {
    final shared = linesOnEdge(edgeId);
    if (shared.length < 2) return 0;
    return (trackIndex(line, edgeId) - (shared.length - 1) / 2) * separation;
  }

  List<Offset> offsetRoutePoints(DeliveryLine line) =>
      offsetRoutePointsFor(line, (String id) => _nodeForEntity(id));

  List<Offset> routePoints(DeliveryLine line) =>
      routePointsFor(line, (String id) => _nodeForEntity(id));

  DeliveryLine? lineNear(Offset point, {double radius = 32}) {
    DeliveryLine? best;
    var bestDistance = radius;
    for (final line in lines) {
      final points = offsetRoutePoints(line);
      final distance = distanceToPolyline(point, points);
      if (distance <= bestDistance) {
        final currentBest = best;
        final orderedBefore = currentBest != null &&
            (line.colorIndex < currentBest.colorIndex ||
                (line.colorIndex == currentBest.colorIndex && line.id.compareTo(currentBest.id) < 0));
        if (currentBest == null || distance < bestDistance || orderedBefore) {
          best = line;
          bestDistance = distance;
        }
      }
    }
    return best;
  }

  static double distanceToPolyline(Offset point, List<Offset> points) {
    var best = double.infinity;
    for (var i = 1; i < points.length; i++) {
      best = math.min(best, distanceToSegment(point, points[i - 1], points[i]));
    }
    return best;
  }

  static double distanceToSegment(Offset point, Offset a, Offset b) {
    final delta = b - a;
    final lengthSquared = delta.dx * delta.dx + delta.dy * delta.dy;
    if (lengthSquared == 0) return (point - a).distance;
    final t = (((point.dx - a.dx) * delta.dx + (point.dy - a.dy) * delta.dy) /
            lengthSquared)
        .clamp(0.0, 1.0);
    final normalized = t.toDouble();
    return (point - Offset(a.dx + delta.dx * normalized, a.dy + delta.dy * normalized)).distance;
  }

  Offset pointOnRoute(DeliveryLine line, double progress) {
    final points = offsetRoutePoints(line);
    if (points.isEmpty) return Offset.zero;
    var length = 0.0;
    for (var i = 1; i < points.length; i++) {
      length += (points[i] - points[i - 1]).distance;
    }
    var target = progress.clamp(0.0, 1.0) * length;
    for (var i = 1; i < points.length; i++) {
      final segment = (points[i] - points[i - 1]).distance;
      if (target <= segment) {
        return Offset.lerp(points[i - 1], points[i], (target / math.max(1, segment)).toDouble())!;
      }
      target -= segment;
    }
    return points.last;
  }

  String? _nodeForEntity(String id) {
    final resolved = nodeForEntity?.call(id);
    if (resolved != null) return resolved;
    for (final restaurant in city.restaurantPois) {
      if (restaurant.id == id) return restaurant.nodeId;
    }
    for (final customer in city.customerPois) {
      if (customer.id == id) return customer.nodeId;
    }
    if (city.nodes.containsKey(id)) return id;
    return null;
  }

  List<Offset> offsetRoutePointsFor(DeliveryLine line, String? Function(String) nodeForEntity) {
    final result = <Offset>[];
    var current = nodeForEntity(line.stopIds.first);
    for (final edgeId in line.edgeIds) {
      final edge = city.edgeById(edgeId);
      if (edge == null) continue;
      final forward = edge.from == current;
      final canonical = _offsetEdge(edge.points, trackOffset(line, edge.id));
      final shifted = forward ? canonical : canonical.reversed.toList();
      if (result.isEmpty) {
        result.addAll(shifted);
      } else {
        result.addAll(shifted.skip(1));
      }
      current = forward ? edge.to : edge.from;
    }
    return result;
  }

  List<Offset> routePointsFor(DeliveryLine line, String? Function(String) nodeForEntity) {
    final result = <Offset>[];
    var current = nodeForEntity(line.stopIds.first);
    for (final edgeId in line.edgeIds) {
      final edge = city.edgeById(edgeId);
      if (edge == null) continue;
      final forward = edge.from == current;
      final points = forward ? edge.points : edge.points.reversed.toList();
      if (result.isEmpty) {
        result.addAll(points);
      } else {
        result.addAll(points.skip(1));
      }
      current = forward ? edge.to : edge.from;
    }
    return result;
  }

  List<Offset> _offsetEdge(List<Offset> points, double offset) {
    if (points.length < 2 || offset == 0) return List<Offset>.of(points);
    final lengths = <double>[0];
    for (var i = 1; i < points.length; i++) {
      lengths.add(lengths.last + (points[i] - points[i - 1]).distance);
    }
    final total = lengths.last;
    return List<Offset>.generate(points.length, (int i) {
      final previous = points[math.max(0, i - 1)];
      final next = points[math.min(points.length - 1, i + 1)];
      var tangent = next - previous;
      if (tangent.distance == 0) tangent = const Offset(1, 0);
      tangent = tangent / tangent.distance;
      final normal = Offset(-tangent.dy, tangent.dx);
      final fromEnd = total - lengths[i];
      final fade = _smoothStep((lengths[i] / nodeTaper).clamp(0.0, 1.0).toDouble()) *
          _smoothStep((fromEnd / nodeTaper).clamp(0.0, 1.0).toDouble());
      return points[i] + normal * offset * fade;
    });
  }

  double _smoothStep(double value) => value * value * (3 - 2 * value);

  /// Builds a smooth Path with rounded corner fillets for aesthetic drawing.
  static Path buildSmoothPath(List<Offset> points, {double cornerRadius = 14.0}) {
    final path = Path();
    if (points.isEmpty) return path;
    if (points.length == 1) {
      path.moveTo(points.first.dx, points.first.dy);
      return path;
    }
    if (points.length == 2) {
      path.moveTo(points.first.dx, points.first.dy);
      path.lineTo(points.last.dx, points.last.dy);
      return path;
    }

    path.moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length - 1; i++) {
      final pPrev = points[i - 1];
      final pCurr = points[i];
      final pNext = points[i + 1];

      final v1 = pCurr - pPrev;
      final v2 = pNext - pCurr;
      final len1 = v1.distance;
      final len2 = v2.distance;

      if (len1 < 1e-4 || len2 < 1e-4) {
        path.lineTo(pCurr.dx, pCurr.dy);
        continue;
      }

      final r = math.min(cornerRadius, math.min(len1 * 0.45, len2 * 0.45));
      final startFillet = pCurr - (v1 / len1) * r;
      final endFillet = pCurr + (v2 / len2) * r;

      path.lineTo(startFillet.dx, startFillet.dy);
      path.quadraticBezierTo(pCurr.dx, pCurr.dy, endFillet.dx, endFillet.dy);
    }
    path.lineTo(points.last.dx, points.last.dy);
    return path;
  }
}
