// ============================================================
// FILE: lib/features/tournament/screens/tournament_answer_review_screen.dart
//
// Shows a player's submitted answers for a tournament round.
// • Locked (with countdown) until the round's endAt timestamp.
// • After unlock: shows every question with the player's choice
//   highlighted (green = correct, red = wrong) and the correct
//   answer always marked in green.
// • Skipped questions shown with a clear "Skipped" badge.
// ============================================================

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/tournament_model.dart';
import '../../../core/widgets/glass_card.dart';

class TournamentAnswerReviewScreen extends StatefulWidget {
  final TournamentModel tournament;
  final TournamentRound round;

  const TournamentAnswerReviewScreen({
    super.key,
    required this.tournament,
    required this.round,
  });

  @override
  State<TournamentAnswerReviewScreen> createState() =>
      _TournamentAnswerReviewScreenState();
}

class _TournamentAnswerReviewScreenState
    extends State<TournamentAnswerReviewScreen> {
  final _db  = FirebaseFirestore.instance;
  final _uid = FirebaseAuth.instance.currentUser?.uid ?? '';

  // ── State ────────────────────────────────────────────────────────────────
  bool _loading = true;
  String? _error;

  List<_QuestionData> _questions = [];
  Map<String, int>    _userAnswers = {}; // questionId → selectedOptionIndex

  // Countdown timer (used only while round is still live)
  Timer?  _countdownTimer;
  Duration _remaining = Duration.zero;
  bool get _isUnlocked => DateTime.now().isAfter(widget.round.endAt);

  // ── Lifecycle ────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    if (_isUnlocked) {
      _loadData();
    } else {
      _remaining = widget.round.endAt.difference(DateTime.now());
      _startCountdown();
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final now = DateTime.now();
      if (now.isAfter(widget.round.endAt)) {
        _countdownTimer?.cancel();
        setState(() { _loading = true; });
        _loadData();
      } else {
        setState(() => _remaining = widget.round.endAt.difference(now));
      }
    });
  }

  // ── Data Loading ─────────────────────────────────────────────────────────
  Future<void> _loadData() async {
    setState(() { _loading = true; _error = null; });

    try {
      // 1. Load user's saved answers from participant roundScores
      final participantSnap = await _db
          .collection('tournaments')
          .doc(widget.tournament.id)
          .collection('participants')
          .doc(_uid)
          .get();

      if (!participantSnap.exists) {
        throw Exception('You are not a participant in this tournament.');
      }

      final roundScores = (participantSnap.data()?['roundScores'] as List?) ?? [];
      final roundEntry = roundScores.firstWhere(
        (s) => (s['round'] as int?) == widget.round.roundNumber,
        orElse: () => null,
      );

      if (roundEntry == null) {
        throw Exception('No submission found for Round ${widget.round.roundNumber}.\n'
            'You may not have attempted this round.');
      }

      // Parse saved answers list → map
      final answersList = (roundEntry['answers'] as List?) ?? [];
      final Map<String, int> userAnswers = {};
      for (final entry in answersList) {
        final qId = entry['qId'] as String?;
        final idx  = entry['idx'] as int?;
        if (qId != null && idx != null) userAnswers[qId] = idx;
      }

      // 2. Load questions from Firestore
      if (widget.round.quizId.isEmpty) {
        throw Exception('No quiz assigned to Round ${widget.round.roundNumber}.');
      }

      QuerySnapshot<Map<String, dynamic>> snap;
      try {
        snap = await _db
            .collection('quizzes')
            .doc(widget.round.quizId)
            .collection('questions')
            .orderBy('order')
            .get();
      } catch (_) {
        snap = await _db
            .collection('quizzes')
            .doc(widget.round.quizId)
            .collection('questions')
            .get();
      }

      if (snap.docs.isEmpty) {
        throw Exception('No questions found for this round.');
      }

      // Sort by order field if present
      final docs = snap.docs.toList()
        ..sort((a, b) {
          final aO = a.data()['order'];
          final bO = b.data()['order'];
          if (aO is num && bO is num) return aO.compareTo(bO);
          return 0;
        });

      final questions = docs.map((doc) {
        final d = doc.data();
        return _QuestionData(
          id: doc.id,
          text: _str(d, ['question', 'questionText', 'text', 'title', 'prompt']),
          options: _options(d),
          correctIndex: _correct(d),
        );
      }).toList();

      if (!mounted) return;
      setState(() {
        _questions   = questions;
        _userAnswers = userAnswers;
        _loading     = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error   = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  // ── Field helpers ────────────────────────────────────────────────────────
  static String _str(Map<String, dynamic> d, List<String> keys) {
    for (final k in keys) {
      final v = d[k];
      if (v != null && v.toString().trim().isNotEmpty) return v.toString();
    }
    return '(Question text missing)';
  }

  static List<String> _options(Map<String, dynamic> d) {
    for (final k in ['options', 'choices', 'answers', 'opts']) {
      final v = d[k];
      if (v is List && v.isNotEmpty) return v.map((e) => e.toString()).toList();
    }
    return [];
  }

  static int _correct(Map<String, dynamic> d) {
    for (final k in ['correctIndex', 'correct', 'correctAnswer', 'answerIndex', 'answer']) {
      final v = d[k];
      if (v is int) return v;
      if (v is String) { final p = int.tryParse(v); if (p != null) return p; }
    }
    return -1;
  }

  // ── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Container(decoration: const BoxDecoration(gradient: AppColors.mainGradient)),
          SafeArea(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return Column(
      children: [
        _buildHeader(),
        Expanded(child: _buildContent()),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Round ${widget.round.roundNumber} — Answer Review',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  widget.tournament.title,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (!_loading && !_isUnlocked)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.orange.withOpacity(0.4)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock_rounded, color: Colors.orange, size: 13),
                  SizedBox(width: 5),
                  Text('Locked', style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          if (!_loading && _isUnlocked && _questions.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.teal.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.teal.withOpacity(0.4)),
              ),
              child: Text(
                '${_questions.length} Q',
                style: const TextStyle(color: Colors.tealAccent, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return const Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          CircularProgressIndicator(color: Colors.tealAccent),
          SizedBox(height: 16),
          Text('Loading review...', style: TextStyle(color: Colors.white54, fontSize: 13)),
        ]),
      );
    }

    if (!_isUnlocked) return _buildLockedView();
    if (_error != null) return _buildErrorView();
    if (_questions.isEmpty) return _buildEmptyView();
    return _buildReviewList();
  }

  // ── Locked View ──────────────────────────────────────────────────────────
  Widget _buildLockedView() {
    final h = _remaining.inHours;
    final m = _remaining.inMinutes % 60;
    final s = _remaining.inSeconds % 60;
    final countdownStr = h > 0
        ? '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}'
        : '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Lock icon with glow
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.orange.withOpacity(0.12),
                border: Border.all(color: Colors.orange.withOpacity(0.4), width: 2),
              ),
              child: const Icon(Icons.lock_rounded, color: Colors.orange, size: 48),
            ),
            const SizedBox(height: 24),
            const Text(
              'Review Locked',
              style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              'Answer review is available only after\nthe round window closes.',
              style: TextStyle(color: Colors.white54, fontSize: 14, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            // Countdown
            GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
              borderRadius: 18,
              child: Column(
                children: [
                  const Text(
                    'UNLOCKS IN',
                    style: TextStyle(color: Colors.white38, fontSize: 11, letterSpacing: 1.5, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    countdownStr,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Round closes ${_formatDate(widget.round.endAt)}',
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              '🔒 Come back after the round ends\nto see all correct answers and your score breakdown.',
              style: TextStyle(color: Colors.white30, fontSize: 12, height: 1.5),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ── Error View ───────────────────────────────────────────────────────────
  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyView() {
    return const Center(
      child: Text('No questions found.', style: TextStyle(color: Colors.white54)),
    );
  }

  // ── Summary Banner ───────────────────────────────────────────────────────
  Widget _buildSummaryBanner() {
    final correct  = _questions.where((q) => _userAnswers[q.id] == q.correctIndex).length;
    final skipped  = _questions.where((q) => !_userAnswers.containsKey(q.id)).length;
    final wrong    = _questions.length - correct - skipped;
    final pct      = _questions.isNotEmpty ? correct / _questions.length * 100 : 0.0;
    final color    = pct >= 80 ? Colors.greenAccent : pct >= 60 ? Colors.tealAccent : pct >= 40 ? Colors.amber : Colors.redAccent;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.12), color.withOpacity(0.04)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          // Score ring
          SizedBox(
            width: 64,
            height: 64,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: pct / 100,
                  strokeWidth: 6,
                  backgroundColor: Colors.white12,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  strokeCap: StrokeCap.round,
                ),
                Text(
                  '${pct.toStringAsFixed(0)}%',
                  style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Round ${widget.round.roundNumber} Summary',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _SummaryChip(label: '$correct Correct', color: Colors.greenAccent, icon: Icons.check_circle_rounded),
                    const SizedBox(width: 8),
                    _SummaryChip(label: '$wrong Wrong', color: Colors.redAccent, icon: Icons.cancel_rounded),
                    const SizedBox(width: 8),
                    _SummaryChip(label: '$skipped Skipped', color: Colors.white38, icon: Icons.radio_button_unchecked),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Review List ──────────────────────────────────────────────────────────
  Widget _buildReviewList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
      itemCount: _questions.length + 1, // +1 for the summary header
      itemBuilder: (ctx, i) {
        if (i == 0) return _buildSummaryBanner();
        final q         = _questions[i - 1];
        final userIdx   = _userAnswers[q.id];
        final isCorrect = userIdx != null && userIdx == q.correctIndex;
        final isSkipped = userIdx == null;
        final isWrong   = !isCorrect && !isSkipped;

        return _ReviewQuestionCard(
          number: i,
          question: q,
          userAnswerIndex: userIdx,
          isCorrect: isCorrect,
          isSkipped: isSkipped,
          isWrong: isWrong,
        );
      },
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────
  String _formatDate(DateTime dt) {
    final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final m = dt.minute.toString().padLeft(2, '0');
    return '${months[dt.month - 1]} ${dt.day} • $h:$m $ampm';
  }
}

// ── Question Card ─────────────────────────────────────────────────────────
class _ReviewQuestionCard extends StatelessWidget {
  final int number;
  final _QuestionData question;
  final int? userAnswerIndex;
  final bool isCorrect;
  final bool isSkipped;
  final bool isWrong;

  const _ReviewQuestionCard({
    required this.number,
    required this.question,
    required this.userAnswerIndex,
    required this.isCorrect,
    required this.isSkipped,
    required this.isWrong,
  });

  @override
  Widget build(BuildContext context) {
    // Card border color: green=correct, red=wrong, grey=skipped
    final cardBorderColor = isCorrect
        ? Colors.greenAccent.withOpacity(0.4)
        : isWrong
            ? Colors.redAccent.withOpacity(0.4)
            : Colors.white.withOpacity(0.12);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cardBorderColor, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Question header ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Q number badge
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.08),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Text(
                    '$number',
                    style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    question.text,
                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500, height: 1.5),
                  ),
                ),
                const SizedBox(width: 8),
                // Result badge
                _ResultBadge(isCorrect: isCorrect, isSkipped: isSkipped),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // ── Options ─────────────────────────────────────────────────
          if (question.options.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Text('No options.', style: const TextStyle(color: Colors.white38, fontSize: 12)),
            )
          else
            ...question.options.asMap().entries.map((e) {
              final idx    = e.key;
              final label  = e.value;
              final isUser    = idx == userAnswerIndex;
              final isCorrectOpt = idx == question.correctIndex;

              // Determine styling
              Color bg, border, text;
              IconData? icon;

              if (isCorrectOpt && isUser) {
                // User picked the correct answer ✓
                bg     = Colors.green.withOpacity(0.18);
                border = Colors.greenAccent;
                text   = Colors.greenAccent;
                icon   = Icons.check_circle_rounded;
              } else if (isCorrectOpt && !isUser) {
                // Correct answer (user didn't pick this) — always highlight
                bg     = Colors.green.withOpacity(0.10);
                border = Colors.greenAccent.withOpacity(0.6);
                text   = Colors.greenAccent;
                icon   = Icons.check_circle_outline_rounded;
              } else if (isUser && !isCorrectOpt) {
                // User's wrong pick ✗
                bg     = Colors.red.withOpacity(0.18);
                border = Colors.redAccent;
                text   = Colors.redAccent;
                icon   = Icons.cancel_rounded;
              } else {
                // Unselected, not correct
                bg     = Colors.transparent;
                border = Colors.white12;
                text   = Colors.white54;
              }

              return Container(
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: border, width: isCorrectOpt || isUser ? 1.5 : 1),
                ),
                child: Row(
                  children: [
                    // Letter circle
                    Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: border.withOpacity(0.2),
                        border: Border.all(color: border.withOpacity(0.5)),
                      ),
                      child: Text(
                        String.fromCharCode(65 + idx), // A, B, C, D
                        style: TextStyle(color: text, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(label, style: TextStyle(color: text, fontSize: 14, height: 1.35)),
                    ),
                    if (icon != null) ...[
                      const SizedBox(width: 8),
                      Icon(icon, color: text, size: 20),
                    ],
                    // "Your answer" tag
                    if (isUser) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: text.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'You',
                          style: TextStyle(color: text, fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }),

          // Skipped notice
          if (isSkipped)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  Icon(Icons.radio_button_unchecked, color: Colors.white38, size: 14),
                  const SizedBox(width: 6),
                  const Text('You skipped this question', style: TextStyle(color: Colors.white38, fontSize: 12)),
                ],
              ),
            ),

          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

// ── Small widgets ─────────────────────────────────────────────────────────
class _ResultBadge extends StatelessWidget {
  final bool isCorrect;
  final bool isSkipped;
  const _ResultBadge({required this.isCorrect, required this.isSkipped});

  @override
  Widget build(BuildContext context) {
    if (isSkipped) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text('SKIPPED', style: TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
      );
    }
    if (isCorrect) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.18),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.greenAccent.withOpacity(0.4)),
        ),
        child: const Text('CORRECT', style: TextStyle(color: Colors.greenAccent, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.18),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
      ),
      child: const Text('WRONG', style: TextStyle(color: Colors.redAccent, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  const _SummaryChip({required this.label, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 13),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

// ── Data model ────────────────────────────────────────────────────────────
class _QuestionData {
  final String id;
  final String text;
  final List<String> options;
  final int correctIndex;

  const _QuestionData({
    required this.id,
    required this.text,
    required this.options,
    required this.correctIndex,
  });
}