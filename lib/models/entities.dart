
import '../core/game_config.dart';

enum Cuisine { pizza, asian, burger, dessert, healthy }
enum Difficulty { normal, realism, infinite, sandbox }
enum CourierType { walk, bike, car }
enum CourierState { moving, waitingBlocked, idle, reassigning }
enum RoadEventType { trafficJam, roadworks, accident }
enum EventPhase { warning, active }
enum WeatherType { clear, rain }
enum RewardType { line, walker, bike, car, ferry, house }

enum TimeScale { paused, normal, fast }
extension TimeScaleValue on TimeScale { double get value => switch (this) { TimeScale.paused => 0, TimeScale.normal => 1, TimeScale.fast => 2 }; }

extension CourierBalance on CourierType {
  double get speed => switch (this) { CourierType.walk => 37, CourierType.bike => 62, CourierType.car => 92 };
  int get capacity => switch (this) { CourierType.walk => 2, CourierType.bike => 3, CourierType.car => 5 };
}

class Dish {
  Dish({required this.id, required this.cuisine, this.age = 0});
  final String id;
  final Cuisine cuisine;
  double age;
  int get coolingStage => (age / GameConfig.dishLifetime * 5).floor().clamp(0, 5);
  Map<String, Object?> toJson() => <String, Object?>{'id': id, 'cuisine': cuisine.name, 'age': age};
  factory Dish.fromJson(Map<String, Object?> j) => Dish(id: j['id']! as String, cuisine: Cuisine.values.byName(j['cuisine']! as String), age: (j['age']! as num).toDouble());
}

class Restaurant {
  Restaurant({required this.id, required this.nodeId, required this.cuisine, List<Dish>? dishes, this.production = 0}) : dishes = dishes ?? <Dish>[];
  final String id;
  final String nodeId;
  final Cuisine cuisine;
  final List<Dish> dishes;
  double production;
  Map<String, Object?> toJson() => <String, Object?>{'id': id, 'nodeId': nodeId, 'cuisine': cuisine.name, 'dishes': dishes.map((Dish d) => d.toJson()).toList(), 'production': production};
  factory Restaurant.fromJson(Map<String, Object?> j) => Restaurant(id: j['id']! as String, nodeId: j['nodeId']! as String, cuisine: Cuisine.values.byName(j['cuisine']! as String), dishes: (j['dishes']! as List<Object?>).map((Object? d) => Dish.fromJson(d! as Map<String, Object?>)).toList(), production: (j['production']! as num).toDouble());
}

class Customer {
  Customer({required this.id, required this.nodeId, Map<Cuisine, int>? demand, this.houseApplied = false, this.overloadRemaining, this.demandSuspended = false}) : demand = demand ?? <Cuisine, int>{};
  final String id;
  final String nodeId;
  final Map<Cuisine, int> demand;
  bool houseApplied;
  double? overloadRemaining;
  bool demandSuspended;
  int get limit => houseApplied ? GameConfig.upgradedDemandLimit : GameConfig.baseDemandLimit;
  int get totalDemand => demand.values.fold(0, (int a, int b) => a + b);
  bool get overloaded => totalDemand > limit;
  Map<String, Object?> toJson() => <String, Object?>{'id': id, 'nodeId': nodeId, 'demand': demand.map((Cuisine k, int v) => MapEntry(k.name, v)), 'houseApplied': houseApplied, 'overloadRemaining': overloadRemaining, 'demandSuspended': demandSuspended};
  factory Customer.fromJson(Map<String, Object?> j) => Customer(id: j['id']! as String, nodeId: j['nodeId']! as String, demand: (j['demand']! as Map<String, Object?>).map((String k, Object? v) => MapEntry(Cuisine.values.byName(k), (v! as num).toInt())), houseApplied: (j['houseApplied'] as bool?) ?? false, overloadRemaining: (j['overloadRemaining'] as num?)?.toDouble(), demandSuspended: (j['demandSuspended'] as bool?) ?? false);
}

class DeliveryLine {
  DeliveryLine({required this.id, required this.colorIndex, required this.stopIds, required this.edgeIds});
  final String id;
  final int colorIndex;
  final List<String> stopIds;
  final List<String> edgeIds;
  Map<String, Object?> toJson() => <String, Object?>{'id': id, 'colorIndex': colorIndex, 'stopIds': stopIds, 'edgeIds': edgeIds};
  factory DeliveryLine.fromJson(Map<String, Object?> j) => DeliveryLine(id: j['id']! as String, colorIndex: (j['colorIndex']! as num).toInt(), stopIds: (j['stopIds']! as List<Object?>).cast<String>(), edgeIds: (j['edgeIds']! as List<Object?>).cast<String>());
}

class Courier {
  Courier({required this.id, required this.type, this.lineId, List<Dish>? cargo, this.progress = 0, this.forward = true, this.state = CourierState.idle}) : cargo = cargo ?? <Dish>[];
  final String id;
  final CourierType type;
  String? lineId;
  final List<Dish> cargo;
  double progress;
  bool forward;
  CourierState state;
  Map<String, Object?> toJson() => <String, Object?>{'id': id, 'type': type.name, 'lineId': lineId, 'cargo': cargo.map((Dish d) => d.toJson()).toList(), 'progress': progress, 'forward': forward, 'state': state.name};
  factory Courier.fromJson(Map<String, Object?> j) => Courier(id: j['id']! as String, type: CourierType.values.byName(j['type']! as String), lineId: j['lineId'] as String?, cargo: (j['cargo']! as List<Object?>).map((Object? d) => Dish.fromJson(d! as Map<String, Object?>)).toList(), progress: (j['progress']! as num).toDouble(), forward: j['forward']! as bool, state: CourierState.values.byName(j['state']! as String));
}

class RoadEvent {
  RoadEvent({required this.id, required this.type, required this.edgeId, required this.remaining, required this.total, required this.phase, this.blocksCar = false});
  final String id;
  final RoadEventType type;
  final String edgeId;
  double remaining;
  final double total;
  EventPhase phase;
  final bool blocksCar;
  double get fraction => (remaining / total).clamp(0, 1);
  Map<String, Object?> toJson() => <String, Object?>{'id': id, 'type': type.name, 'edgeId': edgeId, 'remaining': remaining, 'total': total, 'phase': phase.name, 'blocksCar': blocksCar};
  factory RoadEvent.fromJson(Map<String, Object?> j) => RoadEvent(id: j['id']! as String, type: RoadEventType.values.byName(j['type']! as String), edgeId: j['edgeId']! as String, remaining: (j['remaining']! as num).toDouble(), total: (j['total']! as num).toDouble(), phase: EventPhase.values.byName(j['phase']! as String), blocksCar: (j['blocksCar'] as bool?) ?? false);
}

class GameSnapshot {
  GameSnapshot({
    required this.difficulty, required this.restaurants, required this.customers,
    required this.lines, required this.couriers, required this.events,
    required this.score, required this.elapsed, required this.day,
    required this.minute, required this.availableLines, required this.ferryTokens,
    required this.houseTokens, required this.weather, required this.fleet,
  });
  Difficulty difficulty;
  List<Restaurant> restaurants;
  List<Customer> customers;
  List<DeliveryLine> lines;
  List<Courier> couriers;
  List<RoadEvent> events;
  int score;
  double elapsed;
  int day;
  double minute;
  int availableLines;
  int ferryTokens;
  int houseTokens;
  WeatherType weather;
  Map<CourierType, int> fleet;

  Map<String, Object?> toJson() => <String, Object?>{
    'difficulty': difficulty.name, 'restaurants': restaurants.map((Restaurant e) => e.toJson()).toList(),
    'customers': customers.map((Customer e) => e.toJson()).toList(), 'lines': lines.map((DeliveryLine e) => e.toJson()).toList(),
    'couriers': couriers.map((Courier e) => e.toJson()).toList(), 'events': events.map((RoadEvent e) => e.toJson()).toList(),
    'score': score, 'elapsed': elapsed, 'day': day, 'minute': minute, 'availableLines': availableLines,
    'ferryTokens': ferryTokens, 'houseTokens': houseTokens, 'weather': weather.name,
    'fleet': fleet.map((CourierType k, int v) => MapEntry(k.name, v)),
  };
  factory GameSnapshot.fromJson(Map<String, Object?> j) => GameSnapshot(
    difficulty: Difficulty.values.byName(j['difficulty']! as String),
    restaurants: (j['restaurants']! as List<Object?>).map((Object? e) => Restaurant.fromJson(e! as Map<String, Object?>)).toList(),
    customers: (j['customers']! as List<Object?>).map((Object? e) => Customer.fromJson(e! as Map<String, Object?>)).toList(),
    lines: (j['lines']! as List<Object?>).map((Object? e) => DeliveryLine.fromJson(e! as Map<String, Object?>)).toList(),
    couriers: (j['couriers']! as List<Object?>).map((Object? e) => Courier.fromJson(e! as Map<String, Object?>)).toList(),
    events: (j['events']! as List<Object?>).map((Object? e) => RoadEvent.fromJson(e! as Map<String, Object?>)).toList(),
    score: (j['score']! as num).toInt(), elapsed: (j['elapsed']! as num).toDouble(), day: (j['day']! as num).toInt(), minute: (j['minute']! as num).toDouble(),
    availableLines: (j['availableLines']! as num).toInt(), ferryTokens: (j['ferryTokens']! as num).toInt(), houseTokens: (j['houseTokens']! as num).toInt(),
    weather: WeatherType.values.byName(j['weather']! as String), fleet: (j['fleet']! as Map<String, Object?>).map((String k, Object? v) => MapEntry(CourierType.values.byName(k), (v! as num).toInt())),
  );
}
