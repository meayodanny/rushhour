import 'dart:ui';

abstract final class GameConfig {
  // MVP is intentionally a compact district; the graph no longer reserves a
  // large empty world around the playable neighbourhood.
  static const Size worldSize = Size(860, 1320);
  static const int startingLines = 2;
  static const int startingWalkCouriers = 2;
  static const int baseDemandLimit = 8;
  static const int upgradedDemandLimit = 12;
  static const int maxDishes = 6;
  static const int maxLines = 6;
  static const int maxCouriersPerLine = 4;
  static const int maxStopsPerLine = 12;
  static const int deliveriesPerReward = 15;
  static const double dishLifetime = 55;
  static const double normalOverloadSeconds = 18;
  static const double realismOverloadSeconds = 10;
  static const List<Color> lineColors = <Color>[
    Color(0xffef476f), Color(0xff118ab2), Color(0xffff9f1c),
    Color(0xff7b61ff), Color(0xff2a9d8f), Color(0xffd1495b),
  ];
}
