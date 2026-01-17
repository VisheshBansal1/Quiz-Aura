import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quiz_app/home/answer_review_screen.dart';
import 'package:quiz_app/home/home_screen.dart';

class QuizResultScreen extends StatelessWidget {
  final String quizId;
  final int score;
  final int total;
  final int percentage;
  final Map<int, int> answers;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> questions;

  const QuizResultScreen({
    super.key,
    required this.quizId,
    required this.score,
    required this.total,
    required this.percentage,
    required this.answers,
    required this.questions,
  });

  @override
  Widget build(BuildContext context) {
    final passed = percentage >= 60;

    return WillPopScope(
      onWillPop: () async => false, // 🔒 block back
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Quiz Result"),
          automaticallyImplyLeading: false,
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                passed ? Icons.emoji_events : Icons.error_outline,
                size: 72,
                color: passed ? Colors.green : Colors.red,
              ),

              const SizedBox(height: 16),

              Text(
                passed ? "Congratulations!" : "Better luck next time",
                style: Theme.of(context).textTheme.titleLarge,
              ),

              const SizedBox(height: 24),

              Text(
                "$score / $total",
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                "$percentage%",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: passed ? Colors.green : Colors.red,
                ),
              ),

              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.visibility),
                  label: const Text("Review Answers"),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AnswerReviewScreen(
                          questions: questions,
                          answers: answers,
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
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
    );
  }
}
