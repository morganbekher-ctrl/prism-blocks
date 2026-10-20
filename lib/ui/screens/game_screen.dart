import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../engine/board.dart';
import '../../engine/challenge.dart';
import '../../engine/game_state.dart';
import '../../engine/shape.dart';
import '../../services/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/painters.dart';

enum _Phase { playing, paused, over, challengeDone, zenFull, tutorial }

class GameScreen extends StatefulWidget {
  final GameMode mode;
  final Challenge? challenge;
  final bool resume;
  const GameScreen({super.key, required this.mode, this.challenge, this.resume = false});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final AppState _app;
  late GameState _game;
  final _boardKey = GlobalKey();
  final _stackKey = GlobalKey();
  final _rng = Random();

  // Timing (total play time only; there is never a countdown).
  final Stopwatch _watch = Stopwatch();
  int _baseMs = 0;
  int get _elapsedMs => _baseMs + _watch.elapsedMilliseconds;

  _Phase _phase = _Phase.playing;
  bool _recorded = false;
  bool _finishing = false;
  GameResult? _result;
  int _bestAtStart = 0;
  bool _recordShown = false;
  int _tutorialPage = 0;

  // Animations / effects.
  late final AnimationController _placeC;
  late final AnimationController _clearC;
  late final AnimationController _pulseC;
  late final AnimationController _popupC;
  late final AnimationController _recordC;
  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;
  final List<Particle> _particles = [];
  final ValueNotifier<int> _repaint = ValueNotifier<int>(0);
  Set<int> _placedIdx = {};
  Map<int, int> _clearing = {};
  String _popupText = '';
  Color _popupColor = Colors.white;
  bool _danger = false;

  // Interaction.
  int? _selected;
  int? _dragSlot;
  bool _dragging = false;
  bool _wasSelected = false;
  Offset _downPos = Offset.zero;
  Offset _finger = Offset.zero;
  Map<int, int> _ghost = {};
  bool _ghostValid = false;
  int _ghostRow = 0;
  int _ghostCol = 0;
  Set<int> _previewClear = {};
  int _lastGhostKey = -1;
  Hint? _hint;
  Timer? _hintTimer;

  static const double _liftPx = 56;

  @override
  void initState() {
    super.initState();
    _app = AppState.read(context);
    WidgetsBinding.instance.addObserver(this);

    _placeC = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 320), value: 1.0);
    _clearC = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 520), value: 1.0);
    _pulseC = AnimationController(vsync: this, duration: const Duration(milliseconds: 750));
    _popupC = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000), value: 1.0);
    _recordC = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2400), value: 1.0);
    _ticker = createTicker(_onTick);

    final saved = widget.resume ? _app.savedGame : null;
    if (saved != null) {
      _game = saved.state;
      _baseMs = saved.elapsedMs;
    } else {
      _game = GameState(mode: widget.mode, challenge: widget.challenge);
    }
    _bestAtStart = _app.stats.bestFor(_game.mode.name);
    _app.feedback.volumeScale = _game.mode == GameMode.zen ? 0.6 : 1.0;

    if (!_app.settings.tutorialSeen && _game.mode == GameMode.classic && _game.moves == 0) {
      _phase = _Phase.tutorial;
    } else {
      _watch.start();
    }
    _danger = _computeDanger();
    _syncPulse();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _hintTimer?.cancel();
    _ticker.dispose();
    _placeC.dispose();
    _clearC.dispose();
    _pulseC.dispose();
    _popupC.dispose();
    _recordC.dispose();
    _repaint.dispose();
    _app.feedback.volumeScale = 1.0;
    super.dispose();
  }

  // ------------------------------------------------------------------ lifecycle
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      _watch.stop();
      _saveProgress();
      if (_phase == _Phase.playing && !_finishing && mounted) {
        _resetDrag();
        setState(() => _phase = _Phase.paused);
      }
    }
  }

  void _saveProgress() {
    if (_recorded || _game.over || _game.challengeComplete || _game.moves == 0) return;
    unawaited(_app.storage.saveGame(_game, _elapsedMs));
  }

  // ------------------------------------------------------------------ geometry
  ({Offset origin, double cs})? _boardMetrics() {
    final ro = _boardKey.currentContext?.findRenderObject();
    if (ro is! RenderBox || !ro.hasSize) return null;
    return (
      origin: ro.localToGlobal(Offset.zero),
      cs: (ro.size.width - kBoardPad * 2) / _game.board.size,
    );
  }

  Offset _shapeTopLeft(Offset finger, Shape s, double cs) =>
      Offset(finger.dx - s.width * cs / 2, finger.dy - s.height * cs - _liftPx);

  // ------------------------------------------------------------------ input
  bool get _inputOpen => _phase == _Phase.playing && !_finishing;

  void _onDown(int i, PointerDownEvent e) {
    if (!_inputOpen || _game.tray[i] == null || _dragSlot != null) return;
    _dragSlot = i;
    _downPos = e.position;
    _finger = e.position;
    _wasSelected = _selected == i;
    _dragging = false;
    _app.feedback.select();
    setState(() => _selected = i);
  }

  void _onMove(int i, PointerMoveEvent e) {
    if (_dragSlot != i) return;
    _finger = e.position;
    if (!_dragging) {
      if ((e.position - _downPos).distance <= 10) return;
      _dragging = true;
      _hintTimer?.cancel();
      _hint = null;
    }
    _updateDrag(e.position);
  }

  void _onUp(int i, PointerUpEvent e) {
    if (_dragSlot != i) return;
    if (_dragging) {
      _drop();
    } else {
      _dragSlot = null;
      setState(() {
        if (_wasSelected) _selected = null;
      });
    }
  }

  void _onCancel(int i) {
    if (_dragSlot != i) return;
    _resetDrag();
  }

  void _updateDrag(Offset global) {
    final slot = _dragSlot;
    if (slot == null) return;
    final shape = _game.tray[slot];
    final m = _boardMetrics();
    if (shape == null || m == null) return;
    final n = _game.board.size;
    final tl = _shapeTopLeft(global, shape, m.cs);
    final col = ((tl.dx - m.origin.dx - kBoardPad) / m.cs).round();
    final row = ((tl.dy - m.origin.dy - kBoardPad) / m.cs).round();
    final valid = _game.board.canPlace(shape, row, col);

    final ghost = <int, int>{};
    for (final c in shape.cells) {
      final r = row + c.r;
      final cc = col + c.c;
      if (_game.board.inBounds(r, cc)) ghost[r * n + cc] = shape.color;
    }
    final preview = <int>{};
    if (valid) {
      final res = _game.board.previewPlace(shape, row, col);
      for (final cell in res.clearedCells) {
        preview.add(cell.r * n + cell.c);
      }
    }
    final key = row * 100 + col;
    if (key != _lastGhostKey) {
      _lastGhostKey = key;
      _app.feedback.moveTick();
    }
    setState(() {
      _ghost = ghost;
      _ghostValid = valid;
      _ghostRow = row;
      _ghostCol = col;
      _previewClear = preview;
    });
    _syncPulse();
  }

  void _resetDrag() {
    if (!mounted) return;
    setState(() {
      _dragging = false;
      _dragSlot = null;
      _ghost = {};
      _previewClear = {};
      _ghostValid = false;
      _lastGhostKey = -1;
    });
    _syncPulse();
  }

  void _drop() {
    final slot = _dragSlot;
    final valid = _ghostValid;
    final r = _ghostRow;
    final c = _ghostCol;
    _resetDrag();
    setState(() => _selected = null);
    if (slot != null && valid) {
      _commitMove(slot, r, c);
    } else {
      _app.feedback.invalid();
    }
  }

  void _onBoardTap(TapUpDetails d) {
    final sel = _selected;
    if (!_inputOpen || sel == null) return;
    final shape = _game.tray[sel];
    final m = _boardMetrics();
    if (shape == null || m == null) return;
    final col = ((d.localPosition.dx - kBoardPad) / m.cs).floor() - shape.width ~/ 2;
    final row = ((d.localPosition.dy - kBoardPad) / m.cs).floor() - shape.height ~/ 2;
    if (_game.board.canPlace(shape, row, col)) {
      _commitMove(sel, row, col);
    } else {
      _app.feedback.invalid();
    }
  }

  // ------------------------------------------------------------------ moves
  void _commitMove(int slot, int row, int col) {
    if (!_inputOpen) return;
    final out = _game.place(slot, row, col);
    if (out == null) {
      _app.feedback.invalid();
      return;
    }
    final n = _game.board.size;
    _hintTimer?.cancel();
    _hint = null;
    _selected = null;
    _placedIdx = {for (final c in out.result.placedCells) c.r * n + c.c};
    _clearing = {
      for (var i = 0; i < out.result.clearedCells.length; i++)
        out.result.clearedCells[i].r * n + out.result.clearedCells[i].c:
            out.result.clearedColors[i]
    };
    _placeC.forward(from: 0);

    final lines = out.result.lines;
    final m = _boardMetrics();
    if (lines > 0) {
      _clearC.forward(from: 0);
      if (m != null) _spawnClearParticles(out.result, m.cs);
      _app.feedback.clear(lines);
      if (lines >= 2 || out.streak >= 3) _app.feedback.combo();
      _showPopup(_popupFor(lines, out), _popupColorFor(lines));
    } else {
      _app.feedback.place();
    }

    // Record-breaking celebration (only for modes that chase a record).
    if (_game.mode.chasesRecord &&
        !_recordShown &&
        _bestAtStart > 0 &&
        _game.score > _bestAtStart) {
      _recordShown = true;
      _recordC.forward(from: 0);
      _app.feedback.record();
      if (m != null) _spawnConfetti(m.cs * n + kBoardPad * 2);
    }

    // Near-miss: only one of the remaining pieces still fits.
    final remaining = _game.tray.whereType<Shape>().toList();
    final fits = remaining.where(_game.board.canPlaceAnywhere).length;
    if (!out.gameOver && lines == 0 && remaining.length >= 2 && fits == 1) {
      _showPopup('Close call!', const Color(0xFFFFB020));
    }
    _danger = _computeDanger();

    setState(() {});
    _syncPulse();
    _saveProgress();

    if (out.challengeComplete) {
      _finish(success: true);
    } else if (out.gameOver) {
      _finish();
    }
  }

  bool _computeDanger() {
    if (_game.over) return false;
    final remaining = _game.tray.whereType<Shape>().toList();
    final fits = remaining.where(_game.board.canPlaceAnywhere).length;
    return remaining.length >= 2 && fits == 1;
  }

  String _popupFor(int lines, MoveOutcome out) {
    if (out.score.perfect > 0) return 'PERFECT CLEAR!\n+${out.score.total}';
    const names = ['', 'Nice!', 'Double!', 'Triple!', 'Quad!'];
    final name = lines < names.length ? names[lines] : 'Incredible!';
    final streak = out.streak >= 2 ? '\nStreak \u00d7${out.streak}' : '';
    return '$name  +${out.score.total}$streak';
  }

  Color _popupColorFor(int lines) {
    if (lines >= 3) return const Color(0xFFFF5E7E);
    if (lines == 2) return const Color(0xFFFFC52E);
    return Colors.white;
  }

  void _showPopup(String text, Color color) {
    setState(() {
      _popupText = text;
      _popupColor = color;
    });
    _popupC.forward(from: 0);
  }

  Future<void> _finish({bool success = false}) async {
    if (_finishing) return;
    _finishing = true;
    _watch.stop();
    await Future<void>.delayed(const Duration(milliseconds: 650)); // let the clear play out
    if (!mounted) return;
    final mode = _game.mode;
    if (!success && mode != GameMode.zen) _app.feedback.gameOver();
    _recorded = true;
    final res = await _app.recordGame(
        game: _game, elapsedMs: _elapsedMs, challengeCompleted: success);
    if (!mounted) return;
    if (res.newBest && mode.chasesRecord && !_recordShown) {
      _recordShown = true;
      _app.feedback.record();
      final m = _boardMetrics();
      if (m != null) _spawnConfetti(m.cs * _game.board.size + kBoardPad * 2);
    }
    setState(() {
      _result = res;
      _phase = success
          ? _Phase.challengeDone
          : (mode == GameMode.zen ? _Phase.zenFull : _Phase.over);
    });
  }

  Future<void> _restart() async {
    if (!_recorded && _game.moves > 0 && !_finishing) {
      _recorded = true;
      await _app.recordGame(game: _game, elapsedMs: _elapsedMs);
    } else {
      await _app.storage.clearGame();
    }
    if (!mounted) return;
    _hintTimer?.cancel();
    _particles.clear();
    setState(() {
      _game = GameState(mode: _game.mode, challenge: _game.challenge);
      _bestAtStart = _app.stats.bestFor(_game.mode.name);
      _recordShown = false;
      _recorded = false;
      _finishing = false;
      _result = null;
      _baseMs = 0;
      _watch
        ..reset()
        ..start();
      _phase = _Phase.playing;
      _selected = null;
      _hint = null;
      _placedIdx = {};
      _clearing = {};
      _danger = false;
    });
    _syncPulse();
  }

  void _toMenu() {
    _saveProgress();
    Navigator.of(context).pop();
  }

  void _pause() {
    if (_phase != _Phase.playing) return;
    _watch.stop();
    _resetDrag();
    _app.feedback.select();
    setState(() => _phase = _Phase.paused);
  }

  void _resume() {
    _watch.start();
    setState(() => _phase = _Phase.playing);
  }

  // ------------------------------------------------------------------ hints
  bool get _hintsAvailable => _app.settings.hints || _game.mode == GameMode.timeFree;

  void _showHint() {
    if (!_inputOpen) return;
    final h = _game.findHint();
    if (h == null) return;
    _app.feedback.select();
    setState(() => _hint = h);
    _syncPulse();
    _hintTimer?.cancel();
    _hintTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() => _hint = null);
      _syncPulse();
    });
  }

  void _syncPulse() {
    final need = _danger || _hint != null || _dragging;
    if (need) {
      if (!_pulseC.isAnimating) _pulseC.repeat(reverse: true);
    } else if (_pulseC.isAnimating) {
      _pulseC.stop();
      _pulseC.value = 0;
    }
  }

  // ------------------------------------------------------------------ particles
  void _spawnClearParticles(PlaceResult res, double cs) {
    for (var i = 0; i < res.clearedCells.length; i++) {
      final cell = res.clearedCells[i];
      final color = Palette.block(res.clearedColors[i]);
      final center = Offset(kBoardPad + (cell.c + 0.5) * cs, kBoardPad + (cell.r + 0.5) * cs);
      for (var k = 0; k < 4; k++) {
        final ang = _rng.nextDouble() * 2 * pi;
        final sp = 80 + _rng.nextDouble() * 220;
        _particles.add(Particle(center, Offset(cos(ang) * sp, sin(ang) * sp - 120), color,
            0.6 + _rng.nextDouble() * 0.5, 3 + _rng.nextDouble() * 4));
      }
    }
    if (_particles.length > 500) _particles.removeRange(0, _particles.length - 500);
    _startTicker();
  }

  void _spawnConfetti(double width) {
    for (var k = 0; k < 90; k++) {
      _particles.add(Particle(
        Offset(_rng.nextDouble() * width, -8),
        Offset((_rng.nextDouble() - 0.5) * 320, _rng.nextDouble() * 160),
        Palette.block(_rng.nextInt(7)),
        1.6 + _rng.nextDouble() * 0.8,
        4 + _rng.nextDouble() * 4,
      ));
    }
    _startTicker();
  }

  void _startTicker() {
    if (!_ticker.isActive) {
      _lastTick = Duration.zero;
      _ticker.start();
    }
  }

  void _onTick(Duration e) {
    final dt = ((e - _lastTick).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _lastTick = e;
    for (final p in _particles) {
      p.v = Offset(p.v.dx * 0.99, p.v.dy + 800 * dt);
      p.p = p.p + p.v * dt;
      p.life -= dt;
    }
    _particles.removeWhere((p) => p.life <= 0);
    _repaint.value++;
    if (_particles.isEmpty) _ticker.stop();
  }

  // ------------------------------------------------------------------ build
  @override
  Widget build(BuildContext context) {
    final c = GameColors.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        switch (_phase) {
          case _Phase.playing:
            _pause();
            break;
          case _Phase.paused:
            _resume();
            break;
          case _Phase.tutorial:
            break;
          default:
            Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        body: GameBackground(
          child: SafeArea(
            child: Stack(
              key: _stackKey,
              // Fill the screen: the idle overlays are zero-size non-positioned
              // children, which would otherwise shrink a loose Stack to 0x0.
              fit: StackFit.expand,
              children: [
                Positioned.fill(child: LayoutBuilder(builder: _buildMain)),
                _dragOverlay(),
                _popupWidget(),
                _recordBanner(),
                _overlay(c),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMain(BuildContext context, BoxConstraints box) {
    final c = GameColors.of(context);
    final patterns = _app.settings.colorAssist;
    final w = box.maxWidth;
    final h = box.maxHeight;
    const headerH = 92.0;
    const hintH = 56.0;
    final extra = _game.challenge != null ? 52.0 : 0.0;
    var side = (h - headerH - extra - hintH - 12 - 16) / 1.3875;
    // Upper bound may drop below 200 (narrow screens, or a 0x0 first frame),
    // and clamp() throws when upper < lower, so bound it explicitly.
    final maxSide = max(0.0, w - 24);
    side = min(max(side, 200.0), maxSide);
    final cs = (side - kBoardPad * 2) / _game.board.size;
    final trayCs = cs * 0.62;
    final slotH = 5 * trayCs + 20;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _header(c),
        if (_game.challenge != null) _challengeBar(c),
        const SizedBox(height: 4),
        _board(side, c, patterns),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [for (var i = 0; i < 3; i++) _slot(i, trayCs, slotH, c, patterns)],
          ),
        ),
        SizedBox(
          height: hintH,
          child: _hintsAvailable
              ? Center(
                  child: TextButton.icon(
                    onPressed: _showHint,
                    icon: const Icon(Icons.lightbulb_rounded, color: Color(0xFFFFC52E)),
                    label: Text('Hint',
                        style: TextStyle(
                            color: c.text, fontWeight: FontWeight.w700, fontSize: 16)),
                    style: TextButton.styleFrom(minimumSize: const Size(120, 48)),
                  ),
                )
              : null,
        ),
      ],
    );
  }

  Widget _roundButton(IconData icon, String label, VoidCallback onTap, GameColors c) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: c.card,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: Colors.black.op(0.12), blurRadius: 8, offset: const Offset(0, 3))
            ],
          ),
          child: Icon(icon, color: c.text, size: 28),
        ),
      ),
    );
  }

  Widget _header(GameColors c) {
    final best = max(_bestAtStart, _game.score);
    return SizedBox(
      height: 92,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            _roundButton(Icons.pause_rounded, 'Pause', _pause, c),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_game.mode.label.toUpperCase(),
                      style: TextStyle(
                          color: c.textDim,
                          fontSize: 12,
                          letterSpacing: 2,
                          fontWeight: FontWeight.w700)),
                  TweenAnimationBuilder<int>(
                    tween: IntTween(begin: 0, end: _game.score),
                    duration: Duration(milliseconds: _game.mode == GameMode.zen ? 700 : 450),
                    builder: (_, v, __) => Text('$v',
                        semanticsLabel: 'Score $v',
                        style: TextStyle(
                            color: c.text,
                            fontSize: 44,
                            height: 1.05,
                            fontWeight: FontWeight.w900)),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 70,
              child: _game.mode.chasesRecord
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('BEST',
                            style: TextStyle(
                                color: c.textDim,
                                fontSize: 12,
                                letterSpacing: 2,
                                fontWeight: FontWeight.w700)),
                        Text('$best',
                            style: TextStyle(
                                color: _game.score > _bestAtStart && _bestAtStart > 0
                                    ? const Color(0xFFFFC52E)
                                    : c.text,
                                fontSize: 20,
                                fontWeight: FontWeight.w800)),
                      ],
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _challengeBar(GameColors c) {
    final ch = _game.challenge!;
    final p = ch.progress(_game).clamp(0, ch.target);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: SizedBox(
        height: 52,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('${ch.title}   $p / ${ch.target}',
                style: TextStyle(color: c.text, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: p / ch.target,
                minHeight: 8,
                color: const Color(0xFFFFC52E),
                backgroundColor: c.cellEmpty,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _board(double side, GameColors c, bool patterns) {
    final n = _game.board.size;
    final hintCells = <int>{};
    final h = _hint;
    if (h != null) {
      final s = _game.tray[h.slot];
      if (s != null) {
        for (final cell in s.cells) {
          hintCells.add((h.row + cell.r) * n + h.col + cell.c);
        }
      }
    }
    return Semantics(
      label: 'Game board, ${_game.board.filledCount} of ${n * n} cells filled',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: _onBoardTap,
        child: SizedBox(
          key: _boardKey,
          width: side,
          height: side,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: BoardPainter(
                    board: _game.board,
                    colors: c,
                    patterns: patterns,
                    ghost: _ghost,
                    ghostValid: _ghostValid,
                    previewClear: _previewClear,
                    clearing: _clearing,
                    clearT: _clearC,
                    placed: _placedIdx,
                    placeT: _placeC,
                    pulse: _pulseC,
                    hintCells: hintCells,
                    dangerGlow: _danger ? const Color(0xFFFFB020) : null,
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(painter: ParticlePainter(_particles, _repaint)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _slot(int i, double trayCs, double slotH, GameColors c, bool patterns) {
    final shape = _game.tray[i];
    final isDragging = _dragging && _dragSlot == i;
    final isSelected = _selected == i && shape != null;
    final isHint = _hint?.slot == i;
    final fits = shape != null && _game.board.canPlaceAnywhere(shape);

    Widget? piece;
    if (shape != null) {
      piece = AnimatedScale(
        scale: isSelected && !isDragging ? 1.12 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: CustomPaint(
          size: Size(shape.width * trayCs, shape.height * trayCs),
          painter: ShapePainter(shape, trayCs,
              patterns: patterns, alpha: isDragging ? 0.2 : (fits ? 1.0 : 0.4)),
        ),
      );
    }

    return Expanded(
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (e) => _onDown(i, e),
        onPointerMove: (e) => _onMove(i, e),
        onPointerUp: (e) => _onUp(i, e),
        onPointerCancel: (_) => _onCancel(i),
        child: Semantics(
          label: shape == null ? 'Empty slot' : 'Block ${i + 1}',
          child: Container(
            height: slotH,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSelected ? c.card.op(0.55) : Colors.transparent,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isHint
                    ? Colors.white.op(0.9)
                    : (isSelected ? Colors.white.op(0.5) : Colors.transparent),
                width: 2,
              ),
            ),
            child: piece,
          ),
        ),
      ),
    );
  }

  Widget _dragOverlay() {
    if (!_dragging || _dragSlot == null) return const SizedBox.shrink();
    final shape = _game.tray[_dragSlot!];
    final m = _boardMetrics();
    final ro = _stackKey.currentContext?.findRenderObject();
    if (shape == null || m == null || ro is! RenderBox) return const SizedBox.shrink();
    final tl = ro.globalToLocal(_shapeTopLeft(_finger, shape, m.cs));
    return Positioned(
      left: tl.dx,
      top: tl.dy,
      child: IgnorePointer(
        child: CustomPaint(
          size: Size(shape.width * m.cs, shape.height * m.cs),
          painter: ShapePainter(shape, m.cs, patterns: _app.settings.colorAssist),
        ),
      ),
    );
  }

  Widget _popupWidget() {
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _popupC,
          builder: (_, __) {
            final t = _popupC.value;
            if (t >= 1.0 || _popupText.isEmpty) return const SizedBox.shrink();
            final fade = t < 0.12 ? t / 0.12 : 1.0 - pow((t - 0.12) / 0.88, 2).toDouble();
            final scale = 0.8 + 0.3 * Curves.easeOutBack.transform(min(1.0, t * 3));
            return Align(
              alignment: const Alignment(0, -0.2),
              child: Opacity(
                opacity: fade.clamp(0.0, 1.0),
                child: Transform.translate(
                  offset: Offset(0, -50 * t),
                  child: Transform.scale(
                    scale: scale,
                    child: Text(
                      _popupText,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _popupColor,
                        fontSize: 32,
                        height: 1.15,
                        fontWeight: FontWeight.w900,
                        shadows: [
                          Shadow(color: Colors.black.op(0.45), blurRadius: 14),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _recordBanner() {
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _recordC,
          builder: (_, __) {
            final t = _recordC.value;
            if (t >= 1.0) return const SizedBox.shrink();
            final fade = t < 0.1 ? t / 0.1 : (t > 0.8 ? (1 - t) / 0.2 : 1.0);
            final scale = 0.6 + 0.5 * Curves.elasticOut.transform(min(1.0, t * 2.2));
            return Align(
              alignment: const Alignment(0, -0.62),
              child: Opacity(
                opacity: fade.clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: scale,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [Color(0xFFFFC52E), Color(0xFFFF8A3D)]),
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                            color: const Color(0xFFFFC52E).op(0.6), blurRadius: 24)
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star_rounded, color: Colors.white, size: 28),
                        SizedBox(width: 8),
                        Text('NEW RECORD!',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5)),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ overlays
  Widget _overlay(GameColors c) {
    Widget card(Widget child) => Positioned.fill(
          child: Container(
            color: c.scrim,
            alignment: Alignment.center,
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: SingleChildScrollView(child: SoftCard(padding: const EdgeInsets.all(24), child: child)),
            ),
          ),
        );

    switch (_phase) {
      case _Phase.playing:
        return const SizedBox.shrink();
      case _Phase.paused:
        return card(_pauseContent(c));
      case _Phase.tutorial:
        return card(_tutorialContent(c));
      case _Phase.over:
      case _Phase.zenFull:
      case _Phase.challengeDone:
        return card(_resultContent(c));
    }
  }

  Widget _title(GameColors c, String t) => Text(t,
      textAlign: TextAlign.center,
      style: TextStyle(color: c.text, fontSize: 30, fontWeight: FontWeight.w900));

  Widget _pauseContent(GameColors c) {
    final s = _app.settings;
    Widget toggle(IconData on, IconData off, String label, bool value, void Function(bool) set) {
      return Expanded(
        child: Semantics(
          label: '$label ${value ? 'on' : 'off'}',
          button: true,
          child: GestureDetector(
            onTap: () async {
              await _app.updateSettings((x) => set(!value));
              if (mounted) setState(() {});
            },
            child: Column(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: value ? Palette.blocks[0] : c.cellEmpty,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(value ? on : off,
                      color: value ? Colors.white : c.textDim, size: 28),
                ),
                const SizedBox(height: 4),
                Text(label, style: TextStyle(color: c.textDim, fontSize: 12)),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _title(c, 'Paused'),
        const SizedBox(height: 20),
        GradientButton(
            label: 'Resume', icon: Icons.play_arrow_rounded, onPressed: _resume),
        const SizedBox(height: 18),
        Row(
          children: [
            toggle(Icons.volume_up_rounded, Icons.volume_off_rounded, 'Sound', s.sfx,
                (v) => s.sfx = v),
            toggle(Icons.music_note_rounded, Icons.music_off_rounded, 'Music', s.music,
                (v) => s.music = v),
            toggle(Icons.vibration_rounded, Icons.phone_android_rounded, 'Haptics',
                s.haptics, (v) => s.haptics = v),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                onPressed: _restart,
                child: const Text('Restart'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                onPressed: _toMenu,
                child: const Text('Menu'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _resultContent(GameColors c) {
    final res = _result;
    final g = _game;
    final isZen = _phase == _Phase.zenFull;
    final isChallengeWin = _phase == _Phase.challengeDone;
    final title = isChallengeWin
        ? 'Challenge complete!'
        : isZen
            ? 'The board is full'
            : (g.mode == GameMode.challenge ? 'Challenge failed' : 'Game Over');
    final isBest = res?.newBest == true && g.mode.chasesRecord;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _title(c, title),
        const SizedBox(height: 14),
        if (isBest)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              gradient:
                  const LinearGradient(colors: [Color(0xFFFFC52E), Color(0xFFFF8A3D)]),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text('NEW PERSONAL BEST!',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
          ),
        const SizedBox(height: 10),
        Text('${g.score}',
            style: TextStyle(color: c.text, fontSize: 56, fontWeight: FontWeight.w900)),
        if (g.mode.chasesRecord)
          Text('Best  ${max(_app.stats.bestFor(g.mode.name), g.score)}',
              style: TextStyle(color: c.textDim, fontSize: 16)),
        const SizedBox(height: 8),
        Text('${g.linesCleared} lines  \u00b7  best combo ${g.bestCombo}  \u00b7  ${g.blocksPlaced} blocks',
            textAlign: TextAlign.center,
            style: TextStyle(color: c.textDim, fontSize: 13)),
        if (res != null && res.unlocked.isNotEmpty) ...[
          const SizedBox(height: 14),
          for (final a in res.unlocked)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.emoji_events_rounded,
                      color: Color(0xFFFFC52E), size: 20),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text('Unlocked: ${a.title}',
                        style: TextStyle(
                            color: c.text, fontWeight: FontWeight.w700, fontSize: 14)),
                  ),
                ],
              ),
            ),
        ],
        const SizedBox(height: 20),
        GradientButton(
          label: isZen ? 'Restart' : (isChallengeWin ? 'Play again' : 'Replay'),
          icon: Icons.replay_rounded,
          onPressed: _restart,
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Menu'),
        ),
      ],
    );
  }

  Widget _tutorialContent(GameColors c) {
    const steps = [
      (Icons.touch_app_rounded, 'Drag a block onto the board',
          'Hold a block, slide it over the grid and let go. You can also tap a block, then tap the board.'),
      (Icons.view_week_rounded, 'Fill a row or column to clear it',
          'Clear several lines at once, or on back-to-back moves, for combo and streak bonuses.'),
      (Icons.flag_rounded, 'Keep space for your blocks',
          'The game ends when none of your blocks fit. Blocks never rotate, so plan ahead. Stuck? Tap the lightbulb for a hint.'),
    ];
    final step = steps[_tutorialPage];
    final last = _tutorialPage == steps.length - 1;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(step.$1, size: 64, color: Palette.blocks[_tutorialPage * 2]),
        const SizedBox(height: 14),
        Text(step.$2,
            textAlign: TextAlign.center,
            style: TextStyle(color: c.text, fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        Text(step.$3,
            textAlign: TextAlign.center,
            style: TextStyle(color: c.textDim, fontSize: 15, height: 1.35)),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < steps.length; i++)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i == _tutorialPage ? Palette.blocks[0] : c.cellEmpty,
                ),
              ),
          ],
        ),
        const SizedBox(height: 18),
        GradientButton(
          label: last ? 'Let\u2019s play' : 'Next',
          onPressed: () async {
            if (!last) {
              setState(() => _tutorialPage++);
              return;
            }
            await _app.updateSettings((s) => s.tutorialSeen = true);
            if (!mounted) return;
            _watch.start();
            setState(() => _phase = _Phase.playing);
            _showHint(); // show the first move so the controls click immediately
          },
        ),
        TextButton(
          onPressed: () async {
            await _app.updateSettings((s) => s.tutorialSeen = true);
            if (!mounted) return;
            _watch.start();
            setState(() => _phase = _Phase.playing);
          },
          child: Text('Skip', style: TextStyle(color: c.textDim)),
        ),
      ],
    );
  }
}
