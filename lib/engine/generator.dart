import 'dart:math';

import 'board.dart';
import 'shape.dart';

/// Produces trays of three shapes.
///
/// Fairness rule (applies equally to every player, always, with no hidden
/// difficulty adjustment): a set is only offered if all three pieces can be
/// placed one after another on the current board (clears between pieces are
/// simulated). If no such set is found in a bounded search, the generator falls
/// back to a set where at least one piece fits, and finally to the smallest
/// pieces that fit. The player can still lose by making poor placements.
class PieceGenerator {
  final Random rng;
  PieceGenerator([Random? rng]) : rng = rng ?? Random();

  Shape randomShape() {
    final families = ShapeLibrary.familyNames;
    var total = 0;
    for (final f in families) {
      total += ShapeLibrary.weightOf(f);
    }
    var roll = rng.nextInt(total);
    for (final f in families) {
      roll -= ShapeLibrary.weightOf(f);
      if (roll < 0) {
        final list = ShapeLibrary.byFamily[f]!;
        return list[rng.nextInt(list.length)];
      }
    }
    return ShapeLibrary.all.first;
  }

  List<Shape> nextSet(Board board, {int count = 3}) {
    List<Shape>? partial;
    for (var attempt = 0; attempt < 40; attempt++) {
      final set = List<Shape>.generate(count, (_) => randomShape());
      if (count >= 3 && set.every((s) => s.id == set.first.id)) continue;
      if (canPlaceAll(board, set)) return set;
      partial ??= set.any(board.canPlaceAnywhere) ? set : null;
    }
    if (partial != null) return partial;

    final fitting = ShapeLibrary.all.where(board.canPlaceAnywhere).toList()
      ..sort((a, b) => a.size - b.size);
    if (fitting.isEmpty) {
      // Board is truly stuck; any set results in game over.
      return List<Shape>.generate(count, (_) => randomShape());
    }
    final pool = fitting.take(min(fitting.length, 4)).toList();
    return List<Shape>.generate(count, (_) => pool[rng.nextInt(pool.length)]);
  }

  /// True if all [shapes] can be placed in some order on [board].
  /// Bounded depth-first search; running out of budget counts as "no".
  static bool canPlaceAll(Board board, List<Shape> shapes, {int budget = 4000}) {
    final counter = [budget];
    return _solve(board, shapes, counter);
  }

  static bool _solve(Board board, List<Shape> remaining, List<int> budget) {
    if (remaining.isEmpty) return true;
    for (var i = 0; i < remaining.length; i++) {
      final shape = remaining[i];
      final rest = [...remaining]..removeAt(i);
      for (final p in board.placements(shape)) {
        if (budget[0]-- <= 0) return false;
        final next = board.clone()..place(shape, p.r, p.c);
        if (_solve(next, rest, budget)) return true;
      }
    }
    return false;
  }
}
