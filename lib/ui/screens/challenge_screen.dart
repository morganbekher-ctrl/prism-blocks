import 'package:flutter/material.dart';

import '../../engine/challenge.dart';
import '../../engine/game_state.dart';
import '../../services/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'game_screen.dart';

class ChallengeScreen extends StatefulWidget {
  const ChallengeScreen({super.key});

  @override
  State<ChallengeScreen> createState() => _ChallengeScreenState();
}

class _ChallengeScreenState extends State<ChallengeScreen> {
  Future<void> _start(Challenge ch) async {
    final app = AppState.read(context);
    await app.abandonSavedGame();
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => GameScreen(mode: GameMode.challenge, challenge: ch)));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final app = AppState.of(context);
    final c = GameColors.of(context);
    final today = DateTime.now(); // local device date, never the network
    final list = Challenge.forDate(today);
    const labels = ['Easy', 'Medium', 'Hard'];
    final colors = [
      [const Color(0xFF3FDD98), const Color(0xFF12C9BE)],
      [const Color(0xFFFFC52E), const Color(0xFFFF8A3D)],
      [const Color(0xFFFF5E7E), const Color(0xFF8A3FFC)],
    ];

    return Scaffold(
      body: GameBackground(
        child: SafeArea(
          child: Column(
            children: [
              const ScreenHeader(title: 'Daily Challenges'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${Challenge.dateKey(today)}  \u00b7  new ones at local midnight',
                    style: TextStyle(color: c.textDim),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (_, i) {
                    final ch = list[i];
                    final done = app.stats.challengesDone.containsKey(ch.id);
                    final best = app.stats.challengeBest[ch.id] ?? 0;
                    final frac = (best / ch.target).clamp(0.0, 1.0);
                    return SoftCard(
                      onTap: () => _start(ch),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(colors: colors[i]),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(labels[i],
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12)),
                              ),
                              const Spacer(),
                              if (done)
                                const Row(children: [
                                  Icon(Icons.check_circle_rounded,
                                      color: Color(0xFF3FDD98)),
                                  SizedBox(width: 4),
                                  Text('Completed',
                                      style: TextStyle(
                                          color: Color(0xFF3FDD98),
                                          fontWeight: FontWeight.w700)),
                                ]),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(ch.title,
                              style: TextStyle(
                                  color: c.text,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800)),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: done ? 1.0 : frac,
                              minHeight: 10,
                              color: colors[i].first,
                              backgroundColor: c.cellEmpty,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                              done
                                  ? 'Done!'
                                  : 'Best progress: ${best.clamp(0, ch.target)} / ${ch.target}',
                              style: TextStyle(color: c.textDim, fontSize: 12)),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
