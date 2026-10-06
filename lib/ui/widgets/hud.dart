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
    final palette = Palette.of(context);
    final dateStr = game.formattedDate(context);

    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      color: Colors.transparent,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          // Requirement 31: Date only on the left
          Semantics(
            button: true,
            label: dateStr,
            child: GestureDetector(
              key: clockKey,
              behavior: HitTestBehavior.opaque,
              onTap: onTimeTap,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  dateStr,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: palette.ink,
                    letterSpacing: -.3,
                  ),
                ),
              ),
            ),
          ),
          const Spacer(),
          if (game.session.houseTokens > 0)
            Container(
              margin: const EdgeInsets.only(right: 14),
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: palette.panel, shape: BoxShape.circle),
              child: Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  const Center(child: FlowGlyph(FlowGlyphType.house, size: 18)),
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      width: 16,
                      height: 16,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: palette.coral, shape: BoxShape.circle),
                      child: Text(
                        '${game.session.houseTokens}',
                        style: TextStyle(color: palette.paper, fontSize: 8, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (showSettings)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onSettings,
              child: Container(
                width: 38,
                height: 38,
                margin: const EdgeInsets.only(right: 12),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: palette.panel.withValues(alpha: 0.8),
                  shape: BoxShape.circle,
                ),
                child: FlowGlyph(FlowGlyphType.sliders, size: 18, color: palette.ink),
              ),
            ),
          // Requirement 31: Delivery score as small semi-transparent text on the right
          Text(
            '${game.session.score}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: palette.ink.withValues(alpha: .55),
              letterSpacing: .5,
            ),
          ),
        ],
      ),
    );
  }
}
