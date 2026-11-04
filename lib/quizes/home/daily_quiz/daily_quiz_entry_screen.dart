import 'dart:async';

import 'package:QuizSphere/quizes/home/daily_quiz/daily_quiz_clock.dart';
import 'package:QuizSphere/quizes/home/daily_quiz/daily_quiz_leaderboard_screen.dart';
import 'package:QuizSphere/quizes/home/quiz_attempt_screen.dart';
import 'package:QuizSphere/quizes/home/quiz_result_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class DailyQuizEntryScreen extends StatelessWidget {
  const DailyQuizEntryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const DailyQuizDetailScreen();
  }

  static Widget gradientBg() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
        ),
      ),
    );
  }

  static Widget glassButton({
    required String text,
    required VoidCallback? onTap,
  }) {
    final disabled = onTap == null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: disabled
              ? Colors.grey.withOpacity(0.2)
              : Colors.white.withOpacity(0.15),
          border: Border.all(
            color: disabled ? Colors.grey : Colors.white.withOpacity(0.3),
          ),
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              color: disabled ? Colors.grey : Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

class DailyQuizDetailScreen extends StatefulWidget {
  const DailyQuizDetailScreen({super.key});

  @override
  State<DailyQuizDetailScreen> createState() => _DailyQuizDetailScreenState();
}

class _DailyQuizDetailScreenState extends State<DailyQuizDetailScreen> {
  Map<String, dynamic>? quizData;
  Map<String, dynamic>? myAttempt;
  bool loading = true;
  bool alreadyPlayed = false;
  int playersToday = 0;

  /// Id of the quiz currently on screen (IST date). Re-evaluated every
  /// second so the screen flips to the new quiz right after 12:00 AM.
  String _quizId = DailyQuizClock.todayId();
  Duration _untilNext = DailyQuizClock.untilNextMidnight();
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _loadQuiz();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _untilNext = DailyQuizClock.untilNextMidnight());

      // Midnight passed while the screen was open -> load the new quiz.
      if (_quizId != DailyQuizClock.todayId()) {
        _loadQuiz();
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _loadQuiz() async {
    final quizId = DailyQuizClock.todayId();
    _quizId = quizId;

    try {
      final user = FirebaseAuth.instance.currentUser;

      final quizRef = FirebaseFirestore.instance
          .collection('dailyQuizzes')
          .doc(quizId);

      final quizSnap = await quizRef.get();
      if (!mounted) return;

      Map<String, dynamic>? data = quizSnap.exists ? quizSnap.data() : null;

      // Must be published and already live (the generator pre-creates
      // tomorrow's quiz with publishAt = 12:00 AM IST).
      if (data != null) {
        final publishAtRaw = data['publishAt'];
        final isLive =
            data['isPublished'] == true &&
            publishAtRaw is Timestamp &&
            !DateTime.now().isBefore(publishAtRaw.toDate());
        if (!isLive) data = null;
      }

      if (data == null) {
        setState(() {
          quizData = null;
          myAttempt = null;
          alreadyPlayed = false;
          loading = false;
        });
        return;
      }

      bool played = false;
      int count = 0;
      Map<String, dynamic>? attempt;

      if (user != null) {
        final attemptSnap = await quizRef
            .collection('leaderboard')
            .doc(user.uid)
            .get();
        played = attemptSnap.exists;

        if (played) {
          final a = await quizRef.collection('attempts').doc(user.uid).get();
          attempt = a.data();
        }

        try {
          final countSnap = await quizRef
              .collection('leaderboard')
              .count()
              .get();
          count = countSnap.count ?? 0;
        } catch (_) {
          // Player count is cosmetic — never block the screen on it.
        }
      }

      if (!mounted) return;

      setState(() {
        quizData = data;
        alreadyPlayed = played;
        myAttempt = attempt;
        playersToday = count;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Scaffold(body: DailyQuizEntryScreen.gradientBg());
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          "Today's Challenge",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: DailyQuizEntryScreen.gradientBg(),
      ),
      body: Stack(
        children: [
          DailyQuizEntryScreen.gradientBg(),
          Padding(
            padding: const EdgeInsets.all(20),
            child: quizData == null
                ? _buildPreparing()
                : SingleChildScrollView(child: _buildQuizContent(context)),
          ),
        ],
      ),
    );
  }

  // Shown only in the rare moment the new quiz is not there yet.
  Widget _buildPreparing() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.auto_awesome, color: Colors.white54, size: 56),
          const SizedBox(height: 16),
          const Text(
            "Today's quiz is being prepared",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'A fresh AI quiz arrives every day at 12:00 AM.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: 220,
            child: DailyQuizEntryScreen.glassButton(
              text: 'Refresh',
              onTap: () {
                setState(() => loading = true);
                _loadQuiz();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuizContent(BuildContext context) {
    final data = quizData!;
    final quizId = _quizId;
    final user = FirebaseAuth.instance.currentUser;

    final expiresAtRaw = data['expiresAt'];
    final DateTime expiresAt = expiresAtRaw is Timestamp
        ? expiresAtRaw.toDate()
        : DailyQuizClock.nextMidnight();

    final String title = (data['title'] ?? 'Daily Challenge').toString();
    final String topic = (data['topic'] ?? '').toString();
    final int totalQuestions = (data['totalQuestions'] as num?)?.toInt() ?? 10;
    final int minutes =
        ((data['timeLimitSeconds'] as num?)?.toInt() ?? 600) ~/ 60;
    final int xp = (data['xpReward'] as num?)?.toInt() ?? 150;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          '$totalQuestions Questions • $minutes Minutes',
          style: const TextStyle(color: Colors.white70),
        ),
        if (topic.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: Colors.tealAccent.withOpacity(0.15),
              border: Border.all(color: Colors.tealAccent.withOpacity(0.5)),
            ),
            child: Text(
              'Topic: $topic',
              style: const TextStyle(color: Colors.tealAccent, fontSize: 12),
            ),
          ),
        ],
        const SizedBox(height: 30),

        _infoTile(
          '⏳ New quiz in',
          DailyQuizClock.formatCountdown(_untilNext),
        ),
        _infoTile('🔥 XP Reward', '+$xp XP'),
        _infoTile('🌍 Players Today', playersToday.toString()),

        const SizedBox(height: 36),

        if (!alreadyPlayed)
          DailyQuizEntryScreen.glassButton(
            text: 'Start Daily Quiz',
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => QuizAttemptScreen(
                    quizId: quizId,
                    endAt: expiresAt,
                    isDaily: true,
                    topicId: quizId,
                    topicTitle: title,
                  ),
                ),
              );
              if (mounted) _loadQuiz();
            },
          )
        else ...[
          DailyQuizEntryScreen.glassButton(
            text: myAttempt != null ? 'View My Result' : 'Already Played',
            onTap: (myAttempt == null || user == null)
                ? null
                : () {
                    final a = myAttempt!;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => QuizResultScreen(
                          quizId: quizId,
                          attemptId: user.uid,
                          quizTitle: title,
                          score: (a['score'] as num?)?.toInt() ?? 0,
                          total: (a['total'] as num?)?.toInt() ?? totalQuestions,
                          percentage: (a['percentage'] as num?)?.toDouble() ?? 0,
                          // Daily results are never time-locked.
                          endAt: DateTime.now().subtract(
                            const Duration(seconds: 1),
                          ),
                          passed: a['passed'] == true,
                          passPercentage: 60.0,
                          isDaily: true,
                        ),
                      ),
                    );
                  },
          ),
        ],

        const SizedBox(height: 15),

        DailyQuizEntryScreen.glassButton(
          text: 'View Leaderboard',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    DailyLeaderboardScreen(quizId: quizId, quizTitle: title),
              ),
            );
          },
        ),
      ],
    );
  }
}

Widget _infoTile(String title, String value) {
  return Container(
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(18),
      color: Colors.white.withOpacity(0.12),
      border: Border.all(color: Colors.white.withOpacity(0.25)),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(color: Colors.white70)),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ),
  );
}
