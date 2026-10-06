import 'package:flutter/material.dart';

import 'palette.dart';

/// The app uses Material only as the Flutter application shell.
/// Every visible control is drawn by Flowline widgets and painters.
abstract final class FlowlineTheme {
  static ThemeData get light => createTheme(FlowlinePalette.light);
  static ThemeData get dark => createTheme(FlowlinePalette.dark);

  static ThemeData get data => light;

  static ThemeData createTheme(FlowlinePalette p) => ThemeData(
        useMaterial3: false,
        brightness: p.isDark ? Brightness.dark : Brightness.light,
        fontFamily: 'FlowlineSans',
        scaffoldBackgroundColor: p.paper,
        canvasColor: p.paper,
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
        focusColor: Colors.transparent,
        colorScheme: ColorScheme(
          brightness: p.isDark ? Brightness.dark : Brightness.light,
          primary: p.blue,
          onPrimary: p.paper,
          secondary: p.coral,
          onSecondary: p.paper,
          surface: p.paper,
          onSurface: p.ink,
          error: p.danger,
          onError: p.paper,
        ),
        textTheme: TextTheme(
          displayLarge: TextStyle(color: p.ink, fontSize: 46, height: .96, fontWeight: FontWeight.w700, letterSpacing: -2),
          headlineLarge: TextStyle(color: p.ink, fontSize: 28, height: 1.05, fontWeight: FontWeight.w700, letterSpacing: -.8),
          titleLarge: TextStyle(color: p.ink, fontSize: 19, height: 1.1, fontWeight: FontWeight.w700),
          bodyLarge: TextStyle(color: p.ink, fontSize: 15, height: 1.35),
          bodyMedium: TextStyle(color: p.ink, fontSize: 13, height: 1.35),
          labelLarge: TextStyle(color: p.ink, fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: .5),
        ),
      );
}
