import 'dart:math' show min;

class ScoreBreakdown {
  final int placement;
  final int lines;
  final int streak;
  final int perfect;
  const ScoreBreakdown(
      {this.placement = 0, this.lines = 0, this.streak = 0, this.perfect = 0});

  int get total => placement + lines + streak + perfect;
}

/// Single source of truth for scoring. Scores are computed synchronously inside
/// the engine, never from animation callbacks, so they cannot be duplicated.
class Scoring {
  Scoring._();

  static const int perfectClearBonus = 150;

  /// [streak] is the number of consecutive line-clearing moves *including* this one
  /// (0 when this move cleared nothing).
  static ScoreBreakdown forMove({
    required int cells,
    required int lines,
    required int streak,
    required bool boardEmpty,
  }) {
    final lineScore = lines > 0 ? 10 * lines * lines : 0; // 10, 40, 90, 160...
    final streakScore = (lines > 0 && streak >= 2) ? min(100, 10 * (streak - 1)) : 0;
    final perfect = (lines > 0 && boardEmpty) ? perfectClearBonus : 0;
    return ScoreBreakdown(
        placement: cells, lines: lineScore, streak: streakScore, perfect: perfect);
  }
}
