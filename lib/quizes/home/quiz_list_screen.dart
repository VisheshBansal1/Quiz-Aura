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
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(topic, style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: _gradientBg(),
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: Icon(Icons.arrow_back, color: Colors.white),
        ),
      ),
      body: Stack(
        children: [
          _gradientBg(),

          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('quizzes')
                .where('topic', isEqualTo: topic)
                .where('isActive', isEqualTo: true)
                .orderBy('startAt')
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
                    "Failed to load quizzes",
                    style: TextStyle(color: Colors.white70),
                  ),
                );
              }

              final docs = snapshot.data?.docs ?? [];

              if (docs.isEmpty) {
                return const Center(
                  child: Text(
                    "No quizzes available for this topic",
                    style: TextStyle(color: Colors.white70),
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

                  final DateTime startAt = (data['startAt'] as Timestamp)
                      .toDate();
                  final DateTime endAt = (data['endAt'] as Timestamp).toDate();

                  final DateTime now = DateTime.now();

                  String statusText;
                  Color statusColor;
                  IconData statusIcon;

                  if (now.isAfter(endAt)) {
                    statusText = "Quiz ended";
                    statusColor = Colors.grey;
                    statusIcon = Icons.lock_clock;
                  } else if (now.isBefore(startAt)) {
                    statusText = "Starts at ${_formatTime(startAt)}";
                    statusColor = Colors.orangeAccent;
                    statusIcon = Icons.schedule;
                  } else {
                    statusText = "Live now";
                    statusColor = Colors.greenAccent;
                    statusIcon = Icons.play_arrow;
                  }

                  return InkWell(
                    borderRadius: BorderRadius.circular(20),
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
                          // ===== STATUS ICON =====
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: statusColor.withOpacity(0.25),
                              border: Border.all(color: statusColor),
                            ),
                            child: Icon(statusIcon, color: statusColor),
                          ),

                          const SizedBox(width: 14),

                          // ===== INFO =====
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  isPrivate
                                      ? "Private quiz (join code required)"
                                      : "Public quiz",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isPrivate
                                        ? Colors.redAccent
                                        : Colors.blueAccent,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  statusText,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: statusColor,
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

  // ================= HELPERS =================
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

  static String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return "$h:$m";
  }
}
