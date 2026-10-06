import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../core/game_config.dart';
import '../core/palette.dart';
import '../game/game_controller.dart';
import '../models/entities.dart';
import '../painters/game_painter.dart';
import '../painters/overlay_painter.dart';
import '../painters/static_map_painter.dart';
import 'widgets/fleet_bar.dart';
import 'widgets/game_over_overlay.dart';
import 'widgets/game_settings_overlay.dart';
import 'widgets/hud.dart';
import 'widgets/reward_overlay.dart';
import 'widgets/time_controls.dart';

class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({
    required this.difficulty,
    required this.tutorial,
    required this.startNew,
    required this.onReturnToMenu,
    super.key,
  });

  final Difficulty difficulty;
  final bool tutorial;
  final bool startNew;
  final Future<void> Function() onReturnToMenu;

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
  Offset _gestureAnchor = Offset.zero;
  Offset _lastGestureScene = Offset.zero;
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
              game.assignCourier(details.data, _transform.toScene(viewportPoint));
            },
            builder: (
              BuildContext context,
              List<CourierType?> candidates,
              List<Object?> rejected,
            ) => ClipRect(
              key: _mapKey,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (TapUpDetails details) {
                  if (!_mapMoved) game.handleMapTap(_scenePoint(details.localPosition));
                },
                onScaleStart: _onMapScaleStart,
                onScaleUpdate: _onMapScaleUpdate,
                onScaleEnd: _onMapScaleEnd,
                child: SizedBox.expand(
                  child: ValueListenableBuilder<Matrix4>(
                    valueListenable: _transform,
                    builder: (BuildContext context, Matrix4 matrix, Widget? child) => Transform(
                      alignment: Alignment.topLeft,
                      transform: matrix,
                      child: child,
                    ),
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
              ),
            ),
          );
        },
      );

  Offset _scenePoint(Offset viewportPoint) => _transform.toScene(viewportPoint);

  void _onMapScaleStart(ScaleStartDetails details) {
    _closeTimePanel();
    _mapMoved = false;
    final game = _game ?? ref.read(gameControllerProvider);
    final scene = _scenePoint(details.focalPoint);
    _lastGestureScene = scene;
    _cameraAnimation.stop();
    if (game.beginLineGesture(scene)) {
      _cameraGesture = false;
      return;
    }
    _cameraGesture = true;
    _gestureAnchor = scene;
    _gestureStartScale = _transform.value.getMaxScaleOnAxis();
    _cameraAnimation.stop();
  }

  void _onMapScaleUpdate(ScaleUpdateDetails details) {
    _mapMoved = _mapMoved || details.scale != 1 || details.focalPointDelta.distance > .5;
    final game = _game ?? ref.read(gameControllerProvider);
    if (!_cameraGesture) {
      _lastGestureScene = _scenePoint(details.focalPoint);
      game.updateLineGesture(_lastGestureScene);
      return;
    }
    final viewport = _viewportSize;
    if (viewport == null) return;
    final scale = _softScale(_gestureStartScale * details.scale, viewport);
    final focal = details.focalPoint;
    final rawTranslation = Offset(
      focal.dx - _gestureAnchor.dx * scale,
      focal.dy - _gestureAnchor.dy * scale,
    );
    final translation = _softTranslation(rawTranslation, scale, viewport);
    _transform.value = _matrix(scale, translation);
  }

  void _onMapScaleEnd(ScaleEndDetails details) {
    final game = _game ?? ref.read(gameControllerProvider);
    if (!_cameraGesture) {
      game.endLineGesture(_lastGestureScene);
    } else {
      _animateCameraBack();
    }
    _cameraGesture = false;
  }

  Matrix4 _matrix(double scale, Offset translation) => Matrix4.identity()
    ..translate(translation.dx, translation.dy)
    ..scale(scale);

  // Requirement 40.2: Camera bounds clamped to active reveal bounds
  Rect _mapBounds() {
    final game = _game ?? ref.read(gameControllerProvider);
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
