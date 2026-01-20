import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminQuizService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const String _chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  // --------------------------------------------------
  // 🔐 Generate unique 6-char join code
  // --------------------------------------------------
  String _generateJoinCode() {
    final rand = Random.secure();
    return List.generate(
      6,
      (_) => _chars[rand.nextInt(_chars.length)],
    ).join();
  }

  // --------------------------------------------------
  // 🧠 CREATE QUIZ (PUBLIC / PRIVATE + TIMING)
  // --------------------------------------------------
  Future<Map<String, String?>> createQuiz({
    required String title,
    required String topic,
    required bool isPrivate,
    required DateTime startAt,
    required DateTime endAt,
    required int durationMinutes,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception("User not logged in");

    final String? joinCode = isPrivate ? _generateJoinCode() : null;

    final doc = await _db.collection('quizzes').add({
      'title': title.trim(),
      'topic': topic.trim(),
      'type': isPrivate ? 'private' : 'public',
      'joinCode': joinCode,
      'createdBy': uid,
      'createdAt': FieldValue.serverTimestamp(),
      'isActive': true,
      'startAt': startAt,
      'endAt': endAt,
      'durationMinutes': durationMinutes,
    });

    return {'quizId': doc.id, 'joinCode': joinCode};
  }

  // --------------------------------------------------
  // ❓ ADD QUESTION (WITH DIFFICULTY SUPPORT)
  // --------------------------------------------------
  Future<void> addQuestion({
    required String quizId,
    required String question,
    required List<String> options,
    required int correctIndex,
    String difficulty = "Medium", // ✅ DEFAULT
  }) async {
    if (quizId.isEmpty) {
      throw Exception("Invalid quiz ID");
    }
    if (question.trim().isEmpty) {
      throw Exception("Question required");
    }
    if (options.length != 4) {
      throw Exception("Exactly 4 options required");
    }
    if (correctIndex < 0 || correctIndex > 3) {
      throw Exception("Correct option must be between 0–3");
    }
    if (!["Easy", "Medium", "Hard"].contains(difficulty)) {
      throw Exception("Invalid difficulty");
    }

    await _db
        .collection('quizzes')
        .doc(quizId)
        .collection('questions')
        .add({
      'question': question.trim(),
      'options': options.map((e) => e.trim()).toList(),
      'correctIndex': correctIndex,
      'difficulty': difficulty, // ✅ STORED
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // --------------------------------------------------
  // 🔎 JOIN PRIVATE QUIZ USING CODE
  // --------------------------------------------------
  Future<String> getQuizIdByJoinCode(String inputCode) async {
    final code = inputCode.trim().toUpperCase();

    if (code.length != 6) {
      throw Exception("Invalid join code");
    }

    final snap = await _db
        .collection('quizzes')
        .where('joinCode', isEqualTo: code)
        .where('isActive', isEqualTo: true)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) {
      throw Exception("Quiz not found");
    }

    return snap.docs.first.id;
  }
}
