import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/flowline_app.dart';
import '../core/palette.dart';
import '../l10n/app_strings.dart';
import '../models/city.dart';
import 'widgets/animated_map_background.dart';
import 'widgets/flow_controls.dart';

class MainMenuScreen extends ConsumerWidget {
  const MainMenuScreen({
    required this.city,
    required this.onPlay,
    required this.onSettings,
    required this.onTutorial,
    super.key,
  });

  final CityData city;
  final VoidCallback onPlay;
  final VoidCallback onSettings;
  final VoidCallback onTutorial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routeAnimation = ModalRoute.of(context)?.secondaryAnimation ?? kAlwaysDismissedAnimation;
    final palette = Palette.of(context);
    // Requirement 29: Subscribe to localeProvider so language flag immediately updates
    final currentLocale = ref.watch(localeProvider);

    return ColoredBox(
      color: palette.paper,
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
                dim: palette.isDark ? .55 : .34,
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
                            child: _Wordmark(palette: palette),
                          ),
                          Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 330),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  _MenuButton(label: AppStrings.of(context).play, index: '01', onPressed: onPlay, palette: palette),
                                  const SizedBox(height: 12),
                                  _MenuButton(label: AppStrings.of(context).settings, index: '02', onPressed: onSettings, palette: palette),
                                  const SizedBox(height: 12),
                                  _MenuButton(label: AppStrings.of(context).tutorial, index: '03', onPressed: onTutorial, palette: palette),
                                ],
                              ),
                            ),
                          ),
                          Align(
                            alignment: Alignment.bottomLeft,
                            child: Text(
                              city.attribution,
                              style: TextStyle(
                                color: palette.paper.withValues(alpha: .62),
                                fontSize: 9,
                                letterSpacing: .3,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ),
                          // Requirement 29: Flag button with instant visual feedback
                          Positioned(
                            right: 2,
                            bottom: 0,
                            child: Semantics(
                              button: true,
                              label: AppStrings.of(context).language,
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  ref.read(localeProvider.notifier).cycleLanguage();
                                },
                                child: SizedBox(
                                  width: 56,
                                  height: 56,
                                  child: Center(
                                    child: Text(
                                      currentLocale.languageCode == 'ru' ? '🇷🇺' : '🇬🇧',
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
  const _Wordmark({required this.palette});
  final FlowlinePalette palette;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            AppStrings.of(context).gameTitle,
            style: TextStyle(
              color: palette.paper,
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
              Container(width: 27, height: 3, color: palette.coral),
              const SizedBox(width: 8),
              Text(
                AppStrings.of(context).tagline,
                style: TextStyle(
                  color: palette.paper.withValues(alpha: .72),
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.2,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(width: 8),
              Container(width: 27, height: 3, color: palette.blue),
            ],
          ),
        ],
      );
}

class _MenuButton extends StatelessWidget {
  const _MenuButton({
    required this.label,
    required this.index,
    required this.onPressed,
    required this.palette,
  });

  final String label;
  final String index;
  final VoidCallback onPressed;
  final FlowlinePalette palette;

  @override
  Widget build(BuildContext context) => FlowPressable(
        onPressed: onPressed,
        background: palette.paper.withValues(alpha: .95),
        foreground: palette.ink,
        height: 64,
        radius: 20,
        child: Row(
          children: <Widget>[
            Text(index, style: TextStyle(fontSize: 10, color: palette.muted, fontWeight: FontWeight.w700, letterSpacing: 1)),
            const SizedBox(width: 18),
            Expanded(
              child: Text(
                label.toUpperCase(),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 1.8),
              ),
            ),
            Container(width: 7, height: 7, decoration: BoxDecoration(color: palette.coral, shape: BoxShape.circle)),
          ],
        ),
      );
}
