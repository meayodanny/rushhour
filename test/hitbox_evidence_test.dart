import 'package:flutter_test/flutter_test.dart';

import 'package:rushhour/ui/game_screen.dart';

import 'game_harness.dart';

/// QA evidence generators for Requirement 44.5 / 45.
///
/// These tests render the REAL game screen with the REAL Rivergate map and
/// the temporary hit-box debug overlay enabled, and produce:
///
/// * `goldens/hitbox_map.png`        — hit boxes over the live map (fit zoom);
/// * `goldens/hitbox_map_zoomed.png` — same after a real pinch-zoom (the
///   48x48 boxes must stay 48x48 and stay centred on the icons);
/// * `goldens/drag_frame_XX.png`     — a finger lands ~22px OFF the
///   restaurant icon centre and drags to the customer; the line starts
///   drawing immediately (assembled into docs/qa/hitbox_drag.gif on CI).
///
/// Run with `flutter test --update-goldens` to (re)generate the files.
void main() {
  testWidgets('evidence: hit boxes over the live map', (WidgetTester tester) async {
    await loadAppFonts();
    final harness = await pumpGameScreen(
      tester,
      debugHitBoxes: true,
      seedRestaurants: const ['r001', 'r002'],
      seedCustomers: const ['c001', 'c002', 'c003'],
      seedLineBetween: true,
    );

    // Let the seeded entities/line/courier settle into the frame.
    await tester.pump(const Duration(milliseconds: 200));
    await expectLater(
      find.byType(GameScreen),
      matchesGoldenFile('goldens/hitbox_map.png'),
    );

    // ---- pinch-zoom in with two real pointers -------------------------------
    final centre = harness.paintedGlobalPosition(harness.nodeOf('r001').point);
    final a = await tester.startGesture(centre + const Offset(-45, 0));
    final b = await tester.startGesture(centre + const Offset(45, 0));
    await tester.pump(const Duration(milliseconds: 50));
    for (var i = 0; i < 14; i++) {
      await a.moveBy(const Offset(-4, -1));
      await b.moveBy(const Offset(4, 1));
      await tester.pump(const Duration(milliseconds: 30));
    }
    await a.up();
    await b.up();
    await tester.pump(const Duration(milliseconds: 250));

    // After zooming the hit boxes must STILL be 48x48 screen pixels and
    // still centred on the painted icons.
    for (final entityId in const <String>['r001', 'c001']) {
      final rect = harness.hitRect(entityId);
      expect(rect.width, 48.0);
      expect(rect.height, 48.0);
      final iconCentre = harness.paintedGlobalPosition(harness.nodeOf(entityId).point);
      expect((rect.center - iconCentre).distance, lessThan(0.5));
    }

    await expectLater(
      find.byType(GameScreen),
      matchesGoldenFile('goldens/hitbox_map_zoomed.png'),
    );
  });

  testWidgets('evidence: off-centre drag sequence (finger ~22px off the icon)', (
    WidgetTester tester,
  ) async {
    await loadAppFonts();
    final harness = await pumpGameScreen(
      tester,
      debugHitBoxes: true,
      seedRestaurants: const ['r001'],
      seedCustomers: const ['c001'],
    );
    final game = harness.game;

    final iconCentre = harness.paintedGlobalPosition(harness.nodeOf('r001').point);
    final customerCentre = harness.paintedGlobalPosition(harness.nodeOf('c001').point);

    // The finger lands ~21.9px away from the icon centre — NOT on the icon.
    final touchDown = iconCentre + const Offset(16, -15);
    expect(harness.hitRect('r001').contains(touchDown), isTrue);

    final gesture = await tester.startGesture(touchDown);
    await tester.pump(const Duration(milliseconds: 50));

    var frame = 0;
    Offset position = touchDown;
    const steps = 10;
    final delta = (customerCentre - touchDown) * (1.0 / steps);
    for (var i = 0; i < steps; i++) {
      position += delta;
      await gesture.moveTo(position);
      // Advance the draft draw-in animation so the line is fully visible.
      final draft = game.lineDraft;
      if (draft != null) draft.reachProgress = 1.0;
      await tester.pump(const Duration(milliseconds: 60));
      if (i.isEven) {
        await expectLater(
          find.byType(GameScreen),
          matchesGoldenFile('goldens/drag_frame_${frame.toString().padLeft(2, '0')}.png'),
        );
        frame++;
      }
    }

    await gesture.up();
    await tester.pump(const Duration(milliseconds: 120));
    await expectLater(
      find.byType(GameScreen),
      matchesGoldenFile('goldens/drag_frame_final.png'),
    );

    expect(game.session.lines, isNotEmpty,
        reason: 'the drag must have committed a line');
  });
}
