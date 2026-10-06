import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../core/game_config.dart';
import '../models/city.dart';
import '../models/entities.dart';
import '../services/ad_service.dart';
import '../services/audio_service.dart';
import '../services/persistence_service.dart';
import 'road_graph.dart';

final persistenceProvider = Provider<PersistenceService>((Ref ref) => throw UnimplementedError());
final adServiceProvider = Provider<AdService>((Ref ref) => throw UnimplementedError());
final audioServiceProvider = Provider<AudioService>((Ref ref) => throw UnimplementedError());
final cityProvider = Provider<CityData>((Ref ref) => throw UnimplementedError());
final gameControllerProvider = ChangeNotifierProvider<GameSessionController>((Ref ref) => GameSessionController(
      city: ref.watch(cityProvider),
      persistence: ref.watch(persistenceProvider),
      audio: ref.watch(audioServiceProvider),
      ads: ref.watch(adServiceProvider),
    ));

class GameSessionController extends ChangeNotifier {
  GameSessionController({required this.city, required this.persistence, required this.audio, required this.ads})
      : graph = RoadGraph(city) {
    final saved = persistence.loadSession();
    session = saved ?? _newSession(Difficulty.normal);
    for (final customer in session.customers) {
      _customerAppearance[customer.id] = 1;
    }
    _ticker = Timer.periodic(const Duration(milliseconds: 33), _onFrame);
  }

  final CityData city;
  final PersistenceService persistence;
  final AudioService audio;
  final AdService ads;
  final RoadGraph graph;
  final math.Random _random = math.Random();
  final Map<String, double> _customerAppearance = <String, double>{};

  late GameSnapshot session;
  late Timer _ticker;
  DateTime _lastFrame = DateTime.now();
  TimeScale timeScale = TimeScale.normal;
  String? selectedEntityId;
  bool gameOver = false;
  bool rewardPending = false;
  List<RewardType> rewardOptions = const <RewardType>[];
  bool tutorialVisible = false;
  bool isTutorial = false;
  double animation = 0;
  double _demandTimer = 7;
  double _eventTimer = 30;
  double _weatherTimer = 48;
  double _firstCustomerTimer = 3;
  double _nextCustomerTimer = 34;
  double _nextRestaurantTimer = 72;
  int _id = 100;
  String? failedCustomerId;

  GameSnapshot _newSession(Difficulty difficulty) {
    final cuisineNames = city.availableCuisines.isEmpty ? const <String>['pizza'] : city.availableCuisines;
    final cuisines = cuisineNames.map(Cuisine.values.byName).toList();
    final restaurantPois = List<CityPoi>.of(city.restaurantPois)..shuffle(_random);
    final restaurants = <Restaurant>[];
    if (restaurantPois.isNotEmpty) {
      final poi = restaurantPois.first;
      restaurants.add(Restaurant(
        id: poi.id,
        nodeId: poi.nodeId,
        cuisine: cuisines[_random.nextInt(cuisines.length)],
      ));
    }
    final sandbox = difficulty == Difficulty.sandbox;
    return GameSnapshot(
      difficulty: difficulty,
      restaurants: restaurants,
      customers: <Customer>[],
      lines: <DeliveryLine>[],
      couriers: <Courier>[],
      events: <RoadEvent>[],
      score: 0,
      elapsed: 0,
      day: 1,
      minute: 8 * 60,
      availableLines: sandbox ? 6 : 3,
      ferryTokens: 0,
      houseTokens: 0,
      weather: WeatherType.clear,
      fleet: <CourierType, int>{
        CourierType.walk: sandbox ? 8 : 3,
        CourierType.bike: sandbox ? 8 : 2,
        CourierType.car: sandbox ? 8 : 1,
      },
    );
  }

  /// Every mode shares the same soft opening: one kitchen now, its first
  /// matching customer after 2–4 seconds, then normal load growth.
  void startSession(Difficulty difficulty, {required bool tutorial}) {
    isTutorial = tutorial;
    session = _newSession(difficulty);
    gameOver = false;
    rewardPending = false;
    rewardOptions = const <RewardType>[];
    failedCustomerId = null;
    selectedEntityId = null;
    tutorialVisible = false;
    timeScale = TimeScale.normal;
    _customerAppearance.clear();
    _firstCustomerTimer = 2 + _random.nextDouble() * 2;
    _nextCustomerTimer = 34 + _random.nextDouble() * 12;
    _nextRestaurantTimer = 68 + _random.nextDouble() * 18;
    _demandTimer = 8;
    _eventTimer = tutorial ? 120 : 32;
    _weatherTimer = tutorial ? 135 : 48;
    _lastFrame = DateTime.now();
    unawaited(persistence.clearSession());
    notifyListeners();
  }

  void _onFrame(Timer _) {
    final now = DateTime.now();
    final realDt = math.min(.1, now.difference(_lastFrame).inMicroseconds / 1000000);
    _lastFrame = now;
    animation += realDt;
    for (final entry in _customerAppearance.entries.toList()) {
      if (entry.value < 1) _customerAppearance[entry.key] = math.min(1, entry.value + realDt / .72);
    }
    final dt = realDt * timeScale.value;
    if (dt > 0 && !gameOver && !rewardPending) _tick(dt);
    notifyListeners();
  }

  void _tick(double dt) {
    session.elapsed += dt;
    session.minute += dt * 10;
    while (session.minute >= 1440) {
      session.minute -= 1440;
      session.day++;
    }
    _tickPopulation(dt);
    _tickDemand(dt);
    _tickRestaurants(dt);
    _tickCouriers(dt);
    _tickEvents(dt);
    _tickOverload(dt);
  }

  void _tickPopulation(double dt) {
    if (session.customers.isEmpty) {
      _firstCustomerTimer -= dt;
      if (_firstCustomerTimer <= 0) _spawnCustomer(first: true);
      return;
    }

    _nextCustomerTimer -= dt * (1 + session.score / 220);
    if (_nextCustomerTimer <= 0) {
      _nextCustomerTimer = 36 + _random.nextDouble() * 18;
      _spawnCustomer();
    }
    _nextRestaurantTimer -= dt;
    if (_nextRestaurantTimer <= 0) {
      _nextRestaurantTimer = 78 + _random.nextDouble() * 28;
      _spawnRestaurant();
    }
  }

  void _spawnCustomer({bool first = false}) {
    if (session.restaurants.isEmpty) return;
    final used = session.customers.map((Customer c) => c.id).toSet();
    final candidates = city.customerPois.where((CityPoi p) => !used.contains(p.id)).toList()..shuffle(_random);
    if (candidates.isEmpty) return;
    final cuisine = first
        ? session.restaurants.first.cuisine
        : session.restaurants[_random.nextInt(session.restaurants.length)].cuisine;
    final poi = candidates.first;
    final customer = Customer(id: poi.id, nodeId: poi.nodeId, demand: <Cuisine, int>{cuisine: 1});
    session.customers.add(customer);
    _customerAppearance[customer.id] = 0;
    if (first && !persistence.tutorialSeen('routeGesture')) {
      tutorialVisible = true;
      unawaited(persistence.markTutorialSeen('routeGesture'));
    }
  }

  void _spawnRestaurant() {
    final used = session.restaurants.map((Restaurant r) => r.id).toSet();
    final candidates = city.restaurantPois.where((CityPoi p) => !used.contains(p.id)).toList()..shuffle(_random);
    if (candidates.isEmpty) return;
    final cuisines = city.availableCuisines.map(Cuisine.values.byName).toList();
    if (cuisines.isEmpty) return;
    final poi = candidates.first;
    session.restaurants.add(Restaurant(
      id: poi.id,
      nodeId: poi.nodeId,
      cuisine: cuisines[session.restaurants.length % cuisines.length],
    ));
  }

  double customerAppearance(Customer customer) => _customerAppearance[customer.id] ?? 1;

  List<Offset> get tutorialRoutePoints {
    if (!tutorialVisible || session.restaurants.isEmpty || session.customers.isEmpty) return const <Offset>[];
    final restaurant = session.restaurants.first;
    Customer? customer;
    for (final candidate in session.customers) {
      if ((candidate.demand[restaurant.cuisine] ?? 0) > 0) {
        customer = candidate;
        break;
      }
    }
    if (customer == null) return const <Offset>[];
    final route = graph.findPath(restaurant.nodeId, customer.nodeId, mode: CourierType.walk);
    if (route == null) return <Offset>[city.nodes[restaurant.nodeId]!.point, city.nodes[customer.nodeId]!.point];
    final points = <Offset>[];
    var node = restaurant.nodeId;
    for (final edgeId in route.edgeIds) {
      final edge = city.edgeById(edgeId);
      if (edge == null) continue;
      final segment = edge.from == node ? edge.points : edge.points.reversed;
      points.addAll(points.isEmpty ? segment : segment.skip(1));
      node = edge.from == node ? edge.to : edge.from;
    }
    return points;
  }

  void finishGestureHint() {
    if (!tutorialVisible) return;
    tutorialVisible = false;
    notifyListeners();
  }

  double get _orderMultiplier {
    var value = session.difficulty == Difficulty.realism
        ? 1.45
        : (session.difficulty == Difficulty.sandbox ? .35 : 1.0);
    if (session.weather == WeatherType.rain) value *= 1.35;
    for (final holiday in city.holidays) {
      if (session.day >= holiday.day && session.day < holiday.day + holiday.durationDays) value *= holiday.multiplier;
    }
    return value;
  }

  void _tickDemand(double dt) {
    _demandTimer -= dt * _orderMultiplier * (1 + session.score / 180);
    if (_demandTimer > 0 || session.customers.isEmpty || session.restaurants.isEmpty) return;
    _demandTimer = 5 + _random.nextDouble() * 5;
    final customer = session.customers[_random.nextInt(session.customers.length)];
    if (customer.demandSuspended) return;
    final cuisine = session.restaurants[_random.nextInt(session.restaurants.length)].cuisine;
    customer.demand[cuisine] = (customer.demand[cuisine] ?? 0) + 1;
  }

  void _tickRestaurants(double dt) {
    for (final restaurant in session.restaurants) {
      for (final dish in restaurant.dishes) {
        dish.age += dt;
      }
      restaurant.dishes.removeWhere((Dish dish) => dish.coolingStage >= 5);
      if (restaurant.dishes.length >= GameConfig.maxDishes) continue;
      final unmet = session.customers.fold<int>(0, (int value, Customer c) => value + (c.demand[restaurant.cuisine] ?? 0));
      restaurant.production += dt * (.045 + unmet * .009);
      if (restaurant.production >= 1) {
        restaurant.production = 0;
        restaurant.dishes.add(Dish(id: 'd${_id++}', cuisine: restaurant.cuisine));
        unawaited(audio.play(SoundCue.dishReady));
      }
    }
  }

  void _tickCouriers(double dt) {
    for (final courier in session.couriers) {
      final line = lineById(courier.lineId);
      if (line == null || line.edgeIds.isEmpty) {
        courier.state = CourierState.idle;
        continue;
      }
      final blocked = session.events.any((RoadEvent e) =>
          e.phase == EventPhase.active &&
          e.blocksCar &&
          courier.type == CourierType.car &&
          line.edgeIds.contains(e.edgeId));
      if (blocked) {
        courier.state = CourierState.waitingBlocked;
        continue;
      }
      courier.state = CourierState.moving;
      var modifier = session.weather == WeatherType.rain
          ? switch (courier.type) {
              CourierType.walk => .55,
              CourierType.bike => .68,
              CourierType.car => .86,
            }
          : 1.0;
      for (final event in session.events.where((RoadEvent e) => e.phase == EventPhase.active && line.edgeIds.contains(e.edgeId))) {
        if ((event.type == RoadEventType.trafficJam || event.type == RoadEventType.accident) && courier.type == CourierType.car) modifier *= .35;
        if (event.type == RoadEventType.roadworks && courier.type == CourierType.bike) modifier *= .7;
      }
      final routeLength = line.edgeIds.fold<double>(0, (double sum, String id) => sum + (city.edgeById(id)?.length ?? 0));
      final before = courier.progress;
      courier.progress += (courier.forward ? 1 : -1) * courier.type.speed * modifier * dt / math.max(1, routeLength);
      if (courier.progress >= 1) {
        courier.progress = 1;
        courier.forward = false;
        _arrive(courier, line.stopIds.last);
      }
      if (courier.progress <= 0) {
        courier.progress = 0;
        courier.forward = true;
        _arrive(courier, line.stopIds.first);
      }
      if ((before - courier.progress).abs() > .0001) _serviceCrossedStops(courier, line, before, courier.progress);
    }
  }

  void _serviceCrossedStops(Courier courier, DeliveryLine line, double before, double after) {
    if (line.stopIds.length <= 2) return;
    for (var i = 1; i < line.stopIds.length - 1; i++) {
      final fraction = i / (line.stopIds.length - 1);
      if ((before < fraction && after >= fraction) || (before > fraction && after <= fraction)) {
        _arrive(courier, line.stopIds[i]);
      }
    }
  }

  void _arrive(Courier courier, String entityId) {
    final customer = customerById(entityId);
    if (customer != null) {
      for (final dish in courier.cargo.toList()) {
        final wanted = customer.demand[dish.cuisine] ?? 0;
        if (wanted > 0) {
          customer.demand[dish.cuisine] = wanted - 1;
          customer.demandSuspended = false;
          courier.cargo.remove(dish);
          session.score++;
          unawaited(audio.play(SoundCue.delivery));
          if (session.score % GameConfig.deliveriesPerReward == 0) {
            rewardOptions = _rollRewards();
            rewardPending = true;
            timeScale = TimeScale.paused;
            unawaited(audio.play(SoundCue.levelUp));
          }
        }
      }
      if (!customer.overloaded) customer.overloadRemaining = null;
      return;
    }
    final restaurant = restaurantById(entityId);
    final line = lineById(courier.lineId);
    if (restaurant == null || line == null) return;
    final neededAhead = line.stopIds
        .map(customerById)
        .whereType<Customer>()
        .any((Customer c) => (c.demand[restaurant.cuisine] ?? 0) > 0);
    if (!neededAhead) return;
    while (courier.cargo.length < courier.type.capacity && restaurant.dishes.isNotEmpty) {
      courier.cargo.add(restaurant.dishes.removeAt(0));
      unawaited(audio.play(SoundCue.pickup));
    }
  }

  void _tickEvents(double dt) {
    for (final event in session.events.toList()) {
      event.remaining -= dt;
      if (event.remaining > 0) continue;
      if (event.phase == EventPhase.warning) {
        event.phase = EventPhase.active;
        event.remaining = event.total;
      } else {
        session.events.remove(event);
      }
    }
    if (isTutorial && session.elapsed < 120) return;
    _eventTimer -= dt * (1 + networkLoad / 40);
    if (_eventTimer <= 0 && city.edges.isNotEmpty) {
      _eventTimer = 22 + _random.nextDouble() * 18;
      final type = RoadEventType.values[_random.nextInt(RoadEventType.values.length)];
      final eventEdges = city.edges.where((RoadEdge edge) => edge.type != RoadType.ferry).toList();
      final edge = eventEdges[_random.nextInt(eventEdges.length)];
      final accident = type == RoadEventType.accident;
      session.events.add(RoadEvent(
        id: 'e${_id++}',
        type: type,
        edgeId: edge.id,
        remaining: accident ? 18 : 5,
        total: accident ? 18 : 22,
        phase: accident ? EventPhase.active : EventPhase.warning,
        blocksCar: type == RoadEventType.roadworks && _random.nextBool(),
      ));
      if (!accident) unawaited(audio.play(SoundCue.eventWarning));
    }
    _weatherTimer -= dt;
    if (_weatherTimer <= 0) {
      session.weather = session.weather == WeatherType.clear ? WeatherType.rain : WeatherType.clear;
      _weatherTimer = 35 + _random.nextDouble() * 35;
    }
  }

  void _tickOverload(double dt) {
    for (final customer in session.customers) {
      if (!customer.overloaded) {
        if (!customer.demandSuspended) customer.overloadRemaining = null;
        continue;
      }
      customer.overloadRemaining ??= session.difficulty == Difficulty.realism
          ? GameConfig.realismOverloadSeconds
          : GameConfig.normalOverloadSeconds;
      customer.overloadRemaining = customer.overloadRemaining! - dt;
      if (customer.overloadRemaining! > 0 || session.difficulty == Difficulty.sandbox) continue;
      if (session.difficulty == Difficulty.infinite) {
        for (final cuisine in customer.demand.keys.toList()) {
          customer.demand[cuisine] = (customer.demand[cuisine]! / 2).floor();
        }
        customer.demandSuspended = true;
        customer.overloadRemaining = 0;
        continue;
      }
      failedCustomerId = customer.id;
      gameOver = true;
      timeScale = TimeScale.paused;
      unawaited(audio.play(SoundCue.gameOver));
      unawaited(persistence.clearSession());
      if (isTutorial) unawaited(persistence.completeFirstLaunch());
      unawaited(persistence.saveRecord(city.cityId, session.difficulty, session.score, session.elapsed, session.lines.length));
      ads.onGameFinished();
      break;
    }
  }

  double get networkLoad =>
      session.customers.fold<int>(0, (int value, Customer c) => value + c.totalDemand) + session.couriers.length * 1.5;
  String get formattedTime =>
      '${(session.minute ~/ 60).toString().padLeft(2, '0')}:${(session.minute.toInt() % 60).toString().padLeft(2, '0')}';
  String get formattedSurvival {
    final total = session.elapsed.floor();
    final minutes = total ~/ 60;
    final seconds = total % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  void setTimeScale(TimeScale value) {
    if (session.difficulty != Difficulty.realism || value != TimeScale.paused) {
      timeScale = value;
      notifyListeners();
    }
  }

  void handleMapTap(Offset point) {
    final entity = entityNear(point);
    if (entity == null) {
      selectedEntityId = null;
      notifyListeners();
      return;
    }
    if (session.houseTokens > 0) {
      final customer = customerById(entity);
      if (customer != null && !customer.houseApplied) {
        customer.houseApplied = true;
        session.houseTokens--;
        notifyListeners();
        return;
      }
    }
    if (selectedEntityId == null) {
      selectedEntityId = entity;
      notifyListeners();
      return;
    }
    if (selectedEntityId == entity) {
      selectedEntityId = null;
      notifyListeners();
      return;
    }
    createLine(selectedEntityId!, entity);
    selectedEntityId = null;
    notifyListeners();
  }

  String? entityNear(Offset point) {
    String? result;
    var best = 42.0;
    for (final restaurant in session.restaurants) {
      final node = city.nodes[restaurant.nodeId];
      if (node == null) continue;
      final d = (node.point - point).distance;
      if (d < best) {
        best = d;
        result = restaurant.id;
      }
    }
    for (final customer in session.customers) {
      final node = city.nodes[customer.nodeId];
      if (node == null) continue;
      final d = (node.point - point).distance;
      if (d < best) {
        best = d;
        result = customer.id;
      }
    }
    return result;
  }

  void createLine(String fromEntity, String toEntity) {
    if (session.availableLines <= 0 || session.lines.length >= GameConfig.maxLines) return;
    final fromNode = nodeForEntity(fromEntity);
    final toNode = nodeForEntity(toEntity);
    if (fromNode == null || toNode == null) return;
    final path = graph.findPath(fromNode, toNode, allowFerry: session.ferryTokens > 0);
    if (path == null || path.edgeIds.isEmpty) return;
    session.lines.add(DeliveryLine(
      id: 'l${_id++}',
      colorIndex: session.lines.length % GameConfig.lineColors.length,
      stopIds: <String>[fromEntity, toEntity],
      edgeIds: path.edgeIds,
    ));
    session.availableLines--;
  }

  void createManualLine(List<Offset> points) {
    if (points.length < 2) return;
    final first = entityNear(points.first);
    final last = entityNear(points.last);
    if (first != null && last != null && first != last) createLine(first, last);
  }

  void assignCourier(CourierType type, Offset point) {
    if ((session.fleet[type] ?? 0) <= 0 || session.lines.isEmpty) return;
    DeliveryLine? best;
    var distance = double.infinity;
    for (final line in session.lines) {
      final assigned = session.couriers.where((Courier c) => c.lineId == line.id).length;
      if (assigned >= GameConfig.maxCouriersPerLine) continue;
      for (final edgeId in line.edgeIds) {
        final edge = city.edgeById(edgeId);
        if (edge == null) continue;
        for (final p in edge.points) {
          final d = (p - point).distance;
          if (d < distance) {
            distance = d;
            best = line;
          }
        }
      }
    }
    if (best == null) return;
    session.fleet[type] = session.fleet[type]! - 1;
    session.couriers.add(Courier(id: 'c${_id++}', type: type, lineId: best.id));
  }

  List<RewardType> get rewards => rewardOptions.isEmpty ? _rollRewards() : rewardOptions;

  List<RewardType> _rollRewards() {
    final result = <RewardType>[
      if (session.lines.length < GameConfig.maxLines)
        RewardType.line
      else
        RewardType.values[1 + _random.nextInt(3)],
      RewardType.values[1 + _random.nextInt(3)],
    ];
    if (city.ferryPoints.isNotEmpty && session.ferryTokens < city.ferryPoints.length) {
      result.add(RewardType.ferry);
    } else {
      result.add(RewardType.values[1 + _random.nextInt(3)]);
    }
    if (session.customers.any((Customer c) => c.totalDemand >= 6 && !c.houseApplied)) result[2] = RewardType.house;
    return result;
  }

  void chooseReward(RewardType reward) {
    switch (reward) {
      case RewardType.line:
        session.availableLines++;
      case RewardType.walker:
        session.fleet[CourierType.walk] = session.fleet[CourierType.walk]! + 1;
      case RewardType.bike:
        session.fleet[CourierType.bike] = session.fleet[CourierType.bike]! + 1;
      case RewardType.car:
        session.fleet[CourierType.car] = session.fleet[CourierType.car]! + 1;
      case RewardType.ferry:
        session.ferryTokens++;
      case RewardType.house:
        session.houseTokens++;
    }
    rewardPending = false;
    timeScale = TimeScale.normal;
    notifyListeners();
  }

  void continueRewarded() {
    final customer = customerById(failedCustomerId);
    if (customer == null) return;
    customer.demand.clear();
    customer.overloadRemaining = null;
    customer.demandSuspended = false;
    gameOver = false;
    failedCustomerId = null;
    timeScale = TimeScale.normal;
    notifyListeners();
  }

  void restart(Difficulty difficulty) => startSession(difficulty, tutorial: isTutorial);
  Future<void> abandon() async {
    gameOver = true;
    timeScale = TimeScale.paused;
    await persistence.clearSession();
  }

  Future<void> save() => gameOver ? Future<void>.value() : persistence.saveSession(session);
  Restaurant? restaurantById(String? id) {
    for (final value in session.restaurants) {
      if (value.id == id) return value;
    }
    return null;
  }

  Customer? customerById(String? id) {
    for (final value in session.customers) {
      if (value.id == id) return value;
    }
    return null;
  }

  DeliveryLine? lineById(String? id) {
    for (final value in session.lines) {
      if (value.id == id) return value;
    }
    return null;
  }

  String? nodeForEntity(String id) => restaurantById(id)?.nodeId ?? customerById(id)?.nodeId;

  @override
  void dispose() {
    _ticker.cancel();
    unawaited(save());
    super.dispose();
  }
}
