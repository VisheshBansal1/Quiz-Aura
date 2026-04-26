import 'package:QuizSphere/quizes/home/leaderboard/quiz_leaderboard_screen.dart';
import 'package:QuizSphere/quizes/home/quiz_attempt_screen.dart';
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
  bool loading = true;
  bool alreadyPlayed = false;
  int playersToday = 0;

  String getTodayQuizId() {
    final now = DateTime.now().toUtc();
    return "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
  }

  @override
  void initState() {
    super.initState();
    _loadQuiz();
  }

  Future<void> _loadQuiz() async {
    // FIX: All setState() calls guarded with !mounted to prevent
    // "setState called after dispose" crashes.
    try {
      final user = FirebaseAuth.instance.currentUser;
      final quizId = getTodayQuizId();

      final quizRef = FirebaseFirestore.instance
          .collection('dailyQuizzes')
          .doc(quizId);

      final quizSnap = await quizRef.get();

      if (!mounted) return; // FIX: guard after every await

      if (!quizSnap.exists) {
        setState(() {
          quizData = null;
          loading = false;
        });
        return;
      }

      final data = quizSnap.data()!;

      // FIX: Null-safe Timestamp cast — if 'publishAt' is missing from
      // Firestore the old force-cast `as Timestamp` threw a TypeError crash.
      final publishAtRaw = data['publishAt'];
      if (publishAtRaw == null || publishAtRaw is! Timestamp) {
        // Missing/bad publishAt field — treat as unpublished.
        if (!mounted) return;
        setState(() {
          quizData = null;
          loading = false;
        });
        return;
      }
      final publishAt = publishAtRaw.toDate();
      final now = DateTime.now();

      if (data['isPublished'] != true || now.isBefore(publishAt)) {
        if (!mounted) return;
        setState(() {
          quizData = null;
          loading = false;
        });
        return;
      }

      bool played = false;
      int count = 0;

      if (user != null) {
        final attemptSnap = await quizRef
            .collection('leaderboard')
            .doc(user.uid)
            .get();

        final countSnap = await quizRef.collection('leaderboard').count().get();

        played = attemptSnap.exists;
        count = countSnap.count ?? 0;
      }

      if (!mounted) return; // FIX: guard after every await

      setState(() {
        quizData = data;
        alreadyPlayed = played;
        playersToday = count;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return; // FIX: guard in catch block too
      setState(() => loading = false);
    }
  }

  String _timeLeft(Timestamp expiresAt) {
    final now = DateTime.now().toUtc();
    final diff = expiresAt.toDate().difference(now);

    if (diff.isNegative) return "Expired";
    return "${diff.inHours}h ${diff.inMinutes % 60}m";
  }

  @override
  Widget build(BuildContext context) {
    final quizId = getTodayQuizId();

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
                ? const Center(
                    child: Text(
                      "No Daily Quiz Available Today",
                      style: TextStyle(color: Colors.white70, fontSize: 18),
                    ),
                  )
                : _buildQuizContent(context, quizId),
          ),
        ],
      ),
    );
  }

  Widget _buildQuizContent(BuildContext context, String quizId) {
    // FIX: Null-safe Timestamp access. Force-cast `as Timestamp`
    // crashed when the expiresAt field was missing from Firestore.
    final expiresAtRaw = quizData?['expiresAt'];
    final Timestamp expiresAt = expiresAtRaw is Timestamp
        ? expiresAtRaw
        : Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 1)));
    final isExpired = expiresAt.toDate().isBefore(DateTime.now().toUtc());

    final bool isPracticeMode = isExpired;
    final bool disableStart = !isPracticeMode && alreadyPlayed;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          quizData!['title'],
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          "${quizData!['totalQuestions']} Questions • ${quizData!['timeLimitSeconds'] ~/ 60} Minutes",
          style: const TextStyle(color: Colors.white70),
        ),
        const SizedBox(height: 30),

        _infoTile("⏳ Time Left", _timeLeft(expiresAt)),
        _infoTile(
          "🔥 XP Reward",
          isPracticeMode ? "Practice Only" : "+${quizData!['xpReward']} XP",
        ),
        _infoTile("🌍 Players Today", playersToday.toString()),

        const SizedBox(height: 50),

        DailyQuizEntryScreen.glassButton(
          text: isPracticeMode
              ? "Practice Mode (30 Min)"
              : alreadyPlayed
              ? "Already Played"
              : "Start Daily Quiz",
          onTap: disableStart
              ? null
              : () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => QuizAttemptScreen(
                        quizId: quizId,
                        endAt: isPracticeMode
                            ? DateTime.now().add(const Duration(minutes: 30))
                            : expiresAt.toDate(),
                        isDaily: !isPracticeMode,
                        topicId: quizId,
                        topicTitle: quizData?['title'] ?? 'Daily Quiz',
                      ),
                    ),
                  );

                  _loadQuiz();
                },
        ),

        const SizedBox(height: 15),

        DailyQuizEntryScreen.glassButton(
          text: "View Leaderboard",
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => QuizLeaderboardScreen(
                  quizId: quizId,
                  quizTitle: quizData!['title'],
                ),
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
