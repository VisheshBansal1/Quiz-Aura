import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AnswerReviewScreen extends StatelessWidget {
  final String quizId;
  final String attemptId; // 🔥 REQUIRED

  const AnswerReviewScreen({
    super.key,
    required this.quizId,
    required this.attemptId,
  });

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Answer Review", style: TextStyle(color: Colors.white),),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: _gradientBg(),
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: Icon(Icons.arrow_back, color: Colors.white,),
        ),
      ),
      body: Stack(
        children: [
          _gradientBg(),

          FutureBuilder(
            future: Future.wait([
              // 🔹 Fetch questions
              FirebaseFirestore.instance
                  .collection('quizzes')
                  .doc(quizId)
                  .collection('questions')
                  .orderBy('createdAt')
                  .get(),

              // 🔹 Fetch answers
              FirebaseFirestore.instance
                  .collection('users')
                  .doc(userId)
                  .collection('attempts')
                  .doc(attemptId)
                  .get(),
            ]),
            builder: (context, AsyncSnapshot<List<dynamic>> snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                );
              }

              if (!snapshot.hasData || snapshot.hasError) {
                return const Center(
                  child: Text(
                    "Failed to load review",
                    style: TextStyle(color: Colors.white70),
                  ),
                );
              }

              final questionSnap =
                  snapshot.data![0] as QuerySnapshot<Map<String, dynamic>>;
              final attemptDoc =
                  snapshot.data![1] as DocumentSnapshot<Map<String, dynamic>>;

              final questions = questionSnap.docs;
              final Map<String, dynamic> rawAnswers =
                  attemptDoc.data()?['answers'] ?? {};

              // convert dynamic → Map<String, int>
              final Map<String, int> answers = rawAnswers.map(
                (key, value) => MapEntry(key, value as int),
              );

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: questions.length,
                itemBuilder: (context, i) {
                  final qDoc = questions[i];
                  final q = qDoc.data();

                  final questionId = qDoc.id;
                  final questionText = q['question'] ?? '';
                  final options = List<String>.from(q['options'] ?? []);
                  final int? correctIndex = q['correctIndex'];
                  final int? selectedIndex = answers[questionId];

                  return _reviewCard(
                    index: i + 1,
                    question: questionText,
                    options: options,
                    correctIndex: correctIndex,
                    selectedIndex: selectedIndex,
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  // ================= BACKGROUND =================

  static Widget _gradientBg() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0F2027),
            Color(0xFF203A43),
            Color(0xFF2C5364),
          ],
        ),
      ),
    );
  }

  // ================= REVIEW CARD =================

  static Widget _reviewCard({
    required int index,
    required String question,
    required List<String> options,
    required int? correctIndex,
    required int? selectedIndex,
  }) {
    final bool attempted = selectedIndex != null;
    final bool isCorrect = attempted && selectedIndex == correctIndex;

    final Color statusColor = !attempted
        ? Colors.grey
        : isCorrect
            ? Colors.greenAccent
            : Colors.redAccent;

    // final String statusText = !attempted
    //     ? "Not Attempted"
    //     : isCorrect
    //         ? "Correct"
    //         : "Wrong";

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withOpacity(0.12),
        border: Border.all(color: Colors.white.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Q$index. $question",
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),

          const SizedBox(height: 12),

          for (int i = 0; i < options.length; i++)
            _optionTile(
              text: options[i],
              isCorrect: i == correctIndex,
              isSelected: i == selectedIndex,
            ),

          const SizedBox(height: 10),

          Row(
            children: [
              // Icon(
              //   !attempted
              //       ? Icons.help_outline
              //       : isCorrect
              //           ? Icons.check_circle
              //           : Icons.cancel,
              //   color: statusColor,
              //   size: 18,
              // ),
              const SizedBox(width: 6),
              // Text(
              //   statusText,
              //   style: TextStyle(
              //     fontWeight: FontWeight.bold,
              //     color: statusColor,
              //   ),
              // ),
            ],
          ),
        ],
      ),
    );
  }

  // ================= OPTION TILE =================

  static Widget _optionTile({
    required String text,
    required bool isCorrect,
    required bool isSelected,
  }) {
    Color bgColor = Colors.white.withOpacity(0.08);
    Color borderColor = Colors.transparent;
    IconData? icon;

    if (isCorrect) {
      bgColor = Colors.green.withOpacity(0.25);
      borderColor = Colors.greenAccent;
      icon = Icons.check_circle;
    } else if (isSelected) {
      bgColor = Colors.red.withOpacity(0.25);
      borderColor = Colors.redAccent;
      icon = Icons.cancel;
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white),
            ),
          ),
          if (icon != null)
            Icon(
              icon,
              size: 18,
              color: borderColor,
            ),
        ],
      ),
    );
  }
}
