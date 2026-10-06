import 'package:flutter/material.dart';

import '../core/palette.dart';
import '../l10n/app_strings.dart';
import '../models/city.dart';
import 'widgets/animated_map_background.dart';
import 'widgets/flow_controls.dart';

class MainMenuScreen extends StatelessWidget {
  const MainMenuScreen({
    required this.city,
    required this.localeCode,
    required this.onPlay,
    required this.onSettings,
    required this.onTutorial,
    required this.onCycleLanguage,
    super.key,
  });

  final CityData city;
  final String localeCode;
  final VoidCallback onPlay;
  final VoidCallback onSettings;
  final VoidCallback onTutorial;
  final VoidCallback onCycleLanguage;

  @override
  Widget build(BuildContext context) {
    final routeAnimation = ModalRoute.of(context)?.secondaryAnimation ?? kAlwaysDismissedAnimation;
    return ColoredBox(
      color: Palette.paper,
      child: AnimatedBuilder(
        animation: routeAnimation,
        builder: (BuildContext context, Widget? child) {
          final flight = Curves.easeInOutCubic.transform(routeAnimation.value);
          return Stack(
            fit: StackFit.expand,
            children: <Widget>[
              AnimatedMapBackground(
                city: city,
                cameraZoom: 1 + flight * .18,
                cameraOffset: Offset(-26 * flight, 34 * flight),
                dim: .34,
              ),
              SafeArea(
                child: Opacity(
                  opacity: (1 - flight * 1.35).clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: 1 - flight * .07,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(28, 32, 28, 22),
                      child: Stack(
                        children: <Widget>[
                          Align(
                            alignment: Alignment.topCenter,
                            child: _Wordmark(),
                          ),
                          Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 330),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  _MenuButton(label: AppStrings.of(context).play, index: '01', onPressed: onPlay),
                                  const SizedBox(height: 12),
                                  _MenuButton(label: AppStrings.of(context).settings, index: '02', onPressed: onSettings),
                                  const SizedBox(height: 12),
                                  _MenuButton(label: AppStrings.of(context).tutorial, index: '03', onPressed: onTutorial),
                                ],
                              ),
                            ),
                          ),
                          Align(
                            alignment: Alignment.bottomLeft,
                            child: Text(
                              city.attribution,
                              style: TextStyle(
                                color: Palette.paper.withValues(alpha: .62),
                                fontSize: 9,
                                letterSpacing: .3,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ),
                          Positioned(
                            right: 2,
                            bottom: 0,
                            child: Semantics(
                              button: true,
                              label: AppStrings.of(context).language,
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: onCycleLanguage,
                                // The 56px invisible target is intentional;
                                // only the flag itself is painted.
                                child: SizedBox(
                                  width: 56,
                                  height: 56,
                                  child: Center(
                                    child: Text(
                                      localeCode == 'ru' ? '🇷🇺' : '🇬🇧',
                                      style: const TextStyle(fontSize: 24, decoration: TextDecoration.none),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Wordmark extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            AppStrings.of(context).gameTitle,
            style: const TextStyle(
              color: Palette.paper,
              fontSize: 37,
              fontWeight: FontWeight.w700,
              letterSpacing: 8,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 7),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(width: 27, height: 3, color: Palette.coral),
              const SizedBox(width: 8),
              Text(
                AppStrings.of(context).tagline,
                style: TextStyle(
                  color: Palette.paper.withValues(alpha: .72),
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.2,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(width: 8),
              Container(width: 27, height: 3, color: Palette.blue),
            ],
          ),
        ],
      );
}

class _MenuButton extends StatelessWidget {
  const _MenuButton({required this.label, required this.index, required this.onPressed});
  final String label;
  final String index;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => FlowPressable(
        onPressed: onPressed,
        background: Palette.paper.withValues(alpha: .95),
        foreground: Palette.ink,
        height: 64,
        radius: 20,
        child: Row(
          children: <Widget>[
            Text(index, style: const TextStyle(fontSize: 10, color: Palette.muted, fontWeight: FontWeight.w700, letterSpacing: 1)),
            const SizedBox(width: 18),
            Expanded(
              child: Text(
                label.toUpperCase(),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 1.8),
              ),
            ),
            Container(width: 7, height: 7, decoration: const BoxDecoration(color: Palette.coral, shape: BoxShape.circle)),
          ],
        ),
      );
}
