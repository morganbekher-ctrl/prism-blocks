import 'package:flutter/material.dart';

import '../../engine/game_state.dart';
import '../../services/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'challenge_screen.dart';
import 'game_screen.dart';
import 'settings_screen.dart';
import 'stats_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Future<void> _play(GameMode mode, {bool resume = false}) async {
    final app = AppState.read(context);
    if (!resume) await app.abandonSavedGame();
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => GameScreen(mode: mode, resume: resume)));
    if (mounted) setState(() {});
  }

  void _open(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final app = AppState.of(context);
    final c = GameColors.of(context);
    final saved = app.savedGame;
    final best = app.stats.bestFor('classic');

    return Scaffold(
      body: GameBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const Spacer(flex: 2),
                const _Logo(),
                const SizedBox(height: 12),
                if (best > 0)
                  Text('Best  $best',
                      style: TextStyle(
                          color: c.textDim, fontSize: 18, fontWeight: FontWeight.w700)),
                const Spacer(flex: 2),
                if (saved != null) ...[
                  GradientButton(
                    label: 'Continue ${saved.state.mode.label}',
                    icon: Icons.play_circle_fill_rounded,
                    colors: const [Color(0xFF12C9BE), Color(0xFF4DA9FF)],
                    onPressed: () => _play(saved.state.mode, resume: true),
                  ),
                  const SizedBox(height: 14),
                ],
                GradientButton(
                  label: saved != null ? 'New Game' : 'Play',
                  icon: Icons.play_arrow_rounded,
                  height: 68,
                  onPressed: () => _play(GameMode.classic),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                        child: _ModeCard(
                            icon: Icons.spa_rounded,
                            label: 'Zen',
                            colors: const [Color(0xFF3FDD98), Color(0xFF12C9BE)],
                            onTap: () => _play(GameMode.zen))),
                    const SizedBox(width: 12),
                    Expanded(
                        child: _ModeCard(
                            icon: Icons.emoji_events_rounded,
                            label: 'Challenge',
                            colors: const [Color(0xFFFFC52E), Color(0xFFFF8A3D)],
                            onTap: () => _open(const ChallengeScreen()))),
                    const SizedBox(width: 12),
                    Expanded(
                        child: _ModeCard(
                            icon: Icons.all_inclusive_rounded,
                            label: 'Time-Free',
                            colors: const [Color(0xFF4DA9FF), Color(0xFF8A3FFC)],
                            onTap: () => _play(GameMode.timeFree))),
                  ],
                ),
                const Spacer(flex: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _RoundIcon(
                        icon: Icons.bar_chart_rounded,
                        label: 'Statistics',
                        onTap: () => _open(const StatsScreen())),
                    const SizedBox(width: 28),
                    _RoundIcon(
                        icon: Icons.settings_rounded,
                        label: 'Settings',
                        onTap: () => _open(const SettingsScreen())),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 70,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < 5; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Transform.translate(
                    offset: Offset(0, i.isEven ? 0 : 10),
                    child: CustomPaint(
                        size: const Size(44, 44), painter: _LogoBlock(i)),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        ShaderMask(
          shaderCallback: (r) => const LinearGradient(
            colors: [Color(0xFF8A3FFC), Color(0xFFFF5E7E), Color(0xFFFFC52E)],
          ).createShader(r),
          child: const Text('PRISM',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 58,
                  height: 1.0,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 6)),
        ),
        ShaderMask(
          shaderCallback: (r) => const LinearGradient(
            colors: [Color(0xFF12C9BE), Color(0xFF4DA9FF)],
          ).createShader(r),
          child: const Text('BLOCKS',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  height: 1.1,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 10)),
        ),
      ],
    );
  }
}

class _LogoBlock extends CustomPainter {
  final int i;
  _LogoBlock(this.i);

  @override
  void paint(Canvas canvas, Size size) {
    drawBlock(canvas, Offset.zero & size, i);
  }

  @override
  bool shouldRepaint(covariant _LogoBlock old) => false;
}

class _ModeCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final List<Color> colors;
  final VoidCallback onTap;
  const _ModeCard(
      {required this.icon,
      required this.label,
      required this.colors,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$label mode',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 96,
          decoration: BoxDecoration(
            gradient: LinearGradient(
                colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                  color: colors.first.op(0.4), blurRadius: 12, offset: const Offset(0, 5))
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 32),
              const SizedBox(height: 6),
              Text(label,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _RoundIcon({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = GameColors.of(context);
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: c.card,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                  color: Colors.black.op(0.15), blurRadius: 10, offset: const Offset(0, 4))
            ],
          ),
          child: Icon(icon, color: c.text, size: 30),
        ),
      ),
    );
  }
}
