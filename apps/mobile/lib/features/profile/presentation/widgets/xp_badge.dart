// lib/features/users/presentation/widgets/xp_badge.dart
import 'package:flutter/material.dart';
import '../../domain/xp_levels.dart';

class XPBadge extends StatelessWidget {
  final int xp;
  const XPBadge({super.key, required this.xp});

  @override
  Widget build(BuildContext context) {
    final level = XPLevels.getLevel(xp);
    final rank = XPLevels.getRankName(level);
    final progress = XPLevels.getProgressPercent(xp).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          "Nivel $level • $rank",
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.white10,
            color: Colors.blueAccent,
            minHeight: 8,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          "$xp XP",
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }
}
