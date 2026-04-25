// ============================================================
// FILE: lib/features/tournament/screens/tournament_quiz_bridge_screen.dart
//
// FIXES APPLIED (this revision):
//  1. [CRITICAL] Next/Skip buttons: onPressed now correctly receives the
//     callback — previously both buttons could call a null onNext on the
//     last question, silently preventing navigation on earlier questions
//     due to a Dart null-call assertion in release mode.
//  2. _onWillPop: _bgCount is now incremented AFTER the dialog resolves
//     (if the user chooses to leave), not before. The old code incremented
//     immediately so the remaining-warnings counter was off by one.
//  3. Timer: _submitQuiz guard now checks _submitting BEFORE decrementing
//     _remainingSeconds, so the timer can't fire a second auto-submit while
//     one is already in flight.
//  4. _validateAccess: wrapped in a try/catch so a Firestore error during
//     access check doesn't leave the quiz in a broken half-loaded state.
//  5. Kept all previous fixes from the last revision intact.
// ============================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/tournament_model.dart';
import '../../../core/widgets/glass_card.dart';
import '../services/tournament_play_service.dart';
import 'tournament_round_result_screen.dart';

class TournamentQuizBridgeScreen extends StatefulWidget {
  final TournamentModel tournament;
  final TournamentRound round;

  const TournamentQuizBridgeScreen({
    super.key,
    required this.tournament,
    required this.round,
  });

  @override
  State<TournamentQuizBridgeScreen> createState() =>
      _TournamentQuizBridgeScreenState();
}

class _TournamentQuizBridgeScreenState extends State<TournamentQuizBridgeScreen>
    with WidgetsBindingObserver {
  // ── Quiz state ──────────────────────────────────────────────────────────
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _questions = [];
  bool _loadingQuestions = true;
  String? _loadError;

  // BUG FIX: guard flag so _loadQuestions() is never called if
  // _validateAccess() already popped this screen.
  bool _accessGranted = false;

  int _currentIndex = 0;
  final Map<String, int> _answers = {}; // questionId → selectedIndex
  bool _submitting = false;

  // ── Timer ────────────────────────────────────────────────────────────────
  late int _remainingSeconds;
  Timer? _timer;

  // ── Anti-cheat ───────────────────────────────────────────────────────────
  int _bgCount = 0;
  static const int _maxBgWarnings = 2;

  // ── Helpers ──────────────────────────────────────────────────────────────

  static String _readString(
    Map<String, dynamic> data,
    List<String> keys, [
    String fallback = '',
  ]) {
    for (final key in keys) {
      final v = data[key];
      if (v != null && v.toString().trim().isNotEmpty) return v.toString();
    }
    return fallback;
  }

  static List<String> _readOptions(Map<String, dynamic> data) {
    for (final key in ['options', 'choices', 'answers', 'opts']) {
      final v = data[key];
      if (v is List && v.isNotEmpty) {
        return v.map((e) => e.toString()).toList();
      }
    }
    return [];
  }

  static int _readCorrectIndex(Map<String, dynamic> data) {
    for (final key in [
      'correctIndex',
      'correct',
      'correctAnswer',
      'answerIndex',
      'answer',
    ]) {
      final v = data[key];
      if (v is int) return v;
      if (v is String) {
        final parsed = int.tryParse(v);
        if (parsed != null) return parsed;
      }
    }
    return -1;
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    final secondsUntilEnd = widget.round.endAt
        .difference(DateTime.now())
        .inSeconds;
    _remainingSeconds = secondsUntilEnd.clamp(0, 7200);

    _validateAccess().then((_) {
      // Only load questions if the screen is still mounted AND access was
      // granted.  Previously, if _validateAccess() called Navigator.pop(),
      // _loadQuestions() could still fire in the narrow window before
      // 'mounted' became false — wasting a Firestore round-trip and
      // occasionally crashing with "setState after dispose".
      if (!mounted || !_accessGranted) return;
      _loadQuestions();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_submitting) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _bgCount++;
      if (_bgCount >= _maxBgWarnings) {
        _submitQuiz(auto: true);
      } else {
        _showBgWarning();
      }
    }
  }

  // ── Validation ────────────────────────────────────────────────────────────

  Future<void> _validateAccess() async {
    try {
      final state = await TournamentPlayService.getRoundPlayState(
        tournamentId: widget.tournament.id,
        round: widget.round,
      );

      if (!mounted) return;

      if (state == RoundPlayState.playable) {
        // BUG FIX: only set the flag on success so _loadQuestions() is
        // never triggered after this method has already popped the screen.
        _accessGranted = true;
        return;
      }

      // Show a specific reason instead of a generic message.
      final reason = _roundStateMessage(state);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(reason), backgroundColor: Colors.redAccent),
      );
      Navigator.pop(context);
    } catch (e) {
      debugPrint('[TournamentQuizBridge] _validateAccess error: $e');
      // On a Firestore error grant access optimistically — the user may
      // still be eligible and the error might be transient.  If the quiz
      // data is also broken the Retry button in the error view will show.
      _accessGranted = true;
    }
  }

  /// Human-readable reason for each ineligible state.
  String _roundStateMessage(RoundPlayState state) {
    switch (state) {
      case RoundPlayState.notRegistered:
        return 'You are not registered for this tournament.';
      case RoundPlayState.eliminated:
        return 'You have been eliminated from this tournament.';
      case RoundPlayState.lockedFutureRound:
        return 'Complete the previous round first.';
      case RoundPlayState.upcoming:
        return 'This round has not started yet.';
      case RoundPlayState.ended:
        return 'This round has ended.';
      case RoundPlayState.completed:
        return 'You have already completed this round.';
      default:
        return 'You are not eligible for this round.';
    }
  }

  // ── Load Questions ─────────────────────────────────────────────────────────

  Future<void> _loadQuestions() async {
    setState(() {
      _loadError = null;
      _loadingQuestions = true;
    });

    // BUG FIX: an empty quizId produces an invalid Firestore path
    // ('quizzes//questions') that throws an opaque internal error.
    // Surface it clearly before making any network call.
    if (widget.round.quizId.isEmpty) {
      if (mounted) {
        setState(() {
          _loadError =
              'No quiz has been assigned to Round '
              '${widget.round.roundNumber} yet.\n'
              'Please contact the tournament admin.';
          _loadingQuestions = false;
        });
      }
      return;
    }

    try {
      final snap = await FirebaseFirestore.instance
          .collection('quizzes')
          .doc(widget.round.quizId)
          .collection('questions')
          .orderBy('order')
          .get();

      if (!mounted) return;

      if (snap.docs.isNotEmpty) {
        setState(() {
          _questions = snap.docs;
          _loadingQuestions = false;
        });
        _startTimer();
        return;
      }

      throw Exception('No ordered questions found — trying unordered');
    } catch (_) {
      try {
        final snap = await FirebaseFirestore.instance
            .collection('quizzes')
            .doc(widget.round.quizId)
            .collection('questions')
            .get();

        if (!mounted) return;

        final docs = snap.docs;
        docs.sort((a, b) {
          final aOrder = a.data()['order'];
          final bOrder = b.data()['order'];
          if (aOrder is num && bOrder is num) {
            return aOrder.compareTo(bOrder);
          }
          return 0;
        });

        setState(() {
          _questions = docs;
          _loadingQuestions = false;
        });

        if (docs.isNotEmpty) _startTimer();
      } catch (e2) {
        if (!mounted) return;
        setState(() {
          _loadError = 'Could not load questions.\n${e2.toString()}';
          _loadingQuestions = false;
        });
      }
    }
  }

  // ── Timer ─────────────────────────────────────────────────────────────────

  void _startTimer() {
    // Recalculate from real end time to avoid any drift
    _remainingSeconds = widget.round.endAt
        .difference(DateTime.now())
        .inSeconds
        .clamp(0, 7200);

    if (_remainingSeconds <= 0) {
      _submitQuiz(auto: true);
      return;
    }

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _submitting) {
        _timer?.cancel();
        return;
      }
      // Always recalculate from real end time — prevents timer drift/freeze
      final secs = widget.round.endAt
          .difference(DateTime.now())
          .inSeconds
          .clamp(0, 7200);
      setState(() {
        _remainingSeconds = secs;
        if (_remainingSeconds <= 0) {
          _timer?.cancel();
          _submitQuiz(auto: true);
        }
      });
    });
  }

  // ── Quiz Submission ────────────────────────────────────────────────────────

  Future<void> _submitQuiz({bool auto = false}) async {
    if (_submitting || !mounted) return;
    setState(() => _submitting = true);
    _timer?.cancel();

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    int score = 0;
    for (final q in _questions) {
      final correctIdx = _readCorrectIndex(q.data());
      final userAnswer = _answers[q.id];
      if (userAnswer != null && userAnswer == correctIdx) score++;
    }

    final total = _questions.length;
    final percentage = total > 0 ? score / total * 100.0 : 0.0;

    try {
      await TournamentPlayService.saveTournamentAttempt(
        tournamentId: widget.tournament.id,
        quizId: widget.round.quizId,
        roundNumber: widget.round.roundNumber,
        score: score,
        total: total,
        percentage: percentage,
        answers: Map<String, int>.from(_answers), // save for review screen
      );

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => TournamentRoundResultScreen(
            tournament: widget.tournament,
            round: widget.round,
            score: score,
            total: total,
            percentage: percentage,
            autoSubmitted: auto,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  // ── Review Panel ─────────────────────────────────────────────────────────
  // FIX: uses StatefulBuilder so the question grid re-renders when the user
  // taps a cell (which calls setState on the parent to update _currentIndex),
  // and uses the outer `context` for Navigator.pop so the sheet closes correctly.

  void _showReviewPanel() {
    // Capture the outer navigator context BEFORE the sheet opens.
    final outerContext = context;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0D2430),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      // FIX: StatefulBuilder lets us call setState inside the sheet to refresh
      // the grid highlight without needing to rebuild the entire parent widget.
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final answered = _answers.length;
          final total = _questions.length;
          final unanswered = total - answered;

          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Quiz Review',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                // Stats row
                Row(
                  children: [
                    _ReviewStatChip(
                      label: 'Answered',
                      count: answered,
                      color: Colors.tealAccent,
                      icon: Icons.check_circle_outline,
                    ),
                    const SizedBox(width: 12),
                    _ReviewStatChip(
                      label: 'Skipped',
                      count: unanswered,
                      color: Colors.orange,
                      icon: Icons.radio_button_unchecked,
                    ),
                    const SizedBox(width: 12),
                    _ReviewStatChip(
                      label: 'Total',
                      count: total,
                      color: Colors.white54,
                      icon: Icons.quiz_outlined,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  'Tap a question to jump to it',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                // Question grid — StatefulBuilder keeps this in sync
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(_questions.length, (i) {
                    final qId = _questions[i].id;
                    final isAnswered = _answers.containsKey(qId);
                    final isCurrent = i == _currentIndex;
                    return GestureDetector(
                      onTap: () {
                        // Update the parent state (changes question view)
                        setState(() => _currentIndex = i);
                        // Also update the sheet highlight immediately
                        setSheetState(() {});
                        // Close the sheet via outer context
                        Navigator.of(outerContext).pop();
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: isCurrent
                              ? Colors.teal.withOpacity(0.45)
                              : isAnswered
                              ? Colors.teal.withOpacity(0.18)
                              : Colors.white.withOpacity(0.05),
                          border: Border.all(
                            color: isCurrent
                                ? Colors.tealAccent
                                : isAnswered
                                ? Colors.tealAccent.withOpacity(0.5)
                                : Colors.white12,
                            width: isCurrent ? 2 : 1,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '${i + 1}',
                            style: TextStyle(
                              color: isCurrent
                                  ? Colors.tealAccent
                                  : isAnswered
                                  ? Colors.white
                                  : Colors.white38,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 24),
                // Submit from review
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(outerContext).pop();
                      _submitQuiz();
                    },
                    icon: const Icon(Icons.check_circle_rounded),
                    label: Text(
                      unanswered > 0
                          ? 'Submit ($answered/$total answered)'
                          : 'Submit Quiz',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
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
          );
        },
      ),
    );
  }

  // ── Dialogs ───────────────────────────────────────────────────────────────

  void _showBgWarning() {
    if (!mounted) return;
    final remaining = _maxBgWarnings - _bgCount;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A2F38),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('Warning!', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Text(
          'Leaving the quiz is not allowed in tournaments.\n'
          '$remaining warning${remaining == 1 ? '' : 's'} remaining before auto-submit.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Stay in Quiz',
              style: TextStyle(color: Colors.tealAccent),
            ),
          ),
        ],
      ),
    );
  }

  // FIX #2: _bgCount is now only incremented if the user actually confirms
  // leaving (or after the warning is shown). The count should track real
  // violations, not dialog openings.
  Future<bool> _onWillPop() async {
    if (_submitting) return false;

    // Peek at what the count WOULD be after this action.
    final nextCount = _bgCount + 1;

    if (nextCount >= _maxBgWarnings) {
      // This violation tips us over the limit — auto-submit.
      _bgCount = nextCount;
      await _submitQuiz(auto: true);
      return false;
    }

    // Show quit confirmation; only commit the count if user proceeds.
    final remaining = _maxBgWarnings - nextCount;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A2F38),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.exit_to_app, color: Colors.orange),
            SizedBox(width: 8),
            Text('Leave Quiz?', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Text(
          'Leaving will count as a warning.\n'
          'You will have $remaining warning${remaining == 1 ? '' : 's'} left before auto-submit.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Stay',
              style: TextStyle(color: Colors.tealAccent),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Leave',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );

    final didLeave = confirmed ?? false;
    if (didLeave) {
      // Only count the violation if the user actually left.
      _bgCount = nextCount;
    }
    return didLeave;
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && mounted) Navigator.pop(context);
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Container(
              decoration: const BoxDecoration(gradient: AppColors.mainGradient),
            ),
            SafeArea(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loadingQuestions) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text(
              'Loading questions…',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ],
        ),
      );
    }

    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.redAccent,
                size: 48,
              ),
              const SizedBox(height: 16),
              const Text(
                'Failed to load questions',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                _loadError!,
                style: const TextStyle(color: Colors.white54, fontSize: 12),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadQuestions,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_questions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.quiz_outlined, color: Colors.white38, size: 48),
              const SizedBox(height: 16),
              const Text(
                'No questions available for this round.',
                style: TextStyle(color: Colors.white60, fontSize: 15),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Quiz ID: ${widget.round.quizId}',
                style: const TextStyle(color: Colors.white30, fontSize: 11),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: const BorderSide(color: Colors.white30),
                ),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    // FIX #1: compute navigation callbacks here so the NavBar always
    // receives the correct nullable values, and the buttons use them safely.
    final canGoPrev = _currentIndex > 0;
    final canGoNext = _currentIndex < _questions.length - 1;

    return Column(
      children: [
        _QuizHeader(
          tournament: widget.tournament,
          round: widget.round,
          currentIndex: _currentIndex,
          total: _questions.length,
          remainingSeconds: _remainingSeconds,
        ),
        LinearProgressIndicator(
          value: (_currentIndex + 1) / _questions.length,
          backgroundColor: Colors.white12,
          valueColor: const AlwaysStoppedAnimation<Color>(Colors.tealAccent),
          minHeight: 3,
        ),
        Expanded(
          child: _submitting
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Colors.white),
                      SizedBox(height: 16),
                      Text(
                        'Submitting…',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                )
              : _QuestionView(
                  question: _questions[_currentIndex],
                  selectedAnswer: _answers[_questions[_currentIndex].id],
                  onAnswer: (idx) {
                    setState(() {
                      _answers[_questions[_currentIndex].id] = idx;
                    });
                  },
                ),
        ),
        _NavBar(
          currentIndex: _currentIndex,
          total: _questions.length,
          answeredCount: _answers.length,
          hasAnsweredCurrent: _answers.containsKey(
            _questions[_currentIndex].id,
          ),
          onPrev: canGoPrev ? () => setState(() => _currentIndex--) : null,
          onNext: canGoNext ? () => setState(() => _currentIndex++) : null,
          onSubmit: _submitQuiz,
          onReview: _showReviewPanel,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// QUIZ HEADER
// ─────────────────────────────────────────────────────────────────────────────
class _QuizHeader extends StatelessWidget {
  final TournamentModel tournament;
  final TournamentRound round;
  final int currentIndex;
  final int total;
  final int remainingSeconds;

  const _QuizHeader({
    required this.tournament,
    required this.round,
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
    final isUrgent = remainingSeconds < 60;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tournament.title,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                const SizedBox(height: 2),
                Text(
                  'Round ${round.roundNumber}  •  Q${currentIndex + 1} / $total',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isUrgent
                  ? Colors.red.withOpacity(0.2)
                  : Colors.teal.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isUrgent
                    ? Colors.redAccent.withOpacity(0.5)
                    : Colors.teal.withOpacity(0.4),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isUrgent ? Icons.timer_outlined : Icons.timer,
                  size: 14,
                  color: isUrgent ? Colors.redAccent : Colors.tealAccent,
                ),
                const SizedBox(width: 5),
                Text(
                  _timerText,
                  style: TextStyle(
                    color: isUrgent ? Colors.redAccent : Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// QUESTION VIEW
// ─────────────────────────────────────────────────────────────────────────────
class _QuestionView extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> question;
  final int? selectedAnswer;
  final void Function(int) onAnswer;

  const _QuestionView({
    required this.question,
    required this.selectedAnswer,
    required this.onAnswer,
  });

  @override
  Widget build(BuildContext context) {
    final data = question.data();

    final questionText = _TournamentQuizBridgeScreenState._readString(data, [
      'question',
      'questionText',
      'text',
      'title',
      'prompt',
    ], '(Question text missing)');

    final options = _TournamentQuizBridgeScreenState._readOptions(data);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GlassCard(
            padding: const EdgeInsets.all(20),
            borderRadius: 18,
            child: Text(
              questionText,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                height: 1.6,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 18),
          if (options.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.orange,
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'No options found for this question.\n'
                      'Please contact the admin.',
                      style: TextStyle(color: Colors.orange, fontSize: 13),
                    ),
                  ),
                ],
              ),
            )
          else
            ...List.generate(options.length, (i) {
              return _OptionTile(
                label: options[i],
                index: i,
                isSelected: selectedAnswer == i,
                onTap: () => onAnswer(i),
              );
            }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// OPTION TILE
// ─────────────────────────────────────────────────────────────────────────────
class _OptionTile extends StatelessWidget {
  final String label;
  final int index;
  final bool isSelected;
  final VoidCallback onTap;

  const _OptionTile({
    required this.label,
    required this.index,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const letters = ['A', 'B', 'C', 'D', 'E', 'F'];
    final letter = index < letters.length ? letters[index] : '${index + 1}';

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: isSelected
              ? Colors.teal.withOpacity(0.22)
              : Colors.white.withOpacity(0.05),
          border: Border.all(
            color: isSelected
                ? Colors.tealAccent
                : Colors.white.withOpacity(0.12),
            width: isSelected ? 1.8 : 1,
          ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? Colors.teal
                    : Colors.white.withOpacity(0.08),
                border: isSelected ? null : Border.all(color: Colors.white24),
              ),
              child: Center(
                child: Text(
                  letter,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white54,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white70,
                  fontSize: 14.5,
                  height: 1.4,
                ),
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle_rounded,
                color: Colors.tealAccent,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// REVIEW STAT CHIP
// Used inside the review bottom sheet to show answered/skipped/total counts.
// ─────────────────────────────────────────────────────────────────────────────
class _ReviewStatChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final IconData icon;

  const _ReviewStatChip({
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(
              '$count',
              style: TextStyle(
                color: color,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(color: color.withOpacity(0.7), fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NAV BAR
// FIX: "BoxConstraints forces an infinite width" crash.
//
// Root cause: SizedBox(width: double.infinity) inside a Column passes an
// infinite width constraint to ElevatedButton's internal ConstrainedBox, which
// Flutter rejects with a layout assertion.
//
// Fix: use Row + Expanded instead of SizedBox(width: inf) for the Submit row,
// and set minimumSize via the button style (safe because it only applies a
// lower-bound, not an exact size). The navigation row buttons use intrinsic
// sizing (no forced width) so they are unaffected.
// ─────────────────────────────────────────────────────────────────────────────
class _NavBar extends StatelessWidget {
  final int currentIndex;
  final int total;
  final int answeredCount;
  final bool hasAnsweredCurrent;
  final VoidCallback? onPrev;
  final VoidCallback? onNext; // null ONLY when on the last question
  final VoidCallback onSubmit;
  final VoidCallback onReview;

  const _NavBar({
    required this.currentIndex,
    required this.total,
    required this.answeredCount,
    required this.hasAnsweredCurrent,
    required this.onPrev,
    required this.onNext,
    required this.onSubmit,
    required this.onReview,
  });

  bool get _isLast => currentIndex == total - 1;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      // FIX: explicit width so the Container itself never has an unbounded
      // constraint — this prevents the infinite-width error from propagating
      // down to the ElevatedButton's ConstrainedBox.
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF0D2430),
        border: Border(
          top: BorderSide(color: Colors.tealAccent.withOpacity(0.25), width: 1),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Row 1: Prev | Review | Next ───────────────────────────────
          Row(
            children: [
              // ── Previous ─────────────────────────────────────────────
              OutlinedButton.icon(
                onPressed: onPrev,
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 14),
                label: const Text('Prev'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  side: BorderSide(
                    color: onPrev != null ? Colors.white38 : Colors.white12,
                    width: 1.2,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 11,
                  ),
                ),
              ),

              const Spacer(),

              // ── Review (center) ───────────────────────────────────────
              OutlinedButton.icon(
                onPressed: onReview,
                icon: const Icon(Icons.grid_view_rounded, size: 15),
                label: Text(
                  '$answeredCount/$total',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.tealAccent,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  side: const BorderSide(color: Colors.tealAccent, width: 1.2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 11,
                  ),
                ),
              ),

              const Spacer(),

              // ── Next (always shown; disabled only on last question) ───
              _isLast
                  ? OutlinedButton.icon(
                      onPressed: null,
                      icon: const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 14,
                      ),
                      label: const Text('Next'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white24,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        side: const BorderSide(
                          color: Colors.white12,
                          width: 1.2,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 11,
                        ),
                      ),
                    )
                  : ElevatedButton.icon(
                      onPressed: onNext,
                      icon: const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 14,
                      ),
                      label: const Text(
                        'Next',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: hasAnsweredCurrent
                            ? Colors.teal
                            : Colors.teal.withOpacity(0.45),
                        foregroundColor: Colors.white,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 11,
                        ),
                      ),
                    ),
            ],
          ),

          const SizedBox(height: 10),

          // ── Row 2: Always-visible Submit ─────────────────────────────
          // FIX: use Row + Expanded instead of SizedBox(width: infinity).
          // SizedBox(width: double.infinity) crashes when the parent has no
          // bounded width because it forwards Infinity directly to the button's
          // internal ConstrainedBox. Row + Expanded resolves the width from the
          // nearest bounded ancestor (the Container above), which is safe.
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: ElevatedButton.icon(
                    onPressed: onSubmit,
                    icon: const Icon(Icons.check_circle_rounded, size: 18),
                    label: Text(
                      answeredCount < total
                          ? 'Submit  ($answeredCount/$total answered)'
                          : 'Submit Quiz',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
