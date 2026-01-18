import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AnswerReviewScreen extends StatelessWidget {
  final String quizId;
  final Map<String, int> answers;

  const AnswerReviewScreen({
    super.key,
    required this.quizId,
    required this.answers,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Answer Review"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: _gradientBg(),
      ),
      body: Stack(
        children: [
          _gradientBg(),

          FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
            future: FirebaseFirestore.instance
                .collection('quizzes')
                .doc(quizId)
                .collection('questions')
                .orderBy('createdAt')
                .get(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                );
              }

              if (snapshot.hasError) {
                return const Center(
                  child: Text(
                    "Failed to load answers",
                    style: TextStyle(color: Colors.white70),
                  ),
                );
              }

              final questions = snapshot.data?.docs ?? [];

              if (questions.isEmpty) {
                return const Center(
                  child: Text(
                    "No questions found",
                    style: TextStyle(color: Colors.white70),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: questions.length,
                itemBuilder: (context, i) {
                  final doc = questions[i];
                  final data = doc.data();

                  final String questionId = doc.id;
                  final String questionText = data['question'] ?? '';

                  final List<String> options =
                      List<String>.from(data['options'] ?? []);

                  final int? correctIndex =
                      data['correctIndex'] is int ? data['correctIndex'] : null;

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

  // ================= UI HELPERS =================

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

  static Widget _reviewCard({
    required int index,
    required String question,
    required List<String> options,
    required int? correctIndex,
    required int? selectedIndex,
  }) {
    Color statusColor;
    String statusText;

    if (selectedIndex == null) {
      statusColor = Colors.grey;
      statusText = "Not Attempted";
    } else if (selectedIndex == correctIndex) {
      statusColor = Colors.greenAccent;
      statusText = "Correct";
    } else {
      statusColor = Colors.redAccent;
      statusText = "Wrong";
    }

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
          // ===== QUESTION =====
          Text(
            "Q$index. $question",
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),

          const SizedBox(height: 12),

          // ===== OPTIONS =====
          for (int i = 0; i < options.length; i++)
            _optionTile(
              text: options[i],
              isCorrect: i == correctIndex,
              isSelected: i == selectedIndex,
            ),

          const SizedBox(height: 10),

          // ===== STATUS =====
          Row(
            children: [
              Icon(
                selectedIndex == null
                    ? Icons.help_outline
                    : selectedIndex == correctIndex
                        ? Icons.check_circle
                        : Icons.cancel,
                color: statusColor,
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                statusText,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Widget _optionTile({
    required String text,
    required bool isCorrect,
    required bool isSelected,
  }) {
    Color bgColor = Colors.white.withOpacity(0.08);
    IconData? icon;

    if (isCorrect) {
      bgColor = Colors.green.withOpacity(0.25);
      icon = Icons.check_circle;
    } else if (isSelected && !isCorrect) {
      bgColor = Colors.red.withOpacity(0.25);
      icon = Icons.cancel;
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCorrect
              ? Colors.greenAccent
              : isSelected
                  ? Colors.redAccent
                  : Colors.transparent,
        ),
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
              color: isCorrect ? Colors.greenAccent : Colors.redAccent,
            ),
        ],
      ),
    );
  }
}
