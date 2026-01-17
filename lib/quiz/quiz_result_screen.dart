import 'package:flutter/material.dart';

class QuizResultScreen extends StatelessWidget {
  final String quizTitle;
  final int score;
  final int total;

  const QuizResultScreen({
    super.key,
    required this.quizTitle,
    required this.score,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = ((score / total) * 100).round();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Quiz Result"),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              quizTitle,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            CircleAvatar(
              radius: 60,
              backgroundColor: Colors.deepPurple,
              child: Text(
                "$percentage%",
                style: const TextStyle(
                  fontSize: 28,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 24),
            Text(
              "Score: $score / $total",
              style: const TextStyle(fontSize: 18),
            ),

            const SizedBox(height: 40),

            ElevatedButton(
              onPressed: () {
                Navigator.popUntil(context, (r) => r.isFirst);
              },
              child: const Text("Back to Home"),
            ),
          ],
        ),
      ),
    );
  }
}
