import 'dart:math' as math;
import 'dart:ui';

import '../models/city.dart';
import '../models/entities.dart';

/// Geometry shared by the renderer and hit testing. Keeping the offset
/// calculation here is important: a courier and the line it belongs to must
/// always occupy the same visual track.
class LineGeometry {
  LineGeometry(this.city, this.lines, {this.nodeForEntity});

  final CityData city;
  final List<DeliveryLine> lines;
  final String? Function(String)? nodeForEntity;

  // World units: at the initial phone fit this is roughly 8–10 physical
  // pixels, leaving a visible paper gap between 2–3 coloured tracks.
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

  /// Returns a route with a separate, gently tapered track for every edge.
  /// Offsets reach zero close to graph nodes, so lines meet cleanly instead of
  /// making a sharp dog-leg at a junction.
  List<Offset> offsetRoutePoints(DeliveryLine line) {
    final result = <Offset>[];
    var current = _nodeForEntity(line.stopIds.first);
    for (final edgeId in line.edgeIds) {
      final edge = city.edgeById(edgeId);
      if (edge == null) continue;
      final forward = edge.from == current;
      // Compute the normal in canonical from -> to space, then reverse the
      // shifted points for reverse traversal. Opposite-direction routes thus
      // still occupy distinct, stable tracks.
      final canonical = _offsetEdge(edge.points, trackOffset(line, edge.id));
      final shifted = forward ? canonical : canonical.reversed.toList();
      if (result.isEmpty) {
        result.addAll(shifted);
      } else {
        // Both adjacent edges taper to their common node. Keeping one copy
        // prevents a microscopic cap/loop from appearing at that node.
        result.addAll(shifted.skip(1));
      }
      current = forward ? edge.to : edge.from;
    }
    return result;
  }

  List<Offset> routePoints(DeliveryLine line) {
    final result = <Offset>[];
    var current = _nodeForEntity(line.stopIds.first);
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

  DeliveryLine? lineNear(Offset point, {double radius = 24}) {
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

  // Explicit lookup is useful to the controller for active entities while
  // retaining a small, dependency-free geometry helper for the painter.
  List<Offset> offsetRoutePointsFor(DeliveryLine line, String? Function(String) nodeForEntity) {
    final result = <Offset>[];
    var current = nodeForEntity(line.stopIds.first);
    for (final edgeId in line.edgeIds) {
      final edge = city.edgeById(edgeId);
      if (edge == null) continue;
      final forward = edge.from == current;
      // Compute the normal in canonical from -> to space, then reverse the
      // shifted points for reverse traversal. Opposite-direction routes thus
      // still occupy distinct, stable tracks.
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

}
