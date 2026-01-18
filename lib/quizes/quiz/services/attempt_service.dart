import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AttemptService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Save quiz attempt (safe + scalable)
  Future<void> saveAttempt({
    required String quizId,
    required String quizTitle,
    required int score,
    required int total,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception("User not logged in");
    }

    final attemptRef = _db
        .collection('users')
        .doc(user.uid)
        .collection('attempts')
        .doc(quizId); // 🔒 one attempt per quiz (important)

    final percentage = ((score / total) * 100).round();

    try {
      await attemptRef.set({
        'quizId': quizId,
        'quizTitle': quizTitle,
        'score': score,
        'total': total,
        'percentage': percentage,
        'userId': user.uid,
        'attemptedAt': FieldValue.serverTimestamp(), // 🔒 server time
      });
    } on FirebaseException {
      throw Exception("Failed to save attempt");
    }
  }
}
