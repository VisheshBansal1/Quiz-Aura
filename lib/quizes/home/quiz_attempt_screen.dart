import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:quiz_app/quizes/home/quiz_result_screen.dart';

class QuizAttemptScreen extends StatefulWidget {
  final String quizId;
  final DateTime endAt;

  const QuizAttemptScreen({
    super.key,
    required this.quizId,
    required this.endAt,
  });

  @override
  State<QuizAttemptScreen> createState() => _QuizAttemptScreenState();
}

class _QuizAttemptScreenState extends State<QuizAttemptScreen> {
  int currentIndex = 0;

  /// questionId -> selectedOptionIndex
  final Map<String, int> answers = {};

  bool submitting = false;
  late int remainingSeconds;
  Timer? _timer;

  late Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  _questionsFuture;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _questions = [];

  late final DateTime _startedAt;

  @override
  void initState() {
    super.initState();

    _startedAt = DateTime.now();

    remainingSeconds = widget.endAt
        .difference(DateTime.now())
        .inSeconds
        .clamp(0, 1 << 31);

    _questionsFuture = _loadQuestions();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // ================= LOAD QUESTIONS =================
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

    _questions = snap.docs;

    if (remainingSeconds > 0) {
      _startTimer();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _submitQuiz(auto: true);
      });
    }

    return snap.docs;
  }

  // ================= TIMER =================
  void _startTimer() {
    _timer?.cancel();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || submitting) return;

      if (remainingSeconds <= 0) {
        timer.cancel();
        _submitQuiz(auto: true);
      } else {
        setState(() => remainingSeconds--);
      }
    });
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: const Text("Quiz"),
          automaticallyImplyLeading: false,
          backgroundColor: Colors.transparent,
          elevation: 0,
          flexibleSpace: _gradientBg(),
        ),
        body: Stack(
          children: [
            _gradientBg(),

            FutureBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
              future: _questionsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  );
                }

                if (snapshot.hasError || !snapshot.hasData) {
                  return const Center(
                    child: Text(
                      "Failed to load quiz",
                      style: TextStyle(color: Colors.white70),
                    ),
                  );
                }

                final questionDoc = _questions[currentIndex];
                final q = questionDoc.data();
                final options = List<String>.from(q['options']);
                final questionId = questionDoc.id;

                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ===== TIMER =====
                      _glassCard(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Time Left",
                              style: const TextStyle(color: Colors.white70),
                            ),
                            Text(
                              "${remainingSeconds ~/ 60}:${(remainingSeconds % 60).toString().padLeft(2, '0')}",
                              style: const TextStyle(
                                color: Colors.redAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      // ===== PROGRESS =====
                      LinearProgressIndicator(
                        value: (currentIndex + 1) / _questions.length,
                        backgroundColor: Colors.white.withOpacity(0.2),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Colors.greenAccent,
                        ),
                      ),

                      const SizedBox(height: 16),

                      Text(
                        "Question ${currentIndex + 1} of ${_questions.length}",
                        style: const TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 12),

                      // ===== QUESTION =====
                      _glassCard(
                        child: Text(
                          q['question'],
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ===== OPTIONS =====
                      Expanded(
                        child: ListView.builder(
                          itemCount: options.length,
                          itemBuilder: (_, i) {
                            final selected = answers[questionId] == i;

                            return _optionTile(
                              text: options[i],
                              selected: selected,
                              onTap: submitting
                                  ? null
                                  : () {
                                      setState(() {
                                        answers[questionId] = i;
                                      });
                                    },
                            );
                          },
                        ),
                      ),

                      // ===== NAVIGATION =====
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
                                      if (!answers.containsKey(questionId)) {
                                        _error("Please select an option");
                                        return;
                                      }

                                      if (currentIndex ==
                                          _questions.length - 1) {
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

            if (submitting)
              Container(
                color: Colors.black.withOpacity(0.4),
                child: const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ================= SUBMIT QUIZ =================
  Future<void> _submitQuiz({bool auto = false}) async {
    if (submitting) return;

    setState(() => submitting = true);
    _timer?.cancel();

    try {
      int score = 0;

      for (final q in _questions) {
        final correctIndex = q['correctIndex'] as int?;
        final selectedIndex = answers[q.id];

        if (correctIndex != null && selectedIndex == correctIndex) {
          score++;
        }
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not logged in");

      final total = _questions.length;
      final percentage = ((score / total) * 100).round();

      final int timeTakenSeconds = DateTime.now()
          .difference(_startedAt)
          .inSeconds;

      // 🔥 SAVE ATTEMPT + ANSWERS
      final docRef = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('attempts')
          .add({
            'quizId': widget.quizId,
            'userId': user.uid,
            'score': score,
            'total': total,
            'percentage': percentage,
            'answers': Map<String, int>.from(answers), // 🔥 REQUIRED
            'startedAt': _startedAt,
            'attemptedAt': FieldValue.serverTimestamp(),
            'timeTakenSeconds': timeTakenSeconds,
            'autoSubmitted': auto,
          });

      if (!mounted) return;

      // 🔥 NAVIGATE WITH attemptId
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => QuizResultScreen(
            quizId: widget.quizId,
            attemptId: docRef.id, // 🔥 IMPORTANT
            score: score,
            total: total,
            percentage: percentage,
            endAt: widget.endAt,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        _error(e.toString().replaceFirst('Exception: ', ''));
        setState(() => submitting = false);
      }
    }
  }

  void _error(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ================= UI HELPERS =================

  Widget _gradientBg() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
        ),
      ),
    );
  }

  Widget _glassCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withOpacity(0.12),
        border: Border.all(color: Colors.white.withOpacity(0.25)),
      ),
      child: child,
    );
  }

  Widget _optionTile({
    required String text,
    required bool selected,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: selected
              ? Colors.green.withOpacity(0.25)
              : Colors.white.withOpacity(0.12),
          border: Border.all(
            color: selected
                ? Colors.greenAccent
                : Colors.white.withOpacity(0.25),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(text, style: const TextStyle(color: Colors.white)),
            ),
            if (selected)
              const Icon(Icons.check_circle, color: Colors.greenAccent),
          ],
        ),
      ),
    );
  }
}
