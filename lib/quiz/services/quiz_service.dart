import 'package:cloud_firestore/cloud_firestore.dart';

class QuizService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Fetch quiz by join code
  Future<DocumentSnapshot<Map<String, dynamic>>?> getQuizByCode(
    String joinCode,
  ) async {
    try {
      final code = joinCode.trim().toUpperCase();

      final query = await _db
          .collection('quizzes')
          .where('joinCode', isEqualTo: code)
          .limit(1)
          .get();

      if (query.docs.isEmpty) return null;

      return query.docs.first;
    } on FirebaseException {
      throw Exception("Failed to fetch quiz");
    }
  }

  /// Fetch quiz questions (ordered)
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> getQuestions(
    String quizId,
  ) async {
    try {
      final snap = await _db
          .collection('quizzes')
          .doc(quizId)
          .collection('questions')
          .orderBy('createdAt', descending: false)
          .get();

      return snap.docs;
    } on FirebaseException {
      throw Exception("Failed to fetch questions");
    }
  }
}
