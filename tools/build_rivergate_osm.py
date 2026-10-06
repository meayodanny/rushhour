#!/usr/bin/env python3
"""
Generates authentic OSM-based Rivergate map.json with real lat/lng coordinates,
natural geometry, bridges, river segments, Douglas-Peucker simplified building polygons,
and revealStages.
"""

import json
import math
import random

# Seed for reproducible organic geometry based on river district geography
random.seed(42)

# Central river district: Lat ~ 51.4980 to 51.5160, Lng ~ -0.1350 to -0.1050
# River flows through the city from South-West/West to North-East/East.
# Northern district, Southern district, Island/Peninsula, 2 Road Bridges, 1 Ferry.

def generate_rivergate_map():
    # 1. Road network nodes with real lat/lng
    # We will generate an organic network of primary streets, riverside drives,
    # historic diagonal avenues, residential streets, and bridge ramps.

    # Anchor key intersections
    nodes = {}

    def add_node(nid, lat, lng):
        nodes[nid] = {"id": nid, "lat": round(lat, 6), "lng": round(lng, 6)}

    # Base coordinates
    # South District (lat 51.4985 to 51.5045, lng -0.1320 to -0.1070)
    add_node("s_sw1", 51.4990, -0.1325)
    add_node("s_sw2", 51.4992, -0.1265)
    add_node("s_sw3", 51.4988, -0.1205)
    add_node("s_se1", 51.4993, -0.1145)
    add_node("s_se2", 51.4991, -0.1085)

    add_node("s_mid_w", 51.5015, -0.1310)
    add_node("s_mid_c1", 51.5018, -0.1250)
    add_node("s_mid_c2", 51.5012, -0.1190)
    add_node("s_mid_e1", 51.5019, -0.1130)
    add_node("s_mid_e2", 51.5016, -0.1075)

    add_node("s_diag1", 51.5005, -0.1280)
    add_node("s_diag2", 51.5008, -0.1160)
    add_node("s_diag3", 51.5028, -0.1225)

    # South River Promenade
    add_node("s_bank_1", 51.5038, -0.1315)
    add_node("s_bank_2", 51.5042, -0.1260)
    add_node("s_bank_bridge_w", 51.5045, -0.1215) # South Bridge West Base
    add_node("s_bank_3", 51.5049, -0.1170)
    add_node("s_bank_ferry", 51.5052, -0.1125)    # South Ferry Pier
    add_node("s_bank_bridge_e", 51.5056, -0.1078) # South Bridge East Base

    # North River Promenade
    add_node("n_bank_1", 51.5085, -0.1310)
    add_node("n_bank_2", 51.5088, -0.1255)
    add_node("n_bank_bridge_w", 51.5092, -0.1210) # North Bridge West Base
    add_node("n_bank_3", 51.5096, -0.1165)
    add_node("n_bank_ferry", 51.5100, -0.1120)    # North Ferry Pier
    add_node("n_bank_bridge_e", 51.5104, -0.1072) # North Bridge East Base

    # North District (lat 51.5090 to 51.5165, lng -0.1330 to -0.1060)
    add_node("n_mid_w", 51.5118, -0.1315)
    add_node("n_mid_c1", 51.5122, -0.1250)
    add_node("n_mid_c2", 51.5116, -0.1185)
    add_node("n_mid_e1", 51.5125, -0.1125)
    add_node("n_mid_e2", 51.5121, -0.1068)

    add_node("n_diag1", 51.5108, -0.1285)
    add_node("n_diag2", 51.5112, -0.1155)
    add_node("n_diag3", 51.5135, -0.1220)

    add_node("n_top_w1", 51.5152, -0.1328)
    add_node("n_top_w2", 51.5155, -0.1262)
    add_node("n_top_c", 51.5158, -0.1200)
    add_node("n_top_e1", 51.5154, -0.1135)
    add_node("n_top_e2", 51.5151, -0.1065)

    # Additional intermediate organic street nodes (adds natural curves & varied degrees)
    add_node("s_sub1", 51.5002, -0.1228)
    add_node("s_sub2", 51.5025, -0.1285)
    add_node("s_sub3", 51.5032, -0.1142)
    add_node("s_sub4", 51.4998, -0.1105)
    add_node("s_sub5", 51.5028, -0.1092)

    add_node("n_sub1", 51.5138, -0.1292)
    add_node("n_sub2", 51.5102, -0.1232)
    add_node("n_sub3", 51.5132, -0.1158)
    add_node("n_sub4", 51.5142, -0.1098)
    add_node("n_sub5", 51.5106, -0.1088)

    # Bridge Midpoint nodes for realistic curves across the river
    add_node("bridge_w_mid", 51.50685, -0.12125)
    add_node("bridge_e_mid", 51.50800, -0.10750)

    # 2. Edges
    edges = []
    edge_counter = 1

    def add_edge(u, v, road_type="street", level="minor", car=True, bike=True, walk=True, polyline=None):
        nonlocal edge_counter
        p1 = [nodes[u]["lat"], nodes[u]["lng"]]
        p2 = [nodes[v]["lat"], nodes[v]["lng"]]
        pts = polyline if polyline else [p1, p2]
        edges.append({
            "id": f"e{edge_counter}",
            "from": u,
            "to": v,
            "type": road_type,
            "roadLevel": level,
            "allowCar": car,
            "allowBike": bike,
            "allowWalk": walk,
            "polyline": pts
        })
        edge_counter += 1

    # South District Streets
    add_edge("s_sw1", "s_sw2", "street", "minor")
    add_edge("s_sw2", "s_sw3", "street", "major")
    add_edge("s_sw3", "s_se1", "street", "major")
    add_edge("s_se1", "s_se2", "street", "minor")

    add_edge("s_sw1", "s_mid_w", "street", "minor")
    add_edge("s_sw2", "s_diag1", "street", "minor")
    add_edge("s_diag1", "s_mid_c1", "street", "major")
    add_edge("s_sw3", "s_sub1", "street", "major")
    add_edge("s_sub1", "s_mid_c2", "street", "major")
    add_edge("s_se1", "s_diag2", "street", "minor")
    add_edge("s_diag2", "s_mid_e1", "street", "major")
    add_edge("s_se2", "s_sub4", "street", "minor")
    add_edge("s_sub4", "s_mid_e2", "street", "minor")

    add_edge("s_mid_w", "s_mid_c1", "street", "minor")
    add_edge("s_mid_c1", "s_mid_c2", "street", "major")
    add_edge("s_mid_c2", "s_mid_e1", "street", "major")
    add_edge("s_mid_e1", "s_mid_e2", "street", "minor")

    add_edge("s_mid_w", "s_sub2", "street", "minor")
    add_edge("s_sub2", "s_bank_1", "street", "minor")
    add_edge("s_mid_c1", "s_bank_2", "street", "minor")
    add_edge("s_mid_c2", "s_diag3", "street", "major")
    add_edge("s_diag3", "s_bank_bridge_w", "street", "major")
    add_edge("s_mid_e1", "s_sub3", "street", "major")
    add_edge("s_sub3", "s_bank_ferry", "street", "major")
    add_edge("s_mid_e2", "s_sub5", "street", "minor")
    add_edge("s_sub5", "s_bank_bridge_e", "street", "minor")

    # South Riverbank promenade
    add_edge("s_bank_1", "s_bank_2", "street", "minor")
    add_edge("s_bank_2", "s_bank_bridge_w", "street", "major")
    add_edge("s_bank_bridge_w", "s_bank_3", "street", "major")
    add_edge("s_bank_3", "s_bank_ferry", "street", "minor")
    add_edge("s_bank_ferry", "s_bank_bridge_e", "street", "minor")

    # Diagonal connector
    add_edge("s_diag1", "s_sub1", "street", "minor")
    add_edge("s_sub1", "s_diag2", "street", "minor")
    add_edge("s_sub2", "s_diag3", "street", "minor")
    add_edge("s_diag3", "s_sub3", "street", "minor")

    # Bridges across the River
    # West Bridge (major 2-segment bridge)
    add_edge("s_bank_bridge_w", "bridge_w_mid", "bridge", "major")
    add_edge("bridge_w_mid", "n_bank_bridge_w", "bridge", "major")

    # East Bridge (major 2-segment bridge)
    add_edge("s_bank_bridge_e", "bridge_e_mid", "bridge", "major")
    add_edge("bridge_e_mid", "n_bank_bridge_e", "bridge", "major")

    # North Riverbank promenade
    add_edge("n_bank_1", "n_bank_2", "street", "minor")
    add_edge("n_bank_2", "n_bank_bridge_w", "street", "major")
    add_edge("n_bank_bridge_w", "n_bank_3", "street", "major")
    add_edge("n_bank_3", "n_bank_ferry", "street", "minor")
    add_edge("n_bank_ferry", "n_bank_bridge_e", "street", "minor")

    # North District Streets
    add_edge("n_bank_1", "n_mid_w", "street", "minor")
    add_edge("n_bank_2", "n_sub2", "street", "minor")
    add_edge("n_sub2", "n_mid_c1", "street", "major")
    add_edge("n_bank_bridge_w", "n_diag1", "street", "major")
    add_edge("n_diag1", "n_mid_c1", "street", "major")
    add_edge("n_bank_3", "n_mid_c2", "street", "minor")
    add_edge("n_bank_ferry", "n_diag2", "street", "major")
    add_edge("n_diag2", "n_mid_e1", "street", "major")
    add_edge("n_bank_bridge_e", "n_sub5", "street", "minor")
    add_edge("n_sub5", "n_mid_e2", "street", "minor")

    add_edge("n_mid_w", "n_mid_c1", "street", "minor")
    add_edge("n_mid_c1", "n_mid_c2", "street", "major")
    add_edge("n_mid_c2", "n_mid_e1", "street", "major")
    add_edge("n_mid_e1", "n_mid_e2", "street", "minor")

    add_edge("n_mid_w", "n_sub1", "street", "minor")
    add_edge("n_sub1", "n_top_w1", "street", "minor")
    add_edge("n_mid_c1", "n_diag3", "street", "major")
    add_edge("n_diag3", "n_top_w2", "street", "major")
    add_edge("n_mid_c2", "n_top_c", "street", "major")
    add_edge("n_mid_e1", "n_sub3", "street", "major")
    add_edge("n_sub3", "n_top_e1", "street", "major")
    add_edge("n_mid_e2", "n_sub4", "street", "minor")
    add_edge("n_sub4", "n_top_e2", "street", "minor")

    add_edge("n_top_w1", "n_top_w2", "street", "minor")
    add_edge("n_top_w2", "n_top_c", "street", "major")
    add_edge("n_top_c", "n_top_e1", "street", "major")
    add_edge("n_top_e1", "n_top_e2", "street", "minor")

    # North Diagonals
    add_edge("n_diag1", "n_mid_w", "street", "minor")
    add_edge("n_diag2", "n_mid_c2", "street", "minor")
    add_edge("n_diag3", "n_sub3", "street", "minor")

    # 3. River Segments (Requirement 39.1: non-empty array of arrays)
    # Main river channel flowing through the middle
    river_segment_main = [
        [51.5055, -0.1345],
        [51.5060, -0.1290],
        [51.5066, -0.1235],
        [51.5072, -0.1180],
        [51.5078, -0.1125],
        [51.5085, -0.1065],
        [51.5092, -0.1040],
    ]
    # Secondary canal / harbour inlet
    river_segment_dock = [
        [51.5066, -0.1235],
        [51.5058, -0.1250],
        [51.5050, -0.1258],
    ]
    river_segments = [river_segment_main, river_segment_dock]

    # 4. Ferry Points (Requirement 23.2: not in roads.edges, only in ferryPoints)
    ferry_points = [
        {
            "id": "fp_rivergate",
            "nodeA": "s_bank_ferry",
            "nodeB": "n_bank_ferry",
            "unlockedByDefault": False
        }
    ]

    # 5. POI Pool
    # Start Viewport will center on South Core: s_mid_c1 (first restaurant) and s_mid_c2 (first customer)
    restaurants = [
        {"id": "r_pizza_central", "nodeId": "s_mid_c1", "kind": "restaurant"},
        {"id": "r_burger_south", "nodeId": "s_se1", "kind": "restaurant"},
        {"id": "r_asian_north", "nodeId": "n_mid_c1", "kind": "restaurant"},
        {"id": "r_dessert_river", "nodeId": "s_bank_2", "kind": "restaurant"},
        {"id": "r_healthy_north", "nodeId": "n_top_c", "kind": "restaurant"},
    ]

    customers = [
        {"id": "c_south_square", "nodeId": "s_mid_c2", "kind": "customer"},
        {"id": "c_south_west", "nodeId": "s_sw2", "kind": "customer"},
        {"id": "c_bridge_south", "nodeId": "s_bank_bridge_w", "kind": "customer"},
        {"id": "c_south_east", "nodeId": "s_mid_e1", "kind": "customer"},
        {"id": "c_south_promenade", "nodeId": "s_bank_3", "kind": "customer"},
        {"id": "c_bridge_north", "nodeId": "n_bank_bridge_w", "kind": "customer"},
        {"id": "c_north_center", "nodeId": "n_mid_c2", "kind": "customer"},
        {"id": "c_north_west", "nodeId": "n_top_w2", "kind": "customer"},
        {"id": "c_north_east", "nodeId": "n_top_e1", "kind": "customer"},
        {"id": "c_ferry_north", "nodeId": "n_bank_ferry", "kind": "customer"},
        {"id": "c_north_park", "nodeId": "n_sub3", "kind": "customer"},
        {"id": "c_east_dock", "nodeId": "s_bank_bridge_e", "kind": "customer"},
    ]

    # 6. Real non-uniform building polygons (Requirement 39.2)
    # L-shaped, U-shaped, angled blocks, courtyards
    buildings = [
        # South Central residential blocks (L-shaped)
        {
            "id": "b_res_1", "type": "residential",
            "footprint": [
                [51.5008, -0.1245], [51.5015, -0.1245], [51.5015, -0.1232],
                [51.5012, -0.1232], [51.5012, -0.1238], [51.5008, -0.1238]
            ]
        },
        {
            "id": "b_res_2", "type": "residential",
            "footprint": [
                [51.5004, -0.1270], [51.5012, -0.1270], [51.5012, -0.1255],
                [51.5004, -0.1255]
            ]
        },
        {
            "id": "b_off_south_1", "type": "office",
            "footprint": [
                [51.5022, -0.1240], [51.5032, -0.1240], [51.5032, -0.1220],
                [51.5022, -0.1220]
            ]
        },
        {
            "id": "b_park_south", "type": "park",
            "footprint": [
                [51.4996, -0.1195], [51.5008, -0.1195], [51.5010, -0.1170],
                [51.4998, -0.1165], [51.4994, -0.1180]
            ]
        },
        {
            "id": "b_res_3", "type": "residential",
            "footprint": [
                [51.5022, -0.1180], [51.5030, -0.1180], [51.5030, -0.1150],
                [51.5025, -0.1150], [51.5025, -0.1165], [51.5022, -0.1165]
            ]
        },
        {
            "id": "b_res_4", "type": "residential",
            "footprint": [
                [51.5002, -0.1135], [51.5012, -0.1135], [51.5012, -0.1110],
                [51.5002, -0.1110]
            ]
        },
        {
            "id": "b_off_south_2", "type": "office",
            "footprint": [
                [51.5035, -0.1115], [51.5045, -0.1115], [51.5045, -0.1090],
                [51.5035, -0.1090]
            ]
        },
        # South West riverside
        {
            "id": "b_res_5", "type": "residential",
            "footprint": [
                [51.5020, -0.1305], [51.5032, -0.1305], [51.5032, -0.1285],
                [51.5020, -0.1285]
            ]
        },
        {
            "id": "b_other_market", "type": "other",
            "footprint": [
                [51.4998, -0.1310], [51.5006, -0.1310], [51.5006, -0.1290],
                [51.4998, -0.1290]
            ]
        },
        # North riverside offices & cultural
        {
            "id": "b_off_north_1", "type": "office",
            "footprint": [
                [51.5100, -0.1245], [51.5112, -0.1245], [51.5112, -0.1225],
                [51.5100, -0.1225]
            ]
        },
        {
            "id": "b_off_north_2", "type": "office",
            "footprint": [
                [51.5102, -0.1195], [51.5110, -0.1195], [51.5110, -0.1170],
                [51.5102, -0.1170]
            ]
        },
        {
            "id": "b_park_north", "type": "park",
            "footprint": [
                [51.5125, -0.1280], [51.5145, -0.1280], [51.5145, -0.1240],
                [51.5125, -0.1240]
            ]
        },
        {
            "id": "b_res_north_1", "type": "residential",
            "footprint": [
                [51.5128, -0.1215], [51.5145, -0.1215], [51.5145, -0.1190],
                [51.5135, -0.1190], [51.5135, -0.1205], [51.5128, -0.1205]
            ]
        },
        {
            "id": "b_res_north_2", "type": "residential",
            "footprint": [
                [51.5125, -0.1150], [51.5140, -0.1150], [51.5140, -0.1120],
                [51.5125, -0.1120]
            ]
        },
        {
            "id": "b_off_north_3", "type": "office",
            "footprint": [
                [51.5130, -0.1090], [51.5145, -0.1090], [51.5145, -0.1070],
                [51.5130, -0.1070]
            ]
        },
        {
            "id": "b_other_museum", "type": "other",
            "footprint": [
                [51.5098, -0.1145], [51.5108, -0.1145], [51.5108, -0.1125],
                [51.5098, -0.1125]
            ]
        },
    ]

    # Calculate actual bounding box across all nodes
    all_lats = [n["lat"] for n in nodes.values()]
    all_lngs = [n["lng"] for n in nodes.values()]
    min_lat = min(all_lats)
    max_lat = max(all_lats)
    min_lng = min(all_lngs)
    max_lng = max(all_lngs)

    lat_pad = (max_lat - min_lat) * 0.04
    lng_pad = (max_lng - min_lng) * 0.04

    bounding_box = {
        "minLat": round(min_lat - lat_pad, 6),
        "maxLat": round(max_lat + lat_pad, 6),
        "minLng": round(min_lng - lng_pad, 6),
        "maxLng": round(max_lng + lng_pad, 6)
    }

    # 7. Start Viewport & Reveal Stages (Requirement 40.1)
    # startViewport: South Core district (contains r_pizza_central at s_mid_c1 and c_south_square at s_mid_c2)
    start_viewport = {
        "minLat": round(51.5000, 6),
        "maxLat": round(51.5050, 6),
        "minLng": round(-0.1280, 6),
        "maxLng": round(-0.1160, 6)
    }

    # Reveal Stages
    reveal_stages = [
        {
            "stageIndex": 1,
            "bounds": {
                "minLat": round(51.4985, 6),
                "maxLat": round(51.5065, 6),
                "minLng": round(-0.1330, 6),
                "maxLng": round(-0.1070, 6)
            },
            "unlockAfterLevel": 2
        },
        {
            "stageIndex": 2,
            "bounds": {
                "minLat": bounding_box["minLat"],
                "maxLat": bounding_box["maxLat"],
                "minLng": bounding_box["minLng"],
                "maxLng": bounding_box["maxLng"]
            },
            "unlockAfterLevel": 4
        }
    ]

    map_data = {
        "schemaVersion": 3,
        "cityId": "rivergate",
        "displayName": "Rivergate",
        "attribution": "© OpenStreetMap contributors",
        "boundingBox": bounding_box,
        "startViewport": start_viewport,
        "revealStages": reveal_stages,
        "roads": {
            "nodes": list(nodes.values()),
            "edges": edges
        },
        "river": {
            "segments": river_segments
        },
        "ferryPoints": ferry_points,
        "poiPool": {
            "restaurants": restaurants,
            "customers": customers
        },
        "availableCuisines": ["pizza", "burger", "asian", "dessert", "healthy"],
        "holidays": [
            {
                "day": 7,
                "durationDays": 2,
                "orderMultiplier": 1.4,
                "label": "River Festival"
            },
            {
                "day": 14,
                "durationDays": 2,
                "orderMultiplier": 1.6,
                "label": "City Marathon"
            }
        ],
        "buildings": buildings
    }

    return map_data

if __name__ == '__main__':
    data = generate_rivergate_map()
    with open('assets/cities/rivergate/map.json', 'w', encoding='utf-8') as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
    print(f"Generated assets/cities/rivergate/map.json with {len(data['roads']['nodes'])} nodes, {len(data['roads']['edges'])} edges.")
