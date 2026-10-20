import 'package:flutter/material.dart';

import '../../services/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _confirmReset(BuildContext context, AppState app) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset all statistics?'),
        content: const Text(
            'This permanently deletes your scores, records, achievements and any '
            'saved game on this device. It cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFFE5365A)),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Reset everything')),
        ],
      ),
    );
    if (ok == true) {
      await app.resetStatistics();
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Statistics reset')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppState.of(context);
    final s = app.settings;
    final c = GameColors.of(context);

    Widget sw(String title, String sub, bool value, void Function(bool) onChanged) =>
        SwitchListTile(
          title: Text(title,
              style: TextStyle(color: c.text, fontWeight: FontWeight.w700)),
          subtitle: Text(sub, style: TextStyle(color: c.textDim, fontSize: 12)),
          value: value,
          onChanged: onChanged,
        );

    Widget heading(String t) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
          child: Text(t,
              style: TextStyle(
                  color: c.text, fontSize: 18, fontWeight: FontWeight.w800)),
        );

    return Scaffold(
      body: GameBackground(
        child: SafeArea(
          child: Column(
            children: [
              const ScreenHeader(title: 'Settings'),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 32),
                  children: [
                    heading('Sound & feel'),
                    sw('Sound effects', 'Short sounds for placing and clearing', s.sfx,
                        (v) => app.updateSettings((x) => x.sfx = v)),
                    sw('Music', 'Calm background loop', s.music,
                        (v) => app.updateSettings((x) => x.music = v)),
                    sw('Vibration', 'Haptic feedback where supported', s.haptics,
                        (v) => app.updateSettings((x) => x.haptics = v)),
                    heading('Appearance'),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'system', label: Text('System')),
                          ButtonSegment(value: 'light', label: Text('Light')),
                          ButtonSegment(value: 'dark', label: Text('Dark')),
                        ],
                        selected: {s.theme},
                        onSelectionChanged: (v) =>
                            app.updateSettings((x) => x.theme = v.first),
                      ),
                    ),
                    heading('Accessibility & help'),
                    sw('Colour-blind assist', 'Adds a unique symbol to every block colour',
                        s.colorAssist, (v) => app.updateSettings((x) => x.colorAssist = v)),
                    sw('Move hints', 'Show a hint button during play', s.hints,
                        (v) => app.updateSettings((x) => x.hints = v)),
                    ListTile(
                      title: Text('Replay tutorial',
                          style: TextStyle(color: c.text, fontWeight: FontWeight.w700)),
                      trailing: Icon(Icons.chevron_right, color: c.textDim),
                      onTap: () async {
                        await app.updateSettings((x) => x.tutorialSeen = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                              content: Text('The tutorial will show in your next Classic game')));
                        }
                      },
                    ),
                    heading('Privacy'),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: SoftCard(
                        child: Text(
                          'Prism Blocks works completely offline. It has no accounts, '
                          'no ads, no analytics and no network access. Your scores, '
                          'records and settings are stored only on this device and are '
                          'not synchronised with any other device.\n\n'
                          'Daily challenges are generated from this device\u2019s local date, '
                          'so they rotate at your local midnight and your challenge '
                          'records are local to this device.',
                          style: TextStyle(color: c.textDim, height: 1.4),
                        ),
                      ),
                    ),
                    heading('Data'),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFE5365A),
                          minimumSize: const Size.fromHeight(52),
                        ),
                        icon: const Icon(Icons.delete_outline_rounded),
                        label: const Text('Reset statistics'),
                        onPressed: () => _confirmReset(context, app),
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
}
