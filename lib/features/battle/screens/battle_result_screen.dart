// ============================================================
// FILE: lib/features/battle/screens/battle_result_screen.dart
// Shown to both players when the battle finishes.
// Fetches scores from Firestore, determines winner, shows result.
// ============================================================

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/battle_model.dart';
import '../../../core/widgets/glass_card.dart';
import '../services/battle_v2_service.dart';

class BattleResultScreen extends StatelessWidget {
  final String battleId;

  const BattleResultScreen({super.key, required this.battleId});

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Container(
              decoration:
                  const BoxDecoration(gradient: AppColors.mainGradient)),
          SafeArea(
            child: StreamBuilder<BattleV2Model>(
              stream: BattleV2Service.battleStream(battleId),
              builder: (context, battleSnap) {
                final battle = battleSnap.data;
                if (battle == null) {
                  return const Center(
                      child:
                          CircularProgressIndicator(color: Colors.white));
                }

                return StreamBuilder<List<BattleV2Player>>(
                  stream: BattleV2Service.playersStream(battleId),
                  builder: (context, playersSnap) {
                    final players = playersSnap.data ?? [];
                    final me = players
                        .where((p) => p.uid == _uid)
                        .firstOrNull;
                    final opponent = players
                        .where((p) => p.uid != _uid)
                        .firstOrNull;

                    final winnerId = battle.winnerId;
                    final isDraw = winnerId == null && battle.isFinished;
                    final iWon = winnerId == _uid;
                    final iLost =
                        !isDraw && winnerId != null && winnerId != _uid;

                    return _ResultContent(
                      me: me,
                      opponent: opponent,
                      iWon: iWon,
                      iLost: iLost,
                      isDraw: isDraw,
                      onPlayAgain: () {
                        // Pop back to battle home
                        Navigator.of(context)
                            .popUntil((route) => route.isFirst);
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultContent extends StatelessWidget {
  final BattleV2Player? me;
  final BattleV2Player? opponent;
  final bool iWon;
  final bool iLost;
  final bool isDraw;
  final VoidCallback onPlayAgain;

  const _ResultContent({
    required this.me,
    required this.opponent,
    required this.iWon,
    required this.iLost,
    required this.isDraw,
    required this.onPlayAgain,
  });

  String get _emoji {
    if (iWon) return '🏆';
    if (iLost) return '😤';
    return '🤝';
  }

  String get _headline {
    if (iWon) return 'You Won!';
    if (iLost) return 'Better Luck Next Time';
    return "It's a Draw!";
  }

  String get _subline {
    if (iWon) return 'Outstanding! You outscored your opponent.';
    if (iLost) return 'Keep practicing — the next battle is yours.';
    return 'Both of you scored equally! Great minds think alike.';
  }

  Color get _resultColor {
    if (iWon) return Colors.greenAccent;
    if (iLost) return Colors.redAccent;
    return Colors.amber;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 20),

          // Result icon
          Text(_emoji, style: const TextStyle(fontSize: 72)),
          const SizedBox(height: 16),

          Text(
            _headline,
            style: TextStyle(
              color: _resultColor,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _subline,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white60, fontSize: 14),
          ),

          const SizedBox(height: 36),

          // Score comparison card
          GlassCard(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                // My score
                Expanded(
                  child: _ScoreColumn(
                    label: 'You',
                    name: me?.name ?? 'You',
                    score: me?.score ?? 0,
                    color: Colors.teal,
                    isWinner: iWon,
                  ),
                ),

                // VS divider
                Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'VS',
                        style: TextStyle(
                            color: Colors.white54,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            letterSpacing: 2),
                      ),
                    ),
                  ],
                ),

                // Opponent score
                Expanded(
                  child: _ScoreColumn(
                    label: 'Opponent',
                    name: opponent?.name ?? 'Opponent',
                    score: opponent?.score ?? 0,
                    color: Colors.blueAccent,
                    isWinner: iLost,
                    alignRight: true,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Submission status
          GlassCard(
            padding: const EdgeInsets.all(16),
            backgroundColor: Colors.white.withOpacity(0.04),
            child: Row(
              children: [
                _StatusRow(
                    label: 'Your submission',
                    done: me?.submitted ?? false),
                const SizedBox(width: 16),
                _StatusRow(
                    label: 'Opponent',
                    done: opponent?.submitted ?? false),
              ],
            ),
          ),

          const Spacer(),

          // Actions
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: onPlayAgain,
              icon: const Icon(Icons.replay),
              label: const Text(
                'Play Another Battle',
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),

          const SizedBox(height: 12),

          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Back to Home',
              style: TextStyle(color: Colors.white54),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreColumn extends StatelessWidget {
  final String label;
  final String name;
  final int score;
  final Color color;
  final bool isWinner;
  final bool alignRight;

  const _ScoreColumn({
    required this.label,
    required this.name,
    required this.score,
    required this.color,
    required this.isWinner,
    this.alignRight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 11),
        ),
        const SizedBox(height: 2),
        Text(
          name.length > 12 ? '${name.substring(0, 12)}...' : name,
          style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w500,
              fontSize: 13),
        ),
        const SizedBox(height: 8),
        Text(
          score.toString(),
          style: TextStyle(
            color: color,
            fontSize: 40,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Text('pts',
            style: TextStyle(color: Colors.white38, fontSize: 12)),
        if (isWinner) ...[
          const SizedBox(height: 4),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'WINNER',
              style: TextStyle(
                  color: Colors.greenAccent,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1),
            ),
          ),
        ],
      ],
    );
  }
}

class _StatusRow extends StatelessWidget {
  final String label;
  final bool done;

  const _StatusRow({required this.label, required this.done});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        children: [
          Icon(
            done ? Icons.check_circle : Icons.pending,
            color: done ? Colors.greenAccent : Colors.amber,
            size: 16,
          ),
          const SizedBox(width: 6),
          Text(
            '$label: ${done ? 'Done' : 'Playing...'}',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
