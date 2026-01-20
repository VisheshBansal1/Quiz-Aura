import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class QuizLeaderboardScreen extends StatelessWidget {
  final String quizId;
  final String quizTitle;

  const QuizLeaderboardScreen({
    super.key,
    required this.quizId,
    required this.quizTitle,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text("Leaderboard • $quizTitle", style: TextStyle(color: Colors.white),),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: _gradientBg(),
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: Icon(Icons.arrow_back, color: Colors.white,),
        ),
      ),
      body: Stack(
        children: [
          _gradientBg(),

          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collectionGroup('attempts')
                .where('quizId', isEqualTo: quizId)
                .orderBy('percentage', descending: true)
                .orderBy('timeTakenSeconds')
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
                    "Failed to load leaderboard",
                    style: TextStyle(color: Colors.white70),
                  ),
                );
              }

              final docs = snapshot.data?.docs ?? [];

              if (docs.isEmpty) {
                return const Center(
                  child: Text(
                    "No attempts for this quiz yet",
                    style: TextStyle(color: Colors.white70),
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final data = docs[index].data();

                  final String userId = data['userId'];
                  final int score = data['score'] ?? 0;
                  final int total = data['total'] ?? 0;
                  final int percentage = data['percentage'] ?? 0;
                  final int timeTaken = data['timeTakenSeconds'] ?? 0;

                  final int rank = index + 1;

                  final Color badgeColor = _rankColor(rank);

                  return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    future: FirebaseFirestore.instance
                        .collection('users')
                        .doc(userId)
                        .get(),
                    builder: (context, userSnap) {
                      String userName = "Anonymous";

                      if (userSnap.hasData && userSnap.data!.exists) {
                        userName =
                            userSnap.data!.data()?['name'] ?? "Anonymous";
                      }

                      return _leaderboardTile(
                        rank: rank,
                        badgeColor: badgeColor,
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
        ],
      ),
    );
  }

  // ================= UI HELPERS =================

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
    required int percentage,
    required int timeTaken,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withOpacity(0.12),
        border: Border.all(color: Colors.white.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          // ===== RANK BADGE =====
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

          // ===== USER INFO =====
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  userName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Score: $score / $total ($percentage%)",
                  style: const TextStyle(color: Colors.white70),
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
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return "${m}m ${s}s";
  }
}
