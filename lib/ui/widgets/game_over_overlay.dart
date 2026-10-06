import 'package:flutter/material.dart';

import '../../core/palette.dart';
import '../../game/game_controller.dart';
import '../../l10n/app_strings.dart';
import 'flow_controls.dart';

/// Shared result surface for tutorial and standard sessions with theme and tutorial branching.
class GameOverOverlay extends StatelessWidget {
  const GameOverOverlay({
    required this.game,
    required this.onMenu,
    this.appearAnimation,
    super.key,
  });

  final GameSessionController game;
  final VoidCallback onMenu;
  final Animation<double>? appearAnimation;

  @override
  Widget build(BuildContext context) {
    if (!game.gameOver) return const SizedBox.shrink();
    final strings = AppStrings.of(context);
    final palette = Palette.of(context);

    Widget content = Center(
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
                decoration: BoxDecoration(color: palette.danger, shape: BoxShape.circle),
                child: FlowGlyph(FlowGlyphType.hub, size: 34, color: palette.paper),
              ),
              const SizedBox(height: 21),
              Text(
                strings.gameOver,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  height: 1.05,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                  color: palette.ink,
                ),
              ),
              const SizedBox(height: 9),
              Text(
                strings.gameOverBody,
                textAlign: TextAlign.center,
                style: TextStyle(color: palette.muted, fontSize: 12),
              ),
              const SizedBox(height: 27),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(color: palette.panel, borderRadius: BorderRadius.circular(22)),
                child: Row(
                  children: <Widget>[
                    Expanded(child: _Stat(value: '${game.session.score}', label: strings.score, palette: palette)),
                    Container(width: 1, height: 42, color: palette.road),
                    Expanded(child: _Stat(value: game.formattedSurvival, label: strings.survived, palette: palette)),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              if (game.ads.rewardedReady && !game.isTutorial) ...<Widget>[
                FlowPressable(
                  onPressed: () => game.ads.showRewarded(game.continueRewarded),
                  background: palette.blue,
                  child: Text(
                    strings.continueAd.toUpperCase(),
                    style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1, color: palette.paper),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              // Requirement 28: In tutorial mode, ONLY show Menu button, hide Restart
              if (game.isTutorial)
                FlowPressable(
                  onPressed: onMenu,
                  background: palette.panel,
                  foreground: palette.ink,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      const FlowGlyph(FlowGlyphType.menu, size: 19),
                      const SizedBox(width: 9),
                      Text(
                        strings.menu.toUpperCase(),
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: .8),
                      ),
                    ],
                  ),
                )
              else
                Row(
                  children: <Widget>[
                    Expanded(
                      child: FlowPressable(
                        onPressed: onMenu,
                        background: palette.panel,
                        foreground: palette.ink,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            const FlowGlyph(FlowGlyphType.menu, size: 19),
                            const SizedBox(width: 9),
                            Text(
                              strings.menu.toUpperCase(),
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: .8),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FlowPressable(
                        onPressed: () => game.restart(game.session.difficulty),
                        background: palette.ink,
                        foreground: palette.paper,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            FlowGlyph(FlowGlyphType.replay, size: 19, color: palette.paper),
                            const SizedBox(width: 9),
                            Text(
                              strings.restart.toUpperCase(),
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: .8),
                            ),
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
    );

    if (appearAnimation != null) {
      content = AnimatedBuilder(
        animation: appearAnimation!,
        builder: (BuildContext context, Widget? child) {
          final t = Curves.easeOutCubic.transform(appearAnimation!.value);
          return Opacity(
            opacity: t,
            child: Transform.scale(
              scale: 0.92 + 0.08 * t,
              child: child,
            ),
          );
        },
        child: content,
      );
    }

    return Positioned.fill(
      child: SafeArea(child: content),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, required this.palette});
  final String value;
  final String label;
  final FlowlinePalette palette;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            value,
            style: TextStyle(fontSize: 29, height: 1, fontWeight: FontWeight.w700, color: palette.ink),
          ),
          const SizedBox(height: 7),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 8,
              color: palette.muted,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
        ],
      );
}
