import 'dart:convert';
import 'package:QuizSphere/compiler/backend_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

// FIX 17: API key loaded from .env — never hardcode secrets in source
String get _groqApiKey => dotenv.env['GROQ_API_KEY'] ?? dotenv.env['Quiz_API'] ?? '';
const String GROQ_URL = 'https://api.groq.com/openai/v1/chat/completions';

Future<void> submitCodingAnswer({
  required String quizId,
  required String questionId,
  required String code,
  required String language,
  required String version,
  required DateTime startedAt,
}) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    throw Exception("User not logged in");
  }

  // ===============================
  // Fetch question
  // ===============================
  final questionSnap = await FirebaseFirestore.instance
      .collection('quizzes')
      .doc(quizId)
      .collection('questions')
      .doc(questionId)
      .get();

  if (!questionSnap.exists) {
    throw Exception("Question not found");
  }

  final String problem =
      (questionSnap['problem'] ?? '').toString();

  final String expectedOutput =
      (questionSnap['expectedOutput'] ?? '').toString();

  final int maxScore = questionSnap['score'] ?? 1;

  // ===============================
  // Run code via Piston
  // ===============================
  Map<String, dynamic> result;
  try {
    result = await BackendService.runCode(
      quizId: quizId,
      questionId: questionId,
      code: code,
      language: language,
      version: version,
    );
  } catch (e) {
    await _saveAttempt(
      userId: user.uid,
      quizId: quizId,
      questionId: questionId,
      language: language,
      version: version,
      score: 0,
      passed: false,
      passedByTests: false,
      passedByAI: false,
      timeTaken: DateTime.now().difference(startedAt).inSeconds,
      stdout: '',
      error: e.toString(),
    );
    rethrow;
  }

  final String stdout = (result['stdout'] ?? '').toString();
  final String stderr = (result['stderr'] ?? '').toString();
  final String compileError =
      (result['compile_output'] ?? '').toString();

  // ===============================
  // Test-case validation (PRIMARY)
  // ===============================
  final bool passedByTests =
      compileError.isEmpty &&
      stderr.isEmpty &&
      _normalize(stdout) == _normalize(expectedOutput);

  // ===============================
  // Groq validation (SECONDARY)
  // ===============================
  bool passedByAI = false;

  if (passedByTests) {
    try {
      passedByAI = await _validateWithGroq(
        problem: problem,
        expectedOutput: expectedOutput,
        code: code,
        language: language,
      );
    } catch (_) {
      passedByAI = false; // AI failure never passes user
    }
  }

  final bool finalPassed = passedByTests && passedByAI;
  final int score = finalPassed ? maxScore : 0;

  final int timeTaken =
      DateTime.now().difference(startedAt).inSeconds;

  // ===============================
  // Save attempt
  // ===============================
  await _saveAttempt(
    userId: user.uid,
    quizId: quizId,
    questionId: questionId,
    language: language,
    version: version,
    score: score,
    passed: finalPassed,
    passedByTests: passedByTests,
    passedByAI: passedByAI,
    timeTaken: timeTaken,
    stdout: stdout,
    error: compileError.isNotEmpty ? compileError : stderr,
  );
}

// ===============================
// GROQ VALIDATION
// ===============================
Future<bool> _validateWithGroq({
  required String problem,
  required String expectedOutput,
  required String code,
  required String language,
}) async {
  final response = await http.post(
    Uri.parse(GROQ_URL),
    headers: {
      'Authorization': 'Bearer $_groqApiKey',
      'Content-Type': 'application/json',
    },
    body: jsonEncode({
      'model': 'llama-3.1-70b-versatile',
      'temperature': 0,
      'messages': [
        {
          'role': 'user',
          'content': '''
You are a strict code validator.

Problem:
$problem

Expected behavior:
$expectedOutput

User code (language: $language):
$code

Rules:
- Ignore formatting
- Detect hardcoded outputs
- Do NOT optimize
- Do NOT explain

Respond ONLY in JSON:

{
  "is_correct": true | false
}
'''
        }
      ],
    }),
  );

  if (response.statusCode != 200) {
    throw Exception('Groq API error');
  }

  final data = jsonDecode(response.body);
  final content = data['choices'][0]['message']['content'];

  final parsed = jsonDecode(content);
  return parsed['is_correct'] == true;
}

// ===============================
// Helpers
// ===============================
String _normalize(String s) {
  return s.trim().replaceAll(RegExp(r'\s+'), ' ');
}

Future<void> _saveAttempt({
  required String userId,
  required String quizId,
  required String questionId,
  required String language,
  required String version,
  required int score,
  required bool passed,
  required bool passedByTests,
  required bool passedByAI,
  required int timeTaken,
  required String stdout,
  required String error,
}) async {
  await FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .collection('attempts')
      .add({
    'quizId': quizId,
    'questionId': questionId,
    'language': language,
    'version': version,
    'score': score,
    'passed': passed,
    'passedByTests': passedByTests,
    'passedByAI': passedByAI,
    'stdout': stdout.trim(),
    'error': error.trim(),
    'timeTakenSeconds': timeTaken,
    'attemptedAt': FieldValue.serverTimestamp(),
  });
}
