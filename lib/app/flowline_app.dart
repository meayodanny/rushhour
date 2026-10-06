import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/flowline_theme.dart';
import '../game/game_controller.dart';
import '../l10n/app_strings.dart';
import '../models/entities.dart';
import '../ui/city_selection_screen.dart';
import '../ui/game_screen.dart';
import '../ui/main_menu_screen.dart';
import '../ui/routes.dart';
import '../ui/settings_screen.dart';

class FlowlineApp extends ConsumerStatefulWidget {
  const FlowlineApp({super.key});

  @override
  ConsumerState<FlowlineApp> createState() => _FlowlineAppState();
}

class _FlowlineAppState extends ConsumerState<FlowlineApp> {
  late Locale _locale;
  late bool _firstLaunch;

  @override
  void initState() {
    super.initState();
    final persistence = ref.read(persistenceProvider);
    final stored = persistence.language;
    final system = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    final code = stored == 'system' ? (<String>{'ru', 'en'}.contains(system) ? system : 'en') : stored;
    _locale = Locale(code);
    _firstLaunch = persistence.isFirstLaunch;
  }

  Future<void> _cycleLanguage() async {
    final next = _locale.languageCode == 'ru' ? 'en' : 'ru';
    setState(() => _locale = Locale(next));
    await ref.read(persistenceProvider).setLanguage(next);
  }

  Widget _menu(BuildContext context) {
    final city = ref.read(cityProvider);
    return MainMenuScreen(
      city: city,
      localeCode: _locale.languageCode,
      onCycleLanguage: () => unawaited(_cycleLanguage()),
      onPlay: () {
        Navigator.of(context).push<void>(buildSharedMapRoute<void>(
          page: CitySelectionScreen(
            city: city,
            onStart: (Difficulty difficulty) => _startGame(context, difficulty: difficulty, tutorial: false),
          ),
        ));
      },
      onSettings: () {
        Navigator.of(context).push<void>(buildPanelRoute<void>(
          page: SettingsScreen(
            city: city,
            localeCode: _locale.languageCode,
            onCycleLanguage: () => unawaited(_cycleLanguage()),
          ),
        ));
      },
      onTutorial: () => unawaited(_startTutorial(context)),
    );
  }

  Future<void> _startTutorial(BuildContext context) async {
    await ref.read(persistenceProvider).resetTutorial();
    if (!context.mounted) return;
    _startGame(context, difficulty: Difficulty.normal, tutorial: true);
  }

  void _startGame(BuildContext context, {required Difficulty difficulty, required bool tutorial}) {
    Navigator.of(context).push<void>(buildCameraRoute<void>(
      page: GameScreen(
        difficulty: difficulty,
        tutorial: tutorial,
        startNew: true,
        onReturnToMenu: () => _returnToMenu(context, tutorial: tutorial),
      ),
    ));
  }

  Future<void> _returnToMenu(BuildContext context, {required bool tutorial}) async {
    if (tutorial && _firstLaunch) {
      await ref.read(persistenceProvider).completeFirstLaunch();
      _firstLaunch = false;
    }
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil<void>(
      buildReturnToMenuRoute<void>(page: Builder(builder: _menu)),
      (Route<dynamic> route) => false,
    );
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Flowline',
        debugShowCheckedModeBanner: false,
        locale: _locale,
        supportedLocales: const <Locale>[Locale('en'), Locale('ru')],
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          AppStringsDelegate(),
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: FlowlineTheme.data,
        home: Builder(
          builder: (BuildContext context) => _firstLaunch
              ? GameScreen(
                  difficulty: Difficulty.normal,
                  tutorial: true,
                  startNew: true,
                  onReturnToMenu: () => _returnToMenu(context, tutorial: true),
                )
              : _menu(context),
        ),
      );
}
