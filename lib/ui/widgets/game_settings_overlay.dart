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
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    return IgnorePointer(
      ignoring: !widget.visible,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (BuildContext context, Widget? child) {
          final t = Curves.easeOutCubic.transform(_animation.value);
          return Opacity(
            opacity: t,
            child: ColoredBox(
              color: palette.veil.withValues(alpha: .68 * t),
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
                        child: _panel(context, palette),
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
  }

  Widget _panel(BuildContext context, FlowlinePalette palette) {
    final strings = AppStrings.of(context);
    final sound = widget.game.persistence.audioEnabled;

    return Container(
      width: 330,
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(color: palette.paper, borderRadius: BorderRadius.circular(28)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  strings.settings.toUpperCase(),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: palette.ink,
                  ),
                ),
              ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onClose,
                child: Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: palette.panel, shape: BoxShape.circle),
                  child: FlowGlyph(FlowGlyphType.back, size: 18, color: palette.ink),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: <Widget>[
              FlowGlyph(sound ? FlowGlyphType.sound : FlowGlyphType.muted, size: 22, color: palette.ink),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(strings.sound, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: palette.ink)),
                    const SizedBox(height: 2),
                    Text(strings.soundCaption, style: TextStyle(fontSize: 11, color: palette.muted)),
                  ],
                ),
              ),
              FlowToggle(
                value: sound,
                semanticLabel: strings.sound,
                onChanged: (bool value) {
                  setState(() {});
                  widget.game.audio.enabled = value;
                  unawaited(widget.game.persistence.setAudioEnabled(value));
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          FlowPressable(
            onPressed: () {
              widget.onClose();
              widget.onFit();
            },
            background: palette.panel,
            foreground: palette.ink,
            height: 48,
            radius: 16,
            child: Text(strings.fit.toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1)),
          ),
          const SizedBox(height: 10),
          FlowPressable(
            onPressed: widget.onMenu,
            background: palette.danger,
            foreground: palette.paper,
            height: 48,
            radius: 16,
            child: Text(strings.quitToMenu.toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1)),
          ),
        ],
      ),
    );
  }
}
