import 'package:flutter/material.dart';

import '../../core/palette.dart';
import '../../game/game_controller.dart';
import '../../l10n/app_strings.dart';
import '../../models/entities.dart';

class RewardOverlay extends StatelessWidget {
  const RewardOverlay({required this.game, super.key});

  final GameSessionController game;

  @override
  Widget build(BuildContext context) {
    if (!game.rewardPending) return const SizedBox.shrink();
    final strings = AppStrings.of(context);
    final rewards = game.rewards;
    return Positioned.fill(
      child: ColoredBox(
        color: Palette.ink.withValues(alpha: .72),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(strings.reward, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 24, letterSpacing: 1)),
                const SizedBox(height: 6),
                Text(strings.choose, style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 20),
                Row(
                  children: rewards.map((RewardType reward) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: AspectRatio(
                        aspectRatio: .72,
                        child: Material(
                          color: Palette.paper,
                          borderRadius: BorderRadius.circular(20),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () => game.chooseReward(reward),
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: <Widget>[
                                  Icon(_icon(reward), size: 38, color: Palette.ink),
                                  const SizedBox(height: 14),
                                  Text(_label(strings, reward), textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  )).toList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _icon(RewardType reward) => switch (reward) {
    RewardType.line => Icons.timeline_rounded,
    RewardType.walker => Icons.directions_walk_rounded,
    RewardType.bike => Icons.pedal_bike_rounded,
    RewardType.car => Icons.directions_car_filled_rounded,
    RewardType.ferry => Icons.directions_boat_filled_rounded,
    RewardType.house => Icons.home_rounded,
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
