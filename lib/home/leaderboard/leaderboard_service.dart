import 'package:cloud_firestore/cloud_firestore.dart';

class LeaderboardService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Fetch top users by best percentage
  Future<List<Map<String, dynamic>>> getLeaderboard() async {
    final snapshot = await _db
        .collectionGroup('attempts') // 🔥 across all users
        .orderBy('percentage', descending: true)
        .limit(50)
        .get();

    return snapshot.docs.map((doc) {
      return {
        'userId': doc['userId'],
        'percentage': doc['percentage'],
        'quizTitle': doc['quizTitle'],
      };
    }).toList();
  }
}
