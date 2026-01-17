import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'quiz_attempt_screen.dart';

class JoinQuizScreen extends StatefulWidget {
  const JoinQuizScreen({super.key});

  @override
  State<JoinQuizScreen> createState() => _JoinQuizScreenState();
}

class _JoinQuizScreenState extends State<JoinQuizScreen> {
  final TextEditingController codeCtrl = TextEditingController();
  bool loading = false;

  @override
  void dispose() {
    codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _joinQuiz() async {
    final code = codeCtrl.text.trim().toUpperCase();

    if (code.length != 6) {
      _error("Enter a valid 6-character join code");
      return;
    }

    setState(() => loading = true);

    try {
      final snap = await FirebaseFirestore.instance
          .collection('quizzes')
          .where('joinCode', isEqualTo: code)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (!mounted) return;

      if (snap.docs.isEmpty) {
        _error("Invalid or expired join code");
        return;
      }

      final quizId = snap.docs.first.id;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => QuizAttemptScreen(quizId: quizId),
        ),
      );
    } catch (e) {
      _error("Failed to join quiz");
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _error(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Join Quiz")),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "Enter Join Code",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: codeCtrl,
              textCapitalization: TextCapitalization.characters,
              maxLength: 6,
              decoration: const InputDecoration(
                labelText: "Join Code",
                hintText: "ABC123",
                counterText: "",
              ),
            ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: loading ? null : _joinQuiz,
                child: loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text("Join Quiz"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
