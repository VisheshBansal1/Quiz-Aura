import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import 'quiz_result_screen.dart';
import 'quiz_result_locked_screen.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Center(child: Text("Please login"));
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('attempts')
          .orderBy('attemptedAt', descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return const Center(child: Text("Failed to load history"));
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return const Center(child: Text("No quiz attempts yet"));
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, i) {
            final data = docs[i].data();

            final quizId = data['quizId'];
            final score = data['score'];
            final total = data['total'];
            final percentage = data['percentage'];

            final ts = data['attemptedAt'] as Timestamp?;
            final date = ts != null
                ? DateFormat('dd MMM yyyy, hh:mm a')
                    .format(ts.toDate())
                : '';

            return Card(
              child: ListTile(
                title: Text("Score: $score / $total"),
                subtitle: Text(date),
                trailing: Text(
                  "$percentage%",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                onTap: () async {
                  // 🔥 FETCH QUIZ DATA
                  final quizSnap = await FirebaseFirestore.instance
                      .collection('quizzes')
                      .doc(quizId)
                      .get();

                  if (!quizSnap.exists) return;

                  final quiz = quizSnap.data()!;
                  final endAt =
                      (quiz['endAt'] as Timestamp).toDate();

                  final now = DateTime.now();

                  // ⛔ QUIZ STILL RUNNING
                  if (now.isBefore(endAt)) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            QuizResultLockedScreen(endAt: endAt),
                      ),
                    );
                    return;
                  }

                  // ✅ QUIZ ENDED → SHOW RESULT
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => QuizResultScreen(
                        quizId: quizId,
                        score: score,
                        total: total,
                        percentage: percentage,
                        answers: const {},
                        questions: const [],
                        endAt: endAt,
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}
