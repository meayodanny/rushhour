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
                dim: .34 + camera * .16,
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
                                background: Palette.paper,
                                foreground: Palette.ink,
                                child: const FlowGlyph(FlowGlyphType.back),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              strings.selectCity,
                              style: const TextStyle(
                                color: Palette.paper,
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
                            color: Palette.paper.withValues(alpha: .96),
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
                                    decoration: const BoxDecoration(color: Palette.water, shape: BoxShape.circle),
                                    alignment: Alignment.center,
                                    child: const FlowGlyph(FlowGlyphType.route, color: Palette.ink),
                                  ),
                                  const SizedBox(width: 15),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Text(strings.city.toUpperCase(), style: const TextStyle(fontSize: 25, height: 1, fontWeight: FontWeight.w700, letterSpacing: .5)),
                                        const SizedBox(height: 7),
                                        Text(strings.cityCaption, style: const TextStyle(fontSize: 9, color: Palette.muted, fontWeight: FontWeight.w700, letterSpacing: 1.1)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 27),
                              Text(strings.difficulty, style: const TextStyle(fontSize: 10, color: Palette.muted, fontWeight: FontWeight.w700, letterSpacing: 1.7)),
                              const SizedBox(height: 11),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: Difficulty.values.map((Difficulty difficulty) {
                                  final selected = _difficulty == difficulty;
                                  return _ModeChip(
                                    label: _difficultyLabel(strings, difficulty),
                                    selected: selected,
                                    onPressed: () => setState(() => _difficulty = difficulty),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 25),
                              FlowPressable(
                                onPressed: () => widget.onStart(_difficulty),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: <Widget>[
                                    Text(strings.start.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1.5)),
                                    const SizedBox(width: 12),
                                    const FlowGlyph(FlowGlyphType.play, size: 18, color: Palette.paper),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        Text(
                          widget.city.attribution,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Palette.paper.withValues(alpha: .66), fontSize: 9, decoration: TextDecoration.none),
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
    );
  }

  String _difficultyLabel(AppStrings strings, Difficulty difficulty) => switch (difficulty) {
        Difficulty.normal => strings.normal,
        Difficulty.realism => strings.realism,
        Difficulty.infinite => strings.infinite,
        Difficulty.sandbox => strings.sandbox,
      };
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({required this.label, required this.selected, required this.onPressed});
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: selected ? Palette.ink : Palette.panel,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Palette.paper : Palette.ink,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: .35,
            ),
          ),
        ),
      );
}
