import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminQuizService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const String _chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  // --------------------------------------------------
  // 🔐 Generate unique 6-char join code
  // --------------------------------------------------
  Future<String> _generateJoinCode() async {
    for (int i = 0; i < 5; i++) {
      final code = List.generate(
        6,
        (_) => _chars[Random.secure().nextInt(_chars.length)],
      ).join();

      final snap = await _db
          .collection('quizzes')
          .where('joinCode', isEqualTo: code)
          .limit(1)
          .get();

      if (snap.docs.isEmpty) {
        return code;
      }
    }
    throw Exception("Failed to generate join code");
  }

  // --------------------------------------------------
  // 🧠 CREATE QUIZ (PUBLIC / PRIVATE + TIMING)
  // --------------------------------------------------
  Future<Map<String, String?>> createQuiz({
    required String title,
    required String topic,
    required bool isPrivate,

    // 🔥 NEW (MANDATORY)
    required DateTime startAt,
    required DateTime endAt,
    required int durationMinutes,
  }) async {
    final cleanTitle = title.trim();
    final cleanTopic = topic.trim();

    if (cleanTitle.isEmpty) {
      throw Exception("Quiz title required");
    }
    if (cleanTopic.isEmpty) {
      throw Exception("Topic required");
    }
    if (endAt.isBefore(startAt)) {
      throw Exception("End time must be after start time");
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception("User not authenticated");
    }

    // 🔒 Prevent duplicate quiz by same user
    final duplicateCheck = await _db
        .collection('quizzes')
        .where('createdBy', isEqualTo: user.uid)
        .where('title', isEqualTo: cleanTitle)
        .where('topic', isEqualTo: cleanTopic)
        .limit(1)
        .get();

    if (duplicateCheck.docs.isNotEmpty) {
      throw Exception("You already created this quiz");
    }

    // 🔐 JOIN CODE (ONLY PRIVATE)
    String? joinCode;
    if (isPrivate) {
      joinCode = await _generateJoinCode();
    }

    final docRef = await _db.collection('quizzes').add({
      // BASIC INFO
      'title': cleanTitle,
      'topic': cleanTopic,
      'type': isPrivate ? 'private' : 'public',

      // TIMING
      'startAt': Timestamp.fromDate(startAt),
      'endAt': Timestamp.fromDate(endAt),
      'durationMinutes': durationMinutes,

      // META
      'joinCode': joinCode,
      'createdBy': user.uid,
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return {
      'quizId': docRef.id,
      'joinCode': joinCode,
    };
  }

  // --------------------------------------------------
  // ❓ ADD QUESTION
  // --------------------------------------------------
  Future<void> addQuestion({
    required String quizId,
    required String question,
    required List<String> options,
    required int correctIndex,
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

    await _db
        .collection('quizzes')
        .doc(quizId)
        .collection('questions')
        .add({
      'question': question.trim(),
      'options': options.map((e) => e.trim()).toList(),
      'correctIndex': correctIndex,
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
