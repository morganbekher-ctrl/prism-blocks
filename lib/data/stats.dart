import 'dart:math';

class GameRecord {
  final int score;
  final String mode; // GameMode.name
  final int timestamp; // ms since epoch, local device clock
  final int lines;
  final int seconds;

  const GameRecord({
    required this.score,
    required this.mode,
    required this.timestamp,
    required this.lines,
    required this.seconds,
  });

  Map<String, dynamic> toJson() => {
        's': score,
        'm': mode,
        't': timestamp,
        'l': lines,
        'd': seconds,
      };

  factory GameRecord.fromJson(Map<String, dynamic> j) => GameRecord(
        score: j['s'] as int,
        mode: j['m'] as String,
        timestamp: j['t'] as int,
        lines: j['l'] as int,
        seconds: j['d'] as int,
      );
}

class Stats {
  static const int maxHistory = 100;

  Stats();

  int gamesPlayed = 0;
  int totalScore = 0;
  int totalLines = 0;
  int totalBlocks = 0;
  int bestCombo = 0;
  int bestStreak = 0;
  int totalPlayMs = 0;
  final Map<String, int> bestByMode = {};
  final List<GameRecord> history = []; // oldest first
  final Set<String> achievements = {};
  final Map<String, int> challengesDone = {}; // id -> completion timestamp
  final Map<String, int> challengeBest = {}; // id -> best progress

  int get bestScore => bestByMode.values.fold(0, max);
  int bestFor(String mode) => bestByMode[mode] ?? 0;
  double get averageScore => gamesPlayed == 0 ? 0 : totalScore / gamesPlayed;

  /// Applies a finished game. Returns true if it set a new best for its mode.
  bool applyGame(
    GameRecord record, {
    required int combo,
    required int streak,
    required int blocks,
  }) {
    final prev = bestFor(record.mode);
    final isBest = record.score > prev && record.score > 0;
    if (isBest) bestByMode[record.mode] = record.score;
    gamesPlayed++;
    totalScore += record.score;
    totalLines += record.lines;
    totalBlocks += blocks;
    totalPlayMs += record.seconds * 1000;
    bestCombo = max(bestCombo, combo);
    bestStreak = max(bestStreak, streak);
    history.add(record);
    if (history.length > maxHistory) {
      history.removeRange(0, history.length - maxHistory);
    }
    return isBest;
  }

  Map<String, dynamic> toJson() => {
        'games': gamesPlayed,
        'score': totalScore,
        'lines': totalLines,
        'blocks': totalBlocks,
        'combo': bestCombo,
        'streak': bestStreak,
        'playMs': totalPlayMs,
        'bestByMode': bestByMode,
        'history': history.map((e) => e.toJson()).toList(),
        'ach': achievements.toList(),
        'done': challengesDone,
        'cbest': challengeBest,
      };

  factory Stats.fromJson(Map<String, dynamic> j) {
    final s = Stats();
    s.gamesPlayed = (j['games'] ?? 0) as int;
    s.totalScore = (j['score'] ?? 0) as int;
    s.totalLines = (j['lines'] ?? 0) as int;
    s.totalBlocks = (j['blocks'] ?? 0) as int;
    s.bestCombo = (j['combo'] ?? 0) as int;
    s.bestStreak = (j['streak'] ?? 0) as int;
    s.totalPlayMs = (j['playMs'] ?? 0) as int;
    (j['bestByMode'] as Map? ?? {}).forEach((k, v) => s.bestByMode[k as String] = v as int);
    for (final h in (j['history'] as List? ?? [])) {
      s.history.add(GameRecord.fromJson((h as Map).cast<String, dynamic>()));
    }
    s.achievements.addAll(((j['ach'] as List?) ?? []).cast<String>());
    (j['done'] as Map? ?? {}).forEach((k, v) => s.challengesDone[k as String] = v as int);
    (j['cbest'] as Map? ?? {}).forEach((k, v) => s.challengeBest[k as String] = v as int);
    return s;
  }
}

class Settings {
  bool music = true;
  bool sfx = true;
  bool haptics = true;
  bool colorAssist = false; // adds a distinct pattern to every colour
  bool hints = true;
  bool tutorialSeen = false;
  String theme = 'system'; // system | light | dark

  Settings();

  Map<String, dynamic> toJson() => {
        'music': music,
        'sfx': sfx,
        'haptics': haptics,
        'colorAssist': colorAssist,
        'hints': hints,
        'tutorialSeen': tutorialSeen,
        'theme': theme,
      };

  factory Settings.fromJson(Map<String, dynamic> j) {
    final s = Settings();
    s.music = (j['music'] ?? true) as bool;
    s.sfx = (j['sfx'] ?? true) as bool;
    s.haptics = (j['haptics'] ?? true) as bool;
    s.colorAssist = (j['colorAssist'] ?? false) as bool;
    s.hints = (j['hints'] ?? true) as bool;
    s.tutorialSeen = (j['tutorialSeen'] ?? false) as bool;
    s.theme = (j['theme'] ?? 'system') as String;
    return s;
  }
}
