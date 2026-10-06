import 'package:flutter/material.dart';

import 'palette.dart';

/// The app deliberately uses Material only as the Flutter application shell.
/// Every visible control is drawn by Flowline widgets and painters.
abstract final class FlowlineTheme {
  static ThemeData get data => ThemeData(
        useMaterial3: false,
        brightness: Brightness.light,
        fontFamily: 'FlowlineSans',
        scaffoldBackgroundColor: Palette.paper,
        canvasColor: Palette.paper,
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
        focusColor: Colors.transparent,
        colorScheme: const ColorScheme.light(
          primary: Palette.blue,
          secondary: Palette.coral,
          surface: Palette.paper,
          error: Palette.danger,
          onPrimary: Palette.paper,
          onSecondary: Palette.paper,
          onSurface: Palette.ink,
          onError: Palette.paper,
        ),
        textTheme: const TextTheme(
          displayLarge: TextStyle(color: Palette.ink, fontSize: 46, height: .96, fontWeight: FontWeight.w700, letterSpacing: -2),
          headlineLarge: TextStyle(color: Palette.ink, fontSize: 28, height: 1.05, fontWeight: FontWeight.w700, letterSpacing: -.8),
          titleLarge: TextStyle(color: Palette.ink, fontSize: 19, height: 1.1, fontWeight: FontWeight.w700),
          bodyLarge: TextStyle(color: Palette.ink, fontSize: 15, height: 1.35),
          bodyMedium: TextStyle(color: Palette.ink, fontSize: 13, height: 1.35),
          labelLarge: TextStyle(color: Palette.ink, fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: .5),
        ),
      );
}
