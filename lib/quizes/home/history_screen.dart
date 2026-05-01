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
          child: Text('Please login',
              style: TextStyle(color: Colors.white70)),
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
                    child: CircularProgressIndicator(color: Colors.white));
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text('Error: ${snapshot.error}',
                      style: const TextStyle(color: Colors.redAccent)),
                );
              }

              final allDocs = snapshot.data?.docs ?? [];

              if (allDocs.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history, color: Colors.white24, size: 60),
                      SizedBox(height: 12),
                      Text('No quiz attempts yet',
                          style: TextStyle(color: Colors.white70, fontSize: 16)),
                      SizedBox(height: 4),
                      Text('Complete a quiz to see it here',
                          style: TextStyle(color: Colors.white38, fontSize: 13)),
                    ],
                  ),
                );
              }

              // Filter out per-question coding docs — only show summary + mcq
              final displayDocs = allDocs.where((d) {
                final t = d.data()['type']?.toString() ?? '';
                // Hide individual coding question sub-attempts
                return t != 'coding';
              }).toList();

              final dailyDocs  = displayDocs.where((d) =>
                  (d.data()['isDaily'] ?? false) == true).toList();
              final normalDocs = displayDocs.where((d) =>
                  (d.data()['isDaily'] ?? false) != true).toList();

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  if (dailyDocs.isNotEmpty) ...[
                    _sectionTitle('Daily Quiz'),
                    const SizedBox(height: 10),
                    ...dailyDocs.map((doc) =>
                        _attemptTile(context, doc, isDaily: true)),
                    const SizedBox(height: 24),
                  ],
                  if (normalDocs.isNotEmpty) ...[
                    _sectionTitle('Quiz History'),
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

  // ── Attempt tile ──────────────────────────────────────────────────────────
  Widget _attemptTile(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc, {
    required bool isDaily,
  }) {
    final data = doc.data();

    final String attemptId = doc.id;
    final String quizId    = data['quizId']    ?? '';
    final String quizTitle = data['quizTitle'] ?? 'Quiz';
    final String type      = data['type']      ?? 'mcq';

    // Support both field names
    final int    score      = (data['score']      ?? data['totalScore'] ?? 0) as int;
    final int    total      = (data['total']       ?? data['totalMax']   ?? 1) as int;
    final double percentage = (data['percentage']  ?? 0).toDouble();
    final bool   passed     = (data['passed']      ?? false) as bool;

    final Timestamp? ts = data['submittedAt'];
    final String date   = ts != null
        ? DateFormat('dd MMM yyyy, hh:mm a').format(ts.toDate())
        : '';

    final bool   isCoding = type == 'coding_summary';
    final Color  accentColor = isCoding
        ? Colors.deepPurpleAccent
        : Colors.blueAccent;

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
              const SnackBar(content: Text('Invalid quiz data')),
            );
            return;
          }

          // Daily flow
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

          // Normal / coding flow
          final quizSnap = await FirebaseFirestore.instance
              .collection('quizzes')
              .doc(quizId)
              .get();

          if (!quizSnap.exists) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Quiz not found')),
              );
            }
            return;
          }

          final quiz = quizSnap.data()!;
          final Timestamp? endTs    = quiz['endAt'];
          final DateTime?  endAt    = endTs?.toDate();
          final double     passPct  =
              (quiz['passPercentage'] ?? 60).toDouble();

          // Locked result
          if (endAt != null && DateTime.now().isBefore(endAt)) {
            if (context.mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => QuizResultLockedScreen(endAt: endAt),
                ),
              );
            }
            return;
          }

          if (context.mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => QuizResultScreen(
                  quizId:         quizId,
                  attemptId:      attemptId,
                  quizTitle:      quizTitle,
                  score:          score,
                  total:          total,
                  percentage:     percentage,
                  endAt:          endAt ?? DateTime.now(),
                  passed:         passed,
                  passPercentage: passPct,
                ),
              ),
            );
          }
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.white.withOpacity(0.10),
            border: Border.all(
              color: isCoding
                  ? Colors.deepPurpleAccent.withOpacity(0.4)
                  : Colors.white.withOpacity(0.2),
            ),
          ),
          child: Row(
            children: [
              // ── Score circle ────────────────────────────────────────────
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: percentColor.withOpacity(0.2),
                  border: Border.all(color: percentColor, width: 2),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${percentage.toStringAsFixed(0)}%',
                  style: TextStyle(
                    color: percentColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),

              const SizedBox(width: 14),

              // ── Details ─────────────────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title + type badge
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            quizTitle,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        // Type chip
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: accentColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: accentColor.withOpacity(0.5)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isCoding ? Icons.code : Icons.quiz_outlined,
                                color: accentColor,
                                size: 11,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                isCoding ? 'Coding' : 'MCQ',
                                style: TextStyle(
                                  color: accentColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Score: $score / $total',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      date,
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 12),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // ── Pass/fail icon ───────────────────────────────────────────
              Icon(
                passed ? Icons.check_circle : Icons.cancel,
                color: passed ? Colors.greenAccent : Colors.redAccent,
                size: 26,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
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
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
        ),
      ),
    );
  }
}
