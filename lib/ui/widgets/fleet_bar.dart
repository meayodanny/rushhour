import 'package:flutter/material.dart';

import '../../core/palette.dart';
import '../../game/game_controller.dart';
import '../../models/entities.dart';
import 'flow_controls.dart';

class FleetBar extends StatelessWidget {
  const FleetBar({required this.game, super.key});
  final GameSessionController game;

  @override
  Widget build(BuildContext context) => Container(
        height: 78,
        color: Palette.paper,
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
        child: Row(
          children: <Widget>[
            _lines(),
            const Spacer(),
            for (final type in CourierType.values)
              Padding(padding: const EdgeInsets.only(left: 9), child: _courier(type)),
          ],
        ),
      );

  Widget _lines() => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: List<Widget>.generate(
              6,
              (int i) => Container(
                width: 17,
                height: 6,
                margin: const EdgeInsets.only(right: 4),
                decoration: BoxDecoration(
                  color: i < game.session.lines.length ? Palette.ink : Palette.road,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text('+${game.session.availableLines}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Palette.muted, letterSpacing: .6)),
        ],
      );

  Widget _courier(CourierType type) {
    final count = game.session.fleet[type] ?? 0;
    final glyph = switch (type) {
      CourierType.walk => FlowGlyphType.walk,
      CourierType.bike => FlowGlyphType.bike,
      CourierType.car => FlowGlyphType.car,
    };
    final marker = SizedBox(
      width: 46,
      height: 46,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Container(
            width: 43,
            height: 43,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: count > 0 ? Palette.ink : Palette.road,
            ),
            child: FlowGlyph(glyph, size: 23, color: Palette.paper),
          ),
          Positioned(
            right: -2,
            top: -3,
            child: Container(
              width: 19,
              height: 19,
              alignment: Alignment.center,
              decoration: const BoxDecoration(shape: BoxShape.circle, color: Palette.coral),
              child: Text('$count', style: const TextStyle(color: Palette.paper, fontSize: 9, fontWeight: FontWeight.w700)),
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
