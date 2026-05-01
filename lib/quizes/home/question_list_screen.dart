import 'package:QuizSphere/compiler/coding_quiz_screen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'quiz_attempt_screen.dart';

/// Shows a pre-quiz overview with MCQ count, Coding count, and separate
/// START buttons for each section.  Supports MCQ-only, Coding-only, and
/// Mixed quizzes.
class QuestionListScreen extends StatelessWidget {
  final String quizId;
  final String quizTitle;

  const QuestionListScreen({
    super.key,
    required this.quizId,
    required this.quizTitle,
  });

  Future<Map<String, dynamic>> _loadQuizMeta() async {
    final snap = await FirebaseFirestore.instance
        .collection('quizzes')
        .doc(quizId)
        .get();
    final data = snap.data() ?? {};

    final ts = data['endAt'];
    final endAt = ts is Timestamp
        ? ts.toDate()
        : DateTime.now().add(const Duration(minutes: 30));

    final topicId = data['topicId'] ?? '';
    final topicTitle = data['topicTitle'] ?? quizTitle;
    final quizType = data['quizType'] ?? 'mcq';

    return {
      'endAt': endAt,
      'topicId': topicId,
      'topicTitle': topicTitle,
      'quizType': quizType,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F2027),
      appBar: AppBar(
        title: Text(quizTitle, style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF0F2027),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: Colors.white),
        ),
        elevation: 0,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _loadQuizMeta(),
        builder: (context, meta) {
          if (!meta.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }

          final endAt = meta.data!['endAt'] as DateTime;
          final topicId = meta.data!['topicId'] as String;
          final topicTitle = meta.data!['topicTitle'] as String;

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
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

              final mcqDocs = docs.where((d) => d['type'] != 'coding').toList();
              final codingDocs = docs
                  .where((d) => d['type'] == 'coding')
                  .toList();

              final mcqCount = mcqDocs.length;
              final codingCount = codingDocs.length;

              if (mcqCount == 0 && codingCount == 0) {
                return const Center(
                  child: Text(
                    'No questions available',
                    style: TextStyle(color: Colors.white70),
                  ),
                );
              }

              final codingIds = codingDocs.map((d) => d.id).toList();

              return Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header ───────────────────────────────────────────
                    const Text(
                      'Quiz Overview',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      mcqCount > 0 && codingCount > 0
                          ? 'This is a Mixed quiz — complete both sections'
                          : mcqCount > 0
                          ? 'MCQ only quiz'
                          : 'Coding only quiz',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 13,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Section cards ────────────────────────────────────
                    if (mcqCount > 0)
                      _SectionCard(
                        title: 'MCQ Section',
                        subtitle:
                            '$mcqCount question${mcqCount != 1 ? "s" : ""}',
                        icon: Icons.quiz_outlined,
                        color: Colors.greenAccent,
                        tags: ['Multiple choice', 'Auto graded'],
                      ),

                    if (mcqCount > 0 && codingCount > 0)
                      const SizedBox(height: 14),

                    if (codingCount > 0)
                      _SectionCard(
                        title: 'Coding Section',
                        subtitle:
                            '$codingCount problem${codingCount != 1 ? "s" : ""}',
                        icon: Icons.code_outlined,
                        color: Colors.deepPurpleAccent,
                        tags: ['Write code', 'Run & submit'],
                      ),

                    const Spacer(),

                    // ── Info ─────────────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        '⏱  One global timer for the entire quiz\n'
                        '🔒  No back navigation once started\n'
                        '📋  Auto-submits when time ends',
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 12,
                          height: 1.6,
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // ── Start buttons ─────────────────────────────────────
                    if (mcqCount > 0)
                      _startButton(
                        context: context,
                        label: 'START MCQ SECTION',
                        color: Colors.greenAccent,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => QuizAttemptScreen(
                                quizId: quizId,
                                endAt: endAt,
                                isDaily: false,
                                topicId: topicId,
                                topicTitle: topicTitle,
                                isMixed: codingCount > 0,
                                codingQuestionIds: codingIds,
                              ),
                            ),
                          );
                        },
                      ),

                    if (mcqCount > 0 && codingCount > 0)
                      const SizedBox(height: 12),

                    if (codingCount > 0)
                      _startButton(
                        context: context,
                        label: 'START CODING SECTION',
                        color: Colors.deepPurpleAccent,
                        textColor: Colors.white,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CodingQuizScreen(
                                quizId: quizId,
                                endAt: endAt,
                                questionIds: codingIds,
                                isMixed: mcqCount > 0,
                              ),
                            ),
                          );
                        },
                      ),

                    const SizedBox(height: 20),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _startButton({
    required BuildContext context,
    required String label,
    required Color color,
    Color textColor = Colors.black,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: textColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 4,
        ),
        onPressed: onTap,
        child: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
      ),
    );
  }
}

// ── Section info card ─────────────────────────────────────────────────────────
class _SectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final List<String> tags;

  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.tags,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withOpacity(0.07),
        border: Border.all(color: color.withOpacity(0.4), width: 1.5),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.2),
            radius: 26,
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
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
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: tags
                      .map(
                        (t) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            t,
                            style: TextStyle(
                              color: color,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}