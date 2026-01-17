import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:quiz_app/home/quiz_result_screen.dart';

class QuizAttemptScreen extends StatefulWidget {
  final String quizId;
  final int durationMinutes;

  const QuizAttemptScreen({
    super.key,
    required this.quizId,
    required this.durationMinutes,
  });

  @override
  State<QuizAttemptScreen> createState() => _QuizAttemptScreenState();
}

class _QuizAttemptScreenState extends State<QuizAttemptScreen> {
  int currentIndex = 0;
  final Map<int, int> answers = {};

  bool submitting = false;

  late int remainingSeconds;
  Timer? _timer;

  late Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _questionsFuture;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _questions = [];

  @override
  void initState() {
    super.initState();
    remainingSeconds = widget.durationMinutes * 60;
    _questionsFuture = _loadQuestions();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // ---------------- LOAD QUESTIONS ----------------
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _loadQuestions() async {
    final snap = await FirebaseFirestore.instance
        .collection('quizzes')
        .doc(widget.quizId)
        .collection('questions')
        .orderBy('createdAt')
        .get();

    if (snap.docs.isEmpty) {
      throw Exception("No questions found");
    }

    _questions = snap.docs;
    _startTimer(); // ✅ start only after questions load
    return snap.docs;
  }

  // ---------------- TIMER ----------------
  void _startTimer() {
    _timer?.cancel();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;

      if (remainingSeconds <= 0) {
        timer.cancel();
        _submitQuiz(auto: true);
      } else {
        setState(() => remainingSeconds--);
      }
    });
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Quiz"),
        automaticallyImplyLeading: false,
      ),
      body: FutureBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
        future: _questionsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError || !snapshot.hasData) {
            return const Center(child: Text("Failed to load quiz"));
          }

          final q = _questions[currentIndex].data();
          final options = List<String>.from(q['options']);

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ⏱ TIMER
                Text(
                  "Time left: ${remainingSeconds ~/ 60}:${(remainingSeconds % 60).toString().padLeft(2, '0')}",
                  style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),

                LinearProgressIndicator(
                  value: (currentIndex + 1) / _questions.length,
                ),
                const SizedBox(height: 12),

                Text(
                  "Question ${currentIndex + 1} of ${_questions.length}",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),

                Text(
                  q['question'],
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 20),

                ...List.generate(options.length, (i) {
                  final selected = answers[currentIndex] == i;
                  return Card(
                    color: selected
                        ? Theme.of(context).colorScheme.primaryContainer
                        : null,
                    child: ListTile(
                      title: Text(options[i]),
                      onTap: submitting
                          ? null
                          : () => setState(() => answers[currentIndex] = i),
                    ),
                  );
                }),

                const Spacer(),

                Row(
                  children: [
                    if (currentIndex > 0)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: submitting
                              ? null
                              : () => setState(() => currentIndex--),
                          child: const Text("Previous"),
                        ),
                      ),
                    if (currentIndex > 0) const SizedBox(width: 12),

                    Expanded(
                      child: ElevatedButton(
                        onPressed: submitting
                            ? null
                            : () {
                                if (!answers.containsKey(currentIndex)) {
                                  _error("Please select an option");
                                  return;
                                }

                                if (currentIndex == _questions.length - 1) {
                                  _submitQuiz();
                                } else {
                                  setState(() => currentIndex++);
                                }
                              },
                        child: Text(
                          currentIndex == _questions.length - 1
                              ? "Submit"
                              : "Next",
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ---------------- SUBMIT QUIZ ----------------
Future<void> _submitQuiz({bool auto = false}) async {
  // 🔒 Hard lock
  if (submitting) return;

  // ❌ No questions loaded → block submit
  if (_questions.isEmpty) {
    _error("Quiz data not ready");
    return;
  }

  setState(() => submitting = true);
  _timer?.cancel();

  try {
    int score = 0;

    for (int i = 0; i < _questions.length; i++) {
      final correctIndex = _questions[i]['correctIndex'] as int?;
      if (correctIndex != null && answers[i] == correctIndex) {
        score++;
      }
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception("User not logged in");
    }

    final int total = _questions.length;
    final int percentage = ((score / total) * 100).round();

    // ✅ SAVE ATTEMPT
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('attempts')
        .add({
      'quizId': widget.quizId,
      'score': score,
      'total': total,
      'percentage': percentage,
      'attemptedAt': FieldValue.serverTimestamp(),
      'autoSubmitted': auto,
    });

    if (!mounted) return;

    // ✅ NAVIGATE TO RESULT
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => QuizResultScreen(
          quizId: widget.quizId,
          score: score,
          total: total,
          percentage: percentage,
          answers: Map<int, int>.from(answers),
          questions: List.from(_questions),
        ),
      ),
    );
  } catch (e) {
    // 🔥 IMPORTANT: unlock submit on failure
    if (mounted) {
      _error(e.toString().replaceFirst('Exception: ', ''));
      setState(() => submitting = false);
    }
  }
}

  void _error(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }
}
