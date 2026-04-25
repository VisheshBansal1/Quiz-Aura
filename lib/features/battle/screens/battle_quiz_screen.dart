// ============================================================
// FILE: lib/features/battle/screens/battle_quiz_screen.dart
// FIXED: Next question button, submit quiz, time's up overlay,
//        loading states, stuck-state recovery, all glitches.
// ============================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/battle_model.dart';
import '../../../core/services/coin_service.dart';
import '../services/battle_service.dart';

class BattleQuizScreen extends StatefulWidget {
  final String battleId;
  const BattleQuizScreen({super.key, required this.battleId});

  @override
  State<BattleQuizScreen> createState() => _BattleQuizScreenState();
}

class _BattleQuizScreenState extends State<BattleQuizScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  final _db = FirebaseFirestore.instance;
  final _uid = FirebaseAuth.instance.currentUser?.uid ?? '';

  int _currentQuestion = 0;
  int _timerSeconds = 20;
  int? _selectedAnswer;
  bool _answered = false;
  bool _battleEnded = false;
  bool _submitting = false;
  bool _finishCalled = false;
  bool _timeUp = false;
  bool _navigatingNext = false;

  Timer? _timer;
  Timer? _battleEndTimeoutTimer;

  List<Map<String, dynamic>> _questions = [];
  bool _questionsLoaded = false;
  String? _loadError;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _battleSub;

  late AnimationController _questionSlideController;
  late AnimationController _timerPulseController;
  late Animation<Offset> _questionSlideAnim;
  late Animation<double> _timerPulseAnim;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _questionSlideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _timerPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _questionSlideAnim =
        Tween<Offset>(begin: const Offset(1.0, 0), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _questionSlideController,
            curve: Curves.easeOutCubic,
          ),
        );
    _timerPulseAnim = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _timerPulseController, curve: Curves.easeInOut),
    );

    _loadBattleAndQuestions();
    _listenToBattle();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _battleEndTimeoutTimer?.cancel();
    _battleSub?.cancel();
    _questionSlideController.dispose();
    _timerPulseController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused &&
        !_battleEnded &&
        !_answered &&
        !_submitting) {
      _onTimeUp();
    }
  }

  // ── Load questions ──────────────────────────────────────────────────────────
  Future<void> _loadBattleAndQuestions() async {
    try {
      final battleSnap = await _db
          .collection('battles')
          .doc(widget.battleId)
          .get();
      if (!battleSnap.exists) {
        if (mounted)
          setState(() {
            _questionsLoaded = true;
            _loadError = 'Battle not found.';
          });
        return;
      }

      final data = battleSnap.data() ?? {};
      final keys = List<String>.from(data['questionIds'] ?? []);

      if (keys.isEmpty) {
        if (mounted)
          setState(() {
            _questionsLoaded = true;
            _loadError = 'No questions assigned to this battle.';
          });
        return;
      }

      final futures = keys.map((key) async {
        try {
          final parts = BattleService.parseQuestionKey(key);
          if ((parts['quizId'] ?? '').isEmpty ||
              (parts['questionId'] ?? '').isEmpty)
            return null;
          final qSnap = await _db
              .collection('quizzes')
              .doc(parts['quizId'])
              .collection('questions')
              .doc(parts['questionId'])
              .get();
          if (!qSnap.exists) return null;
          final qData = qSnap.data()!;
          return <String, dynamic>{
            'id': qSnap.id,
            'question':
                (qData['question'] as String?)?.trim() ??
                (qData['text'] as String?)?.trim() ??
                (qData['title'] as String?)?.trim() ??
                '',
            'options': _normalizeOptions(qData),
            'correctIndex':
                qData['correctIndex'] as int? ?? qData['correct'] as int? ?? 0,
          };
        } catch (e) {
          debugPrint('[BattleQuiz] question load error: $e');
          return null;
        }
      });

      final results = await Future.wait(futures);
      final loaded = results.whereType<Map<String, dynamic>>().toList();

      if (!mounted) return;
      setState(() {
        _questions = loaded;
        _questionsLoaded = true;
      });

      if (loaded.isNotEmpty) {
        _questionSlideController.forward(from: 0);
        _startTimer();
      }
    } catch (e) {
      debugPrint('[BattleQuiz] load error: $e');
      if (mounted)
        setState(() {
          _questionsLoaded = true;
          _loadError = 'Failed to load questions. Please try again.';
        });
    }
  }

  List<String> _normalizeOptions(Map<String, dynamic> data) {
    if (data['options'] is List)
      return List<String>.from(
        (data['options'] as List).map((e) => e?.toString() ?? ''),
      );
    if (data['choices'] is List)
      return List<String>.from(
        (data['choices'] as List).map((e) => e?.toString() ?? ''),
      );
    final lettered = [
      data['a'],
      data['b'],
      data['c'],
      data['d'],
    ].whereType<String>().toList();
    if (lettered.isNotEmpty) return lettered;
    return [];
  }

  // ── Real-time battle listener ───────────────────────────────────────────────
  void _listenToBattle() {
    _battleSub = _db
        .collection('battles')
        .doc(widget.battleId)
        .snapshots()
        .listen((snap) {
          final status = snap.data()?['status'] as String?;
          if (status == 'finished' && !_battleEnded && mounted) {
            // FIX: Only show the result dialog if THIS user has also finished
            // all their questions. If the opponent finishes first, let the
            // current user complete their remaining questions normally.
            // The result dialog will appear once _finalizeBattle() is called.
            if (_finishCalled) {
              _battleEndTimeoutTimer?.cancel();
              _handleBattleEnd(snap.data()?['winnerUid'] as String?);
            }
            // else: opponent finished first — don't block this user.
            // _finalizeBattle already sets a 5-second timeout fallback.
          }
        });
  }

  // ── Timer ───────────────────────────────────────────────────────────────────
  void _startTimer() {
    _timer?.cancel();
    if (mounted) {
      setState(() {
        _timerSeconds = 20;
        _selectedAnswer = null;
        _answered = false;
        _submitting = false;
        _timeUp = false;
        _navigatingNext = false;
      });
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_timerSeconds <= 5 && _timerSeconds > 0) {
        _timerPulseController.forward(from: 0).then((_) {
          if (mounted) _timerPulseController.reverse();
        });
      }
      if (_timerSeconds <= 0) {
        t.cancel();
        if (!_answered) _onTimeUp();
        return;
      }
      setState(() => _timerSeconds--);
    });
  }

  void _onTimeUp() {
    if (_answered || _battleEnded) return;
    _timer?.cancel();
    setState(() {
      _timeUp = true;
      _answered = true;
      _timerSeconds = 0;
    });
    // Auto-submit after showing "Time's Up" for 1.5s
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (!mounted || _navigatingNext) return;
      _submitAndAdvance(forceWrong: true);
    });
  }

  // ── Answer selection ────────────────────────────────────────────────────────
  void _selectAnswer(int index) {
    if (_answered || _battleEnded || _submitting || _navigatingNext) return;
    _timer?.cancel();
    setState(() {
      _selectedAnswer = index;
      _answered = true;
      _timeUp = false;
    });
    // Answer recorded — user now taps "Next Question" button to advance
    _recordAnswerToFirestore(selectedIdx: index, forceWrong: false);
  }

  Future<void> _recordAnswerToFirestore({
    required int? selectedIdx,
    required bool forceWrong,
  }) async {
    if (_questions.isEmpty || _currentQuestion >= _questions.length) return;
    final q = _questions[_currentQuestion];
    final correctIndex = (q['correctIndex'] ?? 0) as int;
    final correct = !forceWrong && selectedIdx == correctIndex;
    final timeTaken = (20 - _timerSeconds).clamp(0, 20) * 1000;
    try {
      await BattleService.submitAnswer(
        battleId: widget.battleId,
        correct: correct,
        timeTakenMs: timeTaken,
        questionIndex: _currentQuestion,
      );
    } catch (e) {
      debugPrint('[BattleQuiz] submitAnswer error: $e');
    }
  }

  // ── Next button tap ─────────────────────────────────────────────────────────
  Future<void> _goToNext() async {
    if (_navigatingNext || _battleEnded) return;
    setState(() => _navigatingNext = true);
    final isLast = _currentQuestion + 1 >= _questions.length;
    if (isLast) {
      await _finalizeBattle();
    } else {
      setState(() {
        _currentQuestion++;
        _navigatingNext = false;
      });
      _questionSlideController.forward(from: 0);
      _startTimer();
    }
  }

  // ── Auto-advance (for time-up) ──────────────────────────────────────────────
  Future<void> _submitAndAdvance({required bool forceWrong}) async {
    if (_navigatingNext || _battleEnded) return;
    setState(() => _navigatingNext = true);
    if (forceWrong)
      await _recordAnswerToFirestore(selectedIdx: null, forceWrong: true);
    final isLast = _currentQuestion + 1 >= _questions.length;
    if (isLast) {
      await _finalizeBattle();
    } else {
      if (!mounted) return;
      setState(() {
        _currentQuestion++;
        _navigatingNext = false;
      });
      _questionSlideController.forward(from: 0);
      _startTimer();
    }
  }

  // ── Finalize ────────────────────────────────────────────────────────────────
  Future<void> _finalizeBattle() async {
    if (_finishCalled) return;
    _finishCalled = true;
    if (mounted) setState(() => _submitting = true);
    try {
      await BattleService.finishBattle(battleId: widget.battleId);
    } catch (e) {
      debugPrint('[BattleQuiz] finishBattle error: $e');
    }
    if (mounted)
      setState(() {
        _submitting = false;
        _navigatingNext = false;
      });

    // Fallback: if Firestore stream doesn't fire in 5s, force end
    _battleEndTimeoutTimer = Timer(const Duration(seconds: 5), () async {
      if (!mounted || _battleEnded) return;
      try {
        final snap = await _db.collection('battles').doc(widget.battleId).get();
        _handleBattleEnd(snap.data()?['winnerUid'] as String?);
      } catch (_) {
        _handleBattleEnd(null);
      }
    });
  }

  // ── Handle battle end dialog ────────────────────────────────────────────────
  void _handleBattleEnd(String? winnerUid) {
    if (!mounted || _battleEnded) return;
    setState(() {
      _battleEnded = true;
      _navigatingNext = false;
      _submitting = false;
    });
    _timer?.cancel();
    _battleEndTimeoutTimer?.cancel();

    final isWinner = winnerUid == _uid;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ResultDialog(
        isWinner: isWinner,
        battleId: widget.battleId,
        myUid: _uid,
        totalQuestions: _questions.length,
        onBack: () {
          Navigator.of(context).pop();
          Navigator.of(context).pop();
        },
      ),
    );
  }

  // ── BUILD ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: const BoxDecoration(gradient: AppColors.mainGradient),
            ),
            SafeArea(child: _buildBody()),

            // Submitting overlay (only while finalizing)
            if (_submitting && _finishCalled)
              Container(
                color: Colors.black54,
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Colors.tealAccent),
                      SizedBox(height: 16),
                      Text(
                        'Submitting quiz...',
                        style: TextStyle(color: Colors.white70, fontSize: 15),
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

  Widget _buildBody() {
    if (!_questionsLoaded) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.tealAccent),
            SizedBox(height: 16),
            Text(
              'Loading battle...',
              style: TextStyle(color: Colors.white70, fontSize: 15),
            ),
          ],
        ),
      );
    }
    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.redAccent,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                _loadError!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 15),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }
    if (_questions.isEmpty) {
      return const Center(
        child: Text(
          'No questions available',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }
    return _buildQuizContent();
  }

  Widget _buildQuizContent() {
    final q = _questions[_currentQuestion];
    final options = List<String>.from(q['options'] ?? []);
    final correct = (q['correctIndex'] ?? 0) as int;
    final questionText = (q['question'] as String?)?.trim() ?? '';
    final isLast = _currentQuestion + 1 >= _questions.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _LiveScoreBar(
          battleId: widget.battleId,
          myUid: _uid,
          totalQs: _questions.length,
          currentQ: _currentQuestion + 1,
          timerSecs: _timerSeconds,
          pulseAnim: _timerPulseAnim,
        ),

        // Timer progress bar
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          height: 6,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3),
            color: Colors.white10,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: _timerSeconds / 20,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(
                _timeUp
                    ? Colors.redAccent
                    : _timerSeconds <= 5
                    ? Colors.redAccent
                    : _timerSeconds <= 10
                    ? Colors.orangeAccent
                    : Colors.tealAccent,
              ),
              minHeight: 6,
            ),
          ),
        ),

        // Time's Up Banner
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: _timeUp
              ? Container(
                  key: const ValueKey('timesup'),
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.redAccent.withOpacity(0.5),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.timer_off_rounded,
                        color: Colors.redAccent,
                        size: 18,
                      ),
                      SizedBox(width: 8),
                      Text(
                        "⏰ Time's Up!",
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink(key: ValueKey('notimesup')),
        ),

        // Question + Options — scrollable, never clips the Next button
        Expanded(
          child: SlideTransition(
            position: _questionSlideAnim,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Question card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.12)),
                    ),
                    child: questionText.isEmpty
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                color: Colors.amber,
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Question data unavailable',
                                style: TextStyle(color: Colors.white54),
                              ),
                            ],
                          )
                        : Text(
                            questionText,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w500,
                              height: 1.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                  ),

                  const SizedBox(height: 16),

                  // Options
                  if (options.isEmpty)
                    const Center(
                      child: Text(
                        'No options available.',
                        style: TextStyle(color: Colors.white54),
                      ),
                    )
                  else
                    ...options.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final option = entry.value.trim();

                      Color bgColor = Colors.white.withOpacity(0.07);
                      Color borderColor = Colors.white.withOpacity(0.12);
                      Color textColor = Colors.white;
                      IconData? icon;

                      if (_answered) {
                        if (idx == correct) {
                          bgColor = Colors.green.withOpacity(0.2);
                          borderColor = Colors.greenAccent;
                          textColor = Colors.greenAccent;
                          icon = Icons.check_circle_rounded;
                        } else if (idx == _selectedAnswer) {
                          bgColor = Colors.red.withOpacity(0.2);
                          borderColor = Colors.redAccent;
                          textColor = Colors.redAccent;
                          icon = Icons.cancel_rounded;
                        }
                      } else if (_selectedAnswer == idx) {
                        bgColor = Colors.teal.withOpacity(0.25);
                        borderColor = Colors.tealAccent;
                        textColor = Colors.tealAccent;
                      }

                      return GestureDetector(
                        onTap: (_answered || _battleEnded || _navigatingNext)
                            ? null
                            : () => _selectAnswer(idx),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOut,
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            color: bgColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: borderColor, width: 1.5),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: borderColor.withOpacity(0.25),
                                  border: Border.all(
                                    color: borderColor.withOpacity(0.6),
                                  ),
                                ),
                                child: Text(
                                  String.fromCharCode(65 + idx),
                                  style: TextStyle(
                                    color: textColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  option.isEmpty ? '(empty option)' : option,
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 15,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                              if (icon != null) ...[
                                const SizedBox(width: 8),
                                Icon(icon, color: textColor, size: 22),
                              ],
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),
        ),

        // ── Next / Submit button ─────────────────────────────────────────────
        // FIXED: Placed OUTSIDE the ScrollView so it is always visible at the
        // bottom of the screen immediately after the user selects an answer,
        // regardless of how far the options list scrolls.
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.4),
                end: Offset.zero,
              ).animate(anim),
              child: child,
            ),
          ),
          // FIX: Show the button when user has answered, even if
          // the opponent has already finished (_battleEnded=true). Only hide
          // it after this user has also submitted (_finishCalled=true).
          child: (_answered && !(_battleEnded && _finishCalled))
              ? Padding(
                  key: ValueKey('next_pad_$_currentQuestion'),
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _NextButton(
                        key: ValueKey('next_btn_$_currentQuestion'),
                        isLast: isLast,
                        isLoading: _navigatingNext,
                        onTap: _goToNext,
                      ),
                      if (!_timeUp && !_navigatingNext)
                        const Padding(
                          padding: EdgeInsets.only(top: 6),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                color: Colors.white30,
                                size: 13,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Your answer is saved',
                                style: TextStyle(
                                  color: Colors.white30,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                )
              : const SizedBox.shrink(key: ValueKey('next_hidden')),
        ),
      ],
    );
  }
}

// ── Next/Submit button widget ─────────────────────────────────────────────────
class _NextButton extends StatelessWidget {
  final bool isLast;
  final bool isLoading;
  final VoidCallback onTap;

  const _NextButton({
    super.key,
    required this.isLast,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        onPressed: isLoading ? null : onTap,
        icon: isLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Icon(
                isLast
                    ? Icons.check_circle_rounded
                    : Icons.arrow_forward_rounded,
                size: 20,
              ),
        label: Text(
          isLoading
              ? 'Please wait...'
              : (isLast ? 'Submit Quiz' : 'Next Question'),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: isLast ? const Color(0xFF2E7D32) : Colors.teal,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.teal.withOpacity(0.4),
          disabledForegroundColor: Colors.white54,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 4,
        ),
      ),
    );
  }
}

// ── Result dialog ─────────────────────────────────────────────────────────────
class _ResultDialog extends StatelessWidget {
  final bool isWinner;
  final String battleId;
  final String myUid;
  final int totalQuestions;
  final VoidCallback onBack;

  const _ResultDialog({
    required this.isWinner,
    required this.battleId,
    required this.myUid,
    required this.totalQuestions,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1A2B3C), Color(0xFF0F1E2D)],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isWinner
                ? AppColors.battleGold.withOpacity(0.5)
                : Colors.white.withOpacity(0.15),
            width: 1.5,
          ),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isWinner
                    ? AppColors.battleGold.withOpacity(0.15)
                    : Colors.white.withOpacity(0.08),
              ),
              child: Icon(
                isWinner
                    ? Icons.emoji_events_rounded
                    : Icons.sentiment_dissatisfied_rounded,
                size: 40,
                color: isWinner ? AppColors.battleGold : Colors.white54,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isWinner ? '🏆 You Won!' : 'You Lost',
              style: TextStyle(
                color: isWinner ? AppColors.battleGold : Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isWinner
                  ? '+${CoinService.battleWinReward} coins awarded!'
                  : 'Better luck next time!',
              style: TextStyle(
                color: isWinner ? Colors.amber.shade300 : Colors.white60,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),

            StreamBuilder<List<BattleV2Player>>(
              stream: BattleService.scoresStream(battleId),
              builder: (ctx, snap) {
                final scores = snap.data ?? [];
                if (scores.isEmpty) {
                  return const SizedBox(
                    height: 48,
                    child: Center(
                      child: CircularProgressIndicator(
                        color: Colors.tealAccent,
                        strokeWidth: 2,
                      ),
                    ),
                  );
                }
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Column(
                    children: scores.asMap().entries.map((e) {
                      final rank = e.key + 1;
                      final player = e.value;
                      final isMe = player.uid == myUid;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.rankColor(
                                  rank,
                                ).withOpacity(0.2),
                              ),
                              child: Text(
                                '#$rank',
                                style: TextStyle(
                                  color: AppColors.rankColor(rank),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                isMe ? '${player.name} (You)' : player.name,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isMe
                                      ? Colors.tealAccent
                                      : Colors.white,
                                  fontWeight: isMe
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.amber.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${player.score}/$totalQuestions',
                                style: const TextStyle(
                                  color: Colors.amber,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                );
              },
            ),

            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: onBack,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Back to Lobby',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Live score bar ────────────────────────────────────────────────────────────
class _LiveScoreBar extends StatelessWidget {
  final String battleId;
  final String myUid;
  final int totalQs;
  final int currentQ;
  final int timerSecs;
  final Animation<double> pulseAnim;

  const _LiveScoreBar({
    required this.battleId,
    required this.myUid,
    required this.totalQs,
    required this.currentQ,
    required this.timerSecs,
    required this.pulseAnim,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<BattleV2Player>>(
      stream: BattleService.scoresStream(battleId),
      builder: (context, snapshot) {
        final scores = snapshot.data ?? [];
        final timerColor = timerSecs <= 5
            ? Colors.redAccent
            : timerSecs <= 10
            ? Colors.orangeAccent
            : Colors.tealAccent;

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.07),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
          child: Row(
            children: [
              Expanded(child: _buildPlayerScore(scores, myUid, isLeft: true)),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Q$currentQ/$totalQs',
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  ScaleTransition(
                    scale: pulseAnim,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: timerColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: timerColor.withOpacity(0.4),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.timer_rounded,
                            color: timerColor,
                            size: 14,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '$timerSecs',
                            style: TextStyle(
                              color: timerColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              Expanded(child: _buildPlayerScore(scores, myUid, isLeft: false)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPlayerScore(
    List<BattleV2Player> scores,
    String myUid, {
    required bool isLeft,
  }) {
    final player = isLeft
        ? scores.where((s) => s.uid == myUid).firstOrNull
        : scores.where((s) => s.uid != myUid).firstOrNull;

    if (player == null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: isLeft
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.end,
        children: [
          Text(
            isLeft ? 'You' : 'Opponent',
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
          const SizedBox(height: 2),
          Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white10,
            ),
            child: const Center(
              child: SizedBox(
                width: 10,
                height: 10,
                child: CircularProgressIndicator(
                  color: Colors.white24,
                  strokeWidth: 1.5,
                ),
              ),
            ),
          ),
        ],
      );
    }

    final isMe = player.uid == myUid;
    final color = isMe ? Colors.tealAccent : Colors.white;
    final displayName = player.name.isNotEmpty
        ? (player.name.split(' ').first.length > 10
              ? '${player.name.split(' ').first.substring(0, 10)}…'
              : player.name.split(' ').first)
        : (isMe ? 'You' : 'Opponent');

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: isLeft
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.end,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLeft) ...[
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(shape: BoxShape.circle, color: color),
              ),
              const SizedBox(width: 4),
            ],
            Text(
              displayName,
              style: TextStyle(
                color: color.withOpacity(0.8),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (!isLeft) ...[
              const SizedBox(width: 4),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(shape: BoxShape.circle, color: color),
              ),
            ],
          ],
        ),
        const SizedBox(height: 2),
        Text(
          '${player.score}',
          style: TextStyle(
            color: color,
            fontSize: 24,
            fontWeight: FontWeight.bold,
            height: 1,
          ),
        ),
      ],
    );
  }
}
