import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/palette.dart';
import '../l10n/app_strings.dart';
import '../ui/game_screen.dart';

class FlowlineApp extends StatelessWidget {
  const FlowlineApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Flowline', debugShowCheckedModeBanner: false,
    supportedLocales: const <Locale>[Locale('en'), Locale('ru')],
    localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
      AppStringsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff118ab2), surface: Palette.paper, brightness: Brightness.light), scaffoldBackgroundColor: Palette.paper, fontFamily: 'sans-serif', useMaterial3: true),
    home: const GameScreen(),
  );
}
