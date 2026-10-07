/// Touch-target sizes, in *screen* logical pixels (Requirement 44).
///
/// Every value here is zoom-independent: the game screen converts them to
/// world units through `MapCamera.worldRadiusFor`, and the POI hit areas are
/// positioned widgets sized directly by these constants. Nothing in the game
/// is allowed to define its own hit radius in world/canvas units — a
/// world-unit tolerance shrinks with the camera zoom, which is exactly the
/// class of bug fixed by Requirement 44.
abstract final class TouchTargets {
  /// Side of the square POI hit area (Requirement 44.2: 48 logical px,
  /// independent of the painted icon size).
  static const double poiHitSize = 48.0;

  /// Half of [poiHitSize] (24 px) — the radius used wherever a circular
  /// check against a POI centre is more natural than a square.
  static const double poiHitRadius = poiHitSize / 2;

  /// Snap radius while a line draft is being dragged towards a target POI
  /// (screen px from the POI centre).
  static const double targetSnapRadius = 24.0;

  /// Width of the touch strip along an existing line (Requirement 44.4).
  static const double lineHitWidth = 44.0;

  /// Half of [lineHitWidth] (22 px).
  static const double lineHitRadius = lineHitWidth / 2;

  /// Courier grab/drop radius (screen px).
  static const double courierHitRadius = 36.0;
}
