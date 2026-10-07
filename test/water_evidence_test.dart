import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rushhour/core/game_config.dart';
import 'package:rushhour/models/city.dart';
import 'package:rushhour/painters/static_map_painter.dart';
import 'package:rushhour/ui/game_screen.dart';

import 'game_harness.dart';

late CityData _city;

/// QA evidence generator for Requirement 46 (schemaVersion 3 water).
///
/// Produces two goldens from the REAL Rivergate map:
///
/// * `goldens/river_map.png` — the live game screen: it shows the new water
///   rendering (filled `river.areas` polygons plus thin `river.segments`
///   polylines) instead of the single thick stroke used before Requirement 46.
///   The test also prints the screen coordinates of a deep interior point of
///   the biggest water polygon and of the water polylines, so the analysis can
///   sample those exact pixels in the PNG.
/// * `goldens/river_painter.png` — `StaticMapPainter` painted at the city's
///   own world size (1 golden pixel == 1 world unit), which makes the fill
///   checkable pixel-exactly against the map geometry.
///
/// Run with `flutter test --update-goldens` to (re)generate the files;
/// `tools/make_evidence_gif.py` copies them into `docs/qa/`.
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

    final harness = await pumpGameScreen(
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

    // ---- QA probes: where does the water land on screen? -------------------
    // The projection used here is the live one of the rendered map layer
    // (Requirement 43/44.5), so the printed coordinates identify the very
    // pixels of `river_map.png` that the PNG analysis has to inspect.
    final areas = _city.riverAreas.toList()
      ..sort((List<Offset> a, List<Offset> b) => _shoelace(b).compareTo(_shoelace(a)));
    final biggest = areas.first;
    final ringBounds = _bounds(biggest);

    Offset? deep;
    var deepDistance = 0.0;
    for (var i = 1; i < 40 && deep == null; i++) {
      for (var j = 1; j < 40 && deep == null; j++) {
        final candidate = Offset(
          ringBounds.left + ringBounds.width * i / 40,
          ringBounds.top + ringBounds.height * j / 40,
        );
        final distance = _distanceToRing(candidate, biggest);
        if (_pointInRing(candidate, biggest) && distance > 20) {
          deep = candidate;
          deepDistance = distance;
        }
      }
    }
    if (deep != null) {
      final screen = harness.paintedGlobalPosition(deep);
      debugPrint(
        'Requirement 46 probe area: world=${deep.dx.toStringAsFixed(1)},${deep.dy.toStringAsFixed(1)} '
        'screen=${screen.dx.toStringAsFixed(1)},${screen.dy.toStringAsFixed(1)} '
        'depth=${deepDistance.toStringAsFixed(1)}px points=${biggest.length} '
        'area=${_shoelace(biggest).toStringAsFixed(0)}px2',
      );
    }

    // The polygon outline in screen space, so the analysis can check the whole
    // filled region instead of a single pixel.
    final ringScreen = <String>[
      for (var i = 0; i < biggest.length; i += 6)
        _screenPair(harness.paintedGlobalPosition(biggest[i])),
    ];
    debugPrint('Requirement 46 probe ring: ${ringScreen.join(' ')}');

    for (final segment in _city.riverSegments) {
      final middle = segment[segment.length ~/ 2];
      final screen = harness.paintedGlobalPosition(middle);
      debugPrint(
        'Requirement 46 probe segment: world=${middle.dx.toStringAsFixed(1)},${middle.dy.toStringAsFixed(1)} '
        'screen=${screen.dx.toStringAsFixed(1)},${screen.dy.toStringAsFixed(1)}',
      );
    }
  });

  testWidgets('evidence: StaticMapPainter fills the water areas (1:1 pixels)', (
    WidgetTester tester,
  ) async {
    // Painted at the city's own world size, so every pixel of the golden is
    // exactly one world unit and the QA analysis can sample the water fill by
    // world coordinates.
    tester.view.physicalSize = GameConfig.worldSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      RepaintBoundary(
        key: const ValueKey<String>('water-painter'),
        child: SizedBox.fromSize(
          size: GameConfig.worldSize,
          child: CustomPaint(painter: StaticMapPainter(_city)),
        ),
      ),
    );
    await tester.pump();

    await expectLater(
      find.byKey(const ValueKey<String>('water-painter')),
      matchesGoldenFile('goldens/river_painter.png'),
    );
  });
}

String _screenPair(Offset screen) =>
    '${screen.dx.toStringAsFixed(1)}:${screen.dy.toStringAsFixed(1)}';

double _shoelace(List<Offset> ring) {
  var sum = 0.0;
  for (var i = 0; i < ring.length; i++) {
    final a = ring[i];
    final b = ring[(i + 1) % ring.length];
    sum += a.dx * b.dy - b.dx * a.dy;
  }
  return sum.abs() / 2;
}

Rect _bounds(List<Offset> points) {
  var left = double.infinity;
  var top = double.infinity;
  var right = double.negativeInfinity;
  var bottom = double.negativeInfinity;
  for (final point in points) {
    left = point.dx < left ? point.dx : left;
    top = point.dy < top ? point.dy : top;
    right = point.dx > right ? point.dx : right;
    bottom = point.dy > bottom ? point.dy : bottom;
  }
  return Rect.fromLTRB(left, top, right, bottom);
}

bool _pointInRing(Offset point, List<Offset> ring) {
  var inside = false;
  for (var i = 0, j = ring.length - 1; i < ring.length; j = i++) {
    final a = ring[i];
    final b = ring[j];
    if ((a.dy > point.dy) != (b.dy > point.dy) &&
        point.dx < (b.dx - a.dx) * (point.dy - a.dy) / (b.dy - a.dy) + a.dx) {
      inside = !inside;
    }
  }
  return inside;
}

double _distanceToRing(Offset point, List<Offset> ring) {
  var best = double.infinity;
  for (var i = 0; i < ring.length; i++) {
    final a = ring[i];
    final b = ring[(i + 1) % ring.length];
    final delta = b - a;
    final lengthSquared = delta.dx * delta.dx + delta.dy * delta.dy;
    var t = 0.0;
    if (lengthSquared > 0) {
      t = (((point.dx - a.dx) * delta.dx + (point.dy - a.dy) * delta.dy) / lengthSquared)
          .clamp(0.0, 1.0)
          .toDouble();
    }
    final d = (point - Offset(a.dx + delta.dx * t, a.dy + delta.dy * t)).distance;
    if (d < best) best = d;
  }
  return best;
}
