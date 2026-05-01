// ============================================================
// FILE: lib/quizes/home/quiz_attempt_screen.dart  (REPLACE EXISTING)
// Anti-cheat additions:
//   1. WidgetsBindingObserver — detect app backgrounding
//   2. backgroundCount tracked in Firestore — auto-submit at 3 strikes
//   3. Question order shuffled per user (deterministic seed)
//   4. Server endAt is truth — client submits if past deadline
// All existing quiz logic PRESERVED
// ============================================================

import 'dart:async';
import 'dart:math';
import 'package:QuizSphere/quizes/home/quiz_result_screen.dart';
import 'package:QuizSphere/quizes/profile/services/level_service.dart';
import 'package:QuizSphere/quizes/profile/services/streak_service.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:ui' show FontFeature;

import 'package:wakelock_plus/wakelock_plus.dart';

import 'package:QuizSphere/compiler/coding_quiz_screen.dart';

class QuizAttemptScreen extends StatefulWidget {
  final String quizId;
  final DateTime endAt;
  final bool isDaily;
  // NEW optional fields for integrated rewards
  final String topicId;
  final String topicTitle;
  // Mixed quiz support
  final bool isMixed;
  final List<String> codingQuestionIds;

  const QuizAttemptScreen({
    super.key,
    required this.quizId,
    required this.endAt,
    required this.isDaily,
    this.topicId = '',
    this.topicTitle = '',
    this.isMixed = false,
    this.codingQuestionIds = const [],
  });

  @override
  State<QuizAttemptScreen> createState() => _QuizAttemptScreenState();
}

class _QuizAttemptScreenState extends State<QuizAttemptScreen>
    with WidgetsBindingObserver {
  // ← Anti-cheat: lifecycle observer

  int currentIndex = 0;
  final Map<String, int> answers = {};

  bool submitting = false;
  late int remainingSeconds;
  Timer? _timer;

  late Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  _questionsFuture;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _questions = [];

  late final DateTime _startedAt;

  // ── Anti-cheat state ─────────────────────────────────────────────────────
  int _backgroundCount = 0;
  static const int _maxBackgroundWarnings = 3;
  bool _showingWarning = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // ← Register lifecycle observer

    _startedAt = DateTime.now();
    remainingSeconds = widget.endAt
        .difference(DateTime.now())
        .inSeconds
        .clamp(0, 1 << 31);

    _questionsFuture = _loadQuestions();

    WakelockPlus.enable();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // ← Clean up observer
    _timer?.cancel();
    WakelockPlus.disable();
    super.dispose();
  }

  // ── Anti-cheat: detect backgrounding ─────────────────────────────────────
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (submitting) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _handleBackground();
    }
  }

  void _handleBackground() {
    if (!mounted || submitting || _showingWarning) return;
    _backgroundCount++;

    final remaining = _maxBackgroundWarnings - _backgroundCount;

    if (_backgroundCount >= _maxBackgroundWarnings) {
      // Auto-submit after 3 strikes
      _submitQuiz(auto: true, reason: 'cheating');
      return;
    }

    _showingWarning = true;
    _timer?.cancel(); // Pause timer during warning

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          backgroundColor: const Color(0xFF203A43),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange),
              SizedBox(width: 8),
              Text('Warning!', style: TextStyle(color: Colors.orange)),
            ],
          ),
          content: Text(
            'You left the quiz screen.\n\n'
            'Strike $_backgroundCount/$_maxBackgroundWarnings — '
            '${remaining > 0 ? "$remaining more will auto-submit your quiz." : "Auto-submitting now."}',
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _showingWarning = false;
                // Resume timer
                if (remainingSeconds > 0 && !submitting) _startTimer();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Continue Quiz',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      );
    });
  }

  // ================= LOAD QUESTIONS =================
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  _loadQuestions() async {
    final collectionName = widget.isDaily ? 'dailyQuizzes' : 'quizzes';

    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection(collectionName)
        .doc(widget.quizId)
        .collection('questions');

    if (!widget.isDaily) {
      query = query
          .where('type', isEqualTo: 'mcq')
          .where('isActive', isEqualTo: true);
    }

    final snap = await query.get();

    if (snap.docs.isEmpty) throw Exception('No questions found');

    // ── Anti-cheat: shuffle questions using uid as seed ──────────────────
    // Same user always gets same order (prevents refresh-for-different-Qs)
    // Different users get different orders (prevents sharing answers)
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final seed = uid.codeUnits.fold<int>(0, (a, b) => a ^ b);
    final shuffled = List.of(snap.docs)..shuffle(Random(seed));

    _questions = shuffled;

    if (remainingSeconds > 0) {
      _startTimer();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _submitQuiz(auto: true);
      });
    }

    return shuffled;
  }

  // ================= TIMER =================
  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || submitting) return;
      if (remainingSeconds <= 0) {
        timer.cancel();
        _submitQuiz(auto: true);
        return;
      }
      setState(() => remainingSeconds--);
    });
  }

  // ================= SUBMIT QUIZ =================
  Future<void> _submitQuiz({bool auto = false, String reason = ''}) async {
    if (submitting || !mounted) return;
    setState(() => submitting = true);
    _timer?.cancel();

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      // ── Score calculation ─────────────────────────────────────────────
      int score = 0;
      for (final q in _questions) {
        final qData = q.data();
        final correctIdx = (qData['correctIndex'] ?? -1) as int;
        final userAnswer = answers[q.id];
        if (userAnswer != null && userAnswer == correctIdx) score++;
      }

      final total = _questions.length;
      final percentage = total > 0 ? score / total * 100.0 : 0.0;
      final passed = percentage >= 60.0;

      final timeTakenSeconds = DateTime.now().difference(_startedAt).inSeconds;

      final collectionName = widget.isDaily ? 'dailyQuizzes' : 'quizzes';

      // ── Save attempt ──────────────────────────────────────────────────
      await FirebaseFirestore.instance
          .collection(collectionName)
          .doc(widget.quizId)
          .collection('attempts')
          .doc(uid)
          .set({
            'uid': uid,
            'quizId': widget.quizId,
            'score': score,
            'total': total,
            'percentage': percentage,
            'passed': passed,
            'answers': answers, // 🔥 THIS IS THE FIX
            'timeTakenSeconds': timeTakenSeconds,
            'submittedAt': FieldValue.serverTimestamp(),
            'autoSubmitted': auto,
            'backgroundCount': _backgroundCount,
            if (reason.isNotEmpty) 'flaggedReason': reason,
          }, SetOptions(merge: false));

      // ── Save to history (users/{uid}/history — same path history_screen reads) ──
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('history')
          .add({
            'quizId': widget.quizId,
            'quizTitle': widget.topicTitle.isNotEmpty
                ? widget.topicTitle
                : 'Quiz',
            'score': score,
            'total': total,
            'percentage': percentage,
            'isDaily': widget.isDaily,
            'passed': passed,
            'submittedAt': FieldValue.serverTimestamp(),
            'playedAt': FieldValue.serverTimestamp(),
          });

      // ── Daily leaderboard entry ────────────────────────────────────────
      if (widget.isDaily) {
        final user = FirebaseAuth.instance.currentUser;
        await FirebaseFirestore.instance
            .collection('dailyQuizzes')
            .doc(widget.quizId)
            .collection('leaderboard')
            .doc(uid)
            .set({
              'uid': uid,
              'name': user?.displayName ?? 'User',
              'percentage': percentage,
              'score': score,
              'timeTaken': timeTakenSeconds,
              'submittedAt': FieldValue.serverTimestamp(),
            });
      }

      // ── XP + coins + badges (using updated LevelService) ─────────────
      final earnedXp = (percentage * 0.5).round().clamp(0, 50);
      await LevelService.addXp(
        userId: uid,
        earnedXp: earnedXp,
        percentage: percentage,
        isDaily: widget.isDaily,
        topicId: widget.topicId,
        topicTitle: widget.topicTitle,
        correctAnswers: score,
        totalQuestions: total,
      );

      // ── Update streak ─────────────────────────────────────────────────
      await StreakService.updateStreak();

      if (!mounted) return;

      // ── Navigate to result screen ─────────────────────────────────────
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => QuizResultScreen(
            quizId: widget.quizId,
            attemptId: uid,
            quizTitle: widget.topicTitle.isNotEmpty
                ? widget.topicTitle
                : 'Quiz Result',
            score: score,
            total: total,
            percentage: percentage,
            endAt: widget.endAt,
            passed: passed,
            passPercentage: 60.0,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error submitting: $e')));
        setState(() => submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) {
          _showExitConfirm();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          flexibleSpace: _gradientBg(),
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: _showExitConfirm,
          ),
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.timer_outlined, color: Colors.white70, size: 18),
              const SizedBox(width: 4),
              _TimerDisplay(seconds: remainingSeconds),
            ],
          ),
          actions: [
            // Switch to Coding button for mixed quizzes
            if (widget.isMixed && widget.codingQuestionIds.isNotEmpty)
              TextButton.icon(
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      backgroundColor: const Color(0xFF203A43),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      title: const Text(
                        'Switch to Coding?',
                        style: TextStyle(color: Colors.white),
                      ),
                      content: const Text(
                        'Your MCQ answers will be saved. You can switch back anytime.',
                        style: TextStyle(color: Colors.white70),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel',
                              style: TextStyle(color: Colors.white60)),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurpleAccent,
                          ),
                          child: const Text('Switch',
                              style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true && mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CodingQuizScreen(
                          quizId: widget.quizId,
                          endAt: widget.endAt,
                          questionIds: widget.codingQuestionIds,
                          isMixed: true,
                        ),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.code, color: Colors.deepPurpleAccent, size: 16),
                label: const Text(
                  'Coding',
                  style: TextStyle(
                    color: Colors.deepPurpleAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            // Anti-cheat warning indicator
            if (_backgroundCount > 0)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.orange,
                      size: 16,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '$_backgroundCount/$_maxBackgroundWarnings',
                      style: const TextStyle(
                        color: Colors.orange,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Text(
                  '${currentIndex + 1}/${_questions.length}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
        body: Stack(
          children: [
            _gradientBg(),
            FutureBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
              future: _questionsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  );
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error: ${snapshot.error}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  );
                }
                if (_questions.isEmpty) {
                  return const Center(
                    child: Text(
                      'No questions available.',
                      style: TextStyle(color: Colors.white70),
                    ),
                  );
                }
                return _buildQuizBody();
              },
            ),
            if (submitting)
              Container(
                color: Colors.black54,
                child: const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuizBody() {
    final q = _questions[currentIndex].data();
    final qId = _questions[currentIndex].id;
    final options = List<String>.from(q['options'] ?? []);

    return Column(
      children: [
        // ── Progress bar ──────────────────────────────────────────────────
        LinearProgressIndicator(
          value: _questions.isEmpty
              ? 0
              : (currentIndex + 1) / _questions.length,
          backgroundColor: Colors.white12,
          color: Colors.tealAccent,
          minHeight: 3,
        ),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),

                // ── Question ──────────────────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: Colors.white.withOpacity(0.08),
                    border: Border.all(color: Colors.white.withOpacity(0.15)),
                  ),
                  child: Text(
                    q['title'] ?? '',
                    style: const TextStyle(
                      fontSize: 17,
                      color: Colors.white,
                      height: 1.5,
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // ── Options ───────────────────────────────────────────────
                ...options.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final option = entry.value;
                  final selected = answers[qId] == idx;

                  return GestureDetector(
                    onTap: () {
                      if (submitting) return;
                      setState(() => answers[qId] = idx);
                    },
                    child: Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: selected
                            ? Colors.teal.withOpacity(0.25)
                            : Colors.white.withOpacity(0.07),
                        border: Border.all(
                          color: selected
                              ? Colors.tealAccent
                              : Colors.white.withOpacity(0.15),
                          width: selected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 30,
                            height: 30,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: selected
                                  ? Colors.teal
                                  : Colors.white.withOpacity(0.1),
                            ),
                            child: Text(
                              String.fromCharCode(65 + idx),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              option,
                              style: TextStyle(
                                color: selected ? Colors.white : Colors.white70,
                                fontSize: 15,
                                height: 1.3,
                              ),
                            ),
                          ),
                          if (selected)
                            const Icon(
                              Icons.check_circle,
                              color: Colors.tealAccent,
                              size: 20,
                            ),
                        ],
                      ),
                    ),
                  );
                }),

                const SizedBox(height: 32),

                // ── Navigation buttons ─────────────────────────────────────
                Row(
                  children: [
                    if (currentIndex > 0)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => setState(() => currentIndex--),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white30),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text('← Back'),
                        ),
                      ),
                    if (currentIndex > 0) const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: submitting
                            ? null
                            : () {
                                if (currentIndex < _questions.length - 1) {
                                  setState(() => currentIndex++);
                                } else {
                                  _confirmSubmit();
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: currentIndex == _questions.length - 1
                              ? Colors.tealAccent
                              : Colors.white,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          currentIndex == _questions.length - 1
                              ? 'Submit Quiz ✓'
                              : 'Next →',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _confirmSubmit() {
    final answered = answers.length;
    final total = _questions.length;
    final unanswered = total - answered;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF203A43),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Submit Quiz?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          unanswered > 0
              ? 'You have $unanswered unanswered question${unanswered > 1 ? "s" : ""}. Submit anyway?'
              : 'You answered all $total questions. Ready to submit?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Review',
              style: TextStyle(color: Colors.white60),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _submitQuiz();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Submit',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showExitConfirm() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF203A43),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Leave Quiz?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Your progress will be lost. Are you sure?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Stay',
              style: TextStyle(color: Colors.tealAccent),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // close dialog
              Navigator.pop(context); // exit quiz
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Leave', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _gradientBg() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
        ),
      ),
    );
  }
}

// ── Timer display widget ────────────────────────────────────────────────────
class _TimerDisplay extends StatelessWidget {
  final int seconds;
  const _TimerDisplay({required this.seconds});

  @override
  Widget build(BuildContext context) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    final label =
        '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';

    final color = seconds <= 30
        ? Colors.redAccent
        : seconds <= 60
        ? Colors.orange
        : Colors.white;

    return Text(
      label,
      style: TextStyle(
        color: color,
        fontWeight: FontWeight.bold,
        fontSize: 16,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}