import 'dart:math' as math;
import 'dart:ui';

import '../models/city.dart';

/// Requirement 46: the one and only authority on the question "does this road
/// cross water?".
///
/// Lines (and therefore courier routes) may only cross the river where the
/// city data says there is a real bridge, so every pathfinder / snap query has
/// to be able to ask this question. Since schemaVersion 3 stores water in two
/// different shapes, the check must look at **both**:
///
/// * [CityData.riverAreas] - wide stretches stored as polygons: a road crosses
///   when it reaches deeper than [toleranceMeters] inside the polygon, so a
///   road that merely grazes the shoreline (two data sources disagreeing by a
///   few centimetres) stays usable;
/// * [CityData.riverSegments] - narrow stretches stored as polylines: a road
///   crosses when it passes from one side of the polyline to the other, so a
///   crossing exactly through a vertex of the line is caught as well, while
///   running along or merely touching the line is not.
///
/// Only [RoadType.bridge] and [RoadType.ferry] edges are allowed to cross;
/// every other edge that crosses water is a "bridge in the wrong place" and
/// ends up in [blockedEdgeIds].
///
/// The projection (`GeoProjection`, Requirement 43) stays the single source of
/// truth for geometry: metre-based thresholds are converted through
/// [GeoProjection.pixelsPerMeter], so the same numbers mean the same physical
/// distance in every city.
class WaterCrossing {
  WaterCrossing(
    this.city, {
    this.toleranceMeters = 1.0,
    this.sampleStepMeters = 0.5,
  })  : assert(toleranceMeters > 0),
        assert(sampleStepMeters > 0),
        assert(sampleStepMeters <= toleranceMeters);

  final CityData city;

  /// How deep (in metres) a road has to reach into a water polygon before it
  /// counts as a crossing.
  final double toleranceMeters;

  /// Distance (in metres) between consecutive samples taken along a road when
  /// testing it against the water. It may never exceed [toleranceMeters],
  /// otherwise a thin crossing could be stepped over.
  final double sampleStepMeters;

  /// Ids of the road edges that may not be used as river crossings
  /// (Requirement 46). Computed once, lazily - the city map is immutable.
  late final Set<String> blockedEdgeIds = _computeBlockedEdgeIds();

  late final Rect _waterBounds = _computeWaterBounds();

  /// True when [edge] would carry a route across water outside a real bridge
  /// or ferry crossing.
  bool isForbiddenCrossing(RoadEdge edge) {
    if (edge.type == RoadType.bridge || edge.type == RoadType.ferry) return false;
    return crossesWater(edge.points);
  }

  /// True when the polyline (world coordinates) crosses the water of [city],
  /// checked against the filled [CityData.riverAreas] polygons **and** the
  /// [CityData.riverSegments] lines.
  bool crossesWater(List<Offset> worldPolyline) {
    if (worldPolyline.length < 2) return false;
    if (!city.hasWater) return false;

    final step = sampleStepMeters * city.projection.pixelsPerMeter;
    final tolerance = toleranceMeters * city.projection.pixelsPerMeter;
    if (step <= 0 || tolerance <= 0) return false;

    final bounds = _bounds(worldPolyline);
    if (!_rectsOverlap(bounds.inflate(tolerance), _waterBounds)) return false;

    final samples = _samples(worldPolyline, step);
    for (final segment in city.riverSegments) {
      if (_crossesLine(samples, segment, tolerance)) return true;
    }
    for (final area in city.riverAreas) {
      if (_crossesArea(samples, area, tolerance)) return true;
    }
    return false;
  }

  Set<String> _computeBlockedEdgeIds() {
    final blocked = <String>{};
    for (final edge in city.edges) {
      if (isForbiddenCrossing(edge)) blocked.add(edge.id);
    }
    return blocked;
  }

  Rect _computeWaterBounds() {
    final points = <Offset>[
      for (final segment in city.riverSegments) ...segment,
      for (final area in city.riverAreas) ...area,
    ];
    return points.isEmpty ? Rect.zero : _bounds(points);
  }

  /// Walks the polyline at [step] steps (never skipping the vertices).
  List<Offset> _samples(List<Offset> polyline, double step) {
    final samples = <Offset>[];
    for (var i = 0; i < polyline.length - 1; i++) {
      final a = polyline[i];
      final b = polyline[i + 1];
      final steps = math.max(1, ((b - a).distance / step).ceil());
      for (var k = 0; k < steps; k++) {
        samples.add(Offset.lerp(a, b, k / steps)!);
      }
      samples.add(b);
    }
    return samples;
  }

  // ---------------------------------------------------------------------------
  // Water areas (polygons)
  // ---------------------------------------------------------------------------

  bool _crossesArea(List<Offset> samples, List<Offset> ring, double tolerance) {
    if (ring.length < 3) return false;
    final ringBounds = _bounds(ring);
    for (final sample in samples) {
      if (!ringBounds.contains(sample)) continue;
      if (!_pointInPolygon(sample, ring)) continue;
      if (_distanceToRing(sample, ring) > tolerance) return true;
    }
    return false;
  }

  bool _pointInPolygon(Offset point, List<Offset> ring) {
    var inside = false;
    for (var i = 0, j = ring.length - 1; i < ring.length; j = i++) {
      final a = ring[i];
      final b = ring[j];
      if ((a.dy > point.dy) != (b.dy > point.dy) &&
          point.dx < (b.dx - a.dx) * (point.dy - a.dy) / (b.dy - a.dy) + a.dx) {
        inside = !inside;
      }
    }
    return inside;
  }

  double _distanceToRing(Offset point, List<Offset> ring) {
    var best = double.infinity;
    for (var i = 0; i < ring.length; i++) {
      best = math.min(best, _distanceToSegment(point, ring[i], ring[(i + 1) % ring.length]));
    }
    return best;
  }

  // ---------------------------------------------------------------------------
  // Water segments (polylines)
  // ---------------------------------------------------------------------------

  /// True when the road passes from one side of the water line to the other.
  ///
  /// Walking the samples (they are at most [sampleStepMeters] apart, so a real
  /// crossing is always seen) and comparing the side of the nearest segment is
  /// robust against crossings that land exactly on a vertex of the line -
  /// which a plain segment-intersection test would miss.
  bool _crossesLine(List<Offset> samples, List<Offset> feature, double tolerance) {
    if (feature.length < 2) return false;
    var lastSide = 0;
    for (final sample in samples) {
      final probe = _sideOfFeature(sample, feature);
      if (probe.distance > tolerance) {
        lastSide = 0;
        continue;
      }
      if (probe.side == 0) continue;
      if (lastSide != 0 && lastSide != probe.side) return true;
      lastSide = probe.side;
    }
    return false;
  }

  /// Distance to the closest point of [feature] plus which side of the
  /// closest segment the point is on (-1 / 0 / +1).
  ({double distance, int side}) _sideOfFeature(Offset point, List<Offset> feature) {
    var bestDistance = double.infinity;
    var side = 0;
    for (var i = 0; i < feature.length - 1; i++) {
      final a = feature[i];
      final b = feature[i + 1];
      final distance = _distanceToSegment(point, a, b);
      if (distance > bestDistance + _epsilon) continue;
      final cross = (b.dx - a.dx) * (point.dy - a.dy) - (b.dy - a.dy) * (point.dx - a.dx);
      final candidate = cross == 0
          ? 0
          : cross > 0
              ? 1
              : -1;
      if (distance < bestDistance - _epsilon || side == 0) {
        bestDistance = distance;
        side = candidate;
      }
    }
    return (distance: bestDistance, side: side);
  }

  /// Tolerance for comparing world distances (1/1000 of a pixel is far below
  /// anything the map can express).
  static const double _epsilon = 0.001;

  // ---------------------------------------------------------------------------
  // Shared helpers
  // ---------------------------------------------------------------------------

  static double _distanceToSegment(Offset point, Offset a, Offset b) {
    final delta = b - a;
    final lengthSquared = delta.dx * delta.dx + delta.dy * delta.dy;
    if (lengthSquared == 0) return (point - a).distance;
    final t = (((point.dx - a.dx) * delta.dx + (point.dy - a.dy) * delta.dy) / lengthSquared)
        .clamp(0.0, 1.0);
    return (point - Offset(a.dx + delta.dx * t, a.dy + delta.dy * t)).distance;
  }

  /// [Rect.overlaps] reports false for empty (zero width/height) rectangles,
  /// which real water geometry can be - a perfectly straight water line has a
  /// zero-height bounding box.
  static bool _rectsOverlap(Rect a, Rect b) =>
      a.right >= b.left && a.left <= b.right && a.bottom >= b.top && a.top <= b.bottom;

  static Rect _bounds(List<Offset> points) {
    var left = double.infinity;
    var top = double.infinity;
    var right = double.negativeInfinity;
    var bottom = double.negativeInfinity;
    for (final point in points) {
      left = math.min(left, point.dx);
      top = math.min(top, point.dy);
      right = math.max(right, point.dx);
      bottom = math.max(bottom, point.dy);
    }
    return Rect.fromLTRB(left, top, right, bottom);
  }
}
