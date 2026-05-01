// ============================================================
// FILE: lib/quizes/home/quiz_list_screen.dart
//
// BUGS FIXED:
//   1. NO "ALREADY PLAYED" GATE — Users could replay the same quiz
//      unlimited times. Fix: QuizCard now checks
//      quizzes/{quizId}/attempts/{uid} on mount. If a doc exists,
//      the button shows "ALREADY PLAYED" and is disabled.
//   2. QuizCard converted from StatefulWidget → ConsumerStatefulWidget
//      so it can read Firebase auth uid without prop drilling.
//   3. _ShimmerList was placed INSIDE _QuizCardState (previous syntax
//      error) — moved to top level.
// ============================================================

import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
                .orderBy('createdAt', descending: true)
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
                return const _ShimmerList();
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
                    quizType: data['quizType'] ?? 'mcq',
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

// ─────────────────────────────────────────────────────────────────────────────
// QuizCard — now ConsumerStatefulWidget so it can check attempts
// ─────────────────────────────────────────────────────────────────────────────

class QuizCard extends ConsumerStatefulWidget {
  final String quizId;
  final String title;
  final bool isPrivate;
  final int duration;
  final int totalQuestions;
  final Timestamp? startTs;
  final Timestamp? endTs;
  final String quizType;

  const QuizCard({
    super.key,
    required this.quizId,
    required this.title,
    required this.isPrivate,
    required this.duration,
    required this.totalQuestions,
    required this.startTs,
    required this.endTs,
    this.quizType = 'mcq',
  });

  @override
  ConsumerState<QuizCard> createState() => _QuizCardState();
}

class _QuizCardState extends ConsumerState<QuizCard> {
  Timer? _timer;
  DateTime _now = DateTime.now();
  bool _isUpdating = false;

  // ── Already-played state ──────────────────────────────────────────────────
  // FIX: Track whether this user has already submitted an attempt for this quiz.
  // Loaded once on initState; shown as a disabled "ALREADY PLAYED" button.
  bool _alreadyPlayed = false;
  bool _checkingAttempt = true; // show a mini spinner while checking

  @override
  void initState() {
    super.initState();

    // Check if user already played this quiz
    _checkAlreadyPlayed();

    if (widget.startTs != null && widget.endTs != null) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        final now = DateTime.now();
        final endAt = widget.endTs!.toDate();

        if (now.isAfter(endAt)) {
          _handleQuizEnd();
        }

        if (mounted) setState(() => _now = now);
      });
    }
  }

  // ── Check if the current user has already attempted this quiz ─────────────
  Future<void> _checkAlreadyPlayed() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _checkingAttempt = false);
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('quizzes')
          .doc(widget.quizId)
          .collection('attempts')
          .doc(uid)
          .get();

      if (mounted) {
        setState(() {
          _alreadyPlayed = doc.exists;
          _checkingAttempt = false;
        });
      }
    } catch (e) {
      debugPrint('[QuizCard] Failed to check attempt: $e');
      if (mounted) setState(() => _checkingAttempt = false);
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
        border: Border.all(
          color: _alreadyPlayed
              ? Colors.tealAccent.withOpacity(0.4)
              : Colors.white.withOpacity(0.2),
        ),
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
              if (_alreadyPlayed)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.tealAccent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.tealAccent.withOpacity(0.5),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: Colors.tealAccent,
                        size: 13,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Played',
                        style: TextStyle(
                          color: Colors.tealAccent,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                )
              else
                _statusChip(isLive, isEnded),
              const SizedBox(width: 6),
              _quizTypeChip(widget.quizType),
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

          if (!isLive && !isEnded && !_alreadyPlayed)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                "Starts in ${_formatDuration(startRemaining)}",
                style: const TextStyle(color: Colors.orangeAccent),
              ),
            ),

          if (isLive && !_alreadyPlayed)
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

          if (_alreadyPlayed)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                "You have already completed this quiz.",
                style: TextStyle(color: Colors.tealAccent, fontSize: 12),
              ),
            ),

          const SizedBox(height: 14),

          // ── Action button ─────────────────────────────────────────────
          _buildActionButton(context, isLive, isEnded, startAt),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    bool isLive,
    bool isEnded,
    DateTime startAt,
  ) {
    // Still checking → show mini spinner
    if (_checkingAttempt) {
      return const SizedBox(
        width: double.infinity,
        height: 48,
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              color: Colors.white54,
              strokeWidth: 2,
            ),
          ),
        ),
      );
    }

    // Already played → show completed state, no action
    if (_alreadyPlayed) {
      return SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.tealAccent.withOpacity(0.15),
            foregroundColor: Colors.tealAccent,
            side: const BorderSide(color: Colors.tealAccent, width: 1),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
          onPressed: null, // disabled — cannot replay
          icon: const Icon(Icons.check_circle_outline, size: 18),
          label: const Text(
            "ALREADY PLAYED",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      );
    }

    // Normal start button
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: isLive && widget.totalQuestions > 0
              ? Colors.greenAccent
              : Colors.grey,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
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
                quizType: widget.quizType,
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
    );
  }

  static Widget _quizTypeChip(String quizType) {
    final labels = {'mcq': 'MCQ', 'coding': 'Code', 'mixed': 'Mixed'};
    final colors = {
      'mcq': Colors.greenAccent,
      'coding': Colors.deepPurpleAccent,
      'mixed': Colors.orangeAccent,
    };
    final icons = {
      'mcq': Icons.quiz_outlined,
      'coding': Icons.code,
      'mixed': Icons.layers,
    };
    final label = labels[quizType] ?? 'MCQ';
    final color = colors[quizType] ?? Colors.greenAccent;
    final icon = icons[quizType] ?? Icons.quiz_outlined;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
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
    final Color color;
    final String text;

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
    return "${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";
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

// ─────────────────────────────────────────────────────────────────────────────
// Shimmer skeleton list
// ─────────────────────────────────────────────────────────────────────────────

class _ShimmerList extends StatefulWidget {
  const _ShimmerList();

  @override
  State<_ShimmerList> createState() => _ShimmerListState();
}

class _ShimmerListState extends State<_ShimmerList>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        final c = Color.lerp(
          Colors.white.withOpacity(0.06),
          Colors.white.withOpacity(0.13),
          _anim.value,
        )!;

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: 4,
          separatorBuilder: (_, __) => const SizedBox(height: 16),
          itemBuilder: (_, __) => Container(
            height: 140,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: c,
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 120,
                      height: 16,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.white.withOpacity(0.15),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      width: 50,
                      height: 22,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(11),
                        color: Colors.white.withOpacity(0.1),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  height: 10,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(5),
                    color: Colors.white.withOpacity(0.08),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 160,
                  height: 10,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(5),
                    color: Colors.white.withOpacity(0.06),
                  ),
                ),
                const Spacer(),
                Container(
                  width: double.infinity,
                  height: 38,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.white.withOpacity(0.08),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
