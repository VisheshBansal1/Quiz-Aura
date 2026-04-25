import 'package:QuizSphere/compiler/coding_quiz_screen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'quiz_attempt_screen.dart';

class QuestionListScreen extends StatelessWidget {
  final String quizId;
  final String quizTitle;

  const QuestionListScreen({
    super.key,
    required this.quizId,
    required this.quizTitle,
  });

  // ================= GET QUIZ END TIME =================
  Future<DateTime> _getQuizEndAt() async {
    final snap = await FirebaseFirestore.instance
        .collection('quizzes')
        .doc(quizId)
        .get();

    final ts = snap.data()?['endAt'];
    return ts is Timestamp
        ? ts.toDate()
        : DateTime.now().add(const Duration(minutes: 30));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F2027),
      appBar: AppBar(
        title: Text(quizTitle, style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF0F2027),
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: Icon(Icons.arrow_back, color: Colors.white),
        ),
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('quizzes')
            .doc(quizId)
            .collection('questions')
            .where('isActive', isEqualTo: true)
            .orderBy('createdAt')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }

          final docs = snapshot.data!.docs;

          // Separate MCQ & Coding
          final mcqQuestions = docs
              .where((d) => d['type'] != 'coding')
              .toList();
          final codingQuestions = docs
              .where((d) => d['type'] == 'coding')
              .toList();

          final mcqCount = mcqQuestions.length;
          final codingCount = codingQuestions.length;

          if (mcqCount == 0 && codingCount == 0) {
            return const Center(
              child: Text(
                "No questions available",
                style: TextStyle(color: Colors.white70),
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // ===== MCQ CARD =====
                _infoCard(
                  title: "MCQ Section",
                  subtitle: "$mcqCount Questions",
                  icon: Icons.quiz,
                  color: Colors.greenAccent,
                ),

                const SizedBox(height: 16),

                // ===== CODING CARD =====
                // _infoCard(
                //   title: "Coding Section",
                //   subtitle: "$codingCount Problems",
                //   icon: Icons.code,
                //   color: Colors.deepPurpleAccent,
                // ),
                const Spacer(),

                // ===== START MCQ =====
                if (mcqCount > 0)
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.greenAccent,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () async {
                        final endAt = await _getQuizEndAt();

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => QuizAttemptScreen(
                              quizId: quizId,
                              endAt: endAt,
                              isDaily: false,
                              topicId: quizId,
                              topicTitle: quizTitle,
                            ),
                          ),
                        );
                      },
                      child: const Text(
                        "START MCQ SECTION",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),

                if (mcqCount > 0 && codingCount > 0) const SizedBox(height: 12),

                // ===== START CODING =====
                if (codingCount > 0)
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurpleAccent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () async {
                        final endAt = await _getQuizEndAt();

                        // ✅ pick FIRST coding question
                        final firstCodingQuestionId = codingQuestions.first.id;

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CodingQuizScreen(
                              quizId: quizId,
                              questionId: firstCodingQuestionId,
                              endAt: endAt,
                            ),
                          ),
                        );
                      },
                      child: const Text(
                        "START CODING SECTION",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 20),

                // ===== INFO =====
                const Text(
                  "• You can switch between MCQ and Coding anytime\n"
                  "• One global timer for the entire quiz\n"
                  "• Test auto-submits when time ends",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ================= INFO CARD =================
  Widget _infoCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withOpacity(0.1),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.2),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(subtitle, style: const TextStyle(color: Colors.white70)),
            ],
          ),
        ],
      ),
    );
  }
}
