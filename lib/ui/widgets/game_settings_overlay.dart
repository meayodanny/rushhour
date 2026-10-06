import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/palette.dart';
import '../../game/game_controller.dart';
import '../../l10n/app_strings.dart';
import 'flow_controls.dart';

class GameSettingsOverlay extends StatefulWidget {
  const GameSettingsOverlay({
    required this.game,
    required this.visible,
    required this.onClose,
    required this.onFit,
    required this.onMenu,
    super.key,
  });

  final GameSessionController game;
  final bool visible;
  final VoidCallback onClose;
  final VoidCallback onFit;
  final VoidCallback onMenu;

  @override
  State<GameSettingsOverlay> createState() => _GameSettingsOverlayState();
}

class _GameSettingsOverlayState extends State<GameSettingsOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 360),
    reverseDuration: const Duration(milliseconds: 260),
  );

  @override
  void didUpdateWidget(covariant GameSettingsOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible != oldWidget.visible) {
      widget.visible ? _animation.forward() : _animation.reverse();
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
        ignoring: !widget.visible,
        child: AnimatedBuilder(
          animation: _animation,
          builder: (BuildContext context, Widget? child) {
            final t = Curves.easeOutCubic.transform(_animation.value);
            return Opacity(
              opacity: t,
              child: ColoredBox(
                color: Palette.ink.withValues(alpha: .68 * t),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.onClose,
                  child: Center(
                    child: GestureDetector(
                      onTap: () {},
                      child: Transform.translate(
                        offset: Offset(0, 34 * (1 - t)),
                        child: Transform.scale(
                          scale: .94 + .06 * t,
                          child: _panel(context),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );

  Widget _panel(BuildContext context) {
    final strings = AppStrings.of(context);
    final sound = widget.game.persistence.audioEnabled;
    return Container(
      width: 330,
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(color: Palette.paper, borderRadius: BorderRadius.circular(28)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(child: Text(strings.settings.toUpperCase(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: 1.2))),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onClose,
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: FlowGlyph(FlowGlyphType.back, size: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: <Widget>[
              FlowGlyph(sound ? FlowGlyphType.sound : FlowGlyphType.muted, size: 23),
              const SizedBox(width: 13),
              Expanded(child: Text(strings.sound, style: const TextStyle(fontWeight: FontWeight.w700))),
              FlowToggle(
                value: sound,
                onChanged: (bool value) {
                  widget.game.audio.enabled = value;
                  unawaited(widget.game.persistence.setAudioEnabled(value));
                  setState(() {});
                },
              ),
            ],
          ),
          const SizedBox(height: 17),
          FlowPressable(
            onPressed: () {
              widget.onFit();
              widget.onClose();
            },
            background: Palette.panel,
            foreground: Palette.ink,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const FlowGlyph(FlowGlyphType.route, size: 20),
                const SizedBox(width: 10),
                Text(strings.fit.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: .8)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          FlowPressable(
            onPressed: () {
              unawaited(widget.game.abandon());
              widget.onMenu();
            },
            background: Palette.ink,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const FlowGlyph(FlowGlyphType.menu, size: 20, color: Palette.paper),
                const SizedBox(width: 10),
                Text(strings.quitToMenu.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: .65)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
