import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rushhour/core/touch_targets.dart';
import 'package:rushhour/models/city.dart';

import 'game_harness.dart';

late CityData _city;

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    _city = await CityData.load('rivergate');
  });

  testWidgets('every active POI has a 48x48 hit area centred on the painted icon', (
    WidgetTester tester,
  ) async {
    final harness = await pumpGameScreen(tester, city: _city);
    final game = harness.game;

    final entities = <String>[
      for (final r in game.session.restaurants) r.id,
      for (final c in game.session.customers) c.id,
    ];
    expect(entities.length, greaterThanOrEqualTo(5));

    for (final entityId in entities) {
      final rect = harness.hitRect(entityId);
      // Requirement 44.2: fixed 48x48 logical-pixel square, independent of
      // the (much smaller) painted icon size.
      expect(rect.width, TouchTargets.poiHitSize,
          reason: '$entityId hit box width');
      expect(rect.height, TouchTargets.poiHitSize,
          reason: '$entityId hit box height');

      // Requirement 44.5: the hit box must be centred exactly where the icon
      // is painted — measured through the real render tree (the world
      // CustomPaint with the live camera transform), not by re-implementing
      // any projection in the test.
      final iconCentre = harness.paintedGlobalPosition(harness.nodeOf(entityId).point);
      expect(
        (rect.center - iconCentre).distance,
        lessThan(0.5),
        reason: '$entityId hit box centre must coincide with the painted icon',
      );
    }

    // The restaurant icon itself is much smaller than its hit box (the whole
    // point of the fix): a 20-radius circle around the icon stays inside.
    final restaurantRect = harness.hitRect('r001');
    final iconCentre = harness.paintedGlobalPosition(harness.nodeOf('r001').point);
    final offCentre = iconCentre + const Offset(16, -15); // ~21.9 px away
    expect(restaurantRect.contains(offCentre), isTrue,
        reason: 'a touch ~22px from the centre must still be inside the hit area');
  });

  testWidgets(
      'ACCEPTANCE: line drawing starts from a touch ~21px off the restaurant icon centre '
      'and commits on the customer', (WidgetTester tester) async {
    final harness = await pumpGameScreen(tester, city: _city);
    final game = harness.game;

    final iconCentre = harness.paintedGlobalPosition(harness.nodeOf('r001').point);
    // The finger does NOT touch the icon: ~21.9px away from the centre,
    // inside the 48x48 hit area (the bug of patches #2/#3 made this fail).
    final touchDown = iconCentre + const Offset(16, -15);
    expect(harness.hitRect('r001').contains(touchDown), isTrue);

    final customerCentre = harness.paintedGlobalPosition(harness.nodeOf('c001').point);

    final gesture = await tester.startGesture(touchDown);
    await tester.pump(const Duration(milliseconds: 40));

    // Move past the touch slop — the drag must turn into a line draft.
    await gesture.moveBy(const Offset(24, 18));
    await tester.pump(const Duration(milliseconds: 40));

    expect(game.lineDraft, isNotNull,
        reason: 'the line draft must start as soon as the finger moves');
    expect(game.lineDraft!.startEntityId, 'r001');

    // Drag towards the customer icon in small visible steps.
    const steps = 8;
    final step = (customerCentre - (touchDown + const Offset(24, 18))) * (1.0 / steps);
    for (var i = 0; i < steps; i++) {
      await gesture.moveBy(step);
      if (game.lineDraft != null) game.lineDraft!.reachProgress = 1.0;
      await tester.pump(const Duration(milliseconds: 40));
    }

    // The draft must have snapped to the customer.
    expect(game.lineDraft!.targetEntityId, 'c001');

    final linesBefore = game.session.lines.length;
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 60));

    expect(game.session.lines.length, linesBefore + 1,
        reason: 'releasing on the customer must commit the line');
    expect(game.session.lines.last.stopIds, containsAll(<String>['r001', 'c001']));
  });

  testWidgets('tap-tap routing still works through the POI hit areas', (
    WidgetTester tester,
  ) async {
    final harness = await pumpGameScreen(tester, city: _city);
    final game = harness.game;

    await tester.tap(find.byKey(const ValueKey<String>('poi-hit-r001')));
    await tester.pump(const Duration(milliseconds: 60));
    expect(game.selectedEntityId, 'r001');

    final linesBefore = game.session.lines.length;
    await tester.tap(find.byKey(const ValueKey<String>('poi-hit-c001')));
    await tester.pump(const Duration(milliseconds: 60));

    expect(game.session.lines.length, linesBefore + 1);
    expect(game.selectedEntityId, isNull,
        reason: 'creating the route must clear the selection');
  });

  testWidgets('dragging empty map pans the camera; dragging a POI does not', (
    WidgetTester tester,
  ) async {
    final harness = await pumpGameScreen(tester, city: _city);
    final game = harness.game;

    Matrix4 cameraMatrix() =>
        tester.widget<Transform>(find.byKey(const ValueKey('map-camera-transform'))).transform;

    // A point in the bottom-left corner of the map area, far from every POI
    // hit box and from the TimeControls overlay in the top-left.
    final mapClip = find
        .ancestor(
          of: find.byKey(const ValueKey<String>('poi-hit-r001')),
          matching: find.byType(ClipRect),
        )
        .first;
    final mapBox = tester.renderObject<RenderBox>(mapClip);
    final emptyPoint =
        mapBox.localToGlobal(Offset.zero) + Offset(20, mapBox.size.height - 40);

    final before = cameraMatrix();
    final pan = await tester.startGesture(emptyPoint);
    await gestureDrag(tester, pan, const Offset(60, 40));
    await pan.up();
    await tester.pump(const Duration(milliseconds: 60));
    final after = cameraMatrix();
    expect(after.storage[12], isNot(closeTo(before.storage[12], 0.5)),
        reason: 'panning empty map must move the camera');
    expect(game.lineDraft, isNull, reason: 'panning must not start a line draft');

    // The very same drag starting inside a POI hit area starts a line
    // instead of panning (Requirement 44.3 — gesture separation).
    final iconCentre = harness.paintedGlobalPosition(harness.nodeOf('r002').point);
    final beforePan = cameraMatrix();
    final draw = await tester.startGesture(iconCentre + const Offset(-14, 14));
    await gestureDrag(tester, draw, const Offset(40, 30));
    expect(game.lineDraft, isNotNull,
        reason: 'dragging from the restaurant hit area must start a line draft');
    expect(game.lineDraft!.startEntityId, 'r002');
    expect(cameraMatrix().storage[12], closeTo(beforePan.storage[12], 0.5),
        reason: 'drawing from a POI must not pan the camera');
    await draw.up();
    await tester.pump(const Duration(milliseconds: 60));
  });
}

Future<void> gestureDrag(WidgetTester tester, TestGesture gesture, Offset delta) async {
  const steps = 4;
  for (var i = 0; i < steps; i++) {
    await gesture.moveBy(delta * (1.0 / steps));
    await tester.pump(const Duration(milliseconds: 30));
  }
}
