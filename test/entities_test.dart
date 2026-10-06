import 'package:flutter_test/flutter_test.dart';
import 'package:rushhour/models/entities.dart';

void main() {
  test('customer limits and demand are deterministic', () {
    final customer = Customer(id: 'c', nodeId: 'n', demand: <Cuisine, int>{Cuisine.pizza: 9});
    expect(customer.overloaded, isTrue);
    customer.houseApplied = true;
    expect(customer.limit, 12);
    expect(customer.overloaded, isFalse);
  });

  test('snapshot survives JSON-compatible round trip', () {
    final source = GameSnapshot(difficulty: Difficulty.normal, restaurants: <Restaurant>[], customers: <Customer>[], lines: <DeliveryLine>[], couriers: <Courier>[], events: <RoadEvent>[], score: 7, elapsed: 12, day: 2, minute: 500, availableLines: 2, ferryTokens: 0, houseTokens: 1, weather: WeatherType.rain, fleet: <CourierType, int>{CourierType.walk: 1, CourierType.bike: 2, CourierType.car: 3});
    final restored = GameSnapshot.fromJson(source.toJson());
    expect(restored.score, 7);
    expect(restored.weather, WeatherType.rain);
    expect(restored.fleet[CourierType.car], 3);
  });
}
