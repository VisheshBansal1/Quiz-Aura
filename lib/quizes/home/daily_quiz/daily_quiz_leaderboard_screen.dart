import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class DailyLeaderboardScreen extends StatelessWidget {
  final String quizId;
  final String quizTitle;

  const DailyLeaderboardScreen({
    super.key,
    required this.quizId,
    required this.quizTitle,
  });

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    final leaderboardStream = FirebaseFirestore.instance
        .collection('dailyQuizzes')
        .doc(quizId)
        .collection('leaderboard')
        .orderBy('percentage', descending: true)
        .orderBy('timeTaken') // ✅ correct field name
        .limit(100)
        .snapshots();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          "Leaderboard • $quizTitle",
          style: const TextStyle(color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: _gradientBg(),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: Colors.white),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF0F2027),
              Color(0xFF203A43),
              Color(0xFF2C5364),
            ],
          ),
        ),
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: leaderboardStream,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(color: Colors.white),
              );
            }

            final docs = snapshot.data!.docs;

            if (docs.isEmpty) {
              return const Center(
                child: Text(
                  "No attempts yet",
                  style: TextStyle(color: Colors.white70),
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: docs.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final data = docs[index].data();
                final userId = docs[index].id;

                final String userName =
                    data['userName'] ?? data['name'] ?? "Anonymous";

                final int score = data['score'] ?? 0;
                final int total = data['total'] ?? 0;
                final double percentage =
                    (data['percentage'] ?? 0).toDouble();
                final int timeTaken =
                    data['timeTaken'] ?? 0; // ✅ correct

                return _leaderboardTile(
                  rank: index + 1,
                  badgeColor: _rankColor(index + 1),
                  userName: userName,
                  score: score,
                  total: total,
                  percentage: percentage,
                  timeTaken: timeTaken,
                  isCurrentUser:
                      userId == currentUserId,
                );
              },
            );
          },
        ),
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

  static Color _rankColor(int rank) {
    if (rank == 1) return Colors.amber;
    if (rank == 2) return Colors.grey;
    if (rank == 3) return Colors.brown;
    return Colors.blueGrey;
  }

  static Widget _leaderboardTile({
    required int rank,
    required Color badgeColor,
    required String userName,
    required int score,
    required int total,
    required double percentage,
    required int timeTaken,
    required bool isCurrentUser,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: isCurrentUser
            ? Colors.blue.withOpacity(0.25)
            : Colors.white.withOpacity(0.12),
        border: Border.all(
          color: isCurrentUser
              ? Colors.blueAccent
              : Colors.white.withOpacity(0.25),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: badgeColor,
            child: Text(
              "#$rank",
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  userName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Score: $score / $total (${percentage.toStringAsFixed(1)}%)",
                  style:
                      const TextStyle(color: Colors.white70),
                ),
                Text(
                  "Time: ${_formatTime(timeTaken)}",
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _formatTime(int seconds) {
    if (seconds <= 0) return "Not calculated";
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return "${m}m ${s}s";
  }
}