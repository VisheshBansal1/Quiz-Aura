import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quiz_app/quiz/quiz_result_screen.dart';
import 'services/attempt_service.dart';

class QuizScreen extends StatefulWidget {
  final String quizId;
  final String quizTitle;
  final List<QueryDocumentSnapshot> questions;

  const QuizScreen({
    super.key,
    required this.quizId,
    required this.quizTitle,
    required this.questions,
  });

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  int index = 0;
  int score = 0;
  int? selected;
  bool submitting = false;

  final attemptService = AttemptService();

  @override
  void initState() {
    super.initState();
    if (widget.questions.isEmpty) {
      Future.microtask(() {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No questions found")),
        );
      });
    }
  }

  void _next() {
    if (selected == null) return;

    final correctIndex = widget.questions[index]['correctIndex'];
    if (selected == correctIndex) score++;

    if (index < widget.questions.length - 1) {
      setState(() {
        index++;
        selected = null;
      });
    } else {
      _finishQuiz();
    }
  }

  Future<void> _finishQuiz() async {
  setState(() => submitting = true);

  await attemptService.saveAttempt(
    quizId: widget.quizId,
    quizTitle: widget.quizTitle,
    score: score,
    total: widget.questions.length,
  );

  if (!mounted) return;

  Navigator.pushReplacement(
    context,
    MaterialPageRoute(
      builder: (_) => QuizResultScreen(
        quizTitle: widget.quizTitle,
        score: score,
        total: widget.questions.length,
      ),
    ),
  );
}


  @override
  Widget build(BuildContext context) {
    final question = widget.questions[index];
    final options = List<String>.from(question['options']);

    return WillPopScope(
      onWillPop: () async => false, // 🔒 Prevent cheating
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.quizTitle),
          automaticallyImplyLeading: false,
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 🔢 Progress
              Text(
                "Question ${index + 1} of ${widget.questions.length}",
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              LinearProgressIndicator(
                value: (index + 1) / widget.questions.length,
              ),
              const SizedBox(height: 24),

              // ❓ Question
              Text(
                question['question'],
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),

              // 🔘 Options
              ...List.generate(
                options.length,
                (i) => RadioListTile<int>(
                  value: i,
                  groupValue: selected,
                  onChanged: submitting ? null : (v) {
                    setState(() => selected = v);
                  },
                  title: Text(options[i]),
                ),
              ),

              const Spacer(),

              // ▶️ Next / Finish
              ElevatedButton(
                onPressed: (selected == null || submitting) ? null : _next,
                child: Text(
                  index == widget.questions.length - 1
                      ? "Finish Quiz"
                      : "Next Question",
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
