import 'package:QuizSphere/quizes/home/daily_quiz/daily_quiz_leaderboard_screen.dart';
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
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text(
            "Please login",
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }

    final attemptsStream = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('history')
        .orderBy('submittedAt', descending: true)
        .limit(50)
        .snapshots();

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          _gradientBg(),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: attemptsStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                );
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    "Error: ${snapshot.error}",
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                );
              }

              final allDocs = snapshot.data?.docs ?? [];

              if (allDocs.isEmpty) {
                return const Center(
                  child: Text(
                    "No quiz attempts yet",
                    style: TextStyle(color: Colors.white70),
                  ),
                );
              }

              // ✅ FIXED SAFE FILTERING
              final dailyDocs = allDocs.where((d) {
                final data = d.data();
                return (data['isDaily'] ?? false) == true;
              }).toList();

              final normalDocs = allDocs.where((d) {
                final data = d.data();
                return (data['isDaily'] ?? false) != true;
              }).toList();

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (dailyDocs.isNotEmpty) ...[
                    _sectionTitle("Daily Quiz"),
                    const SizedBox(height: 10),
                    ...dailyDocs.map((doc) =>
                        _attemptTile(context, doc, isDaily: true)),
                    const SizedBox(height: 30),
                  ],
                  if (normalDocs.isNotEmpty) ...[
                    _sectionTitle("Other Quizzes"),
                    const SizedBox(height: 10),
                    ...normalDocs.map((doc) =>
                        _attemptTile(context, doc, isDaily: false)),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // ================= ATTEMPT TILE =================

  Widget _attemptTile(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc, {
    required bool isDaily,
  }) {
    final data = doc.data();

    final String attemptId = doc.id;
    final String quizId = data['quizId'] ?? '';
    final String quizTitle = data['quizTitle'] ?? "Quiz";

    final int score = (data['score'] ?? 0);
    final int total = (data['total'] ?? 1);
    final double percentage = (data['percentage'] ?? 0).toDouble();
    final bool passed = (data['passed'] ?? false);

    final Timestamp? ts = data['submittedAt'];
    final String date = ts != null
        ? DateFormat('dd MMM yyyy, hh:mm a').format(ts.toDate())
        : '';

    final Color percentColor = passed
        ? Colors.greenAccent
        : percentage >= 40
            ? Colors.orangeAccent
            : Colors.redAccent;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () async {
          if (quizId.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Invalid quiz data")),
            );
            return;
          }

          // ✅ DAILY FLOW
          if (isDaily) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DailyLeaderboardScreen(
                  quizId: quizId,
                  quizTitle: quizTitle,
                ),
              ),
            );
            return;
          }

          // ✅ NORMAL QUIZ FLOW
          final quizSnap = await FirebaseFirestore.instance
              .collection('quizzes')
              .doc(quizId)
              .get();

          if (!quizSnap.exists) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Quiz not found")),
            );
            return;
          }

          final quiz = quizSnap.data()!;

          final Timestamp? endTimestamp = quiz['endAt'];
          final DateTime? endAt = endTimestamp?.toDate();
          final double passPercentage =
              (quiz['passPercentage'] ?? 60).toDouble();

          // 🔒 LOCKED RESULT
          if (endAt != null && DateTime.now().isBefore(endAt)) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => QuizResultLockedScreen(endAt: endAt),
              ),
            );
            return;
          }

          // ✅ RESULT SCREEN
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => QuizResultScreen(
                quizId: quizId,
                attemptId: attemptId,
                quizTitle: quizTitle,
                score: score,
                total: total,
                percentage: percentage,
                endAt: endAt ?? DateTime.now(),
                passed: passed,
                passPercentage: passPercentage,
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
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: percentColor.withOpacity(0.25),
                  border: Border.all(color: percentColor),
                ),
                alignment: Alignment.center,
                child: Text(
                  "${percentage.toStringAsFixed(0)}%",
                  style: TextStyle(
                    color: percentColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      quizTitle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Score: $score / $total",
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      date,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                passed ? Icons.check_circle : Icons.cancel,
                color: passed ? Colors.greenAccent : Colors.redAccent,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  static Widget _gradientBg() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
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