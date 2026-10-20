import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

import '../data/stats.dart';

/// Sound + haptics. Every call is wrapped so that a missing audio backend or a
/// device without a vibration motor can never break gameplay.
class GameFeedback {
  GameFeedback(this._settings);

  final Settings Function() _settings;
  final Map<String, AudioPlayer> _players = {};
  AudioPlayer? _music;
  bool _ready = false;
  int _lastTickMs = 0;

  /// Set by the game screen (e.g. Zen mode plays everything more softly).
  double volumeScale = 1.0;

  static const _sounds = [
    'select', 'move', 'place', 'clear1', 'clearMulti', 'combo', 'record', 'gameover'
  ];

  Future<void> init() async {
    try {
      for (final name in _sounds) {
        final p = AudioPlayer();
        await p.setPlayerMode(PlayerMode.lowLatency);
        await p.setReleaseMode(ReleaseMode.stop);
        _players[name] = p;
      }
      _ready = true;
    } catch (_) {
      _ready = false;
    }
    if (_settings().music) unawaited(startMusic());
  }

  void _play(String name, {double volume = 0.8}) {
    if (!_ready || !_settings().sfx) return;
    try {
      final p = _players[name];
      if (p == null) return;
      unawaited(p.play(AssetSource('audio/$name.wav'), volume: (volume * volumeScale).clamp(0.0, 1.0)));
    } catch (_) {}
  }

  void _haptic(Future<void> Function() f) {
    if (!_settings().haptics) return;
    try {
      unawaited(f());
    } catch (_) {}
  }

  Future<void> startMusic() async {
    if (!_ready || !_settings().music) return;
    try {
      _music ??= AudioPlayer();
      await _music!.setReleaseMode(ReleaseMode.loop);
      await _music!.setVolume(0.35);
      await _music!.play(AssetSource('audio/music_loop.wav'));
    } catch (_) {}
  }

  Future<void> stopMusic() async {
    try {
      await _music?.stop();
    } catch (_) {}
  }

  Future<void> pauseMusic() async {
    try {
      await _music?.pause();
    } catch (_) {}
  }

  Future<void> resumeMusic() async {
    if (!_settings().music) return;
    try {
      if (_music == null) {
        await startMusic();
      } else {
        await _music!.resume();
      }
    } catch (_) {}
  }

  // ---- Events ----
  void select() {
    _play('select', volume: 0.6);
    _haptic(HapticFeedback.selectionClick);
  }

  /// Throttled tick while dragging across cells.
  void moveTick() {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastTickMs < 70) return;
    _lastTickMs = now;
    _play('move', volume: 0.3);
  }

  void place() {
    _play('place');
    _haptic(HapticFeedback.lightImpact);
  }

  void invalid() {
    _haptic(HapticFeedback.vibrate);
  }

  void clear(int lines) {
    if (lines >= 2) {
      _play('clearMulti');
      _haptic(HapticFeedback.heavyImpact);
    } else {
      _play('clear1');
      _haptic(HapticFeedback.mediumImpact);
    }
  }

  void combo() => _play('combo');

  void record() {
    _play('record');
    _haptic(HapticFeedback.heavyImpact);
  }

  void gameOver() {
    _play('gameover');
    _haptic(HapticFeedback.mediumImpact);
  }

  Future<void> dispose() async {
    for (final p in _players.values) {
      await p.dispose();
    }
    await _music?.dispose();
  }
}
