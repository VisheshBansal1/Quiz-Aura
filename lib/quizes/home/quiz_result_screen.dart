import 'package:QuizSphere/ads/provider/premium_provider.dart';
import 'package:QuizSphere/ads/screen/go_premium_screen.dart';
import 'package:QuizSphere/ads/services/ad_analytics_service.dart';
import 'package:QuizSphere/ads/services/rewarded_ad_service.dart';
import 'package:QuizSphere/ads/widgets/ad_failed_dialog.dart';
import 'package:QuizSphere/quizes/home/answer_review_screen.dart';
import 'package:QuizSphere/quizes/home/onboarding_screen.dart'; // defines HomeScreen
import 'package:QuizSphere/quizes/home/leaderboard/quiz_leaderboard_screen.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Identifies this screen in analytics events fired below (view_result_clicked,
/// premium_bypass, ad_retry_clicked, go_premium_clicked).
const String _kAnalyticsScreen = 'quiz_result';

class QuizResultScreen extends ConsumerStatefulWidget {
  final String quizId;
  final String attemptId;
  final String quizTitle;
  final int score;
  final int total;
  final double percentage;
  final DateTime endAt;
  final bool passed;
  final double passPercentage;

  /// Daily quizzes read their attempt/questions/leaderboard from
  /// `dailyQuizzes/{quizId}` instead of `quizzes/{quizId}`.
  final bool isDaily;

  const QuizResultScreen({
    super.key,
    required this.quizId,
    required this.attemptId,
    required this.quizTitle,
    required this.score,
    required this.total,
    required this.percentage,
    required this.endAt,
    required this.passed,
    required this.passPercentage,
    this.isDaily = false,
  });

  @override
  ConsumerState<QuizResultScreen> createState() => _QuizResultScreenState();
}

class _QuizResultScreenState extends ConsumerState<QuizResultScreen> {
  // ── NEW: rewarded-ad gate state for "View Result" ──────────────────────
  // Free users must watch a rewarded ad before the score/pass-fail content
  // below renders. Premium users skip this entirely (see `resultVisible`
  // in build()). This is IN ADDITION TO, and separate from, the existing
  // time-based "Result Locked" state below (quizEnded) — that logic is
  // untouched.
  bool _unlocked = false;
  bool _adLoading = false;

  @override
  Widget build(BuildContext context) {
    final bool quizEnded = DateTime.now().isAfter(widget.endAt);
    final bool isPremium = ref.watch(isPremiumProvider);
    final bool resultVisible = isPremium || _unlocked;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: Text(widget.quizTitle),
          automaticallyImplyLeading: false,
          backgroundColor: Colors.transparent,
          elevation: 0,
          flexibleSpace: _gradientBg(),
        ),
        body: Stack(
          children: [
            _gradientBg(),
            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const SizedBox(height: 20),

                    /// 🔒 IF QUIZ NOT ENDED (time-based lock — unchanged)
                    if (!quizEnded) ...[
                      const Icon(
                        Icons.lock_outline,
                        size: 60,
                        color: Colors.orangeAccent,
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        "Result Locked",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        "Your score and performance will be visible once the quiz ends.",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 30),
                    ],

                    /// ✅ IF QUIZ ENDED
                    if (quizEnded) ...[
                      if (resultVisible) ...[
                        _resultIcon(),
                        const SizedBox(height: 16),
                        _resultMessage(),
                        const SizedBox(height: 24),
                        _scoreSection(),
                        const SizedBox(height: 20),
                      ] else ...[
                        // NEW: rewarded-ad gate — replaces the score
                        // reveal until the user watches an ad (or is
                        // Premium).
                        _resultGate(),
                        const SizedBox(height: 20),
                      ],
                    ],

                    _statusSection(quizEnded),
                    const SizedBox(height: 30),
                    _buttons(context, quizEnded),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================= NEW: RESULT AD-GATE =================

  Widget _resultGate() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.tealAccent.withOpacity(0.15),
          ),
          child: const Icon(
            Icons.emoji_events_outlined,
            size: 48,
            color: Colors.tealAccent,
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          "Your Result is Ready!",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          "Watch a short ad to view your score and complete result.",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70),
        ),
        const SizedBox(height: 22),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: _adLoading ? null : _onViewResultTap,
            icon: _adLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.black54,
                    ),
                  )
                : const Icon(Icons.play_circle_outline),
            label: Text(_adLoading ? "Loading Ad…" : "Watch Ad to View Result"),
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
          onPressed: _adLoading
              ? null
              : () {
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
            "Go Premium for instant, ad-free results",
            style: TextStyle(color: Colors.amberAccent, fontSize: 12),
          ),
        ),
      ],
    );
  }

  void _onViewResultTap() {
    if (_adLoading) return; // Prevent rapid multiple taps.
    AdAnalyticsService.viewResultClicked(_kAnalyticsScreen);

    // Ads in this app are Android-only (see RewardedAdService) — on any
    // other platform there is no ad system to gate behind, so never block
    // a free user just because the platform doesn't serve ads.
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      setState(() => _unlocked = true);
      return;
    }

    if (ref.read(isPremiumProvider)) {
      // Defensive only — resultVisible already keeps this button from
      // rendering for Premium users, but guards against status flipping
      // between build() and this tap.
      AdAnalyticsService.premiumBypass(_kAnalyticsScreen);
      setState(() => _unlocked = true);
      return;
    }

    _showRewardedAdOrFail();
  }

  void _showRewardedAdOrFail() {
    if (!RewardedAdService.instance.isAdReady) {
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
        // Closed before earning the reward — stay locked. The user can
        // tap "View Result" again whenever they're ready.
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
    // Warm up a fresh ad in the background so Retry (or the user's next
    // natural visit) has a real chance of succeeding.
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

  // ================= RESULT ICON =================
  Widget _resultIcon() {
    return CircleAvatar(
      radius: 42,
      backgroundColor: widget.passed
          ? Colors.greenAccent.withOpacity(0.2)
          : Colors.redAccent.withOpacity(0.2),
      child: Icon(
        widget.passed ? Icons.emoji_events : Icons.cancel,
        size: 48,
        color: widget.passed ? Colors.greenAccent : Colors.redAccent,
      ),
    );
  }

  // ================= RESULT MESSAGE =================
  Widget _resultMessage() {
    String message;

    if (widget.percentage >= 90) {
      message = "Outstanding Performance!";
    } else if (widget.percentage >= 75) {
      message = "Great Job!";
    } else if (widget.percentage >= widget.passPercentage) {
      message = "You Passed!";
    } else {
      message = "Keep Practicing!";
    }

    return Text(
      message,
      style: const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
      textAlign: TextAlign.center,
    );
  }

  // ================= SCORE SECTION =================
  Widget _scoreSection() {
    return Column(
      children: [
        Text(
          "${widget.score} / ${widget.total}",
          style: const TextStyle(
            fontSize: 42,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          "${widget.percentage.toStringAsFixed(1)}%",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: widget.passed ? Colors.greenAccent : Colors.redAccent,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "Passing Criteria: ${widget.passPercentage.toStringAsFixed(0)}%",
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade400,
          ),
        ),
      ],
    );
  }

  // ================= STATUS =================
  Widget _statusSection(bool quizEnded) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withOpacity(0.08),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            widget.isDaily
                ? Icons.check_circle
                : (quizEnded ? Icons.lock : Icons.timer),
            color: widget.isDaily
                ? Colors.greenAccent
                : (quizEnded ? Colors.orangeAccent : Colors.blueAccent),
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            widget.isDaily
                ? "Daily Challenge Completed"
                : (quizEnded ? "Quiz Ended" : "Quiz Still Active"),
            style: const TextStyle(color: Colors.white),
          ),
        ],
      ),
    );
  }

  // ================= BUTTONS =================
  Widget _buttons(BuildContext context, bool quizEnded) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.visibility),
            label: const Text("Review Answers"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
            ),
            onPressed: quizEnded
                ? () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AnswerReviewScreen(
                          quizId: widget.quizId,
                          attemptId: widget.attemptId,
                          isDaily: widget.isDaily,
                        ),
                      ),
                    );
                  }
                : null,
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.leaderboard),
            label: const Text("Leaderboard"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: quizEnded
                ? () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => QuizLeaderboardScreen(
                          quizId: widget.quizId,
                          quizTitle: widget.quizTitle,
                          isDaily: widget.isDaily,
                        ),
                      ),
                    );
                  }
                : null,
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.white),
            ),
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (_) => const HomeScreen(),
                ),
                (_) => false,
              );
            },
            child: const Text(
              "Back to Home",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ),
      ],
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
}
