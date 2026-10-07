import 'package:flutter_test/flutter_test.dart';

import 'package:rushhour/models/city.dart';
import 'package:rushhour/ui/game_screen.dart';

import 'game_harness.dart';

late CityData _city;

/// QA evidence generator for Requirement 46 (schemaVersion 3 water).
///
/// Renders the REAL game screen with the REAL Rivergate map and produces
/// `goldens/river_map.png`, which shows the new water rendering on the live
/// map: the wide `river.areas` are *filled* polygons (translucent water
/// colour with a thin shoreline) and the narrow `river.segments` are thin
/// polylines in the very same colour - instead of the single thick stroke
/// used before Requirement 46.
///
/// Run with `flutter test --update-goldens` to (re)generate the file;
/// `tools/make_evidence_gif.py` copies it into `docs/qa/`.
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    _city = await CityData.load('rivergate');
  });

  testWidgets('evidence: filled water areas and thin water segments', (
    WidgetTester tester,
  ) async {
    await loadAppFonts(tester);

    // Requirement 46: both shapes are present in the shipped city data and
    // both are what the painter consumes.
    expect(_city.hasWater, isTrue);
    expect(_city.riverAreas, isNotEmpty);
    expect(_city.riverSegments, isNotEmpty);
    expect(_city.riverAreas.every((List area) => area.length >= 3), isTrue);
    expect(_city.riverSegments.every((List segment) => segment.length >= 2), isTrue);

    await pumpGameScreen(
      tester,
      city: _city,
      seedRestaurants: const <String>['r003'],
      seedCustomers: const <String>['c011'],
      seedLineBetween: true,
    );
    await tester.pump(const Duration(milliseconds: 200));

    await expectLater(
      find.byType(GameScreen),
      matchesGoldenFile('goldens/river_map.png'),
    );
  });
}
