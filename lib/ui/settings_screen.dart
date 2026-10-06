import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/flowline_app.dart';
import '../core/palette.dart';
import '../game/game_controller.dart';
import '../l10n/app_strings.dart';
import '../models/city.dart';
import 'widgets/animated_map_background.dart';
import 'widgets/flow_controls.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({
    required this.city,
    super.key,
  });

  final CityData city;

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
    final palette = Palette.of(context);
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);
    final isDark = themeMode == ThemeMode.dark;

    return ColoredBox(
      color: palette.paper,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          AnimatedMapBackground(
            city: widget.city,
            cameraZoom: 1.08,
            dim: isDark ? .80 : .68,
          ),
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
                          background: palette.paper,
                          foreground: palette.ink,
                          child: const FlowGlyph(FlowGlyphType.back),
                        ),
                      ),
                      const SizedBox(width: 18),
                      Text(
                        strings.settings.toUpperCase(),
                        style: TextStyle(
                          color: palette.paper,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.4,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 23, vertical: 12),
                    decoration: BoxDecoration(
                      color: palette.paper.withValues(alpha: .97),
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Column(
                      children: <Widget>[
                        // Requirement 38: Custom Dark Theme switcher
                        _SettingRow(
                          glyph: isDark ? FlowGlyphType.moon : FlowGlyphType.sun,
                          title: strings.theme,
                          caption: isDark ? strings.darkTheme : strings.lightTheme,
                          palette: palette,
                          trailing: FlowThemeToggle(
                            isDark: isDark,
                            onChanged: (bool dark) {
                              ref.read(themeModeProvider.notifier).setTheme(dark ? ThemeMode.dark : ThemeMode.light);
                            },
                          ),
                        ),
                        Container(height: 1, margin: const EdgeInsets.only(left: 58), color: palette.road),
                        _SettingRow(
                          glyph: _sound ? FlowGlyphType.sound : FlowGlyphType.muted,
                          title: strings.sound,
                          caption: strings.soundCaption,
                          palette: palette,
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
                        Container(height: 1, margin: const EdgeInsets.only(left: 58), color: palette.road),
                        _SettingRow(
                          glyph: FlowGlyphType.route,
                          title: strings.language,
                          caption: locale.languageCode == 'ru' ? 'Русский' : 'English',
                          palette: palette,
                          trailing: SizedBox(
                            width: 64,
                            child: FlowPressable(
                              semanticLabel: strings.language,
                              onPressed: () {
                                ref.read(localeProvider.notifier).cycleLanguage();
                              },
                              height: 48,
                              radius: 15,
                              padding: EdgeInsets.zero,
                              background: palette.panel,
                              foreground: palette.ink,
                              child: Text(locale.languageCode == 'ru' ? '🇷🇺' : '🇬🇧', style: const TextStyle(fontSize: 23)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    widget.city.attribution,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: palette.paper.withValues(alpha: .62),
                      fontSize: 9,
                      decoration: TextDecoration.none,
                    ),
                  ),
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
  const _SettingRow({
    required this.glyph,
    required this.title,
    required this.caption,
    required this.trailing,
    required this.palette,
  });

  final FlowGlyphType glyph;
  final String title;
  final String caption;
  final Widget trailing;
  final FlowlinePalette palette;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 15),
        child: Row(
          children: <Widget>[
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: palette.panel, shape: BoxShape.circle),
              child: FlowGlyph(glyph, size: 22, color: palette.ink),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: palette.ink)),
                  const SizedBox(height: 3),
                  Text(caption, style: TextStyle(fontSize: 11, color: palette.muted)),
                ],
              ),
            ),
            trailing,
          ],
        ),
      );
}
