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

  // Requirement 21: Base speed as fraction of map dimension
  test('courier speeds adapt to map dimension and meet minimum speedup', () {
    const mapSize = 1500.0;
    final walkSpeed = CourierType.walk.calculateSpeed(mapSize);
    final bikeSpeed = CourierType.bike.calculateSpeed(mapSize);
    final carSpeed = CourierType.car.calculateSpeed(mapSize);

    expect(walkSpeed, greaterThan(65.0)); // > 1.75x previous 37
    expect(bikeSpeed, greaterThan(110.0)); // > 1.75x previous 62
    expect(carSpeed, greaterThan(170.0)); // > 1.8x previous 92
  });

  test('snapshot survives JSON-compatible round trip with unlocked courier types and reveal stages', () {
    final source = GameSnapshot(
      difficulty: Difficulty.normal,
      restaurants: <Restaurant>[],
      customers: <Customer>[],
      lines: <DeliveryLine>[],
      couriers: <Courier>[],
      events: <RoadEvent>[],
      score: 7,
      elapsed: 12,
      day: 2,
      minute: 500,
      availableLines: 2,
      ferryTokens: 0,
      houseTokens: 1,
      weather: WeatherType.rain,
      fleet: <CourierType, int>{CourierType.walk: 1, CourierType.bike: 2, CourierType.car: 3},
      unlockedCourierTypes: <CourierType>{CourierType.walk, CourierType.bike},
      activeRevealStage: 1,
    );
    final restored = GameSnapshot.fromJson(source.toJson());
    expect(restored.score, 7);
    expect(restored.weather, WeatherType.rain);
    expect(restored.fleet[CourierType.car], 3);
    expect(restored.unlockedCourierTypes.contains(CourierType.bike), isTrue);
    expect(restored.activeRevealStage, 1);
  });
}
