import 'dart:async';
import 'package:QuizSphere/quizes/home/daily_quiz/daily_quiz_leaderboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DailyQuizPlayScreen extends StatefulWidget {
  final String quizId;
  final DateTime endAt;

  const DailyQuizPlayScreen({
    super.key,
    required this.quizId,
    required this.endAt,
  });

  @override
  State<DailyQuizPlayScreen> createState() =>
      _DailyQuizPlayScreenState();
}

class _DailyQuizPlayScreenState extends State<DailyQuizPlayScreen> {
  int currentIndex = 0;
  int score = 0;
  int total = 0;
  int remainingSeconds = 0;
  int timeLimitSeconds = 0;

  bool submitted = false;
  bool loading = true;

  Timer? timer;

  List<Map<String, dynamic>> questions = [];

  @override
  void initState() {
    super.initState();
    _initializeQuiz();
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> _initializeQuiz() async {
    final now = DateTime.now().toUtc();

    // 🔥 Check if expired globally
    if (widget.endAt.isBefore(now)) {
      Navigator.pop(context);
      return;
    }

    final doc = await FirebaseFirestore.instance
        .collection('dailyQuizzes')
        .doc(widget.quizId)
        .get();

    if (!doc.exists) {
      Navigator.pop(context);
      return;
    }

    final data = doc.data()!;

    timeLimitSeconds = data['timeLimitSeconds'];
    total = data['totalQuestions'];

    // 🔥 Check if user already attempted
    final user = FirebaseAuth.instance.currentUser!;
    final attemptDoc = await FirebaseFirestore.instance
        .collection('dailyQuizzes')
        .doc(widget.quizId)
        .collection('leaderboard')
        .doc(user.uid)
        .get();

    if (attemptDoc.exists) {
      Navigator.pop(context);
      return;
    }

    final questionSnap = await FirebaseFirestore.instance
        .collection('dailyQuizzes')
        .doc(widget.quizId)
        .collection('questions')
        .get();

    questions =
        questionSnap.docs.map((e) => e.data()).toList();

    remainingSeconds = timeLimitSeconds;

    _startTimer();

    setState(() => loading = false);
  }

  void _startTimer() {
    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (remainingSeconds <= 0) {
        t.cancel();
        _submitQuiz();
      } else {
        setState(() => remainingSeconds--);
      }
    });
  }

  Future<void> _submitQuiz() async {
    if (submitted) return;
    submitted = true;

    timer?.cancel();

    final user = FirebaseAuth.instance.currentUser!;
    final percentage =
        total == 0 ? 0 : (score / total) * 100;

    final timeTaken =
        timeLimitSeconds - remainingSeconds;

    int xpEarned = percentage >= 80
        ? 200
        : percentage >= 50
            ? 150
            : 100;

    await FirebaseFirestore.instance
        .collection('dailyQuizzes')
        .doc(widget.quizId)
        .collection('leaderboard')
        .doc(user.uid)
        .set({
      "userName":
          user.displayName ?? "Anonymous",
      "score": score,
      "total": total,
      "percentage": percentage,
      "timeTakenSeconds": timeTaken,
      "xpEarned": xpEarned,
      "submittedAt": FieldValue.serverTimestamp(),
    });

    final quizDoc = await FirebaseFirestore.instance
        .collection('dailyQuizzes')
        .doc(widget.quizId)
        .get();

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => DailyLeaderboardScreen(
          quizId: widget.quizId,
          quizTitle: quizDoc['title'],
        ),
      ),
    );
  }

  void _selectAnswer(int index) {
    if (submitted) return;

    if (index ==
        questions[currentIndex]['correctIndex']) {
      score++;
    }

    if (currentIndex < questions.length - 1) {
      setState(() => currentIndex++);
    } else {
      _submitQuiz();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    final question = questions[currentIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          _gradientBg(),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _topBar(),
                const SizedBox(height: 20),
                Text(
                  "Q${currentIndex + 1} / $total",
                  style:
                      const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 10),
                Text(
                  question['question'],
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 20),
                ...List.generate(
                  question['options'].length,
                  (index) => _optionTile(
                    text: question['options'][index],
                    onTap: () => _selectAnswer(index),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _topBar() {
    final minutes = remainingSeconds ~/ 60;
    final seconds = remainingSeconds % 60;

    return Row(
      mainAxisAlignment:
          MainAxisAlignment.spaceBetween,
      children: [
        Text(
          "⏳ ${minutes}m ${seconds}s",
          style: const TextStyle(color: Colors.orange),
        ),
        const Text(
          "🔥 Daily XP",
          style: TextStyle(color: Colors.white70),
        ),
      ],
    );
  }

  Widget _optionTile({
    required String text,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin:
            const EdgeInsets.only(bottom: 12),
        padding:
            const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius:
              BorderRadius.circular(20),
          color:
              Colors.white.withOpacity(0.12),
          border:
              Border.all(color: Colors.white24),
        ),
        child: Text(
          text,
          style:
              const TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  Widget _gradientBg() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF0F2027),
            Color(0xFF203A43),
            Color(0xFF2C5364),
          ],
        ),
      ),
    );
  }
}