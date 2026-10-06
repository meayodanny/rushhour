import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/palette.dart';

/// Reusable press surface with no Material ink, elevation, or default styling.
class FlowPressable extends StatefulWidget {
  const FlowPressable({
    required this.child,
    required this.onPressed,
    this.background,
    this.foreground,
    this.borderColor,
    this.height = 58,
    this.radius = 18,
    this.padding = const EdgeInsets.symmetric(horizontal: 22),
    this.semanticLabel,
    super.key,
  });

  final Widget child;
  final VoidCallback? onPressed;
  final Color? background;
  final Color? foreground;
  final Color? borderColor;
  final double? height;
  final double radius;
  final EdgeInsets padding;
  final String? semanticLabel;

  @override
  State<FlowPressable> createState() => _FlowPressableState();
}

class _FlowPressableState extends State<FlowPressable> with SingleTickerProviderStateMixin {
  late final AnimationController _press = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 90),
    reverseDuration: const Duration(milliseconds: 180),
  );

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  void _down(PointerDownEvent _) {
    if (widget.onPressed != null) _press.forward();
  }

  void _up(PointerEvent _) => _press.reverse();

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    final bg = widget.background ?? palette.ink;
    final fg = widget.foreground ?? palette.paper;
    final enabled = widget.onPressed != null;

    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onPressed,
        child: Listener(
          onPointerDown: _down,
          onPointerUp: _up,
          onPointerCancel: _up,
          child: AnimatedBuilder(
            animation: _press,
            child: Container(
              height: widget.height,
              padding: widget.padding,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: enabled ? bg : palette.road,
                borderRadius: BorderRadius.circular(widget.radius),
                border: Border.all(color: widget.borderColor ?? Colors.transparent, width: 1.5),
              ),
              child: DefaultTextStyle.merge(
                style: TextStyle(color: enabled ? fg : palette.muted),
                child: IconTheme(data: IconThemeData(color: enabled ? fg : palette.muted), child: widget.child),
              ),
            ),
            builder: (BuildContext context, Widget? child) {
              final t = Curves.easeOutCubic.transform(_press.value);
              return Transform.scale(scale: 1 - .045 * t, child: child);
            },
          ),
        ),
      ),
    );
  }
}

class FlowToggle extends StatefulWidget {
  const FlowToggle({required this.value, required this.onChanged, this.semanticLabel, super.key});
  final bool value;
  final ValueChanged<bool> onChanged;
  final String? semanticLabel;

  @override
  State<FlowToggle> createState() => _FlowToggleState();
}

class _FlowToggleState extends State<FlowToggle> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
    value: widget.value ? 1 : 0,
  );

  @override
  void didUpdateWidget(covariant FlowToggle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      widget.value ? _controller.forward() : _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    return Semantics(
      toggled: widget.value,
      button: true,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => widget.onChanged(!widget.value),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (BuildContext context, Widget? child) {
            final t = Curves.easeInOutCubic.transform(_controller.value);
            return CustomPaint(
              size: const Size(58, 34),
              painter: _TogglePainter(t, palette),
            );
          },
        ),
      ),
    );
  }
}

class _TogglePainter extends CustomPainter {
  const _TogglePainter(this.value, this.palette);
  final double value;
  final FlowlinePalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final track = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(size.height / 2));
    canvas.drawRRect(track, Paint()..color = Color.lerp(palette.road, palette.blue, value)!);
    final x = size.height / 2 + (size.width - size.height) * value;
    canvas.drawCircle(Offset(x, size.height / 2), 12, Paint()..color = palette.paper);
  }

  @override
  bool shouldRepaint(covariant _TogglePainter oldDelegate) =>
      oldDelegate.value != value || oldDelegate.palette != palette;
}

/// Requirement 38: Custom Theme Toggle (Sun / Moon)
class FlowThemeToggle extends StatefulWidget {
  const FlowThemeToggle({
    required this.isDark,
    required this.onChanged,
    super.key,
  });

  final bool isDark;
  final ValueChanged<bool> onChanged;

  @override
  State<FlowThemeToggle> createState() => _FlowThemeToggleState();
}

class _FlowThemeToggleState extends State<FlowThemeToggle> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
    value: widget.isDark ? 1 : 0,
  );

  @override
  void didUpdateWidget(covariant FlowThemeToggle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isDark != widget.isDark) {
      widget.isDark ? _controller.forward() : _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    return Semantics(
      toggled: widget.isDark,
      button: true,
      label: 'Theme toggle',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => widget.onChanged(!widget.isDark),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (BuildContext context, Widget? child) {
            final t = Curves.easeInOutCubic.transform(_controller.value);
            return Container(
              width: 68,
              height: 38,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Color.lerp(palette.road, palette.panel, t)!,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: palette.ink.withValues(alpha: 0.15),
                  width: 1.5,
                ),
              ),
              child: Stack(
                children: <Widget>[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: FlowGlyph(FlowGlyphType.sun, size: 16, color: palette.warning),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: FlowGlyph(FlowGlyphType.moon, size: 15, color: palette.blue),
                    ),
                  ),
                  Align(
                    alignment: Alignment(-1.0 + 2.0 * t, 0.0),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: palette.paper,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.18),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          )
                        ],
                      ),
                      alignment: Alignment.center,
                      child: FlowGlyph(
                        t < 0.5 ? FlowGlyphType.sun : FlowGlyphType.moon,
                        size: 16,
                        color: t < 0.5 ? palette.warning : palette.blue,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

enum FlowGlyphType {
  pause,
  play,
  fast,
  sliders,
  sound,
  muted,
  back,
  route,
  walk,
  bike,
  car,
  ferry,
  house,
  hub,
  replay,
  menu,
  sun,
  moon,
}

class FlowGlyph extends StatelessWidget {
  const FlowGlyph(this.type, {this.size = 24, this.color, this.strokeWidth = 2.4, super.key});
  final FlowGlyphType type;
  final double size;
  final Color? color;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? Palette.of(context).ink;
    return CustomPaint(
      size: Size.square(size),
      painter: FlowGlyphPainter(type, color: effectiveColor, strokeWidth: strokeWidth),
    );
  }
}

class FlowGlyphPainter extends CustomPainter {
  const FlowGlyphPainter(this.type, {required this.color, required this.strokeWidth});
  final FlowGlyphType type;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final c = Offset(size.width / 2, size.height / 2);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()..color = color;

    switch (type) {
      case FlowGlyphType.pause:
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(s * .28, s * .22, s * .14, s * .56), Radius.circular(s * .05)), fill);
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(s * .58, s * .22, s * .14, s * .56), Radius.circular(s * .05)), fill);
      case FlowGlyphType.play:
        canvas.drawPath(Path()..moveTo(s * .34, s * .2)..lineTo(s * .78, s * .5)..lineTo(s * .34, s * .8)..close(), fill);
      case FlowGlyphType.fast:
        canvas.drawPath(Path()..moveTo(s * .16, s * .24)..lineTo(s * .5, s * .5)..lineTo(s * .16, s * .76)..close(), fill);
        canvas.drawPath(Path()..moveTo(s * .48, s * .24)..lineTo(s * .82, s * .5)..lineTo(s * .48, s * .76)..close(), fill);
      case FlowGlyphType.sliders:
        for (var i = 0; i < 3; i++) {
          final y = s * (.25 + i * .25);
          canvas.drawLine(Offset(s * .18, y), Offset(s * .82, y), stroke);
          final x = s * (<double>[.37, .68, .47][i]);
          canvas.drawCircle(Offset(x, y), s * .07, fill);
        }
      case FlowGlyphType.sound:
      case FlowGlyphType.muted:
        canvas.drawPath(Path()..moveTo(s * .18, s * .42)..lineTo(s * .36, s * .42)..lineTo(s * .55, s * .25)..lineTo(s * .55, s * .75)..lineTo(s * .36, s * .58)..lineTo(s * .18, s * .58)..close(), fill);
        if (type == FlowGlyphType.sound) {
          canvas.drawArc(Rect.fromCircle(center: Offset(s * .52, s * .5), radius: s * .2), -math.pi / 3, math.pi * 2 / 3, false, stroke);
          canvas.drawArc(Rect.fromCircle(center: Offset(s * .52, s * .5), radius: s * .34), -math.pi / 3, math.pi * 2 / 3, false, stroke);
        } else {
          canvas.drawLine(Offset(s * .67, s * .34), Offset(s * .86, s * .66), stroke);
          canvas.drawLine(Offset(s * .86, s * .34), Offset(s * .67, s * .66), stroke);
        }
      case FlowGlyphType.back:
        canvas.drawPath(Path()..moveTo(s * .62, s * .18)..lineTo(s * .3, s * .5)..lineTo(s * .62, s * .82), stroke);
      case FlowGlyphType.route:
        canvas.drawCircle(Offset(s * .22, s * .7), s * .1, stroke);
        canvas.drawCircle(Offset(s * .78, s * .3), s * .1, stroke);
        canvas.drawPath(Path()..moveTo(s * .31, s * .66)..cubicTo(s * .46, s * .58, s * .48, s * .38, s * .69, s * .34), stroke);
      case FlowGlyphType.walk:
        canvas.drawCircle(Offset(s * .52, s * .18), s * .09, fill);
        canvas.drawLine(Offset(s * .5, s * .31), Offset(s * .43, s * .57), stroke);
        canvas.drawLine(Offset(s * .45, s * .4), Offset(s * .27, s * .55), stroke);
        canvas.drawLine(Offset(s * .46, s * .42), Offset(s * .67, s * .5), stroke);
        canvas.drawLine(Offset(s * .43, s * .57), Offset(s * .27, s * .83), stroke);
        canvas.drawLine(Offset(s * .43, s * .57), Offset(s * .65, s * .82), stroke);
      case FlowGlyphType.bike:
        canvas.drawCircle(Offset(s * .25, s * .7), s * .17, stroke);
        canvas.drawCircle(Offset(s * .75, s * .7), s * .17, stroke);
        canvas.drawPath(Path()..moveTo(s * .25, s * .7)..lineTo(s * .43, s * .42)..lineTo(s * .58, s * .7)..close()..moveTo(s * .43, s * .42)..lineTo(s * .69, s * .4)..lineTo(s * .75, s * .7), stroke);
      case FlowGlyphType.car:
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(s * .14, s * .37, s * .72, s * .34), Radius.circular(s * .1)), stroke);
        canvas.drawPath(Path()..moveTo(s * .28, s * .37)..lineTo(s * .39, s * .22)..lineTo(s * .65, s * .22)..lineTo(s * .76, s * .37), stroke);
        canvas.drawCircle(Offset(s * .3, s * .73), s * .07, fill);
        canvas.drawCircle(Offset(s * .7, s * .73), s * .07, fill);
      case FlowGlyphType.ferry:
        canvas.drawPath(Path()..moveTo(s * .16, s * .52)..lineTo(s * .84, s * .52)..lineTo(s * .72, s * .74)..lineTo(s * .28, s * .74)..close(), stroke);
        canvas.drawRect(Rect.fromLTWH(s * .35, s * .28, s * .3, s * .24), stroke);
        canvas.drawPath(Path()..moveTo(s * .18, s * .84)..quadraticBezierTo(s * .32, s * .75, s * .46, s * .84)..quadraticBezierTo(s * .62, s * .93, s * .82, s * .82), stroke);
      case FlowGlyphType.house:
        canvas.drawPath(Path()..moveTo(s * .16, s * .48)..lineTo(s * .5, s * .18)..lineTo(s * .84, s * .48)..moveTo(s * .25, s * .43)..lineTo(s * .25, s * .82)..lineTo(s * .75, s * .82)..lineTo(s * .75, s * .43), stroke);
      case FlowGlyphType.hub:
        canvas.drawCircle(c, s * .1, fill);
        for (var i = 0; i < 3; i++) {
          final a = -math.pi / 2 + i * math.pi * 2 / 3;
          final p = c + Offset(math.cos(a), math.sin(a)) * s * .31;
          canvas.drawLine(c, p, stroke);
          canvas.drawCircle(p, s * .09, fill);
        }
      case FlowGlyphType.replay:
        canvas.drawArc(Rect.fromCircle(center: c, radius: s * .28), -.2, math.pi * 1.65, false, stroke);
        canvas.drawPath(Path()..moveTo(s * .23, s * .22)..lineTo(s * .23, s * .47)..lineTo(s * .44, s * .34)..close(), fill);
      case FlowGlyphType.menu:
        canvas.drawLine(Offset(s * .2, s * .3), Offset(s * .8, s * .3), stroke);
        canvas.drawLine(Offset(s * .2, s * .5), Offset(s * .8, s * .5), stroke);
        canvas.drawLine(Offset(s * .2, s * .7), Offset(s * .8, s * .7), stroke);
      case FlowGlyphType.sun:
        canvas.drawCircle(c, s * .22, stroke);
        for (var i = 0; i < 8; i++) {
          final a = i * math.pi / 4;
          final p1 = c + Offset(math.cos(a), math.sin(a)) * (s * .32);
          final p2 = c + Offset(math.cos(a), math.sin(a)) * (s * .46);
          canvas.drawLine(p1, p2, stroke);
        }
      case FlowGlyphType.moon:
        final path = Path()
          ..moveTo(s * .65, s * .18)
          ..cubicTo(s * .35, s * .25, s * .32, s * .75, s * .65, s * .82)
          ..cubicTo(s * .48, s * .72, s * .48, s * .28, s * .65, s * .18)
          ..close();
        canvas.drawPath(path, fill);
    }
  }

  @override
  bool shouldRepaint(covariant FlowGlyphPainter oldDelegate) =>
      oldDelegate.type != type || oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
}
