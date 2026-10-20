import 'dart:math' as math;

import 'package:flutter/material.dart';

extension ColorAlpha on Color {
  /// Opacity helper that works across Flutter versions.
  Color op(double opacity) => withAlpha((opacity.clamp(0.0, 1.0) * 255).round());
}

class Palette {
  Palette._();

  static const List<Color> blocks = [
    Color(0xFF8A3FFC), // electric purple
    Color(0xFFFF5E7E), // coral pink
    Color(0xFF12C9BE), // turquoise
    Color(0xFF4DA9FF), // sky blue
    Color(0xFFFFC52E), // sunshine yellow
    Color(0xFF3FDD98), // mint green
    Color(0xFFFF8A3D), // orange
  ];

  static Color block(int i) => blocks[i % blocks.length];
}

class GameColors {
  final Color bgTop, bgBottom, board, cellEmpty, text, textDim, card, scrim;
  const GameColors({
    required this.bgTop,
    required this.bgBottom,
    required this.board,
    required this.cellEmpty,
    required this.text,
    required this.textDim,
    required this.card,
    required this.scrim,
  });

  static const dark = GameColors(
    bgTop: Color(0xFF1D1140),
    bgBottom: Color(0xFF0D1C3F),
    board: Color(0xFF2A1F55),
    cellEmpty: Color(0xFF382B6E),
    text: Colors.white,
    textDim: Color(0xFFB9B1DD),
    card: Color(0xFF2B2162),
    scrim: Color(0xB3080414),
  );

  static const light = GameColors(
    bgTop: Color(0xFFF5EFFF),
    bgBottom: Color(0xFFDDF2FF),
    board: Color(0xFFE2D9FB),
    cellEmpty: Color(0xFFF3EFFF),
    text: Color(0xFF2A1B54),
    textDim: Color(0xFF6E639A),
    card: Colors.white,
    scrim: Color(0x992A1B54),
  );

  static GameColors of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}

class AppTheme {
  AppTheme._();

  static ThemeData build(Brightness b) {
    final scheme = ColorScheme.fromSeed(
      seedColor: Palette.blocks[0],
      brightness: b,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: b,
      scaffoldBackgroundColor: Colors.transparent,
      fontFamily: null,
    );
  }
}

/// Draws one glossy, rounded block. With [patterns] on, each colour also gets a
/// distinct symbol so the game never relies on colour alone.
void drawBlock(
  Canvas canvas,
  Rect rect,
  int colorIdx, {
  bool patterns = false,
  double alpha = 1.0,
  double glow = 0.0,
  double whiten = 0.0,
}) {
  var base = Palette.block(colorIdx);
  if (whiten > 0) base = Color.lerp(base, Colors.white, whiten)!;
  final rr = RRect.fromRectAndRadius(rect, Radius.circular(rect.width * 0.26));

  if (alpha < 1.0) {
    canvas.saveLayer(rect.inflate(rect.width * 0.5),
        Paint()..color = Color.fromRGBO(0, 0, 0, alpha.clamp(0.0, 1.0)));
  }
  if (glow > 0) {
    canvas.drawRRect(
      rr.inflate(rect.width * 0.1 * glow),
      Paint()
        ..color = base.op(0.55 * glow)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, rect.width * 0.28),
    );
  }
  // soft drop shadow
  canvas.drawRRect(
    rr.shift(Offset(0, rect.height * 0.06)),
    Paint()..color = Colors.black.op(0.18),
  );
  final light = Color.lerp(base, Colors.white, 0.38)!;
  final dark = Color.lerp(base, Colors.black, 0.28)!;
  canvas.drawRRect(
    rr,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [light, base, dark],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(rect),
  );
  // gloss
  final gloss = RRect.fromRectAndRadius(
    Rect.fromLTWH(rect.left + rect.width * 0.14, rect.top + rect.height * 0.09,
        rect.width * 0.72, rect.height * 0.3),
    Radius.circular(rect.width * 0.18),
  );
  canvas.drawRRect(gloss, Paint()..color = Colors.white.op(0.28));
  // rim
  canvas.drawRRect(
    rr,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.0, rect.width * 0.035)
      ..color = Colors.white.op(0.22),
  );
  if (patterns) _drawPattern(canvas, rect, colorIdx % Palette.blocks.length);
  if (alpha < 1.0) canvas.restore();
}

void _drawPattern(Canvas canvas, Rect rect, int idx) {
  final c = rect.center.translate(0, rect.height * 0.04);
  final r = rect.width * 0.17;
  final stroke = Paint()
    ..color = Colors.white.op(0.8)
    ..style = PaintingStyle.stroke
    ..strokeWidth = math.max(1.5, rect.width * 0.07)
    ..strokeCap = StrokeCap.round;
  final fill = Paint()..color = Colors.white.op(0.8);
  switch (idx) {
    case 0: // dot
      canvas.drawCircle(c, r * 0.8, fill);
      break;
    case 1: // stripes
      canvas.drawLine(c.translate(-r, -r * 0.6), c.translate(r, -r * 0.6), stroke);
      canvas.drawLine(c.translate(-r, r * 0.6), c.translate(r, r * 0.6), stroke);
      break;
    case 2: // cross
      canvas.drawLine(c.translate(-r, -r), c.translate(r, r), stroke);
      canvas.drawLine(c.translate(-r, r), c.translate(r, -r), stroke);
      break;
    case 3: // ring
      canvas.drawCircle(c, r, stroke);
      break;
    case 4: // diamond
      final p = Path()
        ..moveTo(c.dx, c.dy - r * 1.2)
        ..lineTo(c.dx + r * 1.2, c.dy)
        ..lineTo(c.dx, c.dy + r * 1.2)
        ..lineTo(c.dx - r * 1.2, c.dy)
        ..close();
      canvas.drawPath(p, fill);
      break;
    case 5: // triangle
      final p = Path()
        ..moveTo(c.dx, c.dy - r)
        ..lineTo(c.dx + r * 1.1, c.dy + r * 0.8)
        ..lineTo(c.dx - r * 1.1, c.dy + r * 0.8)
        ..close();
      canvas.drawPath(p, fill);
      break;
    default: // plus
      canvas.drawLine(c.translate(-r, 0), c.translate(r, 0), stroke);
      canvas.drawLine(c.translate(0, -r), c.translate(0, r), stroke);
  }
}
