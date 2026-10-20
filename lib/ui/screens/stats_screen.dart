import 'package:flutter/material.dart';

import '../../data/achievements.dart';
import '../../services/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppState.of(context);
    final s = app.stats;
    final c = GameColors.of(context);

    Widget tile(String label, String value, IconData icon, Color color) => Expanded(
          child: SoftCard(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
            child: Column(
              children: [
                Icon(icon, color: color, size: 26),
                const SizedBox(height: 6),
                Text(value,
                    style: TextStyle(
                        color: c.text, fontSize: 22, fontWeight: FontWeight.w800)),
                Text(label,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: c.textDim, fontSize: 12)),
              ],
            ),
          ),
        );

    final recent = s.history.reversed.take(20).toList();

    return Scaffold(
      body: GameBackground(
        child: SafeArea(
          child: Column(
            children: [
              const ScreenHeader(title: 'Statistics & Records'),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  children: [
                    SoftCard(
                      child: Row(
                        children: [
                          const Icon(Icons.workspace_premium_rounded,
                              color: Color(0xFFFFC52E), size: 44),
                          const SizedBox(width: 14),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Personal best',
                                  style: TextStyle(color: c.textDim, fontSize: 14)),
                              Text('${s.bestScore}',
                                  style: TextStyle(
                                      color: c.text,
                                      fontSize: 38,
                                      fontWeight: FontWeight.w900)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(children: [
                      tile('Games played', '${s.gamesPlayed}', Icons.sports_esports_rounded,
                          Palette.blocks[0]),
                      const SizedBox(width: 10),
                      tile('Average score', s.averageScore.round().toString(),
                          Icons.show_chart_rounded, Palette.blocks[2]),
                    ]),
                    const SizedBox(height: 10),
                    Row(children: [
                      tile('Lines cleared', '${s.totalLines}', Icons.view_week_rounded,
                          Palette.blocks[1]),
                      const SizedBox(width: 10),
                      tile('Blocks placed', '${s.totalBlocks}', Icons.widgets_rounded,
                          Palette.blocks[3]),
                    ]),
                    const SizedBox(height: 10),
                    Row(children: [
                      tile('Best combo', '${s.bestCombo}', Icons.bolt_rounded,
                          Palette.blocks[4]),
                      const SizedBox(width: 10),
                      tile('Longest streak', '${s.bestStreak}',
                          Icons.local_fire_department_rounded, Palette.blocks[6]),
                      const SizedBox(width: 10),
                      tile('Play time', formatDuration(s.totalPlayMs), Icons.timer_rounded,
                          Palette.blocks[5]),
                    ]),
                    const SizedBox(height: 20),
                    _section(c, 'Best score by mode'),
                    SoftCard(
                      child: Column(
                        children: [
                          for (final m in ['classic', 'zen', 'challenge', 'timeFree'])
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Row(
                                children: [
                                  Text(modeLabel(m),
                                      style: TextStyle(color: c.text, fontSize: 16)),
                                  const Spacer(),
                                  Text('${s.bestFor(m)}',
                                      style: TextStyle(
                                          color: c.text,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800)),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    _section(c, 'Recent games (newest first)'),
                    SoftCard(
                      child: recent.isEmpty
                          ? Text('Play a game and it will show up here.',
                              style: TextStyle(color: c.textDim))
                          : Column(
                              children: [
                                for (final r in recent)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 6),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(modeLabel(r.mode),
                                                  style: TextStyle(
                                                      color: c.text,
                                                      fontWeight: FontWeight.w700)),
                                              Text(formatDate(r.timestamp),
                                                  style: TextStyle(
                                                      color: c.textDim, fontSize: 12)),
                                            ],
                                          ),
                                        ),
                                        Text('${r.score}',
                                            style: TextStyle(
                                                color: c.text,
                                                fontSize: 18,
                                                fontWeight: FontWeight.w800)),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                    ),
                    const SizedBox(height: 20),
                    _section(c,
                        'Achievements  ${s.achievements.length}/${Achievements.all.length}'),
                    SoftCard(
                      child: Column(
                        children: [
                          for (final a in Achievements.all)
                            Builder(builder: (_) {
                              final got = s.achievements.contains(a.id);
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                child: Row(
                                  children: [
                                    Icon(
                                        got
                                            ? Icons.emoji_events_rounded
                                            : Icons.lock_outline_rounded,
                                        color: got
                                            ? const Color(0xFFFFC52E)
                                            : c.textDim.op(0.6)),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(a.title,
                                              style: TextStyle(
                                                  color: got ? c.text : c.textDim,
                                                  fontWeight: FontWeight.w700)),
                                          Text(a.description,
                                              style: TextStyle(
                                                  color: c.textDim, fontSize: 12)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(GameColors c, String t) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(t,
            style: TextStyle(
                color: c.text, fontSize: 18, fontWeight: FontWeight.w800)),
      );
}
