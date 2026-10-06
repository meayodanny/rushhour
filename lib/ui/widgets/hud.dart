import 'package:flutter/material.dart';

import '../../core/palette.dart';
import '../../game/game_controller.dart';
import '../../l10n/app_strings.dart';
import 'flow_controls.dart';

class GameHud extends StatelessWidget {
  const GameHud({
    required this.game,
    required this.onTimeTap,
    required this.onSettings,
    required this.showSettings,
    this.clockKey,
    super.key,
  });

  final GameSessionController game;
  final VoidCallback onTimeTap;
  final VoidCallback onSettings;
  final bool showSettings;
  final Key? clockKey;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Container(
      height: 76,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      color: Palette.paper,
      child: Row(
        children: <Widget>[
          Semantics(
            button: true,
            label: '${game.formattedTime}, ${strings.day} ${game.session.day}',
            child: GestureDetector(
              key: clockKey,
              behavior: HitTestBehavior.opaque,
              onTap: onTimeTap,
              child: Container(
                width: 92,
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 7),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(game.formattedTime, style: const TextStyle(fontSize: 22, height: 1, fontWeight: FontWeight.w700, letterSpacing: -1)),
                    const SizedBox(height: 5),
                    Text('${strings.day} ${game.session.day}', style: const TextStyle(fontSize: 9, color: Palette.muted, fontWeight: FontWeight.w700, letterSpacing: .3)),
                  ],
                ),
              ),
            ),
          ),
          const Spacer(),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text('${game.session.score}', style: const TextStyle(fontSize: 29, height: 1, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(strings.score, style: const TextStyle(fontSize: 8, letterSpacing: 1.3, color: Palette.muted, fontWeight: FontWeight.w700)),
            ],
          ),
          const Spacer(),
          if (game.session.houseTokens > 0)
            Container(
              margin: const EdgeInsets.only(right: 8),
              width: 42,
              height: 42,
              decoration: const BoxDecoration(color: Palette.panel, shape: BoxShape.circle),
              child: Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  const Center(child: FlowGlyph(FlowGlyphType.house, size: 21)),
                  Positioned(
                    right: -2,
                    top: -3,
                    child: Container(
                      width: 18,
                      height: 18,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(color: Palette.coral, shape: BoxShape.circle),
                      child: Text('${game.session.houseTokens}', style: const TextStyle(color: Palette.paper, fontSize: 9, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
          if (showSettings)
            SizedBox(
              width: 48,
              child: FlowPressable(
                semanticLabel: strings.settings,
                onPressed: onSettings,
                height: 46,
                radius: 16,
                padding: EdgeInsets.zero,
                background: Palette.panel,
                foreground: Palette.ink,
                child: const FlowGlyph(FlowGlyphType.sliders, size: 22),
              ),
            )
          else
            const SizedBox(width: 48),
        ],
      ),
    );
  }
}
