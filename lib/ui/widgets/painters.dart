import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../engine/board.dart';
import '../../engine/shape.dart';
import '../theme.dart';

const double kBoardPad = 6.0;

class BoardPainter extends CustomPainter {
  final Board board;
  final GameColors colors;
  final bool patterns;
  final Map<int, int> ghost; // idx -> colour (drag preview)
  final bool ghostValid;
  final Set<int> previewClear; // cells that would clear if dropped now
  final Map<int, int> clearing; // idx -> colour (cells animating out)
  final Animation<double> clearT;
  final Set<int> placed;
  final Animation<double> placeT;
  final Animation<double> pulse;
  final Set<int> hintCells;
  final Color? dangerGlow;

  BoardPainter({
    required this.board,
    required this.colors,
    required this.patterns,
    required this.ghost,
    required this.ghostValid,
    required this.previewClear,
    required this.clearing,
    required this.clearT,
    required this.placed,
    required this.placeT,
    required this.pulse,
    required this.hintCells,
    this.dangerGlow,
  }) : super(repaint: Listenable.merge([clearT, placeT, pulse]));

  @override
  void paint(Canvas canvas, Size size) {
    final n = board.size;
    final cs = (size.width - kBoardPad * 2) / n;
    final bg = RRect.fromRectAndRadius(
        Offset.zero & size, Radius.circular(cs * 0.55));
    canvas.drawRRect(bg, Paint()..color = colors.board);
    if (dangerGlow != null) {
      canvas.drawRRect(
          bg,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = dangerGlow!.op(0.35 + 0.4 * pulse.value));
    }

    Rect cellRect(int r, int c, {double inset = 2.0}) => Rect.fromLTWH(
        kBoardPad + c * cs + inset, kBoardPad + r * cs + inset, cs - inset * 2, cs - inset * 2);

    for (var r = 0; r < n; r++) {
      for (var c = 0; c < n; c++) {
        final idx = r * n + c;
        final rect = cellRect(r, c);
        final v = board.cells[idx];
        if (v == -1) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(rect, Radius.circular(cs * 0.2)),
            Paint()..color = colors.cellEmpty,
          );
        } else {
          var drawRect = rect;
          if (placed.contains(idx) && placeT.value < 1.0) {
            final s = 1.0 + 0.22 * math.sin(placeT.value * math.pi);
            drawRect = Rect.fromCenter(
                center: rect.center, width: rect.width * s, height: rect.height * s);
          }
          drawBlock(canvas, drawRect, v, patterns: patterns);
        }
      }
    }

    // Lines that would complete if dropped now (near-complete excitement).
    if (previewClear.isNotEmpty) {
      final a = 0.25 + 0.25 * pulse.value;
      for (final idx in previewClear) {
        final rect = cellRect(idx ~/ n, idx % n, inset: 1.0);
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(cs * 0.24)),
          Paint()..color = Colors.white.op(a),
        );
      }
    }

    // Drag ghost.
    ghost.forEach((idx, color) {
      final rect = cellRect(idx ~/ n, idx % n);
      if (ghostValid) {
        drawBlock(canvas, rect, color, patterns: patterns, alpha: 0.6);
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(cs * 0.2)),
          Paint()..color = const Color(0xFFFF3B5C).op(0.4),
        );
      }
    });

    // Clearing animation: shrink + whiten + glow.
    if (clearing.isNotEmpty && clearT.value < 1.0) {
      final t = Curves.easeIn.transform(clearT.value);
      clearing.forEach((idx, color) {
        final rect = cellRect(idx ~/ n, idx % n);
        final s = 1.0 - 0.85 * t;
        final r = Rect.fromCenter(
            center: rect.center, width: rect.width * s, height: rect.height * s);
        drawBlock(canvas, r, color,
            patterns: patterns, glow: 1.0 - t, whiten: 0.6 * math.sin(t * math.pi),
            alpha: 1.0 - 0.6 * t);
      });
    }

    // Hint outline.
    if (hintCells.isNotEmpty) {
      final a = 0.45 + 0.5 * pulse.value;
      for (final idx in hintCells) {
        final rect = cellRect(idx ~/ n, idx % n, inset: 1.5);
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(cs * 0.22)),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = Colors.white.op(a),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant BoardPainter old) => true;
}

/// Paints a shape at a fixed cell size (used for tray pieces and the dragged piece).
class ShapePainter extends CustomPainter {
  final Shape shape;
  final double cs;
  final bool patterns;
  final double alpha;
  ShapePainter(this.shape, this.cs, {this.patterns = false, this.alpha = 1.0});

  @override
  void paint(Canvas canvas, Size size) {
    for (final c in shape.cells) {
      final rect = Rect.fromLTWH(c.c * cs + 1.5, c.r * cs + 1.5, cs - 3, cs - 3);
      drawBlock(canvas, rect, shape.color, patterns: patterns, alpha: alpha);
    }
  }

  @override
  bool shouldRepaint(covariant ShapePainter old) =>
      old.shape != shape || old.cs != cs || old.alpha != alpha || old.patterns != patterns;
}

class Particle {
  Offset p;
  Offset v;
  final Color color;
  double life;
  final double maxLife;
  final double size;
  Particle(this.p, this.v, this.color, this.life, this.size) : maxLife = life;
}

class ParticlePainter extends CustomPainter {
  final List<Particle> particles;
  ParticlePainter(this.particles, Listenable repaint) : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final t = (p.life / p.maxLife).clamp(0.0, 1.0);
      canvas.drawCircle(p.p, p.size * (0.4 + 0.6 * t), Paint()..color = p.color.op(t));
    }
  }

  @override
  bool shouldRepaint(covariant ParticlePainter old) => true;
}
