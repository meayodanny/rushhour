import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../core/game_config.dart';
import '../core/palette.dart';
import '../game/game_controller.dart';
import '../l10n/app_strings.dart';
import '../models/entities.dart';
import '../painters/game_painter.dart';
import '../painters/overlay_painter.dart';
import '../painters/static_map_painter.dart';
import 'widgets/fleet_bar.dart';
import 'widgets/game_over_overlay.dart';
import 'widgets/hud.dart';
import 'widgets/reward_overlay.dart';

class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key});
  @override ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> with WidgetsBindingObserver {
  final TransformationController _transform = TransformationController(Matrix4.identity()..scale(.52));
  final GlobalKey _mapKey = GlobalKey();
  final List<Offset> _manual = <Offset>[];

  @override void initState() { super.initState(); WidgetsBinding.instance.addObserver(this); }
  @override void dispose() { WidgetsBinding.instance.removeObserver(this); _transform.dispose(); super.dispose(); }
  @override void didChangeAppLifecycleState(AppLifecycleState state) { if (state == AppLifecycleState.paused || state == AppLifecycleState.detached || state == AppLifecycleState.inactive) unawaited(ref.read(gameControllerProvider).save()); }

  @override
  Widget build(BuildContext context) {
    final game = ref.watch(gameControllerProvider);
    return Scaffold(
      backgroundColor: Palette.paper,
      body: SafeArea(child: Column(children: <Widget>[
        GameHud(game: game, onSettings: () => _showSettings(game)),
        Expanded(child: Stack(children: <Widget>[
          Positioned.fill(child: LayoutBuilder(builder: (BuildContext _context, BoxConstraints _constraints) => DragTarget<CourierType>(
            onAcceptWithDetails: (DragTargetDetails<CourierType> details) {
              final box = _mapKey.currentContext!.findRenderObject()! as RenderBox;
              final viewportPoint = box.globalToLocal(details.offset);
              game.assignCourier(details.data, _transform.toScene(viewportPoint));
            },
            builder: (BuildContext _context, List<CourierType?> _candidates, List<Object?> _rejected) => ClipRect(key: _mapKey, child: InteractiveViewer(
              transformationController: _transform, constrained: false, minScale: .35, maxScale: 2.5,
              boundaryMargin: const EdgeInsets.all(240), panEnabled: _manual.isEmpty,
              child: SizedBox(width: GameConfig.worldSize.width, height: GameConfig.worldSize.height, child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (TapUpDetails details) => game.handleMapTap(details.localPosition),
                onLongPressStart: (LongPressStartDetails details) => setState(() { _manual..clear()..add(details.localPosition); }),
                onLongPressMoveUpdate: (LongPressMoveUpdateDetails details) => setState(() { if (_manual.isEmpty || (_manual.last - details.localPosition).distance > 14) _manual.add(details.localPosition); }),
                onLongPressEnd: (LongPressEndDetails _details) { game.createManualLine(List<Offset>.of(_manual)); setState(_manual.clear); },
                child: Stack(children: <Widget>[
                  RepaintBoundary(child: CustomPaint(size: GameConfig.worldSize, painter: StaticMapPainter(game.city))),
                  CustomPaint(size: GameConfig.worldSize, painter: GamePainter(game)),
                  CustomPaint(size: GameConfig.worldSize, painter: OverlayPainter(game, List<Offset>.of(_manual))),
                ]),
              )),
            )),
          ))),
          GameOverOverlay(game: game),
          RewardOverlay(game: game),
        ])),
        FleetBar(game: game),
        AnimatedBuilder(
          animation: game.ads,
          builder: (BuildContext context, Widget? child) {
            final banner = game.ads.banner;
            return banner == null
                ? const SizedBox.shrink()
                : SizedBox(width: banner.size.width.toDouble(), height: banner.size.height.toDouble(), child: AdWidget(ad: banner));
          },
        ),
      ])),
      floatingActionButton: game.tutorialVisible ? FloatingActionButton.extended(onPressed: game.dismissTutorial, backgroundColor: Palette.ink, foregroundColor: Colors.white, icon: const Icon(Icons.gesture_rounded), label: Text(AppStrings.of(context).hint)) : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      extendBody: true,
      persistentFooterButtons: const <Widget>[],
      bottomSheet: null,
    );
  }

  void _fit() { _transform.value = Matrix4.identity()..scale(.52); }

  void _showSettings(GameSessionController game) {
    final s = AppStrings.of(context);
    showModalBottomSheet<void>(context: context, showDragHandle: true, isScrollControlled: true, builder: (BuildContext context) => SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 24), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
      Text(s.settings, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
      SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(s.sound), value: game.persistence.audioEnabled, onChanged: (bool value) { game.audio.enabled = value; unawaited(game.persistence.setAudioEnabled(value)); Navigator.pop(context); }),
      ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.fit_screen_rounded), title: Text(s.fit), onTap: () { _fit(); Navigator.pop(context); }),
      ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.school_rounded), title: Text(s.tutorial), onTap: () { unawaited(game.persistence.resetTutorial()); Navigator.pop(context); }),
      const Divider(), Text(s.difficulty, style: const TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: Difficulty.values.map((Difficulty d) => ActionChip(avatar: Icon(_difficultyIcon(d), size: 17), label: Text(_difficultyLabel(s, d)), onPressed: () { game.restart(d); Navigator.pop(context); })).toList()),
      const SizedBox(height: 15), Text(game.city.attribution, style: const TextStyle(color: Palette.muted, fontSize: 11)),
    ]))));
  }

  IconData _difficultyIcon(Difficulty d) => switch (d) { Difficulty.normal => Icons.circle_outlined, Difficulty.realism => Icons.bolt_rounded, Difficulty.infinite => Icons.all_inclusive_rounded, Difficulty.sandbox => Icons.auto_awesome_rounded };
  String _difficultyLabel(AppStrings s, Difficulty d) => switch (d) { Difficulty.normal => s.normal, Difficulty.realism => s.realism, Difficulty.infinite => s.infinite, Difficulty.sandbox => s.sandbox };
}
