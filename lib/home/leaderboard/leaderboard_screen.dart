import 'package:flutter/material.dart';
import '../leaderboard/leaderboard_service.dart';

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = LeaderboardService();

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: service.getLeaderboard(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text("No leaderboard data yet"));
        }

        final data = snapshot.data!;

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: data.length,
          itemBuilder: (_, i) {
            final item = data[i];

            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  child: Text("${i + 1}"),
                ),
                title: Text(
                  "User ${item['userId'].substring(0, 6)}",
                ),
                subtitle: Text(item['quizTitle']),
                trailing: Text(
                  "${item['percentage']}%",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
