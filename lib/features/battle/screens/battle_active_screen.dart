// ============================================================
// FILE: lib/features/battle/screens/battle_active_screen.dart
// Both players see this screen once the battle is active.
// Shows a live opponent score sidebar + the quiz itself.
// On submit → calls BattleV2Service.submitResult()
//           → navigates to BattleResultScreen
// ============================================================

import 'dart:async';
import 'package:QuizSphere/core/models/battle_model.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/glass_card.dart';
import '../services/battle_v2_service.dart';
import 'battle_result_screen.dart';

class BattleActiveScreen extends StatefulWidget {
  final String battleId;

  const BattleActiveScreen({super.key, required this.battleId});

  @override
  State<BattleActiveScreen> createState() => _BattleActiveScreenState();
}

class _BattleActiveScreenState extends State<BattleActiveScreen>
    with WidgetsBindingObserver {
  // ── Quiz state ──────────────────────────────────────────────────────────
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _questions = [];
  String _quizId = '';
  bool _loadingQuiz = true;
  String? _loadError;

  int _currentIndex = 0;
  final Map<String, int> _answers = {};
  bool _submitting = false;
  bool _submitted = false;

  // ── Timer ────────────────────────────────────────────────────────────────
  int _remainingSeconds = 0;
  Timer? _timer;
  static const int _defaultQuizSeconds = 600; // 10 min

  // ── Listen for both finished (winner resolved) ───────────────────────────
  late StreamSubscription<BattleV2Model> _battleSub;
  bool _navigatedToResult = false;

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadBattleAndQuiz();

    // Listen for battle to finish (opponent also submitted)
    _battleSub = BattleV2Service.battleStream(widget.battleId)
        .listen(_onBattleUpdate);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _battleSub.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // No auto-submit in battles — just warn
  }

  void _onBattleUpdate(BattleV2Model battle) {
    if (!mounted || _navigatedToResult) return;
    if (battle.isFinished) {
      _navigatedToResult = true;
      _timer?.cancel();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  BattleResultScreen(battleId: widget.battleId),
            ),
          );
        }
      });
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // LOAD BATTLE + QUIZ
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _loadBattleAndQuiz() async {
    try {
      final battle =
          await BattleV2Service.fetchBattle(widget.battleId);
      if (battle == null) {
        setState(() {
          _loadError = 'Battle not found';
          _loadingQuiz = false;
        });
        return;
      }

      _quizId = battle.quizId;

      // Guard: if the battle document is missing a quizId, show a clear error
      // instead of making an invalid Firestore path request (quizzes//questions).
      if (_quizId.isEmpty) {
        if (mounted) {
          setState(() {
            _loadError = 'This battle has no quiz assigned. Please contact the host.';
            _loadingQuiz = false;
          });
        }
        return;
      }

      // Load questions.
      // BUG FIX: The previous primary query filtered by isActive==true.
      // If questions don't have that field set, it returns 0 docs without
      // throwing (so the catch block never fired). We now try orderBy first,
      // and fall back to a plain fetch; in both cases we also retry without
      // any filter if the result set is empty.
      QuerySnapshot<Map<String, dynamic>> snap;
      try {
        snap = await FirebaseFirestore.instance
            .collection('quizzes')
            .doc(_quizId)
            .collection('questions')
            .orderBy('order')
            .get();
      } catch (_) {
        snap = await FirebaseFirestore.instance
            .collection('quizzes')
            .doc(_quizId)
            .collection('questions')
            .get();
      }

      // If the ordered query returned nothing (index missing or no docs),
      // fall back to an unordered fetch.
      if (snap.docs.isEmpty) {
        try {
          snap = await FirebaseFirestore.instance
              .collection('quizzes')
              .doc(_quizId)
              .collection('questions')
              .get();
        } catch (_) {
          // Leave snap as-is; the empty-check below will surface the error.
        }
      }

      if (!mounted) return;
      setState(() {
        _questions = snap.docs;
        _remainingSeconds = _defaultQuizSeconds;
        _loadingQuiz = false;
      });

      _startTimer();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.toString();
        _loadingQuiz = false;
      });
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
        } else {
          _timer?.cancel();
          if (!_submitted) _submitQuiz();
        }
      });
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SUBMIT
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _submitQuiz() async {
    if (_submitting || _submitted || !mounted) return;
    setState(() => _submitting = true);
    _timer?.cancel();

    // Calculate score
    int score = 0;
    for (final q in _questions) {
      // BUG FIX: support both 'correctIndex' and 'correct' field names
      final correctIdx = (q.data()['correctIndex'] as int?) ??
          (q.data()['correct'] as int?) ??
          -1;
      final userAnswer = _answers[q.id];
      if (userAnswer != null && userAnswer == correctIdx) score++;
    }

    final total = _questions.length;

    try {
      await BattleV2Service.submitResult(
        battleId: widget.battleId,
        score: score,
        total: total,
      );
      _submitted = true;

      // Show "waiting for opponent" state if not already navigated
      if (mounted && !_navigatedToResult) {
        setState(() => _submitting = false);
        _showWaitingForOpponent();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  e.toString().replaceFirst('Exception: ', '')),
              backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  void _showWaitingForOpponent() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF203A43),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text('Done! ✅',
            style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Colors.teal),
            const SizedBox(height: 16),
            const Text(
              'Waiting for your opponent to finish...\nResults will appear automatically.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Container(
              decoration: const BoxDecoration(
                  gradient: AppColors.mainGradient)),
          SafeArea(
            child: _buildBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loadingQuiz) {
      return const Center(
          child: CircularProgressIndicator(color: Colors.white));
    }

    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline,
                  color: Colors.redAccent, size: 48),
              const SizedBox(height: 16),
              Text(_loadError!,
                  style: const TextStyle(color: Colors.white),
                  textAlign: TextAlign.center),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    if (_questions.isEmpty) {
      return const Center(
          child: Text('No questions in this quiz',
              style: TextStyle(color: Colors.white60)));
    }

    return Column(
      children: [
        // Battle header with live scores
        _BattleHeader(
          battleId: widget.battleId,
          uid: _uid,
          currentIndex: _currentIndex,
          total: _questions.length,
          remainingSeconds: _remainingSeconds,
        ),

        // Progress
        LinearProgressIndicator(
          value: (_currentIndex + 1) / _questions.length,
          backgroundColor: Colors.white12,
          valueColor:
              const AlwaysStoppedAnimation<Color>(Colors.tealAccent),
          minHeight: 3,
        ),

        // Question
        Expanded(
          child: _submitting
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Colors.white),
                      SizedBox(height: 16),
                      Text('Submitting...',
                          style: TextStyle(color: Colors.white70)),
                    ],
                  ),
                )
              : _BattleQuestionView(
                  question: _questions[_currentIndex],
                  selectedAnswer:
                      _answers[_questions[_currentIndex].id],
                  onAnswer: (idx) {
                    setState(() {
                      _answers[_questions[_currentIndex].id] = idx;
                    });
                  },
                ),
        ),

        // Nav bar
        _BattleNavBar(
          currentIndex: _currentIndex,
          total: _questions.length,
          onPrev: _currentIndex > 0
              ? () => setState(() => _currentIndex--)
              : null,
          onNext: _currentIndex < _questions.length - 1
              ? () => setState(() => _currentIndex++)
              : null,
          onSubmit: _submitQuiz,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BATTLE HEADER — shows both players' live scores + timer
// ─────────────────────────────────────────────────────────────────────────────
class _BattleHeader extends StatelessWidget {
  final String battleId;
  final String uid;
  final int currentIndex;
  final int total;
  final int remainingSeconds;

  const _BattleHeader({
    required this.battleId,
    required this.uid,
    required this.currentIndex,
    required this.total,
    required this.remainingSeconds,
  });

  String get _timerText {
    final m = remainingSeconds ~/ 60;
    final s = remainingSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<BattleV2Player>>(
      stream: BattleV2Service.playersStream(battleId),
      builder: (context, snap) {
        final players = snap.data ?? [];
        final me = players.where((p) => p.uid == uid).firstOrNull;
        final opponent =
            players.where((p) => p.uid != uid).firstOrNull;

        return Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              // My score
              _PlayerScoreChip(
                name: 'You',
                score: me?.score ?? 0,
                color: Colors.teal,
                submitted: me?.submitted ?? false,
              ),

              const Spacer(),

              // Timer
              Column(
                children: [
                  Text(
                    'Q${currentIndex + 1}/$total',
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 11),
                  ),
                  Text(
                    _timerText,
                    style: TextStyle(
                      color: remainingSeconds < 60
                          ? Colors.redAccent
                          : Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),

              const Spacer(),

              // Opponent score
              _PlayerScoreChip(
                name: opponent?.name ?? 'Opponent',
                score: opponent?.score ?? 0,
                color: Colors.blueAccent,
                submitted: opponent?.submitted ?? false,
                isOpponent: true,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PlayerScoreChip extends StatelessWidget {
  final String name;
  final int score;
  final Color color;
  final bool submitted;
  final bool isOpponent;

  const _PlayerScoreChip({
    required this.name,
    required this.score,
    required this.color,
    required this.submitted,
    this.isOpponent = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          isOpponent ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          name.length > 10 ? '${name.substring(0, 10)}...' : name,
          style: const TextStyle(color: Colors.white60, fontSize: 11),
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            if (!isOpponent)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(right: 4),
                decoration: BoxDecoration(
                    shape: BoxShape.circle, color: color),
              ),
            Text(
              score.toString(),
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 20),
            ),
            if (isOpponent)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(left: 4),
                decoration: BoxDecoration(
                    shape: BoxShape.circle, color: color),
              ),
          ],
        ),
        if (submitted)
          Text('Done',
              style: TextStyle(
                  color: color.withOpacity(0.7),
                  fontSize: 10,
                  fontStyle: FontStyle.italic)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// QUESTION VIEW (battle version)
// ─────────────────────────────────────────────────────────────────────────────
class _BattleQuestionView extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> question;
  final int? selectedAnswer;
  final void Function(int) onAnswer;

  const _BattleQuestionView({
    required this.question,
    required this.selectedAnswer,
    required this.onAnswer,
  });

  @override
  Widget build(BuildContext context) {
    final data = question.data();
    // BUG FIX: support both 'question' and 'text' field names
    final questionText =
        (data['question'] as String?)?.trim() ??
        (data['text'] as String?)?.trim() ??
        '';
    // BUG FIX: support both 'options' and 'choices' field names
    final List<String> options;
    if (data['options'] is List) {
      options = List<String>.from(
          (data['options'] as List).map((e) => e?.toString() ?? ''));
    } else if (data['choices'] is List) {
      options = List<String>.from(
          (data['choices'] as List).map((e) => e?.toString() ?? ''));
    } else {
      options = [];
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GlassCard(
            padding: const EdgeInsets.all(18),
            child: Text(
              questionText,
              style: const TextStyle(
                  color: Colors.white, fontSize: 16, height: 1.5),
            ),
          ),
          const SizedBox(height: 16),
          ...List.generate(options.length, (i) {
            final isSelected = selectedAnswer == i;
            final letters = ['A', 'B', 'C', 'D', 'E'];
            final letter = i < letters.length ? letters[i] : '${i + 1}';

            return GestureDetector(
              onTap: () => onAnswer(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: isSelected
                      ? AppColors.battleBlue.withOpacity(0.2)
                      : Colors.white.withOpacity(0.05),
                  border: Border.all(
                      color: isSelected
                          ? AppColors.battleBlue
                          : Colors.white.withOpacity(0.12),
                      width: isSelected ? 1.5 : 1),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected
                            ? AppColors.battleBlue
                            : Colors.white.withOpacity(0.08),
                      ),
                      child: Center(
                        child: Text(letter,
                            style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : Colors.white54,
                                fontWeight: FontWeight.bold,
                                fontSize: 13)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(options[i],
                          style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : Colors.white70,
                              fontSize: 14.5)),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NAV BAR
// ─────────────────────────────────────────────────────────────────────────────
class _BattleNavBar extends StatelessWidget {
  final int currentIndex;
  final int total;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final VoidCallback onSubmit;

  const _BattleNavBar({
    required this.currentIndex,
    required this.total,
    required this.onPrev,
    required this.onNext,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final isLast = currentIndex == total - 1;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        border: Border(
            top: BorderSide(color: Colors.white.withOpacity(0.08))),
      ),
      child: Row(
        children: [
          if (onPrev != null)
            OutlinedButton.icon(
              onPressed: onPrev,
              icon: const Icon(Icons.arrow_back_ios, size: 14),
              label: const Text('Prev'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white70,
                side: const BorderSide(color: Colors.white24),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            )
          else
            const SizedBox(width: 90),

          const Spacer(),

          isLast
              ? ElevatedButton.icon(
                  onPressed: onSubmit,
                  icon: const Icon(Icons.flag_rounded),
                  label: const Text('Finish Battle'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                )
              : ElevatedButton.icon(
                  onPressed: onNext,
                  icon: const Icon(Icons.arrow_forward_ios, size: 14),
                  label: const Text('Next'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
        ],
      ),
    );
  }
}
