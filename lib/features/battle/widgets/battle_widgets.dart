// ============================================================
// FILE: lib/features/battle/widgets/battle_widgets.dart
// Small reusable pieces for the 1v1 battle screens, styled with the
// app's existing AppColors / GlassCard.
// ============================================================

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/glass_card.dart';
import '../models/battle_models.dart';

class BattleScaffold extends StatelessWidget {
  final Widget child;
  const BattleScaffold({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(gradient: AppColors.mainGradient),
        child: SafeArea(child: child),
      ),
    );
  }
}

class BattleAvatar extends StatelessWidget {
  final String name;
  final String photoUrl;
  final double radius;
  final Color? ringColor;

  const BattleAvatar({
    super.key,
    required this.name,
    required this.photoUrl,
    this.radius = 28,
    this.ringColor,
  });

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: ringColor ?? Colors.white24, width: 2),
      ),
      child: CircleAvatar(
        radius: radius,
        backgroundColor: Colors.white12,
        foregroundImage: photoUrl.isEmpty ? null : NetworkImage(photoUrl),
        onForegroundImageError: photoUrl.isEmpty ? null : (_, __) {},
        child: Text(
          initial,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: radius * 0.8,
          ),
        ),
      ),
    );
  }
}

class BattlePlayerCard extends StatelessWidget {
  final BattlePlayer player;
  final Color color;
  final bool showReady;
  final bool isMe;

  const BattlePlayerCard({
    super.key,
    required this.player,
    required this.color,
    this.showReady = false,
    this.isMe = false,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      borderColor: color.withOpacity(0.6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BattleAvatar(
              name: player.name, photoUrl: player.photoUrl, radius: 32, ringColor: color),
          const SizedBox(height: 10),
          Text(
            isMe ? '${player.name} (You)' : player.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 6),
          Text('Rating ${player.rating}',
              style: const TextStyle(color: AppColors.battleGold, fontSize: 13)),
          const SizedBox(height: 2),
          Text(
            '${player.played} battles · ${player.winRate.toStringAsFixed(0)}% wins',
            style: const TextStyle(color: Colors.white60, fontSize: 11),
          ),
          if (showReady) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: (player.ready ? AppColors.accentGreen : Colors.white24)
                    .withOpacity(0.25),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                player.ready ? 'Ready' : 'Not ready',
                style: TextStyle(
                  color: player.ready ? AppColors.accentGreen : Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class BattleModeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback? onTap;

  const BattleModeCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: GlassCard(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        borderColor: color.withOpacity(0.5),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(color: Colors.white60, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white38),
          ],
        ),
      ),
    );
  }
}

class StatPill extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const StatPill({super.key, required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                color: color ?? Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
      ],
    );
  }
}

class EmptyOrError extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const EmptyOrError({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(message, style: const TextStyle(color: Colors.white60, fontSize: 13)),
          ),
          if (onRetry != null) TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

void showBattleSnack(BuildContext context, String message) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

String formatSeconds(int s) {
  final m = s ~/ 60;
  final r = s % 60;
  return '${m.toString().padLeft(2, '0')}:${r.toString().padLeft(2, '0')}';
}
