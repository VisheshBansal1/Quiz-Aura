import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'quiz_screen.dart';
import 'services/quiz_service.dart';

class JoinQuizScreen extends StatefulWidget {
  final String topic;
  const JoinQuizScreen({super.key, required this.topic});

  @override
  State<JoinQuizScreen> createState() => _JoinQuizScreenState();
}

class _JoinQuizScreenState extends State<JoinQuizScreen> {
  final codeCtrl = TextEditingController();
  final service = QuizService();

  bool loading = false;

  @override
  void dispose() {
    codeCtrl.dispose();
    super.dispose();
  }

  Future<void> joinQuiz() async {
    FocusScope.of(context).unfocus();

    final code = codeCtrl.text.trim().toUpperCase();

    if (code.length != 6) {
      _error("Enter a valid 6-digit quiz code");
      return;
    }

    if (loading) return;

    setState(() => loading = true);

    try {
      final quizDoc = await service.getQuizByCode(code);

      if (quizDoc == null) {
        _error("Quiz not found");
        return;
      }

      final questions = await service.getQuestions(quizDoc.id);

      if (questions.isEmpty) {
        _error("Quiz has no questions");
        return;
      }

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => QuizScreen(
            quizId: quizDoc.id,
            quizTitle: quizDoc['title'],
            questions: questions,
          ),
        ),
      );
    } on FirebaseException catch (_) {
      _error("Network error. Try again.");
    } catch (_) {
      _error("Something went wrong");
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  void _error(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("${widget.topic} Quiz")),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "Enter Quiz Code",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),

                TextField(
                  controller: codeCtrl,
                  maxLength: 6,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: "ABC123",
                  ),
                ),

                const SizedBox(height: 20),

                ElevatedButton(
                  onPressed: loading ? null : joinQuiz,
                  child: const Text("Join Quiz"),
                ),
              ],
            ),
          ),

          // 🔄 Full-screen loader (real UX)
          if (loading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}
