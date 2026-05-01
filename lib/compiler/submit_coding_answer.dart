// submit_coding_answer.dart
// Standalone helper — submits a coding answer from outside CodingQuizScreen
// (e.g. from a battle or tournament flow that already has the run result).

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'backend_service.dart';
import 'compiler_groq_service.dart';
import 'language_constants.dart';

class SubmitCodingAnswer {
  /// Runs [code] against the question's stdin, grades it, and writes the
  /// attempt document.  Returns the Firestore attempt document ID.
  static Future<String> submit({
    required String quizId,
    required String questionId,
    required String code,
    required Language language,
    required DateTime endAt,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not logged in');

    // ── Quiz meta ──────────────────────────────────────────────────────────
    final quizSnap = await FirebaseFirestore.instance
        .collection('quizzes')
        .doc(quizId)
        .get();

    final quizData = quizSnap.data() ?? {};
    final quizTitle = quizData['title']?.toString() ?? 'Quiz';
    final passPercentage = (quizData['passPercentage'] ?? 60).toDouble();

    // ── Question ────────────────────────────────────────────────────────────
    final qSnap = await FirebaseFirestore.instance
        .collection('quizzes')
        .doc(quizId)
        .collection('questions')
        .doc(questionId)
        .get();

    if (!qSnap.exists) throw Exception('Question not found: $questionId');

    final q = qSnap.data()!;
    final stdin = (q['input'] ?? '').toString();
    final expected = (q['expectedOutput'] ?? '').toString();
    final problem = (q['description'] ?? q['problem'] ?? '').toString();
    final maxScore = (q['score'] is int) ? q['score'] as int : 1;

    // ── Execute ─────────────────────────────────────────────────────────────
    final result = await BackendService.runCode(
      quizId: quizId,
      questionId: questionId,
      code: code,
      language: language.pistonKey,
      version: language.version,
      stdin: stdin,
    );

    final stdout = result['stdout']?.toString() ?? '';
    final compileErr = result['compile_output']?.toString() ?? '';

    // ── Grade ────────────────────────────────────────────────────────────────
    bool passed;
    if (compileErr.isNotEmpty) {
      passed = false;
    } else if (_outputsMatch(stdout, expected)) {
      passed = true;
    } else {
      passed = await GroqService.validateCode(
        problem: problem,
        expected: expected,
        code: code,
        language: language.name,
      );
    }

    final score = passed ? maxScore : 0;
    final percentage = maxScore == 0 ? 0.0 : (score / maxScore) * 100.0;
    final finalPassed = percentage >= passPercentage;
    final timeTaken = endAt.difference(DateTime.now()).inSeconds.abs();

    // ── Persist ──────────────────────────────────────────────────────────────
    final ref = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('attempts')
        .add({
          'quizId': quizId,
          'quizTitle': quizTitle,
          'questionId': questionId,
          'type': 'coding',
          'section': 'coding',
          'language': language.name,
          'code': code,
          'passed': finalPassed,
          'score': score,
          'total': maxScore,
          'percentage': percentage,
          'passPercentage': passPercentage,
          'expectedOutput': expected,
          'actualOutput': stdout,
          'compileError': compileErr,
          'timeTakenSeconds': timeTaken,
          'submittedAt': FieldValue.serverTimestamp(),
          'autoSubmitted': false,
        });

    return ref.id;
  }

  static bool _outputsMatch(String actual, String expected) {
    List<String> tokens(String s) => s
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .trim()
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();

    final a = tokens(actual);
    final b = tokens(expected);
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
