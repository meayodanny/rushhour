import 'package:flutter/material.dart';

import '../../core/palette.dart';
import '../../game/game_controller.dart';
import '../../l10n/app_strings.dart';
import '../../models/entities.dart';
import 'flow_controls.dart';

class RewardOverlay extends StatelessWidget {
  const RewardOverlay({required this.game, super.key});
  final GameSessionController game;

  @override
  Widget build(BuildContext context) {
    if (!game.rewardPending) return const SizedBox.shrink();
    final strings = AppStrings.of(context);
    final palette = Palette.of(context);
    final rewards = game.rewards;

    return Positioned.fill(
      child: ColoredBox(
        color: palette.veil.withValues(alpha: .82),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  strings.reward,
                  style: TextStyle(
                    color: palette.paper,
                    fontWeight: FontWeight.w700,
                    fontSize: 23,
                    letterSpacing: 1.3,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  strings.choose,
                  style: TextStyle(color: palette.paper.withValues(alpha: .68), fontSize: 12),
                ),
                const SizedBox(height: 21),
                Row(
                  children: rewards.map((RewardType reward) {
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: AspectRatio(
                          aspectRatio: .68,
                          child: FlowPressable(
                            onPressed: () => game.chooseReward(reward),
                            height: null,
                            radius: 22,
                            padding: const EdgeInsets.all(10),
                            background: palette.paper,
                            foreground: palette.ink,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                Container(
                                  width: 52,
                                  height: 52,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(color: palette.panel, shape: BoxShape.circle),
                                  child: FlowGlyph(_glyph(reward), size: 29, color: palette.ink),
                                ),
                                const SizedBox(height: 15),
                                Text(
                                  _label(strings, reward),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: palette.ink),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  FlowGlyphType _glyph(RewardType reward) => switch (reward) {
        RewardType.line => FlowGlyphType.route,
        RewardType.walker => FlowGlyphType.walk,
        RewardType.bike => FlowGlyphType.bike,
        RewardType.car => FlowGlyphType.car,
        RewardType.ferry => FlowGlyphType.ferry,
        RewardType.house => FlowGlyphType.house,
      };

  String _label(AppStrings strings, RewardType reward) => switch (reward) {
        RewardType.line => strings.line,
        RewardType.walker => strings.walker,
        RewardType.bike => strings.bike,
        RewardType.car => strings.car,
        RewardType.ferry => strings.ferry,
        RewardType.house => strings.house,
      };
}
