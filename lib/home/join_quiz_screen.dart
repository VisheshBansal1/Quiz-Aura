import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'quiz_attempt_screen.dart';
import 'quiz_rules_screen.dart';
import 'quiz_ended_screen.dart';

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
    FocusScope.of(context).unfocus(); // 🔹 hide keyboard

    if (loading) return;

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

      final doc = snap.docs.first;
      final data = doc.data();
      final quizId = doc.id;

      // 🔒 Validate timing fields
      if (data['startAt'] == null ||
          data['endAt'] == null ||
          data['durationMinutes'] == null) {
        _error("Quiz timing not configured");
        return;
      }

      final DateTime now = DateTime.now();
      final DateTime startAt = (data['startAt'] as Timestamp).toDate();
      final DateTime endAt = (data['endAt'] as Timestamp).toDate();
      final int durationMinutes = data['durationMinutes'] as int;

      // ⛔ QUIZ ENDED
      if (now.isAfter(endAt)) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => QuizEndedScreen(quizTitle: data['title'] ?? "Quiz"),
          ),
        );
        return;
      }

      // ⏳ QUIZ NOT STARTED → RULES SCREEN
      if (now.isBefore(startAt)) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => QuizRulesScreen(
              startAt: startAt,
              onConfirmedStart: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => QuizAttemptScreen(
                      quizId: quizId,
                      durationMinutes: durationMinutes,
                    ),
                  ),
                );
              },
            ),
          ),
        );
      }

      // ✅ QUIZ RUNNING
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => QuizAttemptScreen(
            quizId: quizId,
            durationMinutes: durationMinutes,
          ),
        ),
      );
    } catch (e) {
      _error("Failed to join quiz");
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  void _error(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
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
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: codeCtrl,
              textCapitalization: TextCapitalization.characters,
              maxLength: 6,
              enabled: !loading,
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
