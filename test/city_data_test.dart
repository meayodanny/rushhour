import 'package:flutter_test/flutter_test.dart';
import 'package:rushhour/models/city.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Rivergate asset produces drawable in-bounds geometry', () async {
    final city = await CityData.load('rivergate');

    expect(city.nodes, isNotEmpty);
    expect(city.edges, isNotEmpty);
    expect(city.restaurantPois, isNotEmpty);
    expect(city.customerPois, isNotEmpty);
    expect(city.contentBounds.width, greaterThan(0));
    expect(city.contentBounds.height, greaterThan(0));
    expect(
      city.edges.every((RoadEdge edge) => edge.points.length >= 2),
      isTrue,
    );
  });
}
