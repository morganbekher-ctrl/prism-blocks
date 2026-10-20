import 'stats.dart';

class AchievementDef {
  final String id;
  final String title;
  final String description;
  final bool Function(Stats) test;
  const AchievementDef(this.id, this.title, this.description, this.test);
}

class Achievements {
  Achievements._();

  static final List<AchievementDef> all = [
    AchievementDef('first_clear', 'First Spark', 'Clear your first line',
        (s) => s.totalLines >= 1),
    AchievementDef('lines_100', 'Line Hundred', 'Clear 100 lines in total',
        (s) => s.totalLines >= 100),
    AchievementDef('lines_500', 'Line Legend', 'Clear 500 lines in total',
        (s) => s.totalLines >= 500),
    AchievementDef('score_1000', 'Four Digits', 'Score 1,000 in a single game',
        (s) => s.bestScore >= 1000),
    AchievementDef('score_5000', 'Five Grand', 'Score 5,000 in a single game',
        (s) => s.bestScore >= 5000),
    AchievementDef('combo_2', 'Double Trouble', 'Clear 2 lines with one move',
        (s) => s.bestCombo >= 2),
    AchievementDef('combo_3', 'Triple Threat', 'Clear 3 lines with one move',
        (s) => s.bestCombo >= 3),
    AchievementDef('streak_5', 'On a Roll', 'Clear lines on 5 moves in a row',
        (s) => s.bestStreak >= 5),
    AchievementDef('games_10', 'Regular', 'Play 10 games', (s) => s.gamesPlayed >= 10),
    AchievementDef('games_50', 'Devoted', 'Play 50 games', (s) => s.gamesPlayed >= 50),
    AchievementDef('blocks_500', 'Block Builder', 'Place 500 blocks',
        (s) => s.totalBlocks >= 500),
    AchievementDef('challenge_1', 'Challenger', 'Complete a challenge',
        (s) => s.challengesDone.isNotEmpty),
  ];

  /// Unlocks any newly satisfied achievements and returns them.
  static List<AchievementDef> evaluate(Stats stats) {
    final unlocked = <AchievementDef>[];
    for (final a in all) {
      if (!stats.achievements.contains(a.id) && a.test(stats)) {
        stats.achievements.add(a.id);
        unlocked.add(a);
      }
    }
    return unlocked;
  }
}
