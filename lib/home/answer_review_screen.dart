import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AnswerReviewScreen extends StatelessWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> questions;
  final Map<int, int> answers;

  const AnswerReviewScreen({
    super.key,
    required this.questions,
    required this.answers,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Answer Review")),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: questions.length,
        itemBuilder: (context, i) {
          final q = questions[i].data();
          final options = List<String>.from(q['options']);
          final correct = q['correctIndex'];
          final selected = answers[i];

          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Q${i + 1}. ${q['question']}",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),

                  ...List.generate(options.length, (idx) {
                    Color? color;

                    if (idx == correct) {
                      color = Colors.green.shade100;
                    } else if (idx == selected && selected != correct) {
                      color = Colors.red.shade100;
                    }

                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(options[idx]),
                    );
                  }),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
