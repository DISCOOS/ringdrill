import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/numbering.dart';

// Ports the ring illustration from docs/design/mockups/onboarding-concept-primer.html
// (SVG viewBox 0 0 240 212). ColorScheme mapping: accent→primary,
// accent-fill→primaryContainer, accent-text→onPrimaryContainer,
// team chip→secondary, chip text→onSecondary, dashed ring→outlineVariant.
class RingRotationFigure extends StatelessWidget {
  const RingRotationFigure({super.key, this.size = 240});

  /// Width in logical pixels; height follows the SVG aspect ratio (212/240).
  final double size;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return CustomPaint(
      size: Size(size, size * 212 / 240),
      painter: _RingRotationFigurePainter(
        colorScheme: cs,
        // Chip labels in arc order: Arc1 (2a→2c), Arc2 (2c→2b), Arc3 (2b→2a).
        chipLabels: [
          l10n.primerTeamLabel(1),
          l10n.primerTeamLabel(3),
          l10n.primerTeamLabel(2),
        ],
        postLabels: [
          Numbering.station(
            StationNumberFormat.alpha,
            exerciseNumber: 2,
            stationIndex: 0,
          ),
          Numbering.station(
            StationNumberFormat.alpha,
            exerciseNumber: 2,
            stationIndex: 1,
          ),
          Numbering.station(
            StationNumberFormat.alpha,
            exerciseNumber: 2,
            stationIndex: 2,
          ),
        ],
      ),
    );
  }
}

class _RingRotationFigurePainter extends CustomPainter {
  _RingRotationFigurePainter({
    required this.colorScheme,
    required this.chipLabels,
    required this.postLabels,
  });

  final ColorScheme colorScheme;
  // Chip labels in arc order: [Arc1, Arc2, Arc3] → [Lag 1, Lag 3, Lag 2].
  final List<String> chipLabels;
  // Post labels in SVG position order: [top/2a, bottom-left/2b, bottom-right/2c].
  final List<String> postLabels;

  static const double _svgW = 240;
  static const double _svgH = 212;
  static const double _cx = 120;
  static const double _cy = 108;
  static const double _r = 70;
  static const double _postR = 20;

  // Post centres (SVG coords): top/2a, bottom-left/2b, bottom-right/2c.
  static const List<Offset> _postCenters = [
    Offset(120.0, 38.0),
    Offset(59.0, 143.0),
    Offset(181.0, 143.0),
  ];

  // [startDeg, sweepDeg] clockwise; arrowhead drawn at arc end.
  // Arc1: near 2a → near 2c; Arc2: near 2c → near 2b; Arc3: near 2b → near 2a.
  static const List<List<double>> _arcs = [
    [-68.2, 76.5],
    [51.9, 76.2],
    [171.7, 76.5],
  ];

  @override
  bool shouldRepaint(covariant _RingRotationFigurePainter old) =>
      old.colorScheme != colorScheme ||
      !listEquals(old.chipLabels, chipLabels) ||
      !listEquals(old.postLabels, postLabels);

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width / _svgW, size.height / _svgH);
    final dx = (size.width - _svgW * s) / 2;
    final dy = (size.height - _svgH * s) / 2;
    canvas.save();
    canvas.translate(dx, dy);
    canvas.scale(s);

    _paintDashedRing(canvas);
    _paintArcs(canvas);
    _paintPosts(canvas);
    _paintChips(canvas);

    canvas.restore();
  }

  void _paintDashedRing(Canvas canvas) {
    final paint = Paint()
      ..color = colorScheme.outlineVariant
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final rect = Rect.fromCircle(center: const Offset(_cx, _cy), radius: _r);
    // Dash pattern: 4 on, 6 off — mirrors SVG stroke-dasharray="4 6".
    const dashRad = 4.0 / _r;
    const gapRad = 6.0 / _r;
    var angle = 0.0;
    while (angle < 2 * math.pi) {
      final end = math.min(angle + dashRad, 2 * math.pi);
      canvas.drawArc(rect, angle, end - angle, false, paint);
      angle += dashRad + gapRad;
    }
  }

  void _paintArcs(Canvas canvas) {
    final strokePaint = Paint()
      ..color = colorScheme.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    final fillPaint = Paint()
      ..color = colorScheme.primary
      ..style = PaintingStyle.fill;
    final rect = Rect.fromCircle(center: const Offset(_cx, _cy), radius: _r);

    for (final arc in _arcs) {
      final startRad = arc[0] * math.pi / 180;
      final sweepRad = arc[1] * math.pi / 180;
      canvas.drawArc(rect, startRad, sweepRad, false, strokePaint);

      // Arrowhead at arc endpoint, pointing in the clockwise tangent direction.
      final endAngle = startRad + sweepRad;
      final tipX = _cx + _r * math.cos(endAngle);
      final tipY = _cy + _r * math.sin(endAngle);
      // Clockwise tangent at angle θ in screen coords (y-down): (-sinθ, cosθ).
      final tx = -math.sin(endAngle);
      final ty = math.cos(endAngle);
      const arrowLen = 8.0;
      const halfBase = 4.0;
      canvas.drawPath(
        Path()
          ..moveTo(tipX, tipY)
          ..lineTo(
            tipX - arrowLen * tx - halfBase * ty,
            tipY - arrowLen * ty + halfBase * tx,
          )
          ..lineTo(
            tipX - arrowLen * tx + halfBase * ty,
            tipY - arrowLen * ty - halfBase * tx,
          )
          ..close(),
        fillPaint,
      );
    }
  }

  void _paintPosts(Canvas canvas) {
    final fillPaint = Paint()
      ..color = colorScheme.primaryContainer
      ..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color = colorScheme.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (int i = 0; i < _postCenters.length; i++) {
      final c = _postCenters[i];
      canvas.drawCircle(c, _postR, fillPaint);
      canvas.drawCircle(c, _postR, strokePaint);
      _paintCenteredText(
        canvas,
        postLabels[i],
        center: c,
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: colorScheme.onPrimaryContainer,
        maxWidth: _postR * 2,
      );
    }
  }

  void _paintChips(Canvas canvas) {
    final fillPaint = Paint()
      ..color = colorScheme.secondary
      ..style = PaintingStyle.fill;

    // Chips sit centred on the midpoint of each rotation arc, on the ring
    // itself (radius _r), so they cover the arrow they belong to and read as
    // "this team is on its way along this arrow". Drawn last, so they paint
    // over the arc stroke. Width follows the label so longer localized team
    // names do not overflow the pill.
    for (int i = 0; i < _arcs.length; i++) {
      final midRad = (_arcs[i][0] + _arcs[i][1] / 2) * math.pi / 180;
      final center = Offset(
        _cx + _r * math.cos(midRad),
        _cy + _r * math.sin(midRad),
      );
      final tp = TextPainter(
        text: TextSpan(
          text: chipLabels[i],
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: colorScheme.onSecondary,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final chipW = math.max(40.0, tp.width + 14);
      final rect = Rect.fromCenter(center: center, width: chipW, height: 18);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(9)),
        fillPaint,
      );
      tp.paint(
        canvas,
        Offset(center.dx - tp.width / 2, center.dy - tp.height / 2),
      );
    }
  }

  // All coordinates are in SVG units (the canvas is already scaled).
  // TextPainter measures text in logical pixels which map 1-to-1 to SVG units
  // in the scaled coordinate space, so tp.width/tp.height can be used directly
  // for centering without additional conversion.
  void _paintCenteredText(
    Canvas canvas,
    String text, {
    required Offset center,
    required double fontSize,
    required FontWeight fontWeight,
    required Color color,
    required double maxWidth,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(minWidth: 0, maxWidth: maxWidth);
    tp.paint(
      canvas,
      Offset(center.dx - tp.width / 2, center.dy - tp.height / 2),
    );
  }
}
