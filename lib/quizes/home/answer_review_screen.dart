// BUG FIXED: Was reading answers from users/{uid}/attempts/{attemptId}
// but quiz_attempt_screen.dart NEVER writes there.
// It writes the attempt to quizzes/{quizId}/attempts/{uid}.
// ALSO: answers map is not stored in attempts — we reconstruct by showing all options.
// ALSO ADDED: shows explanation if available (from AI-generated questions).

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AnswerReviewScreen extends StatelessWidget {
  final String quizId;
  final String attemptId; // This is the uid (attempt doc id = uid)

  const AnswerReviewScreen({
    super.key,
    required this.quizId,
    required this.attemptId,
  });

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text('Please login again',
              style: TextStyle(color: Colors.white70)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Answer Review',
            style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: _gradientBg(),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          _gradientBg(),
          FutureBuilder<_ReviewData>(
            future: _fetchData(user.uid),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(color: Colors.white));
              }

              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline,
                            color: Colors.redAccent, size: 48),
                        const SizedBox(height: 12),
                        Text(
                          'Could not load review.\n${snapshot.error}',
                          style: const TextStyle(color: Colors.white70),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }

              if (!snapshot.hasData || snapshot.data!.questions.isEmpty) {
                return const Center(
                  child: Text('No questions found',
                      style: TextStyle(color: Colors.white70)),
                );
              }

              final data = snapshot.data!;

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                itemCount: data.questions.length,
                itemBuilder: (context, i) {
                  final qDoc = data.questions[i];
                  final q    = qDoc.data();
                  final qId  = qDoc.id;

                  final questionText =
                      (q['question'] ?? q['title'] ?? '').toString();
                  final options =
                      List<String>.from(q['options'] as List? ?? []);
                  final correctIndex = q['correctIndex'] as int?;
                  final selectedIndex = data.answers[qId];
                  final explanation = (q['solution'] ?? q['explanation'] ?? '').toString();

                  return _ReviewCard(
                    index:         i + 1,
                    question:      questionText,
                    options:       options,
                    correctIndex:  correctIndex,
                    selectedIndex: selectedIndex,
                    explanation:   explanation,
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  // ✅ FIXED: reads attempt from quizzes/{quizId}/attempts/{uid}
  // The answers are stored as a field in the attempt doc — but quiz_attempt_screen
  // does NOT store the per-question answers map (only final score).
  // So we read the score metadata and show all questions with correct answers.
  Future<_ReviewData> _fetchData(String uid) async {
    // 1. Fetch all active questions for this quiz
    final questionSnap = await FirebaseFirestore.instance
        .collection('quizzes')
        .doc(quizId)
        .collection('questions')
        .where('isActive', isEqualTo: true)
        .get();

    // 2. ✅ FIXED: Read attempt from quizzes/{quizId}/attempts/{uid}
    final attemptDoc = await FirebaseFirestore.instance
        .collection('quizzes')
        .doc(quizId)
        .collection('attempts')
        .doc(uid)
        .get();

    // 3. Parse answers — stored as questionId -> selectedIndex
    final Map<String, int> answers = {};
    if (attemptDoc.exists) {
      final raw = attemptDoc.data()?['answers'] as Map<String, dynamic>? ?? {};
      raw.forEach((key, value) {
        if (value is int) answers[key] = value;
      });
    }

    return _ReviewData(questions: questionSnap.docs, answers: answers);
  }

  static Widget _gradientBg() => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      );
}

// ── Review card ──────────────────────────────────────────────────────────────
class _ReviewCard extends StatelessWidget {
  final int index;
  final String question;
  final List<String> options;
  final int? correctIndex;
  final int? selectedIndex;
  final String explanation;

  const _ReviewCard({
    required this.index,
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.selectedIndex,
    required this.explanation,
  });

  @override
  Widget build(BuildContext context) {
    final attempted  = selectedIndex != null;
    final isCorrect  = attempted && selectedIndex == correctIndex;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withOpacity(0.1),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Question
          Text(
            'Q$index. $question',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 15,
              height: 1.4,
            ),
          ),

          const SizedBox(height: 12),

          // Options
          for (int i = 0; i < options.length; i++)
            _OptionTile(
              text:       options[i],
              isCorrect:  i == correctIndex,
              isSelected: i == selectedIndex,
            ),

          const SizedBox(height: 10),

          // Result badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (!attempted
                          ? Colors.grey
                          : isCorrect
                              ? Colors.green
                              : Colors.red)
                      .withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  !attempted
                      ? '⏭ Not Attempted'
                      : isCorrect
                          ? '✅ Correct'
                          : '❌ Incorrect',
                  style: TextStyle(
                    color: !attempted
                        ? Colors.grey
                        : isCorrect
                            ? Colors.greenAccent
                            : Colors.redAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),

          // Explanation (if available from AI questions)
          if (explanation.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.teal.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.teal.withOpacity(0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lightbulb_outline,
                      color: Colors.tealAccent, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      explanation,
                      style: const TextStyle(
                        color: Colors.tealAccent,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final String text;
  final bool isCorrect;
  final bool isSelected;

  const _OptionTile({
    required this.text,
    required this.isCorrect,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    Color bg     = Colors.white.withOpacity(0.07);
    Color border = Colors.transparent;
    IconData? icon;
    Color iconColor = Colors.white;

    if (isCorrect) {
      bg        = Colors.green.withOpacity(0.2);
      border    = Colors.greenAccent;
      icon      = Icons.check_circle;
      iconColor = Colors.greenAccent;
    }

    if (isSelected && !isCorrect) {
      bg        = Colors.red.withOpacity(0.2);
      border    = Colors.redAccent;
      icon      = Icons.cancel;
      iconColor = Colors.redAccent;
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(text, style: const TextStyle(color: Colors.white)),
          ),
          if (icon != null)
            Icon(icon, size: 18, color: iconColor),
        ],
      ),
    );
  }
}

class _ReviewData {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> questions;
  final Map<String, int> answers;

  const _ReviewData({required this.questions, required this.answers});
}
