import 'package:flutter/material.dart';

import '../data/achievements.dart';
import '../data/stats.dart';
import '../data/storage.dart';
import '../engine/game_state.dart';
import 'feedback.dart';

class GameResult {
  final bool newBest;
  final int previousBest;
  final List<AchievementDef> unlocked;
  const GameResult(this.newBest, this.previousBest, this.unlocked);
}

/// App-wide state: settings, lifetime statistics, and services.
class AppState extends ChangeNotifier {
  AppState._(this.storage, this.settings, this.stats) {
    feedback = GameFeedback(() => settings);
  }

  final Storage storage;
  Settings settings;
  Stats stats;
  late final GameFeedback feedback;

  static Future<AppState> create() async {
    final storage = await Storage.open();
    final app = AppState._(storage, storage.loadSettings(), storage.loadStats());
    await app.feedback.init();
    return app;
  }

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  /// Non-subscribing lookup, safe in initState.
  static AppState read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;

  ThemeMode get themeMode {
    switch (settings.theme) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  Future<void> updateSettings(void Function(Settings s) change) async {
    final musicBefore = settings.music;
    change(settings);
    await storage.saveSettings(settings);
    if (musicBefore != settings.music) {
      settings.music ? await feedback.startMusic() : await feedback.stopMusic();
    }
    notifyListeners();
  }

  SavedGame? get savedGame => storage.loadGame();

  /// Records a finished (or abandoned) game, updates achievements and persists.
  Future<GameResult> recordGame({
    required GameState game,
    required int elapsedMs,
    bool challengeCompleted = false,
  }) async {
    final prev = stats.bestFor(game.mode.name);
    final record = GameRecord(
      score: game.score,
      mode: game.mode.name,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      lines: game.linesCleared,
      seconds: (elapsedMs / 1000).round(),
    );
    final isBest = stats.applyGame(record,
        combo: game.bestCombo, streak: game.bestStreak, blocks: game.blocksPlaced);

    final ch = game.challenge;
    if (ch != null) {
      final p = ch.progress(game);
      if (p > (stats.challengeBest[ch.id] ?? 0)) stats.challengeBest[ch.id] = p;
      if (challengeCompleted) {
        stats.challengesDone[ch.id] = DateTime.now().millisecondsSinceEpoch;
      }
    }
    final unlocked = Achievements.evaluate(stats);
    await storage.saveStats(stats);
    await storage.clearGame();
    notifyListeners();
    return GameResult(isBest, prev, unlocked);
  }

  /// Counts a saved-but-unfinished game toward the statistics and discards it.
  Future<void> abandonSavedGame() async {
    final saved = storage.loadGame();
    if (saved != null && saved.state.moves > 0) {
      await recordGame(game: saved.state, elapsedMs: saved.elapsedMs);
    } else {
      await storage.clearGame();
    }
  }

  Future<void> resetStatistics() async {
    await storage.resetStats();
    stats = Stats();
    notifyListeners();
  }
}

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
      : super(notifier: state);
}
