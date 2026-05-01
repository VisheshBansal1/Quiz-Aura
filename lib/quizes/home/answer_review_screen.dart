// ============================================================
// FILE: lib/quizes/home/answer_review_screen.dart
//
// Ad integration:
//   • Free users → rewarded ad gate shown BEFORE review content.
//     They must watch the ad to unlock the review.
//   • Premium users → review unlocks immediately, no ads shown.
//
// Rewarded ad rules:
//   • Ad is triggered once when this screen opens (not on every scroll).
//   • If the ad fails to load → fallback: unlock the review anyway
//     so the UX is never permanently blocked.
//   • After reward earned → _unlocked = true → review renders.
// ============================================================

// BUG FIXED: Was reading answers from users/{uid}/attempts/{attemptId}
// but quiz_attempt_screen.dart NEVER writes there.
// It writes the attempt to quizzes/{quizId}/attempts/{uid}.

import 'package:QuizSphere/ads/provider/premium_provider.dart';
import 'package:QuizSphere/ads/services/admob_service.dart';
import 'package:QuizSphere/ads/screen/premium_screen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AnswerReviewScreen extends ConsumerStatefulWidget {
  final String quizId;
  final String attemptId;

  const AnswerReviewScreen({
    super.key,
    required this.quizId,
    required this.attemptId,
  });

  @override
  ConsumerState<AnswerReviewScreen> createState() => _AnswerReviewScreenState();
}

class _AnswerReviewScreenState extends ConsumerState<AnswerReviewScreen> {
  bool _unlocked = false;
  bool _adLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initGate());
  }

  void _initGate() {
    // Ad control logic: premium users skip the ad gate entirely.
    final isPremium = ref.read(isPremiumProvider);
    if (isPremium) {
      setState(() => _unlocked = true);
      return;
    }
    _showRewardedAd();
  }

  void _showRewardedAd() {
    setState(() => _adLoading = true);

    AdmobService.loadAndShowRewardedAd(
      onRewarded: () {
        if (mounted) setState(() => _unlocked = true);
      },
      onAdDismissed: () {
        if (mounted) setState(() => _adLoading = false);
      },
      // Fail-open: never permanently block the user if the ad fails.
      onFailed: () {
        if (mounted)
          setState(() {
            _adLoading = false;
            _unlocked = true;
          });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text(
            'Please login again',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          'Answer Review',
          style: TextStyle(color: Colors.white),
        ),
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
          if (!_unlocked)
            _AdGateOverlay(isLoading: _adLoading, onWatchAd: _showRewardedAd)
          else
            FutureBuilder<_ReviewData>(
              future: _fetchData(user.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          color: Colors.tealAccent,
                          strokeWidth: 2.5,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Loading answers…',
                          style: TextStyle(color: Colors.white60, fontSize: 13),
                        ),
                      ],
                    ),
                  );
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Colors.redAccent,
                            size: 48,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Could not load review.\n${snapshot.error}',
                            style: const TextStyle(color: Colors.white70),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.questions.isEmpty) {
                  return const Center(
                    child: Text(
                      'No questions found',
                      style: TextStyle(color: Colors.white70),
                    ),
                  );
                }

                final data = snapshot.data!;
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                  itemCount: data.questions.length,
                  itemBuilder: (context, i) {
                    final qDoc = data.questions[i];
                    final q = qDoc.data();
                    final qId = qDoc.id;
                    return _ReviewCard(
                      index: i + 1,
                      question: (q['question'] ?? q['title'] ?? '').toString(),
                      options: List<String>.from(q['options'] as List? ?? []),
                      correctIndex: q['correctIndex'] as int?,
                      selectedIndex: data.answers[qId],
                      explanation: (q['solution'] ?? q['explanation'] ?? '')
                          .toString(),
                    );
                  },
                );
              },
            ),
        ],
      ),
    );
  }

  Future<_ReviewData> _fetchData(String uid) async {
    final questionSnap = await FirebaseFirestore.instance
        .collection('quizzes')
        .doc(widget.quizId)
        .collection('questions')
        .where('isActive', isEqualTo: true)
        .get();

    final attemptDoc = await FirebaseFirestore.instance
        .collection('quizzes')
        .doc(widget.quizId)
        .collection('attempts')
        .doc(uid)
        .get();

    final Map<String, int> answers = {};
    if (attemptDoc.exists) {
      final raw = attemptDoc.data()?['answers'] as Map<String, dynamic>? ?? {};
      raw.forEach((key, value) {
        if (value is int) answers[key] = value;
      });
    }
    return _ReviewData(questions: questionSnap.docs, answers: answers);
  }

  static Widget _gradientBg() => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
  );
}

// ── Ad gate overlay ────────────────────────────────────────────────────────────
class _AdGateOverlay extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onWatchAd;

  const _AdGateOverlay({required this.isLoading, required this.onWatchAd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.tealAccent.withOpacity(0.1),
                border: Border.all(color: Colors.tealAccent.withOpacity(0.4)),
              ),
              child: const Icon(
                Icons.play_circle_outline,
                color: Colors.tealAccent,
                size: 52,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Watch a short ad to\nunlock your review',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            const Text(
              'Go Premium to skip ads forever.',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PremiumScreen()),
              ),
              icon: const Icon(
                Icons.workspace_premium,
                color: Colors.amberAccent,
                size: 16,
              ),
              label: const Text(
                'Upgrade to Premium',
                style: TextStyle(color: Colors.amberAccent),
              ),
            ),
            const SizedBox(height: 16),
            if (isLoading)
              const CircularProgressIndicator(color: Colors.tealAccent)
            else
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: onWatchAd,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text(
                    'Watch Ad & Review',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.tealAccent,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Review card ────────────────────────────────────────────────────────────────
class _ReviewCard extends StatelessWidget {
  final int index;
  final String question;
  final List<String> options;
  final int? correctIndex;
  final int? selectedIndex;
  final String explanation;

  const _ReviewCard({
    required this.index,
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.selectedIndex,
    required this.explanation,
  });

  @override
  Widget build(BuildContext context) {
    final attempted = selectedIndex != null;
    final isCorrect = attempted && selectedIndex == correctIndex;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withOpacity(0.1),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Q$index. $question',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 15,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          for (int i = 0; i < options.length; i++)
            _OptionTile(
              text: options[i],
              isCorrect: i == correctIndex,
              isSelected: i == selectedIndex,
            ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color:
                  (!attempted
                          ? Colors.grey
                          : isCorrect
                          ? Colors.green
                          : Colors.red)
                      .withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              !attempted
                  ? '⏭ Not Attempted'
                  : isCorrect
                  ? '✅ Correct'
                  : '❌ Incorrect',
              style: TextStyle(
                color: !attempted
                    ? Colors.grey
                    : isCorrect
                    ? Colors.greenAccent
                    : Colors.redAccent,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          if (explanation.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.teal.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.teal.withOpacity(0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.lightbulb_outline,
                    color: Colors.tealAccent,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      explanation,
                      style: const TextStyle(
                        color: Colors.tealAccent,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final String text;
  final bool isCorrect;
  final bool isSelected;

  const _OptionTile({
    required this.text,
    required this.isCorrect,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    Color bg = Colors.white.withOpacity(0.07);
    Color border = Colors.transparent;
    IconData? icon;
    Color iconColor = Colors.white;

    if (isCorrect) {
      bg = Colors.green.withOpacity(0.2);
      border = Colors.greenAccent;
      icon = Icons.check_circle;
      iconColor = Colors.greenAccent;
    }
    if (isSelected && !isCorrect) {
      bg = Colors.red.withOpacity(0.2);
      border = Colors.redAccent;
      icon = Icons.cancel;
      iconColor = Colors.redAccent;
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(text, style: const TextStyle(color: Colors.white)),
          ),
          if (icon != null) Icon(icon, size: 18, color: iconColor),
        ],
      ),
    );
  }
}

class _ReviewData {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> questions;
  final Map<String, int> answers;
  const _ReviewData({required this.questions, required this.answers});
}
