import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class QuizLeaderboardScreen extends StatelessWidget {
  final String quizId;
  final String quizTitle;
  final bool isDaily;

  const QuizLeaderboardScreen({
    super.key,
    required this.quizId,
    required this.quizTitle,
    this.isDaily = false,
  });

  @override
  Widget build(BuildContext context) {
    final String displayTitle =
        quizTitle.trim().isEmpty ? "Leaderboard" : quizTitle;

    final Query<Map<String, dynamic>> query = isDaily
        ? FirebaseFirestore.instance
            .collection('dailyQuizzes')
            .doc(quizId)
            .collection('leaderboard')
            .orderBy('percentage', descending: true)
            .orderBy('timeTaken')
            .limit(50)
        // FIX 20: collectionGroup('attempts') was too broad — use the direct
        // quizzes/{quizId}/attempts path so only this quiz's data is returned.
        : FirebaseFirestore.instance
            .collection('quizzes')
            .doc(quizId)
            .collection('attempts')
            .orderBy('percentage', descending: true)
            .orderBy('timeTakenSeconds')
            .limit(50);

    return Scaffold(
      backgroundColor: Color(0xFF2C5364),
      appBar: AppBar(
        title: Text(
          "${isDaily ? "Daily" : "Quiz"} Leaderboard • $displayTitle",
          style: const TextStyle(color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
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
          stream: query.snapshots(),
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
                final int rank = index + 1;

                final int score = data['score'] ?? 0;
                final int total = data['total'] ?? 0;
                final double percentage =
                    (data['percentage'] ?? 0).toDouble();

                final int timeTaken = isDaily
                    ? (data['timeTaken'] ?? 0)
                    : (data['timeTakenSeconds'] ?? 0);

                // 🔥 Try to get userName first
                final String? storedName = data['userName'];

                if (storedName != null &&
                    storedName.trim().isNotEmpty) {
                  return _leaderboardTile(
                    rank: rank,
                    badgeColor: _rankColor(rank),
                    userName: storedName,
                    score: score,
                    total: total,
                    percentage: percentage,
                    timeTaken: timeTaken,
                  );
                }

                // 🔥 Fallback: fetch from users collection
                final String userId =
                    data['userId'] ?? docs[index].id;

                return FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('users')
                      .doc(userId)
                      .get(),
                  builder: (context, userSnap) {
                    String userName = "Unknown";

                    if (userSnap.hasData &&
                        userSnap.data!.exists) {
                      final userData =
                          userSnap.data!.data()
                              as Map<String, dynamic>?;
                      userName =
                          userData?['name'] ??
                              userData?['userName'] ??
                              "Unknown";
                    }

                    return _leaderboardTile(
                      rank: rank,
                      badgeColor: _rankColor(rank),
                      userName: userName,
                      score: score,
                      total: total,
                      percentage: percentage,
                      timeTaken: timeTaken,
                    );
                  },
                );
              },
            );
          },
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
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withOpacity(0.12),
        border:
            Border.all(color: Colors.white.withOpacity(0.25)),
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
    if (seconds <= 0) return "-";
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return "${m}m ${s}s";
  }
}