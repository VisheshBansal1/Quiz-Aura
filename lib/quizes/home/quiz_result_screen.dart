import 'package:flutter/material.dart';
import 'package:quiz_app/quizes/home/answer_review_screen.dart';
import 'package:quiz_app/quizes/home/home_screen.dart';
import 'package:quiz_app/quizes/home/leaderboard/quiz_leaderboard_screen.dart';

class QuizResultScreen extends StatelessWidget {
  final String quizId;
  final String attemptId; // 🔥 REQUIRED
  final int score;
  final int total;
  final int percentage;
  final DateTime endAt;

  const QuizResultScreen({
    super.key,
    required this.quizId,
    required this.attemptId,
    required this.score,
    required this.total,
    required this.percentage,
    required this.endAt,
  });

  @override
  Widget build(BuildContext context) {
    final bool passed = percentage >= 60;
    final bool quizEnded = DateTime.now().isAfter(endAt);

    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: const Text("Quiz Result"),
          automaticallyImplyLeading: false,
          backgroundColor: Colors.transparent,
          elevation: 0,
          flexibleSpace: _gradientBg(),
        ),
        body: Stack(
          children: [
            _gradientBg(),

            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: _glassCard(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        passed ? Icons.emoji_events : Icons.error_outline,
                        size: 56,
                        color:
                            passed ? Colors.greenAccent : Colors.redAccent,
                      ),

                      const SizedBox(height: 16),

                      Text(
                        passed
                            ? "Congratulations!"
                            : "Better luck next time",
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),

                      const SizedBox(height: 16),

                      Text(
                        "$score / $total",
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),

                      const SizedBox(height: 8),

                      Text(
                        "$percentage%",
                        style: TextStyle(
                          fontSize: 18,
                          color: passed
                              ? Colors.greenAccent
                              : Colors.redAccent,
                        ),
                      ),

                      const SizedBox(height: 24),

                      // ✅ REVIEW (Firestore-based)
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.visibility),
                          label: const Text("Review Answers"),
                          onPressed: quizEnded
                              ? () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          AnswerReviewScreen(
                                        quizId: quizId,
                                        attemptId: attemptId,
                                      ),
                                    ),
                                  );
                                }
                              : null,
                        ),
                      ),

                      const SizedBox(height: 12),

                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.leaderboard),
                          label: const Text("View Leaderboard"),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    QuizLeaderboardScreen(
                                  quizId: quizId,
                                  quizTitle: "Quiz",
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 12),

                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: OutlinedButton(
                          child: const Text("Back to Home"),
                          onPressed: () {
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const HomeScreen(),
                              ),
                              (_) => false,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

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

  static Widget _glassCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.white.withOpacity(0.12),
        border: Border.all(color: Colors.white.withOpacity(0.25)),
      ),
      child: child,
    );
  }
}
