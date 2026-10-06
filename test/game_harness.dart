/// Shared test doubles and harness for pumping the real [GameScreen] with
/// the real Rivergate city, without Hive, ads or audio plugins.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rushhour/core/flowline_theme.dart';
import 'package:rushhour/game/game_controller.dart';
import 'package:rushhour/l10n/app_strings.dart';
import 'package:rushhour/models/city.dart';
import 'package:rushhour/models/entities.dart';
import 'package:rushhour/painters/game_painter.dart';
import 'package:rushhour/services/ad_service.dart';
import 'package:rushhour/services/audio_service.dart';
import 'package:rushhour/services/persistence_service.dart';
import 'package:rushhour/ui/game_screen.dart';

class FakePersistenceService extends PersistenceService {
  @override
  bool get isFirstLaunch => false;

  @override
  Future<void> completeFirstLaunch() async {}

  @override
  bool tutorialSeen(String key) => true;

  @override
  Future<void> markTutorialSeen(String key) async {}

  @override
  Future<void> resetTutorial() async {}

  @override
  String get language => 'en';

  @override
  Future<void> setLanguage(String value) async {}

  @override
  ThemeMode get themeMode => ThemeMode.light;

  @override
  Future<void> setThemeMode(ThemeMode mode) async {}

  @override
  bool get audioEnabled => false;

  @override
  Future<void> setAudioEnabled(bool value) async {}

  @override
  Future<void> saveSession(GameSnapshot snapshot) async {}

  @override
  GameSnapshot? loadSession() => null;

  @override
  Future<void> clearSession() async {}

  @override
  Future<void> saveRecord(
    String cityId,
    Difficulty difficulty,
    double survival,
    int networkSize,
  ) async {}
}

class SilentAudioService extends AudioService {
  SilentAudioService() : super(enabled: false);

  @override
  Future<void> preload() async {}

  @override
  Future<void> play(SoundCue cue) async {}

  @override
  Future<void> dispose() async {}
}

class StubAdService extends AdService {
  @override
  Future<void> initialize() async {}

  @override
  Future<void> loadBanner() async {}

  @override
  void onGameFinished() {}
}

/// Loads the real UI font so golden-file screenshots show proper text.
Future<void> loadAppFonts() async {
  final loader = FontLoader('FlowlineSans');
  for (final path in const <String>[
    'assets/fonts/DejaVuSans.ttf',
    'assets/fonts/DejaVuSans-Bold.ttf',
  ]) {
    final bytes = File(path).readAsBytesSync();
    loader.addFont(Future<ByteData>.value(
      ByteData.view(bytes.buffer, bytes.offsetInBytes, bytes.lengthInBytes),
    ));
  }
  await loader.load();
}

/// The live game session plus helpers to read the real widget geometry.
class GameHarness {
  GameHarness({required this.game, required this.city, required this.tester});

  final GameSessionController game;
  final CityData city;
  final WidgetTester tester;

  /// Screen-space rect of the positioned hit-area widget of a POI entity
  /// (Requirement 44.2 — measured from the real render tree).
  Rect hitRect(String entityId) {
    final finder = find.byKey(ValueKey<String>('poi-hit-$entityId'));
    expect(finder, findsOneWidget, reason: 'hit-area widget for $entityId');
    return tester.getRect(finder);
  }

  /// Global (screen) position of a world point as it is actually painted in
  /// the world layer — resolved through the render tree's live camera
  /// transform, NOT through any re-implemented projection, so tests measure
  /// what the user really sees (Requirement 44.5).
  Offset paintedGlobalPosition(Offset worldPoint) {
    final finder = find.byWidgetPredicate(
      (Widget widget) => widget is CustomPaint && widget.painter is GamePainter,
    );
    final renderObject = tester.renderObject<RenderBox>(finder);
    return renderObject.localToGlobal(worldPoint);
  }

  RoadNode nodeOf(String entityId) {
    final nodeId = game.nodeForEntity(entityId)!;
    return game.city.nodes[nodeId]!;
  }
}

/// Pumps the real [GameScreen] with the real city and deterministic,
/// hand-seeded entities (the controller's own random spawning is
/// unpredictable in tests, so the harness seeds known POIs directly).
Future<GameHarness> pumpGameScreen(
  WidgetTester tester, {
  bool debugHitBoxes = false,
  Size logicalSize = const Size(390, 844),
  double devicePixelRatio = 2.0,
  List<String> seedRestaurants = const ['r001', 'r002'],
  List<String> seedCustomers = const ['c001', 'c002', 'c003'],
  bool seedLineBetween = false,
}) async {
  final city = await CityData.load('rivergate');
  final persistence = FakePersistenceService();
  final audio = SilentAudioService();
  final ads = StubAdService();

  final container = ProviderContainer(overrides: <Override>[
    persistenceProvider.overrideWithValue(persistence),
    cityProvider.overrideWithValue(city),
    audioServiceProvider.overrideWithValue(audio),
    adServiceProvider.overrideWithValue(ads),
  ]);
  addTearDown(container.dispose);

  tester.view.physicalSize = logicalSize * devicePixelRatio;
  tester.view.devicePixelRatio = devicePixelRatio;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: const Locale('en'),
        supportedLocales: const <Locale>[Locale('en'), Locale('ru')],
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          AppStringsDelegate(),
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: FlowlineTheme.light,
        home: GameScreen(
          difficulty: Difficulty.normal,
          tutorial: false,
          startNew: true,
          debugHitBoxes: debugHitBoxes,
          onReturnToMenu: () async {},
        ),
      ),
    ),
  );

  // Flush initState post-frame callbacks (listener wiring + startSession).
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));

  final game = container.read(gameControllerProvider);

  // Seed deterministic entities (skip ids the random spawn already used).
  for (final id in seedRestaurants) {
    if (game.restaurantById(id) != null) continue;
    final poi = city.restaurantPois.firstWhere((CityPoi p) => p.id == id);
    game.session.restaurants.add(
      Restaurant(id: poi.id, nodeId: poi.nodeId, cuisine: Cuisine.pizza),
    );
  }
  for (final id in seedCustomers) {
    if (game.customerById(id) != null) continue;
    final poi = city.customerPois.firstWhere((CityPoi p) => p.id == id);
    game.session.customers.add(
      Customer(id: poi.id, nodeId: poi.nodeId, demand: <Cuisine, int>{Cuisine.pizza: 2}),
    );
  }
  if (seedLineBetween && game.session.lines.isEmpty) {
    game.createLine(seedRestaurants.first, seedCustomers.first);
  }

  // Force the UI to rebuild with the seeded entities.
  game.setTimeScale(TimeScale.normal);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));

  return GameHarness(game: game, city: city, tester: tester);
}
