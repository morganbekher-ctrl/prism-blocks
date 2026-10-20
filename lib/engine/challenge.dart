import 'dart:math';

import 'board.dart';
import 'game_state.dart';

enum ChallengeType { score, lines, combo, streak }

/// A locally generated objective. Everything derives from the device's local
/// calendar date, so no network access is ever needed.
class Challenge {
  final String id; // "yyyy-MM-dd-i"
  final ChallengeType type;
  final int target;
  final int seed;
  final int prefill;

  const Challenge(
      {required this.id,
      required this.type,
      required this.target,
      required this.seed,
      required this.prefill});

  static String dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Three challenges per local day, increasing in difficulty.
  static List<Challenge> forDate(DateTime date) =>
      List.generate(3, (i) => _make(date, i));

  static Challenge? fromId(String id) {
    final parts = id.split('-');
    if (parts.length != 4) return null;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    final i = int.tryParse(parts[3]);
    if (y == null || m == null || d == null || i == null || i < 0 || i > 2) return null;
    return _make(DateTime(y, m, d), i);
  }

  static Challenge _make(DateTime date, int i) {
    final base = date.year * 10000 + date.month * 100 + date.day;
    final seed = base * 10 + i;
    final r = Random(seed);
    final type = ChallengeType.values[(i + base) % ChallengeType.values.length];
    final int target;
    switch (type) {
      case ChallengeType.score:
        target = 300 + r.nextInt(4) * 100 + i * 300;
        break;
      case ChallengeType.lines:
        target = 6 + r.nextInt(5) + i * 3;
        break;
      case ChallengeType.combo:
        target = i == 2 ? 3 : 2;
        break;
      case ChallengeType.streak:
        target = 3 + i * 2;
        break;
    }
    return Challenge(
      id: '${dateKey(date)}-$i',
      type: type,
      target: target,
      seed: seed,
      prefill: 6 + r.nextInt(10),
    );
  }

  String get title {
    switch (type) {
      case ChallengeType.score:
        return 'Reach $target points';
      case ChallengeType.lines:
        return 'Clear $target lines';
      case ChallengeType.combo:
        return 'Clear $target lines in one move';
      case ChallengeType.streak:
        return 'Clear lines $target moves in a row';
    }
  }

  int progress(GameState g) {
    switch (type) {
      case ChallengeType.score:
        return g.score;
      case ChallengeType.lines:
        return g.linesCleared;
      case ChallengeType.combo:
        return g.bestCombo;
      case ChallengeType.streak:
        return g.bestStreak;
    }
  }

  bool isMet(GameState g) => progress(g) >= target;

  /// Deterministic starting board (never contains a completed line).
  Board buildBoard() {
    final r = Random(seed);
    final b = Board();
    var n = prefill;
    while (n > 0) {
      final idx = r.nextInt(b.size * b.size);
      if (b.cells[idx] == -1) {
        b.cells[idx] = r.nextInt(7);
        n--;
      }
    }
    while (true) {
      final rows = b.fullRows();
      final cols = b.fullCols();
      if (rows.isEmpty && cols.isEmpty) break;
      if (rows.isNotEmpty) {
        b.setAt(rows.first, r.nextInt(b.size), -1);
      } else {
        b.setAt(r.nextInt(b.size), cols.first, -1);
      }
    }
    return b;
  }
}
