import 'package:QuizSphere/quizes/home/answer_review_screen.dart';
import 'package:QuizSphere/quizes/home/onboarding_screen.dart';
import 'package:QuizSphere/quizes/home/leaderboard/quiz_leaderboard_screen.dart';
import 'package:flutter/material.dart';

class QuizResultScreen extends StatelessWidget {
  final String quizId;
  final String attemptId;
  final String quizTitle;
  final int score;
  final int total;
  final double percentage;
  final DateTime endAt;
  final bool passed;
  final double passPercentage;

  const QuizResultScreen({
    super.key,
    required this.quizId,
    required this.attemptId,
    required this.quizTitle,
    required this.score,
    required this.total,
    required this.percentage,
    required this.endAt,
    required this.passed,
    required this.passPercentage,
  });

  @override
  Widget build(BuildContext context) {
    final bool quizEnded = DateTime.now().isAfter(endAt);

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: Text(quizTitle),
          automaticallyImplyLeading: false,
          backgroundColor: Colors.transparent,
          elevation: 0,
          flexibleSpace: _gradientBg(),
        ),
        body: Stack(
          children: [
            _gradientBg(),
            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const SizedBox(height: 20),

                    /// 🔒 IF QUIZ NOT ENDED
                    if (!quizEnded) ...[
                      const Icon(
                        Icons.lock_outline,
                        size: 60,
                        color: Colors.orangeAccent,
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        "Result Locked",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        "Your score and performance will be visible once the quiz ends.",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 30),
                    ],

                    /// ✅ IF QUIZ ENDED
                    if (quizEnded) ...[
                      _resultIcon(),
                      const SizedBox(height: 16),
                      _resultMessage(),
                      const SizedBox(height: 24),
                      _scoreSection(),
                      const SizedBox(height: 20),
                    ],

                    _statusSection(quizEnded),
                    const SizedBox(height: 30),
                    _buttons(context, quizEnded),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================= RESULT ICON =================
  Widget _resultIcon() {
    return CircleAvatar(
      radius: 42,
      backgroundColor: passed
          ? Colors.greenAccent.withOpacity(0.2)
          : Colors.redAccent.withOpacity(0.2),
      child: Icon(
        passed ? Icons.emoji_events : Icons.cancel,
        size: 48,
        color: passed ? Colors.greenAccent : Colors.redAccent,
      ),
    );
  }

  // ================= RESULT MESSAGE =================
  Widget _resultMessage() {
    String message;

    if (percentage >= 90) {
      message = "Outstanding Performance!";
    } else if (percentage >= 75) {
      message = "Great Job!";
    } else if (percentage >= passPercentage) {
      message = "You Passed!";
    } else {
      message = "Keep Practicing!";
    }

    return Text(
      message,
      style: const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
      textAlign: TextAlign.center,
    );
  }

  // ================= SCORE SECTION =================
  Widget _scoreSection() {
    return Column(
      children: [
        Text(
          "$score / $total",
          style: const TextStyle(
            fontSize: 42,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          "${percentage.toStringAsFixed(1)}%",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: passed ? Colors.greenAccent : Colors.redAccent,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "Passing Criteria: ${passPercentage.toStringAsFixed(0)}%",
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade400,
          ),
        ),
      ],
    );
  }

  // ================= STATUS =================
  Widget _statusSection(bool quizEnded) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withOpacity(0.08),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            quizEnded ? Icons.lock : Icons.timer,
            color: quizEnded ? Colors.orangeAccent : Colors.blueAccent,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            quizEnded ? "Quiz Ended" : "Quiz Still Active",
            style: const TextStyle(color: Colors.white),
          ),
        ],
      ),
    );
  }

  // ================= BUTTONS =================
  Widget _buttons(BuildContext context, bool quizEnded) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.visibility),
            label: const Text("Review Answers"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
            ),
            onPressed: quizEnded
                ? () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AnswerReviewScreen(
                          quizId: quizId,
                          attemptId: attemptId,
                        ),
                      ),
                    );
                  }
                : null,
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.leaderboard),
            label: const Text("Leaderboard"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: quizEnded
                ? () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => QuizLeaderboardScreen(
                          quizId: quizId,
                          quizTitle: quizTitle,
                        ),
                      ),
                    );
                  }
                : null,
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.white),
            ),
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (_) => const HomeScreen(),
                ),
                (_) => false,
              );
            },
            child: const Text(
              "Back to Home",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  // ================= BACKGROUND =================
  static Widget _gradientBg() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
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
