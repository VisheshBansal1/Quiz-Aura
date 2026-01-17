import 'package:flutter/material.dart';

class QuizEndedScreen extends StatelessWidget {
  final String quizTitle;

  const QuizEndedScreen({
    super.key,
    required this.quizTitle,
  });

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      // 🔒 Disable back button
      onWillPop: () async => false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Quiz Ended"),
          automaticallyImplyLeading: false,
        ),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ⛔ ICON
              Icon(
                Icons.lock_clock,
                size: 80,
                color: Colors.red.shade400,
              ),

              const SizedBox(height: 20),

              // 🧠 TITLE
              Text(
                quizTitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),

              // ❌ MESSAGE
              const Text(
                "This quiz has already ended.\nYou can no longer attempt it.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.black54,
                ),
              ),

              const SizedBox(height: 32),

              // 🔙 GO HOME
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.home),
                  label: const Text("Go to Home"),
                  onPressed: () {
                    Navigator.popUntil(context, (route) => route.isFirst);
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
