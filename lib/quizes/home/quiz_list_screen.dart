import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'join_quiz_screen.dart';
import 'quiz_rules_screen.dart';
import 'quiz_ended_screen.dart';
import 'question_list_screen.dart';

class QuizListScreen extends StatelessWidget {
  final String topicId;
  final String topicTitle;

  const QuizListScreen({
    super.key,
    required this.topicId,
    required this.topicTitle,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(topicTitle, style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: _gradientBg(),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          _gradientBg(),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('quizzes')
                .where('topicId', isEqualTo: topicId)
                .orderBy('createdAt', descending: true) // 🔥 latest first
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(
                  child: Text(
                    "Something went wrong",
                    style: TextStyle(color: Colors.white),
                  ),
                );
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                );
              }

              final docs = snapshot.data?.docs ?? [];

              if (docs.isEmpty) {
                return const Center(
                  child: Text(
                    "No quizzes available",
                    style: TextStyle(color: Colors.white70),
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 16),
                itemBuilder: (context, i) {
                  final doc = docs[i];
                  final data = doc.data();

                  return QuizCard(
                    quizId: doc.id,
                    title: data['title'] ?? 'Quiz',
                    isPrivate: data['type'] == 'private',
                    duration: data['durationMinutes'] ?? 10,
                    totalQuestions: data['totalQuestions'] ?? 0,
                    startTs: data['startAt'],
                    endTs: data['endAt'],
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  static Widget _gradientBg() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    );
  }
}

class QuizCard extends StatefulWidget {
  final String quizId;
  final String title;
  final bool isPrivate;
  final int duration;
  final int totalQuestions;
  final Timestamp? startTs;
  final Timestamp? endTs;

  const QuizCard({
    super.key,
    required this.quizId,
    required this.title,
    required this.isPrivate,
    required this.duration,
    required this.totalQuestions,
    required this.startTs,
    required this.endTs,
  });

  @override
  State<QuizCard> createState() => _QuizCardState();
}

class _QuizCardState extends State<QuizCard> {
  Timer? _timer;
  DateTime _now = DateTime.now();
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();

    if (widget.startTs != null && widget.endTs != null) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        final now = DateTime.now();
        final endAt = widget.endTs!.toDate();

        if (now.isAfter(endAt)) {
          _handleQuizEnd();
        }

        if (mounted) {
          setState(() {
            _now = now;
          });
        }
      });
    }
  }

  Future<void> _handleQuizEnd() async {
    if (_isUpdating) return;

    _isUpdating = true;

    await _markQuizEnded();

    _timer?.cancel();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.startTs == null || widget.endTs == null) {
      return const SizedBox();
    }

    final startAt = widget.startTs!.toDate();
    final endAt = widget.endTs!.toDate();

    final isLive = _now.isAfter(startAt) && _now.isBefore(endAt);
    final isEnded = _now.isAfter(endAt);

    final startRemaining = startAt.difference(_now);
    final endRemaining = endAt.difference(_now);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: Colors.white.withOpacity(0.1),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              _statusChip(isLive, isEnded),
            ],
          ),

          const SizedBox(height: 10),

          Row(
            children: [
              _infoTile(
                Icons.help_outline,
                "${widget.totalQuestions} Questions",
              ),
              const SizedBox(width: 12),
              _infoTile(Icons.timer, "${widget.duration} min"),
            ],
          ),

          if (!isLive && !isEnded)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                "Starts in ${_formatDuration(startRemaining)}",
                style: const TextStyle(color: Colors.orangeAccent),
              ),
            ),

          if (isLive)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                "Ends in ${_formatDuration(endRemaining)}",
                style: const TextStyle(
                  color: Colors.greenAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

          const SizedBox(height: 14),

          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isLive && widget.totalQuestions > 0
                    ? Colors.greenAccent
                    : Colors.grey,
                foregroundColor: Colors.black,
              ),
              onPressed: () {
                if (widget.totalQuestions == 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Quiz has no questions")),
                  );
                  return;
                }

                if (widget.isPrivate) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const JoinQuizScreen()),
                  );
                  return;
                }

                if (isEnded) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => QuizEndedScreen(quizTitle: widget.title),
                    ),
                  );
                  return;
                }

                if (!isLive) return;

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => QuizRulesScreen(
                      startAt: startAt,
                      onConfirmedStart: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => QuestionListScreen(
                              quizId: widget.quizId,
                              quizTitle: widget.title,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
              child: Text(
                isLive
                    ? "START QUIZ"
                    : isEnded
                    ? "ENDED"
                    : "NOT STARTED",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _infoTile(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: Colors.white54, size: 18),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(color: Colors.white70)),
      ],
    );
  }

  static Widget _statusChip(bool isLive, bool isEnded) {
    Color color;
    String text;

    if (isEnded) {
      color = Colors.grey;
      text = "ENDED";
    } else if (isLive) {
      color = Colors.greenAccent;
      text = "LIVE";
    } else {
      color = Colors.orangeAccent;
      text = "UPCOMING";
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  static String _formatDuration(Duration d) {
    if (d.isNegative) return "00:00:00";

    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;

    return "${h.toString().padLeft(2, '0')}:"
        "${m.toString().padLeft(2, '0')}:"
        "${s.toString().padLeft(2, '0')}";
  }

  Future<void> _markQuizEnded() async {
    try {
      final doc = FirebaseFirestore.instance
          .collection('quizzes')
          .doc(widget.quizId);

      final snap = await doc.get();

      if (snap.exists && snap.data()?['isActive'] == true) {
        await doc.update({
          "isActive": false,
          "endedAt": FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint("Failed to update quiz status: $e");
    }
  }
}
