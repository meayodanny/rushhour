import 'package:flutter/material.dart';

import '../../core/palette.dart';
import '../../game/game_controller.dart';
import '../../l10n/app_strings.dart';

class GameOverOverlay extends StatelessWidget {
  const GameOverOverlay({required this.game, super.key});
  final GameSessionController game;
  @override
  Widget build(BuildContext context) {
    if (!game.gameOver) return const SizedBox.shrink();
    final s = AppStrings.of(context);
    return Positioned.fill(child: ColoredBox(color: Palette.paper.withValues(alpha: .94), child: Center(child: Padding(padding: const EdgeInsets.all(30), child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
      const Icon(Icons.hub_rounded, size: 50, color: Palette.danger), const SizedBox(height: 20),
      Text(s.gameOver, textAlign: TextAlign.center, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900, letterSpacing: 1)), const SizedBox(height: 9), Text(s.gameOverBody, textAlign: TextAlign.center, style: const TextStyle(color: Palette.muted)), const SizedBox(height: 22),
      Text('${game.session.score}', style: const TextStyle(fontSize: 50, fontWeight: FontWeight.w900)), Text(s.score, style: const TextStyle(fontSize: 10, letterSpacing: 2, color: Palette.muted)), const SizedBox(height: 22),
      if (game.ads.rewardedReady) FilledButton.icon(onPressed: () => game.ads.showRewarded(game.continueRewarded), icon: const Icon(Icons.play_circle_fill_rounded), label: Text(s.continueAd)),
      TextButton(onPressed: () => game.restart(game.session.difficulty), child: Text(s.restart)),
    ])))));
  }
}
