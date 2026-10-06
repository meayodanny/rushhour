import 'dart:async';
import 'dart:math' as math;

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
  final List<Offset> _manual = <Offset>[];

  late final AnimationController _timeAnimation;
  late final AnimationController _hintAnimation;

  GameSessionController? _game;
  Size? _viewportSize;
  bool _timeOpen = false;
  bool _settingsOpen = false;

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
      duration: const Duration(milliseconds: 6200),
    )..addStatusListener(_onHintStatus);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final game = ref.read(gameControllerProvider);
      _game = game;
      game.addListener(_syncHintAnimation);
      if (widget.startNew) game.startSession(widget.difficulty, tutorial: widget.tutorial);
      _syncHintAnimation();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _game?.removeListener(_syncHintAnimation);
    _transform.dispose();
    _timeAnimation.dispose();
    _hintAnimation.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.inactive) {
      final game = _game;
      if (game != null) unawaited(game.save());
    }
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
    return PopScope(
      canPop: !widget.tutorial,
      child: ColoredBox(
        color: Palette.paper,
        child: SafeArea(
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: _handleOutsidePointer,
            child: Stack(
              children: <Widget>[
                Column(
                  children: <Widget>[
                    GameHud(
                      game: game,
                      clockKey: _clockKey,
                      onTimeTap: _toggleTimePanel,
                      onSettings: () {
                        _closeTimePanel();
                        setState(() => _settingsOpen = true);
                      },
                      showSettings: !widget.tutorial,
                    ),
                    Expanded(child: _map(game)),
                    FleetBar(game: game),
                    AnimatedBuilder(
                      animation: game.ads,
                      builder: (BuildContext context, Widget? child) {
                        final banner = game.ads.banner;
                        return banner == null
                            ? const SizedBox.shrink()
                            : SizedBox(
                                width: banner.size.width.toDouble(),
                                height: banner.size.height.toDouble(),
                                child: AdWidget(ad: banner),
                              );
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
                GameOverOverlay(
                  game: game,
                  onMenu: () => unawaited(widget.onReturnToMenu()),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _map(GameSessionController game) => LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final viewport = Size(constraints.maxWidth, constraints.maxHeight);
          if (_viewportSize != viewport && viewport.width.isFinite && viewport.height.isFinite) {
            _viewportSize = viewport;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _fitToViewport(game);
            });
          }
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
              child: InteractiveViewer(
                transformationController: _transform,
                constrained: false,
                minScale: .25,
                maxScale: 2.5,
                boundaryMargin: const EdgeInsets.all(280),
                panEnabled: _manual.isEmpty,
                onInteractionStart: (_) => _closeTimePanel(),
                child: SizedBox(
                  width: GameConfig.worldSize.width,
                  height: GameConfig.worldSize.height,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapUp: (TapUpDetails details) => game.handleMapTap(details.localPosition),
                    onLongPressStart: (LongPressStartDetails details) {
                      setState(() {
                        _manual
                          ..clear()
                          ..add(details.localPosition);
                      });
                    },
                    onLongPressMoveUpdate: (LongPressMoveUpdateDetails details) {
                      setState(() {
                        if (_manual.isEmpty || (_manual.last - details.localPosition).distance > 14) {
                          _manual.add(details.localPosition);
                        }
                      });
                    },
                    onLongPressEnd: (LongPressEndDetails details) {
                      game.createManualLine(List<Offset>.of(_manual));
                      setState(_manual.clear);
                    },
                    child: Stack(
                      fit: StackFit.expand,
                      children: <Widget>[
                        RepaintBoundary(
                          child: CustomPaint(
                            size: GameConfig.worldSize,
                            painter: StaticMapPainter(game.city),
                          ),
                        ),
                        CustomPaint(size: GameConfig.worldSize, painter: GamePainter(game)),
                        CustomPaint(
                          size: GameConfig.worldSize,
                          painter: OverlayPainter(
                            game,
                            List<Offset>.of(_manual),
                            hintAnimation: _hintAnimation,
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

  void _fitToViewport(GameSessionController game) {
    final viewport = _viewportSize;
    if (viewport == null || viewport.isEmpty || game.city.nodes.isEmpty) return;
    final bounds = game.city.contentBounds.inflate(65);
    final scale = math.min(viewport.width / bounds.width, viewport.height / bounds.height).clamp(.25, 2.5);
    final matrix = Matrix4.identity()
      ..translate(viewport.width / 2, viewport.height / 2)
      ..scale(scale)
      ..translate(-bounds.center.dx, -bounds.center.dy);
    _transform.value = matrix;
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
