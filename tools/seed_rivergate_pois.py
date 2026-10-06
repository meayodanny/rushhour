#!/usr/bin/env python3
"""Seed the Rivergate map with restaurant/customer POI nodes.

The OSM-derived map (3980 nodes / 3483 edges) was checked in with an EMPTY
`poiPool` (plus placeholder `cityId`/`displayName` and no
`startViewport`/`revealStages`), which makes the game unplayable: no restaurant
can ever spawn, so no customer, no line and no delivery is possible — and the
existing `test/city_data_test.dart` fails.

This script is fully deterministic (no randomness): it selects POI nodes with
farthest-point sampling over the walk-connected road graph, fills the missing
map fields, and writes the map back. Run it from the repo root:

    python3 tools/seed_rivergate_pois.py

Selection rules:
  * every POI node sits in the largest allowWalk-connected component;
  * every POI node has degree >= 2 (no dangling dead-ends) and at least one
    incident street edge (restaurants do not live on bridges);
  * POIs keep a minimum separation (~120 m) so their 48x48 hit areas and
    icons do not stack on top of each other;
  * restaurants and customers are spread across the whole bounding box, with
    a guaranteed dense cluster inside the start viewport (stage 0 of the
    reveal) so the early game has targets on screen.
"""

import json
import math
import sys
from collections import deque

MAP_PATH = "assets/cities/rivergate/map.json"

RESTAURANTS_TOTAL = 24
RESTAURANTS_IN_VIEWPORT = 8
CUSTOMERS_TOTAL = 56
CUSTOMERS_IN_VIEWPORT = 24

VIEWPORT_LAT_FRACTION = 0.55  # share of the bounding-box lat span
VIEWPORT_LNG_FRACTION = 0.50  # share of the bounding-box lng span

MIN_SEPARATION_M = 120.0  # between any two POIs


def geo_distance_m(lat1, lng1, lat2, lng2):
    cos_mid = math.cos(math.radians((lat1 + lat2) / 2))
    dx = (lng1 - lng2) * cos_mid * 111320.0
    dy = (lat1 - lat2) * 111320.0
    return math.hypot(dx, dy)


def load_map(path):
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def build_walk_adjacency(data):
    nodes = {n["id"]: (float(n["lat"]), float(n.get("lng", n.get("lon"))))
             for n in data["roads"]["nodes"]}
    adjacency = {nid: set() for nid in nodes}
    street_adjacent = set()
    for edge in data["roads"]["edges"]:
        if not edge.get("allowWalk", True):
            continue
        a, b = edge["from"], edge["to"]
        if a in nodes and b in nodes:
            adjacency[a].add(b)
            adjacency[b].add(a)
            if edge.get("type", "street") != "bridge":
                street_adjacent.add(a)
                street_adjacent.add(b)
    return nodes, adjacency, street_adjacent


def largest_component(adjacency):
    best = set()
    seen = set()
    for start in adjacency:
        if start in seen:
            continue
        component = {start}
        queue = deque([start])
        seen.add(start)
        while queue:
            for neighbour in adjacency[queue.popleft()]:
                if neighbour not in seen:
                    seen.add(neighbour)
                    component.add(neighbour)
                    queue.append(neighbour)
        if len(component) > len(best):
            best = component
    return best


def farthest_point_pick(candidates, coords, picked, count):
    """Deterministic farthest-point sampling from `candidates`.

    Starts from the candidate closest to the region centre, then repeatedly
    appends the candidate maximizing the distance to the closest already
    picked point (ties resolved by node id for reproducibility).
    """
    remaining = [c for c in candidates if c not in picked]
    if not remaining:
        return []
    if picked:
        result = []
        pool = list(remaining)
        while pool and len(result) < count:
            best = None
            best_key = None
            for node in pool:
                lat, lng = coords[node]
                closest = min(geo_distance_m(lat, lng, coords[p][0], coords[p][1]) for p in picked)
                key = (-closest, node)  # maximize distance, then stable id order
                if best_key is None or key < best_key:
                    best_key = key
                    best = node
            result.append(best)
            pool.remove(best)
        return result
    # No seeds yet: start from the candidate closest to the centroid.
    lats = [coords[c][0] for c in remaining]
    lngs = [coords[c][1] for c in remaining]
    centre = (sum(lats) / len(lats), sum(lngs) / len(lngs))
    first = min(remaining, key=lambda c: (geo_distance_m(coords[c][0], coords[c][1], centre[0], centre[1]), c))
    return [first] + farthest_point_pick(candidates, coords, [first], count - 1)


def min_separation_ok(node, coords, picked):
    lat, lng = coords[node]
    return all(geo_distance_m(lat, lng, coords[p][0], coords[p][1]) >= MIN_SEPARATION_M
               for p in picked)


def main():
    data = load_map(MAP_PATH)
    nodes, adjacency, street_adjacent = build_walk_adjacency(data)
    component = largest_component(adjacency)

    candidates = sorted(
        nid for nid in component
        if len(adjacency[nid]) >= 2 and nid in street_adjacent
    )
    if len(candidates) < RESTAURANTS_TOTAL + CUSTOMERS_TOTAL:
        print(f"Not enough candidate nodes: {len(candidates)}", file=sys.stderr)
        return 1

    bbox = data["boundingBox"]
    lat_span = bbox["maxLat"] - bbox["minLat"]
    lng_span = bbox["maxLng"] - bbox["minLng"]
    centre_lat = (bbox["minLat"] + bbox["maxLat"]) / 2
    centre_lng = (bbox["minLng"] + bbox["maxLng"]) / 2

    start_viewport = {
        "minLat": centre_lat - lat_span * VIEWPORT_LAT_FRACTION / 2,
        "maxLat": centre_lat + lat_span * VIEWPORT_LAT_FRACTION / 2,
        "minLng": centre_lng - lng_span * VIEWPORT_LNG_FRACTION / 2,
        "maxLng": centre_lng + lng_span * VIEWPORT_LNG_FRACTION / 2,
    }

    def in_viewport(nid):
        lat, lng = nodes[nid]
        return (start_viewport["minLat"] <= lat <= start_viewport["maxLat"]
                and start_viewport["minLng"] <= lng <= start_viewport["maxLng"])

    viewport_candidates = [c for c in candidates if in_viewport(c)]
    print(f"candidate nodes: {len(candidates)} total, {len(viewport_candidates)} in start viewport")

    picked = []

    def take(candidates_pool, count):
        chosen = farthest_point_pick(candidates_pool, nodes, picked, count)
        # Enforce hard separation, dropping anything that ended up too close.
        for node in chosen:
            if min_separation_ok(node, nodes, picked):
                picked.append(node)
            else:
                replacement = farthest_point_pick(
                    [c for c in candidates_pool if c not in picked], nodes, picked, 1)
                for repl in replacement:
                    if min_separation_ok(repl, nodes, picked):
                        picked.append(repl)
        return [n for n in picked]

    take(viewport_candidates, RESTAURANTS_IN_VIEWPORT)
    take(candidates, RESTAURANTS_TOTAL - RESTAURANTS_IN_VIEWPORT)
    restaurants = list(picked)
    restaurant_count = len(restaurants)

    take(viewport_candidates, CUSTOMERS_IN_VIEWPORT)
    take(candidates, CUSTOMERS_TOTAL - CUSTOMERS_IN_VIEWPORT)
    all_picked = list(picked)
    customers = all_picked[restaurant_count:]

    print(f"selected {len(restaurants)} restaurants, {len(customers)} customers")

    poi_pool = {
        "restaurants": [{"id": f"r{i + 1:03d}", "nodeId": nid} for i, nid in enumerate(restaurants)],
        "customers": [{"id": f"c{i + 1:03d}", "nodeId": nid} for i, nid in enumerate(customers)],
    }

    # Reveal stages: stage 1 widens the start viewport, stage 2 opens the map.
    def inflate(rect, toward, factor):
        def lerp(a, b, t):
            return a + (b - a) * t

        t = factor
        return {
            "minLat": lerp(rect["minLat"], toward["minLat"], t),
            "maxLat": lerp(rect["maxLat"], toward["maxLat"], t),
            "minLng": lerp(rect["minLng"], toward["minLng"], t),
            "maxLng": lerp(rect["maxLng"], toward["maxLng"], t),
        }

    reveal_stages = [
        {
            "stageIndex": 1,
            "bounds": inflate(start_viewport, bbox, 0.35),
            "unlockAfterLevel": 2,
        },
        {
            "stageIndex": 2,
            "bounds": dict(bbox),
            "unlockAfterLevel": 4,
        },
    ]

    # Fill the missing / placeholder metadata without touching the geometry.
    data["poiPool"] = poi_pool
    data["startViewport"] = {k: round(v, 8) for k, v in start_viewport.items()}
    data["revealStages"] = [
        {
            "stageIndex": stage["stageIndex"],
            "bounds": {k: round(v, 8) for k, v in stage["bounds"].items()},
            "unlockAfterLevel": stage["unlockAfterLevel"],
        }
        for stage in reveal_stages
    ]
    if data.get("cityId") in (None, "", "your_city_id"):
        data["cityId"] = "rivergate"
    if data.get("displayName") in (None, "", "Your City Name"):
        data["displayName"] = "Rivergate"
    data["schemaVersion"] = 3

    with open(MAP_PATH, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)

    print(f"rewrote {MAP_PATH}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
