// ============================================================
// FILE: lib/quizes/home/answer_review_screen.dart
//
// Ad integration:
//   • Free users → rewarded ad gate. The ad is attempted automatically
//     when this screen opens (matches this screen's original design —
//     triggered once, not on every scroll); if it can't be shown (not
//     loaded, failed, or dismissed without reward), a locked "Unlock
//     Review" card takes over with a manual retry button instead of
//     leaving a blank screen.
//   • Ad fails to load/show → the shared "Ad Couldn't Be Loaded" dialog
//     (Retry / Go Premium / Cancel) — same behavior as the quiz-result
//     gate, kept consistent across the app.
//   • Premium users → review unlocks immediately, no ads shown.
//   • After reward earned → _unlocked = true → review renders.
// ============================================================

// BUG FIXED: Was reading answers from users/{uid}/attempts/{attemptId}
// but quiz_attempt_screen.dart NEVER writes there.
// It writes the attempt to quizzes/{quizId}/attempts/{uid}.

import 'package:QuizSphere/ads/provider/premium_provider.dart';
import 'package:QuizSphere/ads/screen/go_premium_screen.dart';
import 'package:QuizSphere/ads/services/ad_analytics_service.dart';
import 'package:QuizSphere/ads/services/rewarded_ad_service.dart';
import 'package:QuizSphere/ads/widgets/ad_failed_dialog.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const String _kAnalyticsScreen = 'answer_review';

class AnswerReviewScreen extends ConsumerStatefulWidget {
  final String quizId;
  final String attemptId;

  /// Daily quizzes live in `dailyQuizzes/{quizId}` (no `isActive` flag).
  final bool isDaily;

  const AnswerReviewScreen({
    super.key,
    required this.quizId,
    required this.attemptId,
    this.isDaily = false,
  });

  @override
  ConsumerState<AnswerReviewScreen> createState() => _AnswerReviewScreenState();
}

class _AnswerReviewScreenState extends ConsumerState<AnswerReviewScreen> {
  bool _unlocked = false;
  // Starts true: an unlock attempt is auto-triggered the moment this
  // screen opens, so the first frame should show "preparing…", not the
  // locked gate card (that only appears once an attempt has actually
  // failed or been dismissed).
  bool _adLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _attemptUnlock());
  }

  void _attemptUnlock() {
    // Ads in this app are Android-only (see RewardedAdService) — on any
    // other platform there is no ad system to gate behind, so never block
    // a free user just because the platform doesn't serve ads.
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      setState(() {
        _adLoading = false;
        _unlocked = true;
      });
      return;
    }

    if (ref.read(isPremiumProvider)) {
      setState(() {
        _adLoading = false;
        _unlocked = true;
      });
      return;
    }

    // Families Policy: NEVER start an ad automatically. The user must
    // explicitly tap the clearly labelled "Watch Ad to Unlock Review"
    // button on the gate card.
    setState(() => _adLoading = false);
  }

  void _showRewardedAdOrFail() {
    if (!RewardedAdService.instance.isAdReady) {
      setState(() => _adLoading = false);
      _showAdFailedDialog();
      return;
    }

    setState(() => _adLoading = true);
    RewardedAdService.instance.showAd(
      onReward: () {
        if (!mounted) return;
        setState(() {
          _adLoading = false;
          _unlocked = true;
        });
      },
      onAdDismissed: () {
        // Closed before earning the reward — stay locked. The fallback
        // gate card (with its own "Unlock Review" button) takes over.
        if (!mounted) return;
        setState(() => _adLoading = false);
      },
      onAdFailedToShow: () {
        if (!mounted) return;
        setState(() => _adLoading = false);
        _showAdFailedDialog();
      },
    );
  }

  void _showAdFailedDialog() {
    // Warm up a fresh ad in the background so Retry (or the fallback
    // gate's manual button) has a real chance of succeeding.
    RewardedAdService.instance.loadAd();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AdFailedDialog(
        onRetry: () {
          Navigator.of(context).pop();
          AdAnalyticsService.adRetryClicked(_kAnalyticsScreen);
          _showRewardedAdOrFail();
        },
        onGoPremium: () {
          Navigator.of(context).pop();
          AdAnalyticsService.goPremiumClicked(_kAnalyticsScreen);
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const GoPremiumScreen()),
          );
        },
        onCancel: () => Navigator.of(context).pop(),
      ),
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

    final bool isPremium = ref.watch(isPremiumProvider);
    final bool reviewVisible = isPremium || _unlocked;

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
          if (!reviewVisible)
            (_adLoading ? _adPreparingState() : _reviewGate())
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

  // ================= NEW: REVIEW AD-GATE =================

  Widget _adPreparingState() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: Colors.tealAccent, strokeWidth: 2.5),
          SizedBox(height: 16),
          Text(
            'Preparing your review…',
            style: TextStyle(color: Colors.white60, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _reviewGate() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.tealAccent.withOpacity(0.15),
              ),
              child: const Icon(
                Icons.menu_book_rounded,
                size: 48,
                color: Colors.tealAccent,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "Unlock the Full Review",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              "Watch a short ad to see the correct answers and explanations for every question.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _showRewardedAdOrFail,
                icon: const Icon(Icons.play_circle_outline),
                label: const Text("Watch Ad to Unlock Review"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.tealAccent,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: () {
                AdAnalyticsService.goPremiumClicked(_kAnalyticsScreen);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const GoPremiumScreen()),
                );
              },
              icon: const Icon(
                Icons.workspace_premium_rounded,
                size: 16,
                color: Colors.amberAccent,
              ),
              label: const Text(
                "Go Premium for instant, ad-free review",
                style: TextStyle(color: Colors.amberAccent, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<_ReviewData> _fetchData(String uid) async {
    final root = widget.isDaily ? 'dailyQuizzes' : 'quizzes';

    Query<Map<String, dynamic>> questionQuery = FirebaseFirestore.instance
        .collection(root)
        .doc(widget.quizId)
        .collection('questions');
    if (!widget.isDaily) {
      questionQuery = questionQuery.where('isActive', isEqualTo: true);
    }
    final questionSnap = await questionQuery.get();

    final attemptDoc = await FirebaseFirestore.instance
        .collection(root)
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
