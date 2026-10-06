import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

/// Requirement 43: the single source of truth for geographic -> world space.
///
/// Every part of the project (road rendering, building/river geometry,
/// hit-testing & snapping while drawing lines, pathfinding distances, camera
/// framing) MUST go through this class. Duplicating the formula anywhere else
/// is what caused roads to be drawn in one place while the finger/snap logic
/// "saw" them somewhere else.
///
/// The projection is a plain equidistant (equirectangular) projection around a
/// per-city fixed anchor `lat0/lng0`:
///
///   xGeo = (lng - lng0) * cos(lat0)
///   yGeo = (lat0 - lat)
///
/// Both axes are then scaled by the *same* [scale] factor and translated by
/// [origin], so the mapping is a similarity transform: angles and shape are
/// preserved and a straight road stays straight, at the same screen place, for
/// drawing and for logic alike.
@immutable
class GeoProjection {
  const GeoProjection({
    required this.lat0,
    required this.lng0,
    required this.scale,
    required this.origin,
  });

  /// Fixed anchor latitude of the city (degrees).
  final double lat0;

  /// Fixed anchor longitude of the city (degrees).
  final double lng0;

  /// Uniform scale, world pixels per degree of latitude. Identical on both
  /// axes on purpose - an anisotropic fit would distort angles.
  final double scale;

  /// World-space position of the anchor (`lat0`, `lng0`).
  final Offset origin;

  /// Builds the projection for a city: anchored at the centre of [bounds] and
  /// scaled so the whole bounding box fits inside [worldSize] minus [padding],
  /// centred, without ever stretching one axis more than the other.
  factory GeoProjection.fromBounds(
    GeoSpan bounds,
    Size worldSize, {
    double padding = 48.0,
  }) {
    final lat0 = (bounds.minLat + bounds.maxLat) / 2;
    final lng0 = (bounds.minLng + bounds.maxLng) / 2;
    final cosLat0 = math.cos(lat0 * math.pi / 180);

    final geoWidth = math.max(1e-9, (bounds.maxLng - bounds.minLng) * cosLat0.abs());
    final geoHeight = math.max(1e-9, bounds.maxLat - bounds.minLat);

    final effectiveW = math.max(1.0, worldSize.width - 2 * padding);
    final effectiveH = math.max(1.0, worldSize.height - 2 * padding);

    final scale = math.min(effectiveW / geoWidth, effectiveH / geoHeight);

    // Centre the projected bounding box inside the world rect.
    return GeoProjection(
      lat0: lat0,
      lng0: lng0,
      scale: scale,
      origin: Offset(worldSize.width / 2, worldSize.height / 2),
    );
  }

  /// Geographic coordinate -> world space. The only allowed conversion.
  Offset project(double lat, double lng) {
    final cosLat0 = math.cos(lat0 * math.pi / 180);
    return Offset(
      origin.dx + (lng - lng0) * cosLat0 * scale,
      origin.dy + (lat0 - lat) * scale,
    );
  }

  /// Convenience for `[lat, lng]` pairs coming straight out of JSON.
  Offset projectPair(List<double> pair) => project(pair[0], pair[1]);

  /// World space -> geographic coordinate (exact inverse of [project]).
  /// Used by hit-testing/debug tooling that needs to report lat/lng.
  ({double lat, double lng}) unproject(Offset point) {
    final cosLat0 = math.cos(lat0 * math.pi / 180);
    return (
      lat: lat0 - (point.dy - origin.dy) / scale,
      lng: lng0 + (point.dx - origin.dx) / (cosLat0 * scale),
    );
  }

  /// Projects a geographic rectangle into a world-space [Rect].
  Rect projectSpan(GeoSpan span) {
    final topLeft = project(span.maxLat, span.minLng);
    final bottomRight = project(span.minLat, span.maxLng);
    return Rect.fromLTRB(
      math.min(topLeft.dx, bottomRight.dx),
      math.min(topLeft.dy, bottomRight.dy),
      math.max(topLeft.dx, bottomRight.dx),
      math.max(topLeft.dy, bottomRight.dy),
    );
  }

  /// World pixels per metre (approximate, valid near the anchor). Lets game
  /// logic reason about real distances without re-deriving the projection.
  double get pixelsPerMeter => scale / 111320.0;

  @override
  bool operator ==(Object other) =>
      other is GeoProjection &&
      other.lat0 == lat0 &&
      other.lng0 == lng0 &&
      other.scale == scale &&
      other.origin == origin;

  @override
  int get hashCode => Object.hash(lat0, lng0, scale, origin);

  @override
  String toString() =>
      'GeoProjection(lat0: $lat0, lng0: $lng0, scale: $scale, origin: $origin)';
}

/// Minimal geographic rectangle contract consumed by [GeoProjection].
/// `GeoBounds` in the city model implements it, so no second bounds type or
/// second formula is needed.
abstract class GeoSpan {
  double get minLat;
  double get maxLat;
  double get minLng;
  double get maxLng;
}
