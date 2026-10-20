import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../engine/game_state.dart';
import 'stats.dart';

class SavedGame {
  final GameState state;
  final int elapsedMs;
  const SavedGame(this.state, this.elapsedMs);
}

/// All persistence lives here and is strictly local (device preferences).
///
/// Safeguards against data loss:
///  * every blob is wrapped with a version and checksum,
///  * the previous valid copy of the stats is kept as a backup and used
///    automatically if the primary copy is missing or corrupt,
///  * an in-progress game is saved after every move.
class Storage {
  static const kStats = 'stats_v1';
  static const kStatsBackup = 'stats_v1_backup';
  static const kSettings = 'settings_v1';
  static const kGame = 'saved_game_v1';

  final SharedPreferences _p;
  Storage(this._p);

  static Future<Storage> open() async => Storage(await SharedPreferences.getInstance());

  static int _fnv(String s) {
    var h = 0x811c9dc5;
    for (final u in s.codeUnits) {
      h ^= u;
      h = (h * 0x01000193) & 0xFFFFFFFF;
    }
    return h;
  }

  static String wrap(Map<String, dynamic> data) {
    final body = jsonEncode(data);
    return jsonEncode({'v': 1, 'sum': _fnv(body), 'body': body});
  }

  static Map<String, dynamic>? unwrap(String? raw) {
    if (raw == null) return null;
    try {
      final o = jsonDecode(raw) as Map<String, dynamic>;
      final body = o['body'] as String;
      if (o['sum'] != _fnv(body)) return null;
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  // ---- Stats ----
  Stats loadStats() {
    for (final key in [kStats, kStatsBackup]) {
      final data = unwrap(_p.getString(key));
      if (data != null) {
        try {
          return Stats.fromJson(data);
        } catch (_) {
          // try next copy
        }
      }
    }
    return Stats();
  }

  Future<void> saveStats(Stats stats) async {
    final current = _p.getString(kStats);
    if (unwrap(current) != null) {
      await _p.setString(kStatsBackup, current!);
    }
    await _p.setString(kStats, wrap(stats.toJson()));
  }

  Future<void> resetStats() async {
    await _p.remove(kStats);
    await _p.remove(kStatsBackup);
    await _p.remove(kGame);
  }

  // ---- Settings ----
  Settings loadSettings() {
    final data = unwrap(_p.getString(kSettings));
    if (data == null) return Settings();
    try {
      return Settings.fromJson(data);
    } catch (_) {
      return Settings();
    }
  }

  Future<void> saveSettings(Settings s) => _p.setString(kSettings, wrap(s.toJson()));

  // ---- In-progress game ----
  SavedGame? loadGame() {
    final data = unwrap(_p.getString(kGame));
    if (data == null) return null;
    final state = GameState.fromJson((data['state'] as Map).cast<String, dynamic>());
    if (state == null || state.over || state.challengeComplete) return null;
    return SavedGame(state, (data['elapsedMs'] ?? 0) as int);
  }

  Future<void> saveGame(GameState g, int elapsedMs) =>
      _p.setString(kGame, wrap({'state': g.toJson(), 'elapsedMs': elapsedMs}));

  Future<void> clearGame() => _p.remove(kGame);
}
