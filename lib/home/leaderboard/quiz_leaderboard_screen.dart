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
      appBar: AppBar(
        title: Text("Leaderboard • $quizTitle"),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collectionGroup('attempts')
            .where('quizId', isEqualTo: quizId)
            .orderBy('percentage', descending: true)
            .orderBy('timeTakenSeconds')
            .limit(50)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(child: Text("Failed to load leaderboard"));
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return const Center(
              child: Text("No attempts for this quiz yet"),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final data = docs[index].data();

              final String userId = data['userId'];
              final int score = data['score'] ?? 0;
              final int total = data['total'] ?? 0;
              final int percentage = data['percentage'] ?? 0;
              final int timeTaken = data['timeTakenSeconds'] ?? 0;

              final int rank = index + 1;

              Color badgeColor;
              if (rank == 1) {
                badgeColor = Colors.amber;
              } else if (rank == 2) {
                badgeColor = Colors.grey;
              } else if (rank == 3) {
                badgeColor = Colors.brown;
              } else {
                badgeColor = Colors.blueGrey;
              }

              return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(userId)
                    .get(),
                builder: (context, userSnap) {
                  String userName = "Anonymous";

                  if (userSnap.hasData && userSnap.data!.exists) {
                    userName = userSnap.data!.data()?['name'] ?? "Anonymous";
                  }

                  return Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: badgeColor,
                        child: Text(
                          "#$rank",
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        userName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Score: $score / $total ($percentage%)"),
                          const SizedBox(height: 2),
                          Text(
                            "Time: ${_formatTime(timeTaken)}",
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  static String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return "${m}m ${s}s";
  }
}
