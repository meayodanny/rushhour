import 'package:flutter/material.dart';

import '../../core/palette.dart';
import '../../game/game_controller.dart';
import '../../l10n/app_strings.dart';
import '../../models/entities.dart';

class GameHud extends StatelessWidget {
  const GameHud({required this.game, required this.onSettings, super.key});
  final GameSessionController game;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Container(
      height: 76, padding: const EdgeInsets.symmetric(horizontal: 16), color: Palette.paper,
      child: Row(children: <Widget>[
        InkWell(onTap: () => _timeMenu(context), borderRadius: BorderRadius.circular(18), child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Text(game.formattedTime, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -1)),
          Text('${strings.day} ${game.session.day}', style: const TextStyle(fontSize: 10, color: Palette.muted, fontWeight: FontWeight.w700)),
        ]))),
        const Spacer(),
        Column(mainAxisSize: MainAxisSize.min, children: <Widget>[Text('${game.session.score}', style: const TextStyle(fontSize: 30, height: 1, fontWeight: FontWeight.w900)), Text(strings.score, style: const TextStyle(fontSize: 9, letterSpacing: 1.2, color: Palette.muted, fontWeight: FontWeight.w800))]),
        const Spacer(),
        if (game.session.houseTokens > 0) Padding(padding: const EdgeInsets.only(right: 5), child: Badge(label: Text('${game.session.houseTokens}'), child: const Icon(Icons.home_rounded))),
        IconButton(onPressed: onSettings, icon: const Icon(Icons.tune_rounded), tooltip: strings.settings),
      ]),
    );
  }

  void _timeMenu(BuildContext context) {
    showModalBottomSheet<void>(context: context, showDragHandle: true, builder: (BuildContext context) => SafeArea(child: Padding(padding: const EdgeInsets.all(20), child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: TimeScale.values.map((TimeScale scale) => FilledButton.tonalIcon(
      onPressed: game.session.difficulty == Difficulty.realism && scale == TimeScale.paused ? null : () { game.setTimeScale(scale); Navigator.pop(context); },
      icon: Icon(switch (scale) { TimeScale.paused => Icons.pause_rounded, TimeScale.normal => Icons.play_arrow_rounded, TimeScale.fast => Icons.fast_forward_rounded }), label: Text(switch (scale) { TimeScale.paused => '0×', TimeScale.normal => '1×', TimeScale.fast => '2×' }),
    )).toList()))));
  }
}
