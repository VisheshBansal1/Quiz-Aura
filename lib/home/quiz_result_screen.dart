import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quiz_app/home/answer_review_screen.dart';
import 'package:quiz_app/home/home_screen.dart';
import 'package:quiz_app/home/leaderboard/quiz_leaderboard_screen.dart';

class QuizResultScreen extends StatelessWidget {
  final String quizId;
  final int score;
  final int total;
  final int percentage;
  final Map<String, int> answers;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> questions;
  final DateTime endAt;

  const QuizResultScreen({
    super.key,
    required this.quizId,
    required this.score,
    required this.total,
    required this.percentage,
    required this.answers,
    required this.questions,
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
                      // ===== ICON =====
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: passed
                              ? Colors.greenAccent.withOpacity(0.2)
                              : Colors.redAccent.withOpacity(0.2),
                        ),
                        child: Icon(
                          passed
                              ? Icons.emoji_events
                              : Icons.error_outline,
                          size: 56,
                          color: passed
                              ? Colors.greenAccent
                              : Colors.redAccent,
                        ),
                      ),

                      const SizedBox(height: 20),

                      // ===== TITLE =====
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

                      // ===== SCORE =====
                      Text(
                        "$score / $total",
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),

                      const SizedBox(height: 6),

                      Text(
                        "$percentage%",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: passed
                              ? Colors.greenAccent
                              : Colors.redAccent,
                        ),
                      ),

                      const SizedBox(height: 28),

                      // ===== REVIEW =====
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.visibility),
                          label: Text(
                            quizEnded
                                ? "Review Answers"
                                : "Review available after quiz ends",
                          ),
                          onPressed: quizEnded
                              ? () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => AnswerReviewScreen(
                                        quizId: quizId,
                                        answers: answers,
                                      ),
                                    ),
                                  );
                                }
                              : null,
                        ),
                      ),

                      const SizedBox(height: 12),

                      // ===== LEADERBOARD =====
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

                      // ===== HOME =====
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: OutlinedButton(
                          child: const Text("Back to Home"),
                          onPressed: () {
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      const HomeScreen()),
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

  // ================= UI HELPERS =================

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
        border: Border.all(
          color: Colors.white.withOpacity(0.25),
        ),
      ),
      child: child,
    );
  }
}
