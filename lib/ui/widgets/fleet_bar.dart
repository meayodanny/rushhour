import 'package:flutter/material.dart';

import '../../core/palette.dart';
import '../../game/game_controller.dart';
import '../../models/entities.dart';

class FleetBar extends StatelessWidget {
  const FleetBar({required this.game, super.key});
  final GameSessionController game;

  @override
  Widget build(BuildContext context) => Container(
    height: 82, color: Palette.paper, padding: const EdgeInsets.fromLTRB(16, 7, 16, 10),
    child: Row(children: <Widget>[
      _lines(), const Spacer(),
      for (final type in CourierType.values) Padding(padding: const EdgeInsets.only(left: 9), child: _courier(type)),
    ]),
  );

  Widget _lines() => Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
    Row(children: List<Widget>.generate(6, (int i) => Container(width: 17, height: 6, margin: const EdgeInsets.only(right: 4), decoration: BoxDecoration(color: i < game.session.lines.length ? const Color(0xff283238) : Palette.road, borderRadius: BorderRadius.circular(4))))),
    const SizedBox(height: 7), Text('+${game.session.availableLines} ROUTES', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Palette.muted, letterSpacing: 1)),
  ]);

  Widget _courier(CourierType type) {
    final count = game.session.fleet[type] ?? 0;
    final radius = switch (type) { CourierType.walk => 7.0, CourierType.bike => 10.0, CourierType.car => 13.0 };
    final marker = Container(width: 40, height: 40, alignment: Alignment.center, child: Container(width: radius * 2, height: radius * 2, decoration: const BoxDecoration(shape: BoxShape.circle, color: Palette.ink)));
    return Draggable<CourierType>(data: type, maxSimultaneousDrags: count > 0 ? 1 : 0, feedback: Material(color: Colors.transparent, child: marker), childWhenDragging: Opacity(opacity: .25, child: marker), child: Badge(label: Text('$count'), child: marker));
  }
}
