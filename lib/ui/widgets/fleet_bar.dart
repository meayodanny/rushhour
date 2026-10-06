import 'package:flutter/material.dart';

import '../../core/game_config.dart';
import '../../core/palette.dart';
import '../../game/game_controller.dart';
import '../../models/entities.dart';
import 'flow_controls.dart';

class FleetBar extends StatelessWidget {
  const FleetBar({required this.game, super.key});
  final GameSessionController game;

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    final unlockedCourierTypes = CourierType.values.where((CourierType t) => game.isCourierTypeUnlocked(t)).toList();

    return Container(
      height: 70,
      color: Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          _lineSlots(palette),
          const Spacer(),
          for (final type in unlockedCourierTypes)
            Padding(
              padding: const EdgeInsets.only(left: 10),
              child: _courierReserveSlot(type, palette),
            ),
        ],
      ),
    );
  }

  /// Requirement 32: Line slots: filled with line color, outlined if available, dimmed if locked
  Widget _lineSlots(FlowlinePalette palette) {
    const maxSlots = GameConfig.maxLines;
    final activeLines = game.session.lines;
    final totalUnlocked = activeLines.length + game.session.availableLines;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List<Widget>.generate(maxSlots, (int i) {
        if (i < activeLines.length) {
          // Used slot: filled with line color
          final color = GameConfig.lineColors[activeLines[i].colorIndex];
          return Container(
            width: 20,
            height: 9,
            margin: const EdgeInsets.only(right: 5),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          );
        } else if (i < totalUnlocked) {
          // Available slot: outlined
          return Container(
            width: 20,
            height: 9,
            margin: const EdgeInsets.only(right: 5),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: palette.ink, width: 1.5),
            ),
          );
        } else {
          // Locked slot: darkened / faint
          return Container(
            width: 20,
            height: 9,
            margin: const EdgeInsets.only(right: 5),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: palette.ink.withValues(alpha: palette.isDark ? .18 : .14),
                width: 1,
              ),
            ),
          );
        }
      }),
    );
  }

  /// Requirement 32 & 34: Courier reserve icons (Walk, Bike, Car if unlocked)
  Widget _courierReserveSlot(CourierType type, FlowlinePalette palette) {
    final count = game.session.fleet[type] ?? 0;
    final glyph = switch (type) {
      CourierType.walk => FlowGlyphType.walk,
      CourierType.bike => FlowGlyphType.bike,
      CourierType.car => FlowGlyphType.car,
    };

    final marker = SizedBox(
      width: 44,
      height: 44,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: count > 0 ? palette.ink : palette.panel,
              border: Border.all(
                color: count > 0 ? Colors.transparent : palette.road,
                width: 1.5,
              ),
            ),
            child: FlowGlyph(
              glyph,
              size: 21,
              color: count > 0 ? palette.paper : palette.muted,
            ),
          ),
          if (count > 0)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                width: 18,
                height: 18,
                alignment: Alignment.center,
                decoration: BoxDecoration(shape: BoxShape.circle, color: palette.coral),
                child: Text(
                  '$count',
                  style: TextStyle(color: palette.paper, fontSize: 8.5, fontWeight: FontWeight.w700),
                ),
              ),
            ),
        ],
      ),
    );

    return Draggable<CourierType>(
      data: type,
      maxSimultaneousDrags: count > 0 ? 1 : 0,
      feedback: marker,
      childWhenDragging: Opacity(opacity: .25, child: marker),
      child: marker,
    );
  }
}
