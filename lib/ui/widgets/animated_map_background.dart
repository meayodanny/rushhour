import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/palette.dart';
import '../../models/city.dart';

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
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    return RepaintBoundary(
      child: CustomPaint(
        painter: MenuMapPainter(
          widget.city,
          clock: _clock,
          cameraZoom: widget.cameraZoom,
          cameraOffset: widget.cameraOffset,
          dim: widget.dim,
          palette: palette,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class MenuMapPainter extends CustomPainter {
  MenuMapPainter(
    this.city, {
    required Animation<double> clock,
    required this.cameraZoom,
    required this.cameraOffset,
    required this.dim,
    required this.palette,
  })  : _clock = clock,
        super(repaint: clock);

  final CityData city;
  final Animation<double> _clock;
  final double cameraZoom;
  final Offset cameraOffset;
  final double dim;
  final FlowlinePalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = palette.paper);
    if (city.nodes.isEmpty || city.edges.isEmpty) return;

    final bounds = city.contentBounds.inflate(90);
    final fit = math.max(size.width / bounds.width, size.height / bounds.height);
    final scale = fit * cameraZoom;
    canvas.save();
    canvas.translate(size.width / 2 + cameraOffset.dx, size.height / 2 + cameraOffset.dy);
    canvas.scale(scale);
    canvas.translate(-bounds.center.dx, -bounds.center.dy);

    for (final building in city.buildings) {
      if (building.footprint.length < 3) continue;
      final path = _path(building.footprint)..close();
      final color = switch (building.type) {
        BuildingType.residential => palette.buildingResidential,
        BuildingType.office => palette.buildingOffice,
        BuildingType.park => palette.buildingPark,
        BuildingType.other => palette.buildingOther,
      };
      canvas.drawPath(path, Paint()..color = color);
    }

    // Draw all river segments
    final riverPaint = Paint()
      ..color = palette.water
      ..style = PaintingStyle.stroke
      ..strokeWidth = 96
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    for (final seg in city.riverSegments) {
      if (seg.length > 1) {
        canvas.drawPath(_path(seg), riverPaint);
      }
    }

    for (final edge in city.edges) {
      final isMajor = edge.level == RoadLevel.major;
      final width = isMajor ? 12.0 : 7.0;
      if (edge.type == RoadType.bridge) {
        canvas.drawPath(
          _path(edge.points),
          Paint()
            ..color = palette.ink.withValues(alpha: palette.isDark ? .35 : .16)
            ..style = PaintingStyle.stroke
            ..strokeWidth = width + 8
            ..strokeCap = StrokeCap.round,
        );
      }
      canvas.drawPath(
        _path(edge.points),
        Paint()
          ..color = isMajor ? palette.majorRoad : palette.road
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    canvas.restore();

    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = palette.ink.withValues(alpha: dim),
    );
  }

  Path _path(List<Offset> points) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) path.lineTo(p.dx, p.dy);
    return path;
  }

  @override
  bool shouldRepaint(covariant MenuMapPainter oldDelegate) =>
      oldDelegate.city != city ||
      oldDelegate.cameraZoom != cameraZoom ||
      oldDelegate.cameraOffset != cameraOffset ||
      oldDelegate.dim != dim ||
      oldDelegate.palette != palette;
}
