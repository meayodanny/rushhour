import 'package:flutter/material.dart';

import '../core/palette.dart';
import '../l10n/app_strings.dart';
import '../models/city.dart';
import '../models/entities.dart';
import 'widgets/animated_map_background.dart';
import 'widgets/flow_controls.dart';

class CitySelectionScreen extends StatefulWidget {
  const CitySelectionScreen({required this.city, required this.onStart, super.key});
  final CityData city;
  final ValueChanged<Difficulty> onStart;

  @override
  State<CitySelectionScreen> createState() => _CitySelectionScreenState();
}

class _CitySelectionScreenState extends State<CitySelectionScreen> {
  Difficulty _difficulty = Difficulty.normal;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final palette = Palette.of(context);
    final routeAnimation = ModalRoute.of(context)?.animation ?? kAlwaysCompleteAnimation;

    return AnimatedBuilder(
      animation: routeAnimation,
      builder: (BuildContext context, Widget? child) {
        final camera = Curves.easeInOutCubic.transform(routeAnimation.value);
        final reveal = Curves.easeOutCubic.transform(((routeAnimation.value - .28) / .72).clamp(0.0, 1.0));
        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Opacity(
              opacity: camera,
              child: AnimatedMapBackground(
                city: widget.city,
                cameraZoom: 1 + camera * .18,
                cameraOffset: Offset(-26 * camera, 34 * camera),
                dim: palette.isDark ? .65 : (.34 + camera * .16),
              ),
            ),
            SafeArea(
              child: Opacity(
                opacity: reveal,
                child: Transform.scale(
                  scale: .96 + reveal * .04,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            SizedBox(
                              width: 52,
                              child: FlowPressable(
                                semanticLabel: strings.back,
                                onPressed: () => Navigator.of(context).pop(),
                                height: 52,
                                radius: 17,
                                padding: EdgeInsets.zero,
                                background: palette.paper,
                                foreground: palette.ink,
                                child: const FlowGlyph(FlowGlyphType.back),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              strings.selectCity,
                              style: TextStyle(
                                color: palette.paper,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 2.1,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.fromLTRB(23, 25, 23, 23),
                          decoration: BoxDecoration(
                            color: palette.paper.withValues(alpha: .96),
                            borderRadius: BorderRadius.circular(28),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(color: palette.water, shape: BoxShape.circle),
                                    alignment: Alignment.center,
                                    child: FlowGlyph(FlowGlyphType.route, color: palette.ink),
                                  ),
                                  const SizedBox(width: 15),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Text(
                                          strings.city.toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 25,
                                            height: 1,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: .5,
                                            color: palette.ink,
                                          ),
                                        ),
                                        const SizedBox(height: 7),
                                        Text(
                                          strings.cityCaption,
                                          style: TextStyle(
                                            fontSize: 9,
                                            color: palette.muted,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 1.1,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 27),
                              Text(
                                strings.difficulty,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: palette.muted,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.7,
                                ),
                              ),
                              const SizedBox(height: 11),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: Difficulty.values.map((Difficulty difficulty) {
                                  final active = _difficulty == difficulty;
                                  return FlowPressable(
                                    onPressed: () => setState(() => _difficulty = difficulty),
                                    height: 40,
                                    radius: 14,
                                    padding: const EdgeInsets.symmetric(horizontal: 14),
                                    background: active ? palette.ink : palette.panel,
                                    foreground: active ? palette.paper : palette.ink,
                                    child: Text(
                                      switch (difficulty) {
                                        Difficulty.normal => strings.normal,
                                        Difficulty.realism => strings.realism,
                                        Difficulty.infinite => strings.infinite,
                                        Difficulty.sandbox => strings.sandbox,
                                      },
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                                    ),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 24),
                              FlowPressable(
                                onPressed: () => widget.onStart(_difficulty),
                                height: 58,
                                background: palette.blue,
                                foreground: palette.paper,
                                child: Text(
                                  strings.start.toUpperCase(),
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 1.6),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
            ],
          );
        },
      );
  }
}
