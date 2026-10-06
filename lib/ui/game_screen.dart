import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../core/game_config.dart';
import '../core/geo_projection.dart';
import '../core/palette.dart';
import '../core/touch_targets.dart';
import '../game/game_controller.dart';
import '../models/entities.dart';
import '../painters/game_painter.dart';
import '../painters/hitbox_debug_painter.dart';
import '../painters/overlay_painter.dart';
import '../painters/static_map_painter.dart';
import 'widgets/fleet_bar.dart';
import 'widgets/game_over_overlay.dart';
import 'widgets/game_settings_overlay.dart';
import 'widgets/hud.dart';
import 'widgets/reward_overlay.dart';
import 'widgets/time_controls.dart';

/// Temporary hit-box debug overlay switch (Requirement 44.5): enabled with
/// `--dart-define=FLOWLINE_DEBUG_HITBOXES=true` or by passing
/// `GameScreen.debugHitBoxes` (tests do the latter). Defaults to false, so
/// release builds never show it.
const bool kFlowlineDebugHitBoxes = bool.fromEnvironment('FLOWLINE_DEBUG_HITBOXES');

class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({
    required this.difficulty,
    required this.tutorial,
    required this.startNew,
    required this.onReturnToMenu,
    this.debugHitBoxes = kFlowlineDebugHitBoxes,
    super.key,
  });

  final Difficulty difficulty;
  final bool tutorial;
  final bool startNew;
  final Future<void> Function() onReturnToMenu;

  /// Paints the QA overlay with every touch target (Requirement 44.5).
  final bool debugHitBoxes;

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  final TransformationController _transform = TransformationController();
  final GlobalKey _mapKey = GlobalKey();
  final GlobalKey _clockKey = GlobalKey();
  final GlobalKey _timePanelKey = GlobalKey();

  late final AnimationController _timeAnimation;
  late final AnimationController _hintAnimation;
  late final AnimationController _cameraAnimation;
  late final AnimationController _gameOverAnimation;

  GameSessionController? _game;
  Size? _viewportSize;
  bool _timeOpen = false;
  bool _settingsOpen = false;
  bool _cameraGesture = false;
  bool _lineGestureActive = false;
  Offset _gestureAnchor = Offset.zero;
  Offset _lastGestureScreen = Offset.zero;
  double _gestureStartScale = 1;
  Offset _cameraReturnStart = Offset.zero;
  Offset _cameraReturnEnd = Offset.zero;
  double _cameraReturnScaleStart = 1;
  double _cameraReturnScaleEnd = 1;
  bool _mapMoved = false;
  bool _gameOverTriggered = false;

  @override
  void initState() {
    super.initState();
    _timeAnimation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      reverseDuration: const Duration(milliseconds: 240),
    );
    _hintAnimation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 12000),
    )..addStatusListener(_onHintStatus);

    _cameraAnimation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    )..addListener(_applyCameraReturn);

    // Requirement 37: Cinematic defeat animation
    _gameOverAnimation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final game = ref.read(gameControllerProvider);
      _game = game;
      game.addListener(_onGameUpdate);
      if (widget.startNew) game.startSession(widget.difficulty, tutorial: widget.tutorial);
      _syncHintAnimation();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _game?.removeListener(_onGameUpdate);
    _transform.dispose();
    _timeAnimation.dispose();
    _hintAnimation.dispose();
    _cameraAnimation.dispose();
    _gameOverAnimation.dispose();
    super.dispose();
  }

  // Requirement 27: Lifecycle pause & resume handling
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final game = _game;
    if (game == null) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      game.onAppPaused();
    } else if (state == AppLifecycleState.resumed) {
      game.onAppResumed();
    }
  }

  void _onGameUpdate() {
    final game = _game;
    if (game == null || !mounted) return;
    _syncHintAnimation();

    // Requirement 37: Trigger defeat cinematic
    if (game.gameOver && !_gameOverTriggered) {
      _gameOverTriggered = true;
      _triggerGameOverCinematic(game);
    } else if (!game.gameOver && _gameOverTriggered) {
      _gameOverTriggered = false;
      _gameOverAnimation.reset();
    }

    // Requirement 40.2: Trigger cinematic camera expansion on reveal stage
    if (game.newlyRevealedStage) {
      game.newlyRevealedStage = false;
      _animateRevealExpansion(game);
    }
  }

  void _triggerGameOverCinematic(GameSessionController game) {
    final viewport = _viewportSize;
    if (viewport == null) return;

    Offset targetCenter;
    if (game.failedCustomerId != null) {
      final cust = game.customerById(game.failedCustomerId);
      final node = cust != null ? game.city.nodes[cust.nodeId] : null;
      targetCenter = node?.point ?? game.city.contentBounds.center;
    } else {
      targetCenter = game.city.contentBounds.center;
    }

    final currentScale = _transform.value.getMaxScaleOnAxis();
    final targetScale = math.min(2.4, _maxZoom(viewport));

    _cameraReturnScaleStart = currentScale;
    _cameraReturnScaleEnd = targetScale;
    _cameraReturnStart = Offset(_transform.value.storage[12], _transform.value.storage[13]);
    _cameraReturnEnd = Offset(
      viewport.width / 2 - targetCenter.dx * targetScale,
      viewport.height / 2 - targetCenter.dy * targetScale,
    );

    _cameraAnimation.duration = const Duration(milliseconds: 1100);
    _cameraAnimation.forward(from: 0).then((_) {
      _cameraAnimation.duration = const Duration(milliseconds: 450);
    });
    _gameOverAnimation.forward(from: 0);
  }

  void _animateRevealExpansion(GameSessionController game) {
    final viewport = _viewportSize;
    if (viewport == null) return;

    final bounds = _mapBounds();
    final currentScale = _transform.value.getMaxScaleOnAxis();
    final targetScale = _minZoom(viewport).clamp(.25, _maxZoom(viewport)).toDouble();

    _cameraReturnScaleStart = currentScale;
    _cameraReturnScaleEnd = targetScale;
    _cameraReturnStart = Offset(_transform.value.storage[12], _transform.value.storage[13]);
    _cameraReturnEnd = Offset(
      viewport.width / 2 - bounds.center.dx * targetScale,
      viewport.height / 2 - bounds.center.dy * targetScale,
    );

    _cameraAnimation.duration = const Duration(milliseconds: 1200);
    _cameraAnimation.forward(from: 0).then((_) {
      _cameraAnimation.duration = const Duration(milliseconds: 450);
    });
  }

  void _syncHintAnimation() {
    final game = _game;
    if (game == null || !mounted) return;
    if (game.tutorialVisible && !_hintAnimation.isAnimating) {
      _hintAnimation.forward(from: 0);
    }
  }

  void _onHintStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    _game?.finishGestureHint();
    _hintAnimation.reset();
  }

  @override
  Widget build(BuildContext context) {
    final game = ref.watch(gameControllerProvider);
    final palette = Palette.of(context);

    // Requirement 33: Progressive UI reveal flags
    final showAppBar = game.session.lines.isNotEmpty || game.session.score > 0 || game.session.customers.length >= 2 || !widget.startNew;
    final showBottomBar = game.session.customers.length >= 2 || game.session.score >= 1 || game.session.lines.length >= 2 || !widget.startNew;

    return PopScope(
      canPop: !widget.tutorial,
      child: ColoredBox(
        color: palette.paper,
        child: SafeArea(
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: _handleOutsidePointer,
            child: Stack(
              children: <Widget>[
                Column(
                  children: <Widget>[
                    // Requirement 33: AppBar with animated fade + slide
                    AnimatedSlide(
                      offset: showAppBar ? Offset.zero : const Offset(0, -1.0),
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOutCubic,
                      child: AnimatedOpacity(
                        opacity: showAppBar ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 350),
                        child: GameHud(
                          game: game,
                          clockKey: _clockKey,
                          onTimeTap: _toggleTimePanel,
                          onSettings: () {
                            _closeTimePanel();
                            setState(() => _settingsOpen = true);
                          },
                          showSettings: !widget.tutorial,
                        ),
                      ),
                    ),
                    Expanded(child: _map(game, palette)),
                    // Requirement 33: Bottom FleetBar with animated fade + slide
                    AnimatedSlide(
                      offset: showBottomBar ? Offset.zero : const Offset(0, 1.0),
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOutCubic,
                      child: AnimatedOpacity(
                        opacity: showBottomBar ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 350),
                        child: FleetBar(game: game),
                      ),
                    ),
                    // Requirement 35: BannerAd loaded before inserting AdWidget into tree
                    AnimatedBuilder(
                      animation: game.ads,
                      builder: (BuildContext context, Widget? child) {
                        final banner = game.ads.banner;
                        if (banner != null && game.ads.bannerLoaded) {
                          return SizedBox(
                            width: banner.size.width.toDouble(),
                            height: banner.size.height.toDouble(),
                            child: AdWidget(ad: banner),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ],
                ),
                Positioned(
                  left: 14,
                  top: 76,
                  child: TimeControls(
                    game: game,
                    animation: _timeAnimation,
                    panelKey: _timePanelKey,
                  ),
                ),
                Positioned.fill(
                  child: GameSettingsOverlay(
                    game: game,
                    visible: _settingsOpen && !widget.tutorial,
                    onClose: () => setState(() => _settingsOpen = false),
                    onFit: () => _fitToViewport(game),
                    onMenu: () => unawaited(widget.onReturnToMenu()),
                  ),
                ),
                RewardOverlay(game: game),
                // Requirement 37: Animated blur + defeat overlay
                if (game.gameOver)
                  Positioned.fill(
                    child: AnimatedBuilder(
                      animation: _gameOverAnimation,
                      builder: (BuildContext context, Widget? child) {
                        final blur = Curves.easeInQuad.transform(_gameOverAnimation.value) * 12.0;
                        return BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                          child: ColoredBox(
                            color: palette.paper.withValues(alpha: 0.25 * _gameOverAnimation.value),
                            child: child,
                          ),
                        );
                      },
                      child: GameOverOverlay(
                        game: game,
                        appearAnimation: _gameOverAnimation,
                        onMenu: () => unawaited(widget.onReturnToMenu()),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The game map, layered exactly as prescribed by Requirement 44.1:
  ///
  /// * layer 1+3 — the painted world (static map, dynamic entities, draft
  ///   overlay) under the camera `Transform`; not interactive;
  /// * layer 2 — the pan/zoom recognizer; reacts only when the pointer hit
  ///   none of the POI hit areas (they sit above it in the Stack, so Flutter
  ///   resolves the priority natively — Requirement 44.3);
  /// * layer 4 — one positioned, opaque 48x48 hit-area widget per point of
  ///   interest (restaurants and customers) — Requirement 44.2;
  /// * layer 5 — the temporary debug overlay (Requirement 44.5).
  Widget _map(GameSessionController game, FlowlinePalette palette) => LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final viewport = Size(constraints.maxWidth, constraints.maxHeight);
          if (_viewportSize != viewport && viewport.width.isFinite && viewport.height.isFinite) {
            _viewportSize = viewport;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _fitToViewport(game);
            });
          }
          final activeRect = game.city.projectBounds(game.activeRevealBounds);

          return DragTarget<CourierType>(
            onAcceptWithDetails: (DragTargetDetails<CourierType> details) {
              final renderObject = _mapKey.currentContext?.findRenderObject();
              if (renderObject is! RenderBox) return;
              final viewportPoint = renderObject.globalToLocal(details.offset);
              game.assignCourier(details.data, _camera().screenToWorld(viewportPoint));
            },
            builder: (
              BuildContext context,
              List<CourierType?> candidates,
              List<Object?> rejected,
            ) => ClipRect(
              key: _mapKey,
              child: ValueListenableBuilder<Matrix4>(
                valueListenable: _transform,
                builder: (BuildContext context, Matrix4 matrix, Widget? worldChild) {
                  final camera = MapCamera(matrix);
                  // Requirement 44.5: the hit-box rects are computed ONCE and
                  // shared by the positioned hit areas (layer 4) and the debug
                  // overlay (layer 5) — one projection call chain, two consumers.
                  final List<PoiHitRect> poiHitRects = _poiHitRects(game, camera);
                  return IgnorePointer(
                    // While a line gesture owns the pointer, no second pointer
                    // may start a camera pan or another draft.
                    ignoring: _lineGestureActive,
                    child: Stack(
                      fit: StackFit.expand,
                      children: <Widget>[
                        // Layers 1 & 3: painted world under the camera transform.
                        Transform(
                          key: const ValueKey('map-camera-transform'),
                          alignment: Alignment.topLeft,
                          transform: matrix,
                          child: worldChild,
                        ),
                        // Layer 2: pan/zoom — and courier/line drags for touches
                        // that did not land in any POI hit area above.
                        GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onTapUp: (TapUpDetails details) {
                            if (!_mapMoved) {
                              game.handleMapTap(_camera(), details.localPosition);
                            }
                          },
                          onScaleStart: _onMapScaleStart,
                          onScaleUpdate: _onMapScaleUpdate,
                          onScaleEnd: _onMapScaleEnd,
                          child: const SizedBox.expand(),
                        ),
                        // Layer 4 (Requirement 44.2): the points of interest.
                        for (final PoiHitRect hit in poiHitRects)
                          _buildPoiHitArea(game, hit),
                        // Layer 5 (Requirement 44.5): debug overlay, never
                        // interactive itself.
                        if (widget.debugHitBoxes)
                          IgnorePointer(
                            child: CustomPaint(
                              size: Size.infinite,
                              painter: HitBoxDebugPainter(
                                game: game,
                                camera: camera,
                                poiHitRects: poiHitRects,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
                child: OverflowBox(
                  alignment: Alignment.topLeft,
                  minWidth: GameConfig.worldSize.width,
                  maxWidth: GameConfig.worldSize.width,
                  minHeight: GameConfig.worldSize.height,
                  maxHeight: GameConfig.worldSize.height,
                  child: SizedBox(
                    width: GameConfig.worldSize.width,
                    height: GameConfig.worldSize.height,
                    child: Stack(
                      fit: StackFit.expand,
                      children: <Widget>[
                        RepaintBoundary(
                          child: CustomPaint(
                            size: GameConfig.worldSize,
                            painter: StaticMapPainter(
                              game.city,
                              palette: palette,
                              activeBoundsRect: activeRect,
                            ),
                          ),
                        ),
                        CustomPaint(
                          size: GameConfig.worldSize,
                          painter: GamePainter(game, palette: palette),
                        ),
                        CustomPaint(
                          size: GameConfig.worldSize,
                          painter: OverlayPainter(
                            game,
                            const <Offset>[],
                            hintAnimation: _hintAnimation,
                            palette: palette,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );

  /// Builds the 48x48 screen-space hit boxes for every active restaurant and
  /// customer (Requirement 44.2).
  ///
  /// The centre of each rect comes from `GeoProjection.geoToScreen` — the
  /// same single projection chain that `StaticMapPainter`'s world painting
  /// goes through (`project(lat, lng)` baked into `RoadNode.point` plus the
  /// camera matrix that drives the rendering `Transform`).
  List<PoiHitRect> _poiHitRects(GameSessionController game, MapCamera camera) {
    final result = <PoiHitRect>[];
    void add(String entityId, String nodeId, bool isCustomer) {
      final node = game.city.nodes[nodeId];
      if (node == null) return;
      final Offset screenPos =
          game.city.projection.geoToScreen(node.lat, node.lng, camera);
      result.add(
        (
          entityId: entityId,
          rect: Rect.fromCenter(
            center: screenPos,
            width: TouchTargets.poiHitSize,
            height: TouchTargets.poiHitSize,
          ),
          isCustomer: isCustomer,
        ),
      );
    }

    for (final restaurant in game.session.restaurants) {
      add(restaurant.id, restaurant.nodeId, false);
    }
    for (final customer in game.session.customers) {
      add(customer.id, customer.nodeId, true);
    }
    return result;
  }

  /// Requirement 44.2: each point of interest is its own positioned
  /// interactive widget, laid over the painted map. Flutter's own hit
  /// testing resolves "POI vs pan/zoom" — no manual distance checks.
  Widget _buildPoiHitArea(GameSessionController game, PoiHitRect hit) {
    return Positioned(
      key: ValueKey<String>('poi-hit-${hit.entityId}'),
      left: hit.rect.left,
      top: hit.rect.top,
      width: hit.rect.width,
      height: hit.rect.height,
      child: GestureDetector(
        // Mandatory: opaque makes the transparent container hit-testable.
        behavior: HitTestBehavior.opaque,
        onTapUp: (TapUpDetails details) => game.handlePoiTap(hit.entityId),
        onPanStart: (DragStartDetails details) =>
            _onPoiPanStart(hit.entityId, details.globalPosition),
        onPanUpdate: (DragUpdateDetails details) =>
            _onPoiPanUpdate(details.globalPosition),
        onPanEnd: (DragEndDetails details) => _onPoiPanEnd(),
        onPanCancel: _onPoiPanCancel,
        child: Container(color: Colors.transparent),
      ),
    );
  }

  MapCamera _camera() => MapCamera(_transform.value);

  /// The live controller (never null while the screen is mounted).
  GameSessionController get _activeGame =>
      (_game ?? ref.read(gameControllerProvider))!;

  /// Converts a global pointer position into the map viewport's local
  /// coordinates — the space the camera matrix maps from.
  Offset _mapLocalFromGlobal(Offset globalPoint) {
    final renderObject = _mapKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox) return globalPoint;
    return renderObject.globalToLocal(globalPoint);
  }

  // ---------------------------------------------------------------------
  // POI hit-area gestures (layer 4, Requirement 44.2).
  // ---------------------------------------------------------------------

  void _onPoiPanStart(String entityId, Offset globalPosition) {
    _closeTimePanel();
    _cameraAnimation.stop();
    _lastGestureScreen = _mapLocalFromGlobal(globalPosition);
    if (!_lineGestureActive) {
      setState(() => _lineGestureActive = true);
    }
    final game = _activeGame;
    game.startLineDraftFromEntity(entityId);
  }

  void _onPoiPanUpdate(Offset globalPosition) {
    final game = _activeGame;
    final screenPoint = _mapLocalFromGlobal(globalPosition);
    _lastGestureScreen = screenPoint;
    game.updateLineGesture(_camera(), screenPoint);
  }

  void _onPoiPanEnd() {
    final game = _activeGame;
    if (_lineGestureActive) {
      setState(() => _lineGestureActive = false);
    }
    game.endLineGesture(_camera(), _lastGestureScreen);
  }

  void _onPoiPanCancel() {
    if (_lineGestureActive) {
      setState(() => _lineGestureActive = false);
    }
    final game = _activeGame;
    game.cancelLineGesture();
  }

  // ---------------------------------------------------------------------
  // Map-level gestures (layer 2): pan/zoom plus courier & line drags for
  // pointers that missed every POI hit area.
  // ---------------------------------------------------------------------

  void _onMapScaleStart(ScaleStartDetails details) {
    _closeTimePanel();
    _mapMoved = false;
    final game = _activeGame;
    final camera = _camera();
    // THE bug of patches #2/#3, fixed: the recognizer used to feed the GLOBAL
    // focal point into a matrix that expects map-local coordinates. Every
    // hit test was therefore shifted by the HUD height (~90 px) — the line
    // only ever started when the finger was that far BELOW the icon. The
    // local focal point is the coordinate the camera actually understands.
    final scene = camera.screenToWorld(details.localFocalPoint);
    _lastGestureScreen = details.localFocalPoint;
    _cameraAnimation.stop();
    // Courier and line drags are single-finger gestures; a second finger
    // always means pinch-zoom, never a line edit.
    if (details.pointerCount < 2 &&
        game.beginMapGesture(camera, details.localFocalPoint)) {
      _cameraGesture = false;
      if (!_lineGestureActive) {
        setState(() => _lineGestureActive = true);
      }
      return;
    }
    _cameraGesture = true;
    _gestureAnchor = scene;
    _gestureStartScale = _transform.value.getMaxScaleOnAxis();
  }

  void _onMapScaleUpdate(ScaleUpdateDetails details) {
    _mapMoved = _mapMoved || details.scale != 1 || details.focalPointDelta.distance > .5;
    final game = _activeGame;
    if (!_cameraGesture) {
      _lastGestureScreen = details.localFocalPoint;
      game.updateLineGesture(_camera(), details.localFocalPoint);
      return;
    }
    final viewport = _viewportSize;
    if (viewport == null) return;
    final scale = _softScale(_gestureStartScale * details.scale, viewport);
    final focal = details.localFocalPoint;
    final rawTranslation = Offset(
      focal.dx - _gestureAnchor.dx * scale,
      focal.dy - _gestureAnchor.dy * scale,
    );
    final translation = _softTranslation(rawTranslation, scale, viewport);
    _transform.value = _matrix(scale, translation);
  }

  void _onMapScaleEnd(ScaleEndDetails details) {
    final game = _activeGame;
    if (!_cameraGesture) {
      game.endLineGesture(_camera(), _lastGestureScreen);
    } else {
      _animateCameraBack();
    }
    _cameraGesture = false;
    if (_lineGestureActive) {
      setState(() => _lineGestureActive = false);
    }
  }

  Matrix4 _matrix(double scale, Offset translation) => Matrix4.identity()
    ..translate(translation.dx, translation.dy)
    ..scale(scale);

  // Requirement 40.2: Camera bounds clamped to active reveal bounds
  Rect _mapBounds() {
    final game = _activeGame;
    final activeGeo = game.activeRevealBounds;
    final rect = game.city.projectBounds(activeGeo);
    return rect.inflate(45);
  }

  double _minZoom(Size viewport) {
    final bounds = _mapBounds();
    return math.max(viewport.width / bounds.width, viewport.height / bounds.height) * .96;
  }

  double _maxZoom(Size viewport) => math.max(2.4, _minZoom(viewport) * 3.2);

  double _softScale(double value, Size viewport) {
    final min = _minZoom(viewport);
    final max = _maxZoom(viewport);
    if (value < min) return min - (min - value) * .22;
    if (value > max) return max + (value - max) * .22;
    return value;
  }

  Offset _softTranslation(Offset value, double scale, Size viewport) {
    final hard = _hardLimits(scale, viewport);
    double soften(double coordinate, double min, double max) {
      if (min > max) return (min + max) / 2;
      if (coordinate < min) return min - (min - coordinate) * .22;
      if (coordinate > max) return max + (coordinate - max) * .22;
      return coordinate;
    }
    return Offset(soften(value.dx, hard.left, hard.right), soften(value.dy, hard.top, hard.bottom));
  }

  Rect _hardLimits(double scale, Size viewport) {
    final bounds = _mapBounds();
    const padding = 22.0;
    final minX = viewport.width - padding - bounds.right * scale;
    final maxX = padding - bounds.left * scale;
    final minY = viewport.height - padding - bounds.bottom * scale;
    final maxY = padding - bounds.top * scale;
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  void _animateCameraBack() {
    final viewport = _viewportSize;
    if (viewport == null) return;
    final currentScale = _transform.value.getMaxScaleOnAxis();
    final min = _minZoom(viewport);
    final max = _maxZoom(viewport);
    final targetScale = currentScale.clamp(min, max).toDouble();
    final targetTranslation = _clampedTranslation(targetScale, viewport);
    _cameraReturnScaleStart = currentScale;
    _cameraReturnScaleEnd = targetScale;
    _cameraReturnStart = Offset(_transform.value.storage[12], _transform.value.storage[13]);
    _cameraReturnEnd = targetTranslation;
    if ((_cameraReturnScaleStart - _cameraReturnScaleEnd).abs() < .0001 &&
        (_cameraReturnStart - _cameraReturnEnd).distance < .1) {
      return;
    }
    _cameraAnimation.forward(from: 0);
  }

  Offset _clampedTranslation(double scale, Size viewport) {
    final hard = _hardLimits(scale, viewport);
    final current = Offset(_transform.value.storage[12], _transform.value.storage[13]);
    final x = hard.left <= hard.right ? current.dx.clamp(hard.left, hard.right).toDouble() : (hard.left + hard.right) / 2;
    final y = hard.top <= hard.bottom ? current.dy.clamp(hard.top, hard.bottom).toDouble() : (hard.top + hard.bottom) / 2;
    return Offset(x, y);
  }

  void _applyCameraReturn() {
    if (!mounted) return;
    final eased = Curves.easeOutCubic.transform(_cameraAnimation.value);
    final scale = lerpDouble(_cameraReturnScaleStart, _cameraReturnScaleEnd, eased)!;
    final translation = Offset(
      lerpDouble(_cameraReturnStart.dx, _cameraReturnEnd.dx, eased)!,
      lerpDouble(_cameraReturnStart.dy, _cameraReturnEnd.dy, eased)!,
    );
    _transform.value = _matrix(scale, translation);
  }

  void _fitToViewport(GameSessionController game) {
    final viewport = _viewportSize;
    if (viewport == null || viewport.isEmpty || game.city.nodes.isEmpty) return;
    final bounds = _mapBounds();
    final scale = _minZoom(viewport).clamp(.25, _maxZoom(viewport)).toDouble();
    final translation = Offset(
      viewport.width / 2 - bounds.center.dx * scale,
      viewport.height / 2 - bounds.center.dy * scale,
    );
    _transform.value = _matrix(scale, translation);
  }

  void _toggleTimePanel() {
    setState(() => _timeOpen = !_timeOpen);
    _timeOpen ? _timeAnimation.forward() : _timeAnimation.reverse();
  }

  void _closeTimePanel() {
    if (!_timeOpen) return;
    setState(() => _timeOpen = false);
    _timeAnimation.reverse();
  }

  void _handleOutsidePointer(PointerDownEvent event) {
    if (!_timeOpen) return;
    if (_containsGlobalPoint(_clockKey, event.position) || _containsGlobalPoint(_timePanelKey, event.position)) return;
    _closeTimePanel();
  }

  bool _containsGlobalPoint(GlobalKey key, Offset globalPoint) {
    final object = key.currentContext?.findRenderObject();
    if (object is! RenderBox || !object.hasSize) return false;
    final origin = object.localToGlobal(Offset.zero);
    return (origin & object.size).contains(globalPoint);
  }
}
