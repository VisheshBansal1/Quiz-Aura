import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:quiz_app/home/quiz_result_screen.dart';

class QuizAttemptScreen extends StatefulWidget {
  final String quizId;
  const QuizAttemptScreen({super.key, required this.quizId});

  @override
  State<QuizAttemptScreen> createState() => _QuizAttemptScreenState();
}

class _QuizAttemptScreenState extends State<QuizAttemptScreen> {
  int currentIndex = 0;
  final Map<int, int> answers = {};

  bool submitting = false;

  // ⏱ TIMER
  static const int totalSeconds = 300; // 5 min
  int remainingSeconds = totalSeconds;
  Timer? _timer;

  late Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  _questionsFuture;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _questionsCache = [];

  @override
  void initState() {
    super.initState();
    _questionsFuture = _loadQuestions();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // ---------------- LOAD QUESTIONS ----------------
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  _loadQuestions() async {
    final snap = await FirebaseFirestore.instance
        .collection('quizzes')
        .doc(widget.quizId)
        .collection('questions')
        .orderBy('createdAt')
        .get();

    if (snap.docs.isEmpty) {
      throw Exception("No questions found");
    }

    _questionsCache = snap.docs;
    return snap.docs;
  }

  // ---------------- TIMER ----------------
  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (remainingSeconds <= 0) {
        t.cancel();
        if (!submitting) {
          _submitQuiz();
        }
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

          final questions = snapshot.data!;
          final q = questions[currentIndex].data();
          final options = List<String>.from(q['options']);

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ⏱ TIMER
                Text(
                  "Time left: ${remainingSeconds ~/ 60}:${(remainingSeconds % 60).toString().padLeft(2, '0')}",
                  style: const TextStyle(color: Colors.red),
                ),
                const SizedBox(height: 8),

                LinearProgressIndicator(
                  value: (currentIndex + 1) / questions.length,
                ),
                const SizedBox(height: 12),

                Text(
                  "Question ${currentIndex + 1} of ${questions.length}",
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

                                if (currentIndex == questions.length - 1) {
                                  _submitQuiz();
                                } else {
                                  setState(() => currentIndex++);
                                }
                              },
                        child: Text(
                          currentIndex == questions.length - 1
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
Future<void> _submitQuiz() async {
  if (submitting) return;

  setState(() => submitting = true);
  _timer?.cancel();

  int score = 0;

  for (int i = 0; i < _questionsCache.length; i++) {
    final correctIndex = _questionsCache[i]['correctIndex'] as int?;
    if (correctIndex != null && answers[i] == correctIndex) {
      score++;
    }
  }

  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    _error("User not logged in");
    setState(() => submitting = false);
    return;
  }

  final int total = _questionsCache.length;
  final int percentage = ((score / total) * 100).round();

  try {
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
    });
  } catch (e) {
    _error("Failed to save result");
    setState(() => submitting = false);
    return;
  }

  if (!mounted) return;

  Navigator.of(context).pushReplacement(
    MaterialPageRoute(
      builder: (_) => QuizResultScreen(
        quizId: widget.quizId,
        score: score,
        total: total,
        percentage: percentage,
        answers: answers,
        questions: _questionsCache,
      ),
    ),
  );
}

  void _error(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}
