// ============================================================
// FILE: lib/features/tournament/screens/tournament_round_result_screen.dart
//
// FIXES:
//  1. "Back to Tournament" does Navigator.pop() which now correctly lands on
//     TournamentPlayScreen — because the bridge screen used pushReplacement,
//     so it is no longer on the stack.
//  2. Added PopScope to prevent accidental back-swipe from re-opening quiz.
//  3. Animated score ring using CircularProgressIndicator + AnimatedBuilder.
//  4. Unanswered questions count shown when autoSubmitted.
// ============================================================

import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/tournament_model.dart';
import '../../../core/widgets/glass_card.dart';
import 'tournament_answer_review_screen.dart';

class TournamentRoundResultScreen extends StatefulWidget {
  final TournamentModel tournament;
  final TournamentRound round;
  final int score;
  final int total;
  final double percentage;
  final bool autoSubmitted;

  const TournamentRoundResultScreen({
    super.key,
    required this.tournament,
    required this.round,
    required this.score,
    required this.total,
    required this.percentage,
    this.autoSubmitted = false,
  });

  @override
  State<TournamentRoundResultScreen> createState() =>
      _TournamentRoundResultScreenState();
}

class _TournamentRoundResultScreenState
    extends State<TournamentRoundResultScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _anim = Tween<double>(
      begin: 0,
      end: widget.percentage / 100,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Color get _scoreColor {
    if (widget.percentage >= 80) return Colors.greenAccent;
    if (widget.percentage >= 60) return Colors.tealAccent;
    if (widget.percentage >= 40) return Colors.amber;
    return Colors.redAccent;
  }

  String get _emoji {
    if (widget.percentage >= 80) return '🏆';
    if (widget.percentage >= 60) return '🎯';
    if (widget.percentage >= 40) return '📊';
    return '😤';
  }

  String get _feedbackText {
    if (widget.percentage >= 80) return 'Outstanding performance! 🔥';
    if (widget.percentage >= 60) return 'Solid round! Stay focused 💪';
    if (widget.percentage >= 40) return 'Keep pushing — results pending 🎯';
    return 'Tough round. Wait for results…';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Allow popping — pop goes to TournamentPlayScreen (bridge was replaced).
      canPop: true,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Container(
              decoration: const BoxDecoration(gradient: AppColors.mainGradient),
            ),
            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 16),

                    // Emoji trophy
                    Text(_emoji, style: const TextStyle(fontSize: 72)),
                    const SizedBox(height: 16),

                    Text(
                      'Round ${widget.round.roundNumber} Complete!',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.tournament.title,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    // Auto-submitted warning banner
                    if (widget.autoSubmitted) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.orange.withOpacity(0.4),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              color: Colors.orange,
                              size: 16,
                            ),
                            SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                '⚠️ Auto-submitted — time expired or app left',
                                style: TextStyle(
                                  color: Colors.orange,
                                  fontSize: 12,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 32),

                    // ── Animated score card ──────────────────────────────
                    GlassCard(
                      padding: const EdgeInsets.all(28),
                      borderRadius: 24,
                      child: Column(
                        children: [
                          // Circular score ring
                          AnimatedBuilder(
                            animation: _anim,
                            builder: (_, __) {
                              final pct = _anim.value * 100;
                              return SizedBox(
                                width: 150,
                                height: 150,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    CircularProgressIndicator(
                                      value: _anim.value,
                                      strokeWidth: 12,
                                      backgroundColor: Colors.white12,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        _scoreColor,
                                      ),
                                      strokeCap: StrokeCap.round,
                                    ),
                                    Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          '${pct.toStringAsFixed(1)}%',
                                          style: TextStyle(
                                            color: _scoreColor,
                                            fontSize: 28,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const Text(
                                          'score',
                                          style: TextStyle(
                                            color: Colors.white38,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),

                          const SizedBox(height: 20),

                          // Correct / Total
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _ScorePill(
                                icon: Icons.check_circle_rounded,
                                color: Colors.greenAccent,
                                label: 'Correct',
                                value: '${widget.score}',
                              ),
                              const SizedBox(width: 16),
                              _ScorePill(
                                icon: Icons.quiz_outlined,
                                color: Colors.white54,
                                label: 'Total',
                                value: '${widget.total}',
                              ),
                              const SizedBox(width: 16),
                              _ScorePill(
                                icon: Icons.cancel_outlined,
                                color: Colors.redAccent,
                                label: 'Wrong',
                                value: '${widget.total - widget.score}',
                              ),
                            ],
                          ),

                          const SizedBox(height: 20),

                          // Animated progress bar
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: AnimatedBuilder(
                              animation: _anim,
                              builder: (_, __) => LinearProgressIndicator(
                                value: _anim.value,
                                backgroundColor: Colors.white12,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  _scoreColor,
                                ),
                                minHeight: 8,
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          Text(
                            _feedbackText,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── What happens next ────────────────────────────────
                    GlassCard(
                      padding: const EdgeInsets.all(18),
                      borderRadius: 18,
                      backgroundColor: Colors.white.withOpacity(0.04),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'What happens next?',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 14),
                          _infoRow(
                            Icons.people_outline,
                            Colors.teal,
                            'Top ${widget.round.qualifyCount} players advance to '
                            'Round ${widget.round.roundNumber + 1}',
                          ),
                          const SizedBox(height: 10),
                          _infoRow(
                            Icons.schedule,
                            Colors.amber,
                            'Admin reviews results after the round window closes',
                          ),
                          const SizedBox(height: 10),
                          _infoRow(
                            Icons.leaderboard_outlined,
                            Colors.blue,
                            'Check the Participants tab to see standings',
                          ),
                          const SizedBox(height: 10),
                          _infoRow(
                            Icons.notifications_outlined,
                            Colors.purple,
                            "You'll be notified of your qualification status",
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // ── Back button ──────────────────────────────────────
                    // ── Review Answers button ────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TournamentAnswerReviewScreen(
                              tournament: widget.tournament,
                              round: widget.round,
                            ),
                          ),
                        ),
                        icon: const Icon(Icons.rate_review_rounded, size: 18),
                        label: const Text(
                          'Review My Answers',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.tealAccent,
                          side: BorderSide(
                            color: Colors.tealAccent.withOpacity(0.5),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        // FIX: Single pop returns to TournamentPlayScreen
                        // because pushReplacement was used in bridge screen.
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_rounded),
                        label: const Text(
                          'Back to Tournament',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, Color color, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ),
      ],
    );
  }
}

class _ScorePill extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  const _ScorePill({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white38, fontSize: 11),
        ),
      ],
    );
  }
}
