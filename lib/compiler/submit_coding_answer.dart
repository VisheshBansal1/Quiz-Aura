// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:quiz_app/compiler/coding_grader.dart';

// Future<void> submitCodingAnswer({
//   required String quizId,
//   required String questionId,
//   required String code,
//   required String language,
//   required DateTime startedAt,
// }) async {
//   final qSnap = await FirebaseFirestore.instance
//       .collection('quizzes')
//       .doc(quizId)
//       .collection('questions')
//       .doc(questionId)
//       .get();

//   final data = qSnap.data()!;

//   final result = await CodingGrader.grade(
//     code: code,
//     language: language,
//     visible: List<Map<String, String>>.from(data['visibleTestCases']),
//     hidden: List<Map<String, String>>.from(data['hiddenTestCases']),
//     pointsPerCase: data['pointsPerTestCase'],
//   );

//   final timeTaken =
//       DateTime.now().difference(startedAt).inSeconds;

//   await FirebaseFirestore.instance
//       .collection('users')
//       .doc(FirebaseAuth.instance.currentUser!.uid)
//       .collection('attempts')
//       .add({
//     'quizId': quizId,
//     'questionId': questionId,
//     'score': result['score'],
//     'passed': result['passed'],
//     'totalCases': result['total'],
//     'timeTakenSeconds': timeTaken,
//     'attemptedAt': FieldValue.serverTimestamp(),
//   });
// }
