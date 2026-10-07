#!/usr/bin/env python3
"""Reference implementation of the Requirement 46 water-crossing check.

The game itself decides which streets may cross the river in
``lib/game/water_crossing.dart``. Map tooling has to answer the same question
(schemaVersion 3 stores water both as ``river.areas`` polygons *and* as
``river.segments`` polylines), so this module is a line-by-line mirror of that
Dart class, including the constants:

* ``TOLERANCE_M`` - how deep a road has to reach into a water polygon (or how
  far it has to pass the shoreline) before it counts as a crossing;
* ``SAMPLE_STEP_M`` - sampling step along the road when walking it through the
  water (never larger than the tolerance).

Keep the two implementations in sync: ``tools/seed_rivergate_pois.py`` uses
this module to keep every seeded POI on the reachable side of the river, and
``test/water_crossing_test.dart`` pins the Dart implementation to the numbers
this module produces for the checked-in map.
"""

import json
import math

TOLERANCE_M = 1.0
SAMPLE_STEP_M = 0.5

METRES_PER_DEGREE = 111320.0


class Projection:
    """Equidistant projection of ``lib/core/geo_projection.dart``."""

    def __init__(self, bounds, world_width=860.0, world_height=1320.0, padding=48.0):
        self.lat0 = (bounds["minLat"] + bounds["maxLat"]) / 2
        self.lng0 = (bounds["minLng"] + bounds["maxLng"]) / 2
        self.cos_lat0 = math.cos(math.radians(self.lat0))
        geo_width = max(1e-9, (bounds["maxLng"] - bounds["minLng"]) * abs(self.cos_lat0))
        geo_height = max(1e-9, bounds["maxLat"] - bounds["minLat"])
        scale = min(
            max(1.0, world_width - 2 * padding) / geo_width,
            max(1.0, world_height - 2 * padding) / geo_height,
        )
        self.scale = scale
        self.origin = (world_width / 2, world_height / 2)

    @property
    def pixels_per_meter(self):
        return self.scale / METRES_PER_DEGREE

    def project(self, lat, lng):
        return (
            self.origin[0] + (lng - self.lng0) * self.cos_lat0 * self.scale,
            self.origin[1] + (self.lat0 - lat) * self.scale,
        )


def _lerp(a, b, t):
    return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)


def _distance_to_segment(point, a, b):
    dx = b[0] - a[0]
    dy = b[1] - a[1]
    length_squared = dx * dx + dy * dy
    if length_squared == 0:
        return math.hypot(point[0] - a[0], point[1] - a[1])
    t = max(0.0, min(1.0, ((point[0] - a[0]) * dx + (point[1] - a[1]) * dy) / length_squared))
    return math.hypot(point[0] - (a[0] + dx * t), point[1] - (a[1] + dy * t))


def _distance_to_ring(point, ring):
    return min(_distance_to_segment(point, ring[i], ring[(i + 1) % len(ring)]) for i in range(len(ring)))


def _point_in_polygon(point, ring):
    x, y = point
    inside = False
    for i in range(len(ring)):
        a = ring[i]
        b = ring[(i + 1) % len(ring)]
        if (a[1] > y) != (b[1] > y) and x < (b[0] - a[0]) * (y - a[1]) / (b[1] - a[1]) + a[0]:
            inside = not inside
    return inside


def _bounds(points):
    xs = [p[0] for p in points]
    ys = [p[1] for p in points]
    return (min(xs), min(ys), max(xs), max(ys))


def _samples(polyline, step):
    out = []
    for i in range(len(polyline) - 1):
        a, b = polyline[i], polyline[i + 1]
        steps = max(1, math.ceil(math.dist(a, b) / step))
        for k in range(steps):
            out.append(_lerp(a, b, k / steps))
        out.append(b)
    return out


def _side_of_feature(point, feature):
    best_distance = float("inf")
    side = 0
    for i in range(len(feature) - 1):
        a, b = feature[i], feature[i + 1]
        distance = _distance_to_segment(point, a, b)
        if distance > best_distance + 1e-3:
            continue
        cross = (b[0] - a[0]) * (point[1] - a[1]) - (b[1] - a[1]) * (point[0] - a[0])
        candidate = 0 if cross == 0 else (1 if cross > 0 else -1)
        if distance < best_distance - 1e-3 or side == 0:
            best_distance = distance
            side = candidate
    return best_distance, side


class WaterCrossing:
    """Mirror of ``lib/game/water_crossing.dart`` for map tooling."""

    def __init__(self, areas, segments, pixels_per_meter,
                 tolerance_m=TOLERANCE_M, sample_step_m=SAMPLE_STEP_M):
        self.areas = areas
        self.segments = segments
        self.tolerance = tolerance_m * pixels_per_meter
        self.step = sample_step_m * pixels_per_meter
        points = [p for feature in segments for p in feature] + [p for area in areas for p in area]
        self.water_bounds = _bounds(points) if points else None

    def crosses(self, polyline):
        if len(polyline) < 2 or self.water_bounds is None:
            return False
        west, north, east, south = _bounds(polyline)
        tol = self.tolerance
        if not (east + tol >= self.water_bounds[0] and west - tol <= self.water_bounds[2]
                and south + tol >= self.water_bounds[1] and north - tol <= self.water_bounds[3]):
            return False
        samples = _samples(polyline, self.step)
        for feature in self.segments:
            if len(feature) < 2:
                continue
            last_side = 0
            for sample in samples:
                distance, side = _side_of_feature(sample, feature)
                if distance > tol:
                    last_side = 0
                    continue
                if side == 0:
                    continue
                if last_side != 0 and last_side != side:
                    return True
                last_side = side
        for ring in self.areas:
            if len(ring) < 3:
                continue
            ring_bounds = _bounds(ring)
            for sample in samples:
                if not (ring_bounds[0] <= sample[0] < ring_bounds[2]
                        and ring_bounds[1] <= sample[1] < ring_bounds[3]):
                    continue
                if not _point_in_polygon(sample, ring):
                    continue
                if _distance_to_ring(sample, ring) > tol:
                    return True
        return False


def project_water(data, projection):
    """World-space water features of a city map.

    The fields are read exactly the way ``CityData.fromJson`` reads them:
    ``river.segments`` are polylines (narrow stretches), ``river.areas`` are
    closed polygons (wide stretches / water bodies).
    """
    river = data.get("river") or {}
    areas = []
    segments = []
    for raw in river.get("segments") or []:
        points = [projection.project(float(p[0]), float(p[1])) for p in raw]
        if len(points) < 2:
            continue
        segments.append(points)
    for raw in river.get("areas") or []:
        points = [projection.project(float(p[0]), float(p[1])) for p in raw]
        if len(points) < 3:
            continue
        areas.append(points)
    return areas, segments


def world_nodes(data, projection):
    return {
        node["id"]: projection.project(
            float(node["lat"]), float(node.get("lng", node.get("lon")))
        )
        for node in data["roads"]["nodes"]
    }


def edge_world_points(edge, world_by_node, projection):
    if edge.get("polyline"):
        return [projection.project(float(p[0]), float(p[1])) for p in edge["polyline"]]
    return [world_by_node[edge["from"]], world_by_node[edge["to"]]]


def blocked_edge_ids(data, projection=None):
    """Ids of edges that cross water without being a bridge (Requirement 46)."""
    projection = projection or Projection(data["boundingBox"])
    areas, segments = project_water(data, projection)
    crossing = WaterCrossing(areas, segments, projection.pixels_per_meter)
    world = world_nodes(data, projection)
    blocked = set()
    for edge in data["roads"]["edges"]:
        if edge.get("type", "street") in ("bridge", "ferry"):
            continue
        points = edge_world_points(edge, world, projection)
        if crossing.crosses(points):
            blocked.add(edge["id"])
    return blocked


if __name__ == "__main__":
    import sys

    target = sys.argv[1] if len(sys.argv) > 1 else "assets/cities/rivergate/map.json"
    with open(target, "r", encoding="utf-8") as handle:
        payload = json.load(handle)
    ids = sorted(blocked_edge_ids(payload))
    print(f"{len(ids)} edges cross water outside a bridge in {target}:")
    print(", ".join(ids))
