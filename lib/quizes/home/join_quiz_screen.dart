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
    FocusScope.of(context).unfocus();

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

      if (data['startAt'] == null || data['endAt'] == null) {
        _error("Quiz timing not configured");
        return;
      }

      final DateTime now = DateTime.now();
      final DateTime startAt = (data['startAt'] as Timestamp).toDate();
      final DateTime endAt = (data['endAt'] as Timestamp).toDate();

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
                    builder: (_) =>
                        QuizAttemptScreen(quizId: quizId, endAt: endAt),
                  ),
                );
              },
            ),
          ),
        );
        return; // 🔒 CRITICAL
      }

      // ✅ QUIZ LIVE → DIRECT START
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => QuizAttemptScreen(quizId: quizId, endAt: endAt),
        ),
      );
    } catch (e) {
      _error("Failed to join quiz");
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _error(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ===== Background Gradient =====
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0F2027),
                  Color(0xFF203A43),
                  Color(0xFF2C5364),
                ],
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    color: Colors.white.withOpacity(0.12),
                    border: Border.all(color: Colors.white.withOpacity(0.25)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 18,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        "Join Quiz",
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),

                      const SizedBox(height: 8),

                      const Text(
                        "Enter the 6-digit code shared by the host",
                        style: TextStyle(color: Colors.white70),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 32),

                      // ===== Join Code Input =====
                      TextField(
                        controller: codeCtrl,
                        enabled: !loading,
                        maxLength: 6,
                        textCapitalization: TextCapitalization.characters,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          letterSpacing: 6,
                          fontWeight: FontWeight.bold,
                        ),
                        decoration: InputDecoration(
                          hintText: "ABC123",
                          hintStyle: const TextStyle(
                            color: Colors.white54,
                            letterSpacing: 6,
                          ),
                          counterText: "",
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.15),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),

                      const SizedBox(height: 28),

                      // ===== Join Button =====
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: loading ? null : _joinQuiz,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          child: loading
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.black,
                                  ),
                                )
                              : const Text(
                                  "Join Quiz",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
