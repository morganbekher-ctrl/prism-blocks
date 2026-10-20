import 'dart:math';

import 'board.dart';
import 'challenge.dart';
import 'generator.dart';
import 'scoring.dart';
import 'shape.dart';

enum GameMode { classic, zen, challenge, timeFree }

extension GameModeInfo on GameMode {
  String get label {
    switch (this) {
      case GameMode.classic:
        return 'Classic';
      case GameMode.zen:
        return 'Zen';
      case GameMode.challenge:
        return 'Challenge';
      case GameMode.timeFree:
        return 'Time-Free';
    }
  }

  /// Zen has no record chase.
  bool get chasesRecord => this != GameMode.zen && this != GameMode.challenge;
}

class Hint {
  final int slot;
  final int row;
  final int col;
  final int lines;
  const Hint(this.slot, this.row, this.col, this.lines);
}

class MoveOutcome {
  final Shape shape;
  final int row;
  final int col;
  final PlaceResult result;
  final ScoreBreakdown score;
  final int streak;
  final bool trayRefilled;
  final bool gameOver;
  final bool challengeComplete;
  const MoveOutcome({
    required this.shape,
    required this.row,
    required this.col,
    required this.result,
    required this.score,
    required this.streak,
    required this.trayRefilled,
    required this.gameOver,
    required this.challengeComplete,
  });
}

/// Pure-Dart game rules. No Flutter imports, fully unit-testable.
class GameState {
  final GameMode mode;
  final Challenge? challenge;
  Board board;
  List<Shape?> tray;
  int score = 0;
  int streak = 0;
  int bestStreak = 0;
  int bestCombo = 0;
  int linesCleared = 0;
  int blocksPlaced = 0;
  int moves = 0;
  int trayCount = 0;
  bool over = false;
  bool challengeComplete = false;
  final Random _rng;

  GameState({
    required this.mode,
    this.challenge,
    Board? board,
    List<Shape?>? tray,
    Random? rng,
  })  : board = board ?? challenge?.buildBoard() ?? Board(),
        tray = tray ?? <Shape?>[],
        _rng = rng ?? Random() {
    if (tray == null) _refill();
  }

  void _refill() {
    final gen = challenge != null
        ? PieceGenerator(Random(challenge!.seed * 997 + trayCount))
        : PieceGenerator(_rng);
    tray = List<Shape?>.of(gen.nextSet(board));
    trayCount++;
  }

  bool get isStuck =>
      !tray.any((s) => s != null && board.canPlaceAnywhere(s));

  /// Attempts to place tray piece [slot] with its top-left at ([row],[col]).
  /// Returns null (and changes nothing) for invalid or repeated placements, which
  /// is what makes rapid double-taps harmless.
  MoveOutcome? place(int slot, int row, int col) {
    if (over || challengeComplete) return null;
    if (slot < 0 || slot >= tray.length) return null;
    final shape = tray[slot];
    if (shape == null) return null;
    if (!board.canPlace(shape, row, col)) return null;

    final result = board.place(shape, row, col);
    tray[slot] = null;

    final lines = result.lines;
    streak = lines > 0 ? streak + 1 : 0;
    bestStreak = max(bestStreak, streak);
    bestCombo = max(bestCombo, lines);

    final breakdown = Scoring.forMove(
      cells: shape.size,
      lines: lines,
      streak: streak,
      boardEmpty: board.isCompletelyEmpty,
    );
    score += breakdown.total;
    linesCleared += lines;
    blocksPlaced++;
    moves++;

    var refilled = false;
    if (tray.every((s) => s == null)) {
      _refill();
      refilled = true;
    }

    if (challenge != null && challenge!.isMet(this)) {
      challengeComplete = true;
    } else if (isStuck) {
      over = true;
    }

    return MoveOutcome(
      shape: shape,
      row: row,
      col: col,
      result: result,
      score: breakdown,
      streak: streak,
      trayRefilled: refilled,
      gameOver: over,
      challengeComplete: challengeComplete,
    );
  }

  /// Suggests a placement, preferring moves that clear the most lines.
  Hint? findHint() {
    Hint? best;
    var bestValue = -1;
    for (var slot = 0; slot < tray.length; slot++) {
      final shape = tray[slot];
      if (shape == null) continue;
      for (final p in board.placements(shape)) {
        final lines = board.previewPlace(shape, p.r, p.c).lines;
        final value = lines * 100 + shape.size;
        if (value > bestValue) {
          bestValue = value;
          best = Hint(slot, p.r, p.c, lines);
        }
      }
    }
    return best;
  }

  Map<String, dynamic> toJson() => {
        'mode': mode.name,
        'challenge': challenge?.id,
        'board': board.cells,
        'tray': tray.map((s) => s?.id).toList(),
        'score': score,
        'streak': streak,
        'bestStreak': bestStreak,
        'bestCombo': bestCombo,
        'lines': linesCleared,
        'blocks': blocksPlaced,
        'moves': moves,
        'trayCount': trayCount,
        'over': over,
        'challengeComplete': challengeComplete,
      };

  static GameState? fromJson(Map<String, dynamic> j) {
    try {
      final mode = GameMode.values.firstWhere((m) => m.name == j['mode']);
      final challengeId = j['challenge'] as String?;
      final challenge = challengeId == null ? null : Challenge.fromId(challengeId);
      final cells = (j['board'] as List).cast<int>();
      final board = Board.fromCells(Board.defaultSize, cells);
      final tray = (j['tray'] as List).map((id) {
        if (id == null) return null;
        final s = ShapeLibrary.byId[id as String];
        if (s == null) throw StateError('Unknown shape $id');
        return s;
      }).toList();
      final g = GameState(mode: mode, challenge: challenge, board: board, tray: tray);
      g.score = j['score'] as int;
      g.streak = j['streak'] as int;
      g.bestStreak = j['bestStreak'] as int;
      g.bestCombo = j['bestCombo'] as int;
      g.linesCleared = j['lines'] as int;
      g.blocksPlaced = j['blocks'] as int;
      g.moves = j['moves'] as int;
      g.trayCount = j['trayCount'] as int;
      g.over = j['over'] as bool;
      g.challengeComplete = j['challengeComplete'] as bool;
      return g;
    } catch (_) {
      return null;
    }
  }
}
