import 'package:flutter/material.dart';

import '../../core/palette.dart';
import '../../game/game_controller.dart';
import '../../l10n/app_strings.dart';
import 'flow_controls.dart';

/// Shared result surface for tutorial and standard sessions.
class GameOverOverlay extends StatelessWidget {
  const GameOverOverlay({required this.game, required this.onMenu, super.key});
  final GameSessionController game;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    if (!game.gameOver) return const SizedBox.shrink();
    final strings = AppStrings.of(context);
    return Positioned.fill(
      child: ColoredBox(
        color: Palette.paper.withValues(alpha: .97),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 390),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Container(
                      width: 66,
                      height: 66,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(color: Palette.danger, shape: BoxShape.circle),
                      child: const FlowGlyph(FlowGlyphType.hub, size: 34, color: Palette.paper),
                    ),
                    const SizedBox(height: 21),
                    Text(strings.gameOver, textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, height: 1.05, fontWeight: FontWeight.w700, letterSpacing: 1.1)),
                    const SizedBox(height: 9),
                    Text(strings.gameOverBody, textAlign: TextAlign.center, style: const TextStyle(color: Palette.muted, fontSize: 12)),
                    const SizedBox(height: 27),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      decoration: BoxDecoration(color: Palette.panel, borderRadius: BorderRadius.circular(22)),
                      child: Row(
                        children: <Widget>[
                          Expanded(child: _Stat(value: '${game.session.score}', label: strings.score)),
                          Container(width: 1, height: 42, color: Palette.road),
                          Expanded(child: _Stat(value: game.formattedSurvival, label: strings.survived)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    if (game.ads.rewardedReady && !game.isTutorial) ...<Widget>[
                      FlowPressable(
                        onPressed: () => game.ads.showRewarded(game.continueRewarded),
                        background: Palette.blue,
                        child: Text(strings.continueAd.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1)),
                      ),
                      const SizedBox(height: 10),
                    ],
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: FlowPressable(
                            onPressed: onMenu,
                            background: Palette.panel,
                            foreground: Palette.ink,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                const FlowGlyph(FlowGlyphType.menu, size: 19),
                                const SizedBox(width: 9),
                                Text(strings.menu.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: .8)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FlowPressable(
                            onPressed: () => game.restart(game.session.difficulty),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                const FlowGlyph(FlowGlyphType.replay, size: 19, color: Palette.paper),
                                const SizedBox(width: 9),
                                Text(strings.restart.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: .8)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(value, style: const TextStyle(fontSize: 29, height: 1, fontWeight: FontWeight.w700)),
          const SizedBox(height: 7),
          Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 8, color: Palette.muted, fontWeight: FontWeight.w700, letterSpacing: 1.1)),
        ],
      );
}
