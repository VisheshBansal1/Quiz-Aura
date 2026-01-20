import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:quiz_app/compiler/coding_grader.dart';

Future<void> submitCodingAnswer({
  required String quizId,
  required String questionId,
  required String code,
  required int languageId,
  required DateTime startedAt,
}) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    throw Exception("User not logged in");
  }

  final qRef = FirebaseFirestore.instance
      .collection('quizzes')
      .doc(quizId)
      .collection('questions')
      .doc(questionId);

  final qSnap = await qRef.get();
  if (!qSnap.exists) {
    throw Exception("Question not found");
  }

  final data = qSnap.data()!;
  if (!data.containsKey('visibleTestCases') ||
      !data.containsKey('hiddenTestCases')) {
    throw Exception("Invalid question format");
  }

  final result = await CodingGrader.grade(
    code: code,
    languageId: languageId,
    visible: List<Map<String, String>>.from(data['visibleTestCases']),
    hidden: List<Map<String, String>>.from(data['hiddenTestCases']),
    pointsPerCase: data['pointsPerTestCase'] ?? 1,
  );

  final timeTaken =
      DateTime.now().difference(startedAt).inSeconds;

  await FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .collection('attempts')
      .add({
    'quizId': quizId,
    'questionId': questionId,
    'score': result['score'],
    'passed': result['passed'],
    'totalCases': result['total'],
    'timeTakenSeconds': timeTaken,
    'languageId': languageId,
    'attemptedAt': FieldValue.serverTimestamp(),
  });
}

