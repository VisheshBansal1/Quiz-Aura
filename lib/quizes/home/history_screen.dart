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
      return const Center(
        child: Text(
          "Please login",
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          _gradientBg(),

          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .collection('attempts')
                .orderBy('attemptedAt', descending: true)
                .limit(50)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                );
              }

              if (snapshot.hasError) {
                return const Center(
                  child: Text(
                    "Failed to load history",
                    style: TextStyle(color: Colors.white70),
                  ),
                );
              }

              final docs = snapshot.data?.docs ?? [];

              if (docs.isEmpty) {
                return const Center(
                  child: Text(
                    "No quiz attempts yet",
                    style: TextStyle(color: Colors.white70),
                  ),
                );
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

                  final Color percentColor = percentage >= 75
                      ? Colors.greenAccent
                      : percentage >= 40
                          ? Colors.orangeAccent
                          : Colors.redAccent;

                  return InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () async {
                      final quizSnap = await FirebaseFirestore.instance
                          .collection('quizzes')
                          .doc(quizId)
                          .get();

                      if (!quizSnap.exists) return;

                      final quiz = quizSnap.data()!;
                      final endAt =
                          (quiz['endAt'] as Timestamp).toDate();

                      final now = DateTime.now();

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
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: Colors.white.withOpacity(0.12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.25),
                        ),
                      ),
                      child: Row(
                        children: [
                          // ===== SCORE CIRCLE =====
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: percentColor.withOpacity(0.25),
                              border: Border.all(color: percentColor),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              "$percentage%",
                              style: TextStyle(
                                color: percentColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),

                          const SizedBox(width: 14),

                          // ===== INFO =====
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Score: $score / $total",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  date,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const Icon(
                            Icons.chevron_right,
                            color: Colors.white54,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  // ================= UI HELPER =================
  static Widget _gradientBg() {
    return Container(
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
    );
  }
}
