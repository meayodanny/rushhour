#!/usr/bin/env python3
"""
City Map Validator (validate_city_map.py)
Validates that city map JSON contains real OSM geometry, not procedural grids.
"""

import sys
import json
import math
from collections import defaultdict, deque

def calculate_std_dev(values):
    if len(values) < 2:
        return 0.0
    mean = sum(values) / len(values)
    variance = sum((x - mean) ** 2 for x in values) / (len(values) - 1)
    return math.sqrt(variance)

def calculate_angle_degrees(p_prev, p_center, p_next):
    # Vector 1: p_center -> p_prev
    v1_x = p_prev[0] - p_center[0]
    v1_y = p_prev[1] - p_center[1]
    # Vector 2: p_center -> p_next
    v2_x = p_next[0] - p_center[0]
    v2_y = p_next[1] - p_center[1]

    len1 = math.hypot(v1_x, v1_y)
    len2 = math.hypot(v2_x, v2_y)
    if len1 < 1e-9 or len2 < 1e-9:
        return 0.0

    dot = v1_x * v2_x + v1_y * v2_y
    cos_angle = max(-1.0, min(1.0, dot / (len1 * len2)))
    angle_rad = math.acos(cos_angle)
    return math.degrees(angle_rad)

def validate_city_map(file_path):
    print(f"=== Validating city map: {file_path} ===")
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            data = json.load(f)
    except Exception as e:
        print(f"[FAIL] Could not load JSON file: {e}")
        return False

    nodes_list = data.get('roads', {}).get('nodes', [])
    edges_list = data.get('roads', {}).get('edges', [])
    poi_pool = data.get('poiPool', {})
    restaurants = poi_pool.get('restaurants', [])
    customers = poi_pool.get('customers', [])
    ferry_points = data.get('ferryPoints', [])
    river = data.get('river', {})
    bounding_box = data.get('boundingBox', {})

    nodes_dict = {}
    for node in nodes_list:
        node_id = node.get('id')
        # Support lat/lng or lat/lon
        lat = node.get('lat')
        lng = node.get('lng', node.get('lon'))
        if node_id and lat is not None and lng is not None:
            nodes_dict[node_id] = (float(lat), float(lng))

    results = {}

    # Check 5: Validity of references (Check first so other checks are safe)
    ref_errors = []
    for edge in edges_list:
        from_id = edge.get('from')
        to_id = edge.get('to')
        if from_id not in nodes_dict:
            ref_errors.append(f"Edge {edge.get('id')} has unknown 'from': {from_id}")
        if to_id not in nodes_dict:
            ref_errors.append(f"Edge {edge.get('id')} has unknown 'to': {to_id}")

    for r in restaurants:
        nid = r.get('nodeId')
        if nid not in nodes_dict:
            ref_errors.append(f"Restaurant {r.get('id')} has unknown nodeId: {nid}")

    for c in customers:
        nid = c.get('nodeId')
        if nid not in nodes_dict:
            ref_errors.append(f"Customer {c.get('id')} has unknown nodeId: {nid}")

    for fp in ferry_points:
        nA = fp.get('nodeA')
        nB = fp.get('nodeB')
        if nA not in nodes_dict:
            ref_errors.append(f"FerryPoint {fp.get('id')} has unknown nodeA: {nA}")
        if nB not in nodes_dict:
            ref_errors.append(f"FerryPoint {fp.get('id')} has unknown nodeB: {nB}")

    if not ref_errors and len(nodes_dict) > 0 and len(edges_list) > 0:
        results[5] = (True, f"All references valid across {len(nodes_dict)} nodes and {len(edges_list)} edges.")
    else:
        results[5] = (False, f"Reference errors ({len(ref_errors)}): " + "; ".join(ref_errors[:3]))

    # Check 1: Regularity of coordinates
    if len(nodes_dict) < 5:
        results[1] = (False, "Too few nodes to evaluate coordinate regularity.")
    else:
        lats = sorted(list(set(lat for lat, lng in nodes_dict.values())))
        lngs = sorted(list(set(lng for lat, lng in nodes_dict.values())))
        diffs_lat = [lats[i+1] - lats[i] for i in range(len(lats)-1)]
        diffs_lng = [lngs[i+1] - lngs[i] for i in range(len(lngs)-1)]

        std_lat = calculate_std_dev(diffs_lat)
        std_lng = calculate_std_dev(diffs_lng)
        mean_lat = sum(diffs_lat) / len(diffs_lat) if diffs_lat else 1.0
        mean_lng = sum(diffs_lng) / len(diffs_lng) if diffs_lng else 1.0

        cv_lat = std_lat / mean_lat if mean_lat > 0 else 0
        cv_lng = std_lng / mean_lng if mean_lng > 0 else 0

        # In a synthetic grid, std dev of step diffs is 0 or extremely close to 0.
        # Real OSM data has high coefficient of variation (> 0.25).
        if cv_lat > 0.15 and cv_lng > 0.15:
            results[1] = (True, f"Coordinate variance confirmed (CV lat: {cv_lat:.3f}, lng: {cv_lng:.3f}). Natural OSM distribution.")
        else:
            results[1] = (False, f"Coordinates appear synthetic/grid-like (CV lat: {cv_lat:.3f}, lng: {cv_lng:.3f}).")

    # Check 2: Edge angles
    adj = defaultdict(list)
    for edge in edges_list:
        f_id = edge.get('from')
        t_id = edge.get('to')
        if f_id in nodes_dict and t_id in nodes_dict:
            adj[f_id].append(t_id)
            adj[t_id].append(f_id)

    total_angles = 0
    orthogonal_angles = 0
    for node_id, neighbors in adj.items():
        if len(neighbors) < 2:
            continue
        p_center = nodes_dict[node_id]
        unique_neighbors = list(set(neighbors))
        for i in range(len(unique_neighbors)):
            for j in range(i + 1, len(unique_neighbors)):
                n1 = unique_neighbors[i]
                n2 = unique_neighbors[j]
                p1 = nodes_dict[n1]
                p2 = nodes_dict[n2]
                angle = calculate_angle_degrees(p1, p_center, p2)
                total_angles += 1
                # Check if angle is strictly multiple of 90° (+/- 2°) -> 88°..92° or 178°..180°
                if (88.0 <= angle <= 92.0) or (angle >= 178.0):
                    orthogonal_angles += 1

    ortho_ratio = (orthogonal_angles / total_angles) if total_angles > 0 else 0.0
    # In a grid, nearly 100% of angles are 90° or 180°. In real OSM, ratio is significantly lower (< 0.40).
    if total_angles > 0 and ortho_ratio < 0.45:
        results[2] = (True, f"Angle distribution is natural (orthogonal ratio: {ortho_ratio:.2%} out of {total_angles} angles).")
    else:
        results[2] = (False, f"Too many orthogonal 90° angles ({ortho_ratio:.2%}), indicates artificial grid.")

    # Check 3: Node degree distribution
    degrees = [len(set(neighbors)) for neighbors in adj.values()]
    if degrees:
        deg_std = calculate_std_dev(degrees)
        deg_mean = sum(degrees) / len(degrees)
        if deg_std > 0.4:
            results[3] = (True, f"Node degree distribution variance: std={deg_std:.2f}, mean={deg_mean:.2f}.")
        else:
            results[3] = (False, f"Node degrees are too uniform (std={deg_std:.2f}).")
    else:
        results[3] = (False, "No node connections found.")

    # Check 4: Connectivity (BFS/DFS from each POI)
    # Exclude ferry edges from default road network connectivity check (ferry is not active by default)
    poi_nodes = set()
    for r in restaurants:
        poi_nodes.add(r.get('nodeId'))
    for c in customers:
        poi_nodes.add(c.get('nodeId'))

    if not poi_nodes:
        results[4] = (False, "No POIs found in poiPool.")
    else:
        start_poi = next(iter(poi_nodes))
        visited = set()
        queue = deque([start_poi])
        visited.add(start_poi)
        while queue:
            curr = queue.popleft()
            for nbr in adj.get(curr, []):
                if nbr not in visited:
                    visited.add(nbr)
                    queue.append(nbr)

        unreachable = poi_nodes - visited
        if not unreachable:
            results[4] = (True, f"All {len(poi_nodes)} POI nodes are in a single connected component.")
        else:
            results[4] = (False, f"Disconnected POI nodes ({len(unreachable)}): {list(unreachable)[:5]}")

    # Check 6: BoundingBox match
    if nodes_dict:
        actual_min_lat = min(lat for lat, lng in nodes_dict.values())
        actual_max_lat = max(lat for lat, lng in nodes_dict.values())
        actual_min_lng = min(lng for lat, lng in nodes_dict.values())
        actual_max_lng = max(lng for lat, lng in nodes_dict.values())

        bb_min_lat = bounding_box.get('minLat')
        bb_max_lat = bounding_box.get('maxLat')
        bb_min_lng = bounding_box.get('minLng')
        bb_max_lng = bounding_box.get('maxLng')

        if all(x is not None for x in [bb_min_lat, bb_max_lat, bb_min_lng, bb_max_lng]):
            # Verify bounding box encloses all nodes with reasonable padding
            lat_span = actual_max_lat - actual_min_lat
            lng_span = actual_max_lng - actual_min_lng
            tol_lat = max(1e-4, lat_span * 0.15)
            tol_lng = max(1e-4, lng_span * 0.15)

            valid_bb = (
                bb_min_lat <= actual_min_lat + 1e-5 and
                bb_max_lat >= actual_max_lat - 1e-5 and
                bb_min_lng <= actual_min_lng + 1e-5 and
                bb_max_lng >= actual_max_lng - 1e-5 and
                abs(bb_min_lat - actual_min_lat) <= tol_lat and
                abs(bb_max_lat - actual_max_lat) <= tol_lat and
                abs(bb_min_lng - actual_min_lng) <= tol_lng and
                abs(bb_max_lng - actual_max_lng) <= tol_lng
            )
            if valid_bb:
                results[6] = (True, f"BoundingBox matches nodes actual min/max with proper padding.")
            else:
                results[6] = (False, f"BoundingBox mismatch: actual lat=({actual_min_lat:.5f}, {actual_max_lat:.5f}), lng=({actual_min_lng:.5f}, {actual_max_lng:.5f}) vs declared ({bb_min_lat}, {bb_max_lat}, {bb_min_lng}, {bb_max_lng}).")
        else:
            results[6] = (False, "BoundingBox fields missing or invalid.")
    else:
        results[6] = (False, "No nodes to compute actual bounds.")

    # Check 7: River format (segments is non-empty list of lists of coords)
    segments = river.get('segments')
    if isinstance(segments, list) and len(segments) > 0:
        valid_segments = True
        total_pts = 0
        for seg in segments:
            if not isinstance(seg, list) or len(seg) < 2:
                valid_segments = False
                break
            for pt in seg:
                if not isinstance(pt, (list, tuple)) or len(pt) < 2:
                    valid_segments = False
                    break
                total_pts += 1
        if valid_segments and total_pts >= 4:
            results[7] = (True, f"River format valid: {len(segments)} segments with {total_pts} total coordinates.")
        else:
            results[7] = (False, "River segments format malformed or contains invalid coordinates.")
    else:
        results[7] = (False, "River missing 'segments' non-empty array of arrays.")

    # Output report
    print("\n--- VALIDATION RESULTS ---")
    all_passed = True
    critical_failed = False
    for check_id in [1, 2, 3, 4, 5, 6, 7]:
        passed, msg = results.get(check_id, (False, "Check not executed"))
        status_str = "PASS" if passed else "FAIL"
        print(f"[{status_str}] Rule {check_id}: {msg}")
        if not passed:
            all_passed = False
            if check_id in (1, 2, 5):
                critical_failed = True

    print("\n--- SUMMARY ---")
    if all_passed:
        print("ALL CHECKS PASSED: Map conforms to real OSM geometry standards.")
        return True
    else:
        if critical_failed:
            print("CRITICAL FAILURE: Map FAILED rules 1, 2, or 5. CANNOT be used in assets.")
        else:
            print("VALIDATION FAILED: Some checks did not pass.")
        return False

if __name__ == '__main__':
    target = sys.argv[1] if len(sys.argv) > 1 else 'assets/cities/rivergate/map.json'
    success = validate_city_map(target)
    sys.exit(0 if success else 1)
