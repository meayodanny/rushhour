#!/usr/bin/env python3
"""Split the Rivergate water into `river.segments` and `river.areas`.

Requirement 46 (schemaVersion 3) separates the two shapes water is stored in:

* ``river.segments`` - narrow stretches, drawn as thin polylines;
* ``river.areas``    - wide stretches and water bodies, drawn as filled
  polygons.

The checked-in map was still carrying every water feature in ``segments``: the
OSM-derived closed outlines of the river / docks (up to 260 points) as well as
two open polylines that continue the channel where the map has no area. This
script performs the one-off migration - closed rings move to ``areas``, open
polylines stay in ``segments`` - without touching a single coordinate.

It is deterministic and idempotent:

    python3 tools/split_rivergate_water.py

Running it twice changes nothing (second run: 0 features moved).
"""

import json
import math
import sys

MAP_PATH = "assets/cities/rivergate/map.json"

# A ring is closed when its last point repeats the first one closely enough
# (1e-5 degrees is ~1 m) - the same rule the reference geometry in
# tools/water_geometry.py uses to talk about polygons.
CLOSED_EPSILON_DEG = 1e-5
MIN_RING_POINTS = 4  # three corners plus the repeated first point


def is_closed_ring(feature):
    if len(feature) < MIN_RING_POINTS:
        return False
    first = (float(feature[0][0]), float(feature[0][1]))
    last = (float(feature[-1][0]), float(feature[-1][1]))
    return math.dist(first, last) <= CLOSED_EPSILON_DEG


def main():
    with open(MAP_PATH, "r", encoding="utf-8") as handle:
        data = json.load(handle)

    river = data.setdefault("river", {})
    segments = list(river.get("segments") or [])
    areas = list(river.get("areas") or [])

    kept_segments = []
    moved = 0
    for feature in segments:
        if is_closed_ring(feature):
            areas.append(feature)
            moved += 1
        else:
            kept_segments.append(feature)

    data["schemaVersion"] = 3
    data["river"] = {"segments": kept_segments, "areas": areas}

    with open(MAP_PATH, "w", encoding="utf-8") as handle:
        json.dump(data, handle, indent=2, ensure_ascii=False)

    print(
        f"{MAP_PATH}: moved {moved} closed ring(s) to river.areas - "
        f"now {len(kept_segments)} segment(s) and {len(areas)} area(s)."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
