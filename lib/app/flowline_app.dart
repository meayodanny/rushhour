import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../core/flowline_theme.dart';
import '../game/game_controller.dart';
import '../l10n/app_strings.dart';
import '../models/entities.dart';
import '../services/persistence_service.dart';
import '../ui/city_selection_screen.dart';
import '../ui/game_screen.dart';
import '../ui/main_menu_screen.dart';
import '../ui/routes.dart';
import '../ui/settings_screen.dart';

class LocaleNotifier extends StateNotifier<Locale> {
  LocaleNotifier(this._persistence) : super(_initialLocale(_persistence));
  final PersistenceService _persistence;

  static Locale _initialLocale(PersistenceService persistence) {
    final stored = persistence.language;
    final system = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    final code = stored == 'system' ? (<String>{'ru', 'en'}.contains(system) ? system : 'en') : stored;
    return Locale(code);
  }

  Future<void> cycleLanguage() async {
    final next = state.languageCode == 'ru' ? 'en' : 'ru';
    state = Locale(next);
    await _persistence.setLanguage(next);
  }

  Future<void> setLanguage(String code) async {
    state = Locale(code);
    await _persistence.setLanguage(code);
  }
}

final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>((Ref ref) {
  final persistence = ref.watch(persistenceProvider);
  return LocaleNotifier(persistence);
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier(this._persistence) : super(_persistence.themeMode);
  final PersistenceService _persistence;

  Future<void> toggleTheme() async {
    final next = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    state = next;
    await _persistence.setThemeMode(next);
  }

  Future<void> setTheme(ThemeMode mode) async {
    state = mode;
    await _persistence.setThemeMode(mode);
  }
}

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((Ref ref) {
  final persistence = ref.watch(persistenceProvider);
  return ThemeModeNotifier(persistence);
});

class FlowlineApp extends ConsumerStatefulWidget {
  const FlowlineApp({super.key});

  @override
  ConsumerState<FlowlineApp> createState() => _FlowlineAppState();
}

class _FlowlineAppState extends ConsumerState<FlowlineApp> {
  late bool _firstLaunch;

  @override
  void initState() {
    super.initState();
    _firstLaunch = ref.read(persistenceProvider).isFirstLaunch;
  }

  Widget _menu(BuildContext context) {
    final city = ref.read(cityProvider);
    return MainMenuScreen(
      city: city,
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
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'Flowline',
      debugShowCheckedModeBanner: false,
      locale: locale,
      supportedLocales: const <Locale>[Locale('en'), Locale('ru')],
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        AppStringsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: FlowlineTheme.light,
      darkTheme: FlowlineTheme.dark,
      themeMode: themeMode,
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
}
