import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'join_quiz_screen.dart';
import 'quiz_attempt_screen.dart';
import 'quiz_rules_screen.dart';
import 'quiz_ended_screen.dart';

class QuizListScreen extends StatelessWidget {
  final String topic;
  const QuizListScreen({super.key, required this.topic});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(topic)),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('quizzes')
            .where('topic', isEqualTo: topic)
            .where('isActive', isEqualTo: true)
            .orderBy('startAt')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(child: Text("Failed to load quizzes"));
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return const Center(
              child: Text(
                "No quizzes available for this topic",
                style: TextStyle(fontSize: 16),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final doc = docs[i];
              final data = doc.data();

              final String title = data['title'] ?? 'Quiz';
              final bool isPrivate = data['type'] == 'private';

              final DateTime startAt = (data['startAt'] as Timestamp).toDate();
              final DateTime endAt = (data['endAt'] as Timestamp).toDate();

              final DateTime now = DateTime.now();

              String statusText;
              Color statusColor;

              if (now.isAfter(endAt)) {
                statusText = "Quiz ended";
                statusColor = Colors.grey;
              } else if (now.isBefore(startAt)) {
                statusText = "Starts at ${_formatTime(startAt)}";
                statusColor = Colors.orange;
              } else {
                statusText = "Live now";
                statusColor = Colors.green;
              }

              return Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  title: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isPrivate
                            ? "Private quiz (join code required)"
                            : "Public quiz",
                        style: TextStyle(
                          fontSize: 12,
                          color: isPrivate ? Colors.redAccent : Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        statusText,
                        style: TextStyle(fontSize: 12, color: statusColor),
                      ),
                    ],
                  ),
                  trailing: Icon(
                    isPrivate ? Icons.lock : Icons.play_arrow,
                    color: statusColor,
                  ),
                  onTap: () {
                    // 🔐 PRIVATE QUIZ
                    if (isPrivate) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const JoinQuizScreen(),
                        ),
                      );
                      return;
                    }

                    // ⛔ QUIZ ENDED
                    if (now.isAfter(endAt)) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => QuizEndedScreen(quizTitle: title),
                        ),
                      );
                      return;
                    }

                    // ⏳ QUIZ NOT STARTED → RULES
                    // ⏳ QUIZ NOT STARTED → RULES
                    if (now.isBefore(startAt)) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => QuizRulesScreen(
                            startAt: startAt,
                            onConfirmedStart: () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => QuizAttemptScreen(
                                    quizId: doc.id,
                                    endAt: endAt,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      );
                      return;
                    }

                    // ✅ QUIZ LIVE → START
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            QuizAttemptScreen(quizId: doc.id, endAt: endAt),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  static String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return "$h:$m";
  }
}
