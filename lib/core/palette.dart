import 'dart:ui';
import 'package:flutter/material.dart';

class FlowlinePalette {
  const FlowlinePalette({
    required this.isDark,
    required this.paper,
    required this.ink,
    required this.muted,
    required this.road,
    required this.majorRoad,
    required this.water,
    required this.grass,
    required this.warning,
    required this.danger,
    required this.blue,
    required this.coral,
    required this.panel,
    required this.veil,
    required this.buildingResidential,
    required this.buildingOffice,
    required this.buildingOther,
    required this.buildingPark,
    required this.fogOfWar,
  });

  final bool isDark;
  final Color paper;
  final Color ink;
  final Color muted;
  final Color road;
  final Color majorRoad;
  final Color water;
  final Color grass;
  final Color warning;
  final Color danger;
  final Color blue;
  final Color coral;
  final Color panel;
  final Color veil;
  final Color buildingResidential;
  final Color buildingOffice;
  final Color buildingOther;
  final Color buildingPark;
  final Color fogOfWar;

  static const FlowlinePalette light = FlowlinePalette(
    isDark: false,
    paper: Color(0xfff7f3e9),
    ink: Color(0xff283238),
    muted: Color(0xff829095),
    road: Color(0xffd8d4c8),
    majorRoad: Color(0xffc7c3b8),
    water: Color(0xffa9dce3),
    grass: Color(0xffdce8d4),
    warning: Color(0xffffbd4a),
    danger: Color(0xffe64b4b),
    blue: Color(0xff118ab2),
    coral: Color(0xffef476f),
    panel: Color(0xffeeeadd),
    veil: Color(0xb3283238),
    buildingResidential: Color(0xffeadfd0),
    buildingOffice: Color(0xffd8e1e2),
    buildingOther: Color(0xffe7e2d5),
    buildingPark: Color(0xffdce8d4),
    fogOfWar: Color(0x99ded9cb),
  );

  static const FlowlinePalette dark = FlowlinePalette(
    isDark: true,
    paper: Color(0xff14181c),
    ink: Color(0xfff0f4f8),
    muted: Color(0xff8694a0),
    road: Color(0xff283038),
    majorRoad: Color(0xff343e49),
    water: Color(0xff183c50),
    grass: Color(0xff1e3223),
    warning: Color(0xffffbd4a),
    danger: Color(0xfff05a5a),
    blue: Color(0xff2ca8d4),
    coral: Color(0xfff25f82),
    panel: Color(0xff1f262e),
    veil: Color(0xb30c0e10),
    buildingResidential: Color(0xff232a32),
    buildingOffice: Color(0xff29323c),
    buildingOther: Color(0xff20262d),
    buildingPark: Color(0xff1e3223),
    fogOfWar: Color(0xb30d1013),
  );
}

/// Backwards compatibility static accessors
abstract final class Palette {
  static Color get paper => FlowlinePalette.light.paper;
  static Color get ink => FlowlinePalette.light.ink;
  static Color get muted => FlowlinePalette.light.muted;
  static Color get road => FlowlinePalette.light.road;
  static Color get majorRoad => FlowlinePalette.light.majorRoad;
  static Color get water => FlowlinePalette.light.water;
  static Color get grass => FlowlinePalette.light.grass;
  static Color get warning => FlowlinePalette.light.warning;
  static Color get danger => FlowlinePalette.light.danger;
  static Color get blue => FlowlinePalette.light.blue;
  static Color get coral => FlowlinePalette.light.coral;
  static Color get panel => FlowlinePalette.light.panel;
  static Color get veil => FlowlinePalette.light.veil;

  static FlowlinePalette of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.brightness == Brightness.dark
        ? FlowlinePalette.dark
        : FlowlinePalette.light;
  }
}
