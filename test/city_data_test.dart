import 'package:flutter_test/flutter_test.dart';
import 'package:rushhour/models/city.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Rivergate asset produces real OSM geometry with projection and reveal stages', () async {
    final city = await CityData.load('rivergate');

    expect(city.nodes, isNotEmpty);
    expect(city.edges, isNotEmpty);
    expect(city.restaurantPois, isNotEmpty);
    expect(city.customerPois, isNotEmpty);
    expect(city.buildings, isNotEmpty);
    expect(city.buildings.every((CityBuilding building) => building.footprint.length >= 3), isTrue);
    expect(city.contentBounds.width, greaterThan(0));
    expect(city.contentBounds.height, greaterThan(0));
    expect(
      city.edges.every((RoadEdge edge) => edge.points.length >= 2),
      isTrue,
    );
    // Water (Requirement 46, schemaVersion 3): wide stretches are polygons,
    // narrow stretches are polylines - at least one of the two must be there
    // for a city that has a river at all.
    expect(city.hasWater, isTrue);
    expect(city.riverAreas, isNotEmpty);
    expect(city.riverAreas.every((List area) => area.length >= 3), isTrue);
    expect(city.riverSegments, isNotEmpty);
    expect(city.riverSegments.every((List segment) => segment.length >= 2), isTrue);
    // Start viewport and reveal stages
    expect(city.startViewport.minLat, lessThan(city.startViewport.maxLat));
    expect(city.revealStages, isNotEmpty);
  });
}
