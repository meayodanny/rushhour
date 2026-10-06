import 'package:flutter/material.dart';

import '../../core/palette.dart';
import '../../game/game_controller.dart';
import '../../l10n/app_strings.dart';
import '../../models/entities.dart';
import 'flow_controls.dart';

class TimeControls extends StatelessWidget {
  const TimeControls({
    required this.game,
    required this.animation,
    this.panelKey,
    super.key,
  });

  final GameSessionController game;
  final Animation<double> animation;
  final Key? panelKey;

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    return ClipRect(
      key: panelKey,
      child: SizeTransition(
        sizeFactor: CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
        axisAlignment: -1,
        child: FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: const Interval(0, .7, curve: Curves.easeOut)),
          child: Container(
            width: 176,
            height: 62,
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: palette.paper,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: palette.isDark ? 0.4 : 0.12),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: TimeScale.values.map((TimeScale scale) {
                final active = game.timeScale == scale;
                final disabled = game.session.difficulty == Difficulty.realism && scale == TimeScale.paused;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: FlowPressable(
                      semanticLabel: switch (scale) {
                        TimeScale.paused => AppStrings.of(context).pause,
                        TimeScale.normal => AppStrings.of(context).normalSpeed,
                        TimeScale.fast => AppStrings.of(context).fastSpeed,
                      },
                      onPressed: disabled ? null : () => game.setTimeScale(scale),
                      height: 46,
                      radius: 15,
                      padding: EdgeInsets.zero,
                      background: active ? palette.blue : palette.panel,
                      foreground: active ? palette.paper : palette.ink,
                      child: FlowGlyph(
                        switch (scale) {
                          TimeScale.paused => FlowGlyphType.pause,
                          TimeScale.normal => FlowGlyphType.play,
                          TimeScale.fast => FlowGlyphType.fast,
                        },
                        size: 20,
                        color: disabled
                            ? palette.muted
                            : (active ? palette.paper : palette.ink),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}
