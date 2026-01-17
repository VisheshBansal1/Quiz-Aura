import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'join_quiz_screen.dart';
import 'quiz_attempt_screen.dart'; // assume this exists

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
            .snapshots(),
        builder: (context, snapshot) {
          // ⏳ Loading
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // ❌ Error
          if (snapshot.hasError) {
            return const Center(
              child: Text("Failed to load quizzes"),
            );
          }

          final docs = snapshot.data?.docs ?? [];

          // 📭 Empty
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
              final quiz = doc.data();

              final String title = quiz['title'] ?? 'Quiz';
              final String type = quiz['type'] ?? 'public'; // public | private
              final bool isPrivate = type == 'private';

              return Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  title: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    isPrivate ? "Private quiz (join code required)" : "Public quiz",
                    style: TextStyle(
                      color: isPrivate ? Colors.redAccent : Colors.green,
                      fontSize: 12,
                    ),
                  ),
                  trailing: Icon(
                    isPrivate ? Icons.lock : Icons.play_arrow,
                  ),
                  onTap: () {
                    if (isPrivate) {
                      // 🔐 Ask for join code
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => JoinQuizScreen(),
                        ),
                      );
                    } else {
                      // ▶ Direct start
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => QuizAttemptScreen(
                            quizId: doc.id,
                          ),
                        ),
                      );
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
