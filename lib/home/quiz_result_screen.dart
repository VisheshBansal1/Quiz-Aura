import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quiz_app/home/answer_review_screen.dart';

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
    return Scaffold(
      appBar: AppBar(
        title: const Text("Result"),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 20),

            Text(
              "Your Score",
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),

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
                color: percentage >= 60 ? Colors.green : Colors.red,
              ),
            ),

            const SizedBox(height: 32),

            ElevatedButton.icon(
              icon: const Icon(Icons.visibility),
              label: const Text("Review Answers"),
              onPressed: () {
                _showReview(context);
              },
            ),

            const SizedBox(height: 12),

            OutlinedButton(
              onPressed: () {
                Navigator.pop(context); // back to quiz list/home
              },
              child: const Text("Done"),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- ANSWER REVIEW ----------------
  void _showReview(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AnswerReviewScreen(
          questions: questions,
          answers: answers,
        ),
      ),
    );
  }
}
