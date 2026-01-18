import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AnswerReviewScreen extends StatelessWidget {
  final String quizId;
  final Map<String, int> answers; // ✅ FIXED

  const AnswerReviewScreen({
    super.key,
    required this.quizId,
    required this.answers,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Answer Review")),
      body: FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
        future: FirebaseFirestore.instance
            .collection('quizzes')
            .doc(quizId)
            .collection('questions')
            .orderBy('createdAt')
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(child: Text("Failed to load answers"));
          }

          final questions = snapshot.data?.docs ?? [];

          if (questions.isEmpty) {
            return const Center(child: Text("No questions found"));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: questions.length,
            itemBuilder: (context, i) {
              final doc = questions[i];
              final data = doc.data();

              final String questionId = doc.id;
              final String questionText = data['question'] ?? '';

              final List<String> options = List<String>.from(
                data['options'] ?? [],
              );

              final int? correctIndex = data['correctIndex'] is int
                  ? data['correctIndex']
                  : null;

              final int? selectedIndex = answers[questionId];
              debugPrint("QID=$questionId selected=$selectedIndex");

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Q${i + 1}. $questionText",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),

                      ...List.generate(options.length, (idx) {
                        Color bg = Colors.grey.shade100;
                        IconData? icon;

                        if (idx == correctIndex) {
                          bg = Colors.green.shade100;
                          icon = Icons.check_circle;
                        } else if (idx == selectedIndex &&
                            selectedIndex != correctIndex) {
                          bg = Colors.red.shade100;
                          icon = Icons.cancel;
                        }

                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: bg,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Expanded(child: Text(options[idx])),
                              if (icon != null) Icon(icon, size: 18),
                            ],
                          ),
                        );
                      }),

                      const SizedBox(height: 8),

                      Text(
                        selectedIndex == null
                            ? "Not attempted"
                            : selectedIndex == correctIndex
                            ? "Correct"
                            : "Wrong",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: selectedIndex == null
                              ? Colors.grey
                              : selectedIndex == correctIndex
                              ? Colors.green
                              : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
