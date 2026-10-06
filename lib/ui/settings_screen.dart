import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/palette.dart';
import '../game/game_controller.dart';
import '../l10n/app_strings.dart';
import '../models/city.dart';
import 'widgets/animated_map_background.dart';
import 'widgets/flow_controls.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({
    required this.city,
    required this.localeCode,
    required this.onCycleLanguage,
    super.key,
  });

  final CityData city;
  final String localeCode;
  final VoidCallback onCycleLanguage;

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late bool _sound;

  @override
  void initState() {
    super.initState();
    _sound = ref.read(persistenceProvider).audioEnabled;
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return ColoredBox(
      color: Palette.paper,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          AnimatedMapBackground(city: widget.city, cameraZoom: 1.08, dim: .68),
          SafeArea(
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
                          child: const FlowGlyph(FlowGlyphType.back),
                        ),
                      ),
                      const SizedBox(width: 18),
                      Text(
                        strings.settings.toUpperCase(),
                        style: const TextStyle(color: Palette.paper, fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: 1.4, decoration: TextDecoration.none),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 23, vertical: 12),
                    decoration: BoxDecoration(color: Palette.paper.withValues(alpha: .97), borderRadius: BorderRadius.circular(28)),
                    child: Column(
                      children: <Widget>[
                        _SettingRow(
                          glyph: _sound ? FlowGlyphType.sound : FlowGlyphType.muted,
                          title: strings.sound,
                          caption: strings.soundCaption,
                          trailing: FlowToggle(
                            value: _sound,
                            semanticLabel: strings.sound,
                            onChanged: (bool value) {
                              setState(() => _sound = value);
                              ref.read(audioServiceProvider).enabled = value;
                              unawaited(ref.read(persistenceProvider).setAudioEnabled(value));
                            },
                          ),
                        ),
                        Container(height: 1, margin: const EdgeInsets.only(left: 58), color: Palette.road),
                        _SettingRow(
                          glyph: FlowGlyphType.route,
                          title: strings.language,
                          caption: strings.locale.languageCode == 'ru' ? 'Русский' : 'English',
                          trailing: SizedBox(
                            width: 64,
                            child: FlowPressable(
                              semanticLabel: strings.language,
                              onPressed: widget.onCycleLanguage,
                              height: 48,
                              radius: 15,
                              padding: EdgeInsets.zero,
                              background: Palette.panel,
                              foreground: Palette.ink,
                              child: Text(strings.locale.languageCode == 'ru' ? '🇷🇺' : '🇬🇧', style: const TextStyle(fontSize: 23)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Text(widget.city.attribution, textAlign: TextAlign.center, style: TextStyle(color: Palette.paper.withValues(alpha: .62), fontSize: 9, decoration: TextDecoration.none)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({required this.glyph, required this.title, required this.caption, required this.trailing});
  final FlowGlyphType glyph;
  final String title;
  final String caption;
  final Widget trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 17),
        child: Row(
          children: <Widget>[
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: const BoxDecoration(color: Palette.panel, shape: BoxShape.circle),
              child: FlowGlyph(glyph, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(caption, style: const TextStyle(fontSize: 11, color: Palette.muted)),
                ],
              ),
            ),
            trailing,
          ],
        ),
      );
}
