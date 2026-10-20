import 'package:flutter/material.dart';

import '../theme.dart';

/// Full-screen gradient background used by every screen.
class GameBackground extends StatelessWidget {
  final Widget child;
  const GameBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final c = GameColors.of(context);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [c.bgTop, c.bgBottom],
        ),
      ),
      child: child,
    );
  }
}

class GradientButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onPressed;
  final List<Color> colors;
  final double height;

  const GradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.colors = const [Color(0xFF8A3FFC), Color(0xFFFF5E7E)],
    this.height = 60,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          height: height,
          constraints: const BoxConstraints(minWidth: 140),
          padding: const EdgeInsets.symmetric(horizontal: 28),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: colors),
            borderRadius: BorderRadius.circular(height / 2),
            boxShadow: [
              BoxShadow(
                color: colors.first.op(0.45),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, color: Colors.white, size: 26),
                const SizedBox(width: 10),
              ],
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SoftCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  const SoftCard(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.all(16),
      this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = GameColors.of(context);
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
              color: Colors.black.op(0.12), blurRadius: 14, offset: const Offset(0, 6))
        ],
      ),
      child: child,
    );
    if (onTap == null) return card;
    return GestureDetector(onTap: onTap, child: card);
  }
}

class ScreenHeader extends StatelessWidget {
  final String title;
  const ScreenHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    final c = GameColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back',
            iconSize: 28,
            constraints: const BoxConstraints(minWidth: 52, minHeight: 52),
            icon: Icon(Icons.arrow_back_rounded, color: c.text),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: 4),
          Text(title,
              style: TextStyle(
                  color: c.text, fontSize: 26, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

String modeLabel(String name) {
  switch (name) {
    case 'classic':
      return 'Classic';
    case 'zen':
      return 'Zen';
    case 'challenge':
      return 'Challenge';
    case 'timeFree':
      return 'Time-Free';
    default:
      return name;
  }
}

String formatDuration(int ms) {
  final totalMin = ms ~/ 60000;
  if (totalMin < 60) return '${totalMin}m';
  return '${totalMin ~/ 60}h ${totalMin % 60}m';
}

String formatDate(int ts) {
  final d = DateTime.fromMillisecondsSinceEpoch(ts);
  String two(int v) => v.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)}  ${two(d.hour)}:${two(d.minute)}';
}
