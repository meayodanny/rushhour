import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/palette.dart';
import '../../models/city.dart';

/// Decorative menu map. It uses the real city geometry, while courier motion
/// is intentionally independent of game state. The absolute clock keeps two
/// route surfaces in phase during a camera transition.
class AnimatedMapBackground extends StatefulWidget {
  const AnimatedMapBackground({
    required this.city,
    this.cameraZoom = 1,
    this.cameraOffset = Offset.zero,
    this.dim = .30,
    super.key,
  });

  final CityData city;
  final double cameraZoom;
  final Offset cameraOffset;
  final double dim;

  @override
  State<AnimatedMapBackground> createState() => _AnimatedMapBackgroundState();
}

class _AnimatedMapBackgroundState extends State<AnimatedMapBackground> with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 12),
  )..repeat();

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
        child: CustomPaint(
          painter: MenuMapPainter(
            widget.city,
            clock: _clock,
            cameraZoom: widget.cameraZoom,
            cameraOffset: widget.cameraOffset,
            dim: widget.dim,
          ),
          child: const SizedBox.expand(),
        ),
      );
}

class MenuMapPainter extends CustomPainter {
  MenuMapPainter(
    this.city, {
    required Animation<double> clock,
    required this.cameraZoom,
    required this.cameraOffset,
    required this.dim,
  })  : _clock = clock,
        super(repaint: clock);

  final CityData city;
  final Animation<double> _clock;
  final double cameraZoom;
  final Offset cameraOffset;
  final double dim;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Palette.paper);
    if (city.nodes.isEmpty || city.edges.isEmpty) return;

    final bounds = city.contentBounds.inflate(90);
    final fit = math.max(size.width / bounds.width, size.height / bounds.height);
    final scale = fit * cameraZoom;
    canvas.save();
    canvas.translate(size.width / 2 + cameraOffset.dx, size.height / 2 + cameraOffset.dy);
    canvas.scale(scale);
    canvas.translate(-bounds.center.dx, -bounds.center.dy);

    if (city.river.length > 1) {
      final river = _path(city.river);
      canvas.drawPath(
        river,
        Paint()
          ..color = Palette.water
          ..style = PaintingStyle.stroke
          ..strokeWidth = 105
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
    for (final edge in city.edges) {
      final major = edge.level == RoadLevel.major;
      canvas.drawPath(
        _path(edge.points),
        Paint()
          ..color = major ? Palette.majorRoad : Palette.road
          ..style = PaintingStyle.stroke
          ..strokeWidth = major ? 11 : 6
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    final absolutePhase = (DateTime.now().millisecondsSinceEpoch % 12000) / 12000;
    final edgeCount = city.edges.length;
    for (var i = 0; i < math.min(7, edgeCount); i++) {
      final edge = city.edges[(i * 13 + 4) % edgeCount];
      final loop = (absolutePhase * (1 + i * .08) + i * .17) % 1;
      final pingPong = loop < .5 ? loop * 2 : (1 - loop) * 2;
      final p = _pointOn(edge.points, pingPong);
      final radius = <double>[7, 9, 6][i % 3];
      canvas.drawCircle(p, radius + 3, Paint()..color = Palette.paper);
      canvas.drawCircle(p, radius, Paint()..color = <Color>[Palette.coral, Palette.blue, Palette.warning][i % 3]);
    }
    canvas.restore();

    canvas.drawRect(Offset.zero & size, Paint()..color = Palette.ink.withValues(alpha: dim));
  }

  Path _path(List<Offset> points) {
    final path = Path();
    if (points.isEmpty) return path;
    path.moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    return path;
  }

  Offset _pointOn(List<Offset> points, double progress) {
    if (points.isEmpty) return Offset.zero;
    if (points.length == 1) return points.first;
    var length = 0.0;
    for (var i = 1; i < points.length; i++) {
      length += (points[i] - points[i - 1]).distance;
    }
    var target = progress * length;
    for (var i = 1; i < points.length; i++) {
      final segment = (points[i] - points[i - 1]).distance;
      if (target <= segment) return Offset.lerp(points[i - 1], points[i], target / math.max(1, segment))!;
      target -= segment;
    }
    return points.last;
  }

  @override
  bool shouldRepaint(covariant MenuMapPainter oldDelegate) =>
      oldDelegate.city != city ||
      oldDelegate.cameraZoom != cameraZoom ||
      oldDelegate.cameraOffset != cameraOffset ||
      oldDelegate.dim != dim ||
      oldDelegate._clock != _clock;
}
