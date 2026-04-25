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
  // 🧠 CREATE QUIZ
  // --------------------------------------------------
  Future<Map<String, String?>> createQuiz({
    required String title,
    required String topicId,
    required String topicTitle,
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
      'topicId': topicId,
      'topicTitle': topicTitle,
      'visibility': isPrivate ? 'private' : 'public',
      'joinCode': joinCode,
      'createdBy': uid,
      'createdAt': FieldValue.serverTimestamp(),
      'isActive': true,
      'startAt': startAt,
      'endAt': endAt,
      'durationMinutes': durationMinutes,
    });

    return {
      'quizId': doc.id,
      'joinCode': joinCode,
    };
  }

  // --------------------------------------------------
  // ❓ ADD MCQ QUESTION (GENERIC)
  // --------------------------------------------------
  Future<void> addMcqQuestion({
    required String quizId,
    required Map<String, dynamic> data,
  }) async {
    if (quizId.isEmpty) throw Exception("Invalid quiz ID");

    if (data['type'] != 'mcq') {
      throw Exception("MCQ question must have type = mcq");
    }

    await _db
        .collection('quizzes')
        .doc(quizId)
        .collection('questions')
        .add({
      ...data,
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // --------------------------------------------------
  // 💻 ADD CODING QUESTION (GENERIC)
  // --------------------------------------------------
  Future<void> addCodingQuestion({
    required String quizId,
    required Map<String, dynamic> data,
  }) async {
    if (quizId.isEmpty) throw Exception("Invalid quiz ID");

    if (data['type'] != 'coding') {
      throw Exception("Coding question must have type = coding");
    }

    await _db
        .collection('quizzes')
        .doc(quizId)
        .collection('questions')
        .add({
      ...data,
      'isActive': true,
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
