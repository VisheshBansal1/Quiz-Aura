// ── Ad integration note ─────────────────────────────────────────────────────
// Rewarded ad shown BEFORE generating AI questions for FREE users, on
// Android only:
//   • Web                        → ad system skipped entirely, generate now.
//   • Non-Android (iOS/desktop)  → ad system skipped gracefully, generate now.
//   • Premium (isPremiumProvider)→ skip the ad, generate now.
//   • Free + ad not ready/failed → fail OPEN, generate now (never block).
//   • Free + ad shown, reward earned    → generate now.
//   • Free + ad shown, closed WITHOUT reward → do NOT generate.
// The ad itself is loaded/shown by RewardedAdService (see
// lib/ads/services/rewarded_ad_service.dart); this screen only decides
// WHEN to call it and what to do with each outcome.
//
// BUG FIXED (pre-existing, still applies):
//   `loading` must be set INSIDE _doGenerate(), not before it — some paths
//   above skip straight to _doGenerate() without ever touching the ad flow.
//   `_adLoading` is what gives instant visual feedback for the ad-watching
//   path specifically: it's set the moment showAd() is called, before any
//   ad-display latency, so the button never appears frozen.
// ────────────────────────────────────────────────────────────────────────────

import 'package:QuizSphere/ads/provider/premium_provider.dart';
import 'package:QuizSphere/ads/services/rewarded_ad_service.dart';
import 'package:QuizSphere/quizes/admin/screens/admin_dashboard_screen.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/groq_ai_service.dart';
import '../services/Admin_quiz_service.dart';
import 'package:QuizSphere/core/services/ai_quiz_access_service.dart';

class AiGenerateQuestionsScreen extends ConsumerStatefulWidget {
  final String quizId;
  const AiGenerateQuestionsScreen({super.key, required this.quizId});

  @override
  ConsumerState<AiGenerateQuestionsScreen> createState() =>
      _AiGenerateQuestionsScreenState();
}

class _AiGenerateQuestionsScreenState
    extends ConsumerState<AiGenerateQuestionsScreen> {
  late GroqAIService groqAIService;
  late AdminQuizService quizService;

  bool loading = false;
  bool saving = false;

  // FIX: separate state for "ad is loading" so we can show the right message
  bool _adLoading = false;

  String difficulty = "Medium";
  String? topicTitle;
  int questionCount = 5;
  static const int maxQuestionsAllowed = 15;

  List<Map<String, dynamic>> questions = [];

  static const _inputDecoration = InputDecoration(
    labelStyle: TextStyle(color: Colors.white70),
    enabledBorder: UnderlineInputBorder(
      borderSide: BorderSide(color: Colors.white38),
    ),
    focusedBorder: UnderlineInputBorder(
      borderSide: BorderSide(color: Colors.tealAccent),
    ),
  );

  String? _initError;

  @override
  void initState() {
    super.initState();

    // AI Quiz Generation is mobile-only. Every known entry point already
    // stops navigation from reaching this screen on web (see college quiz
    // screen, admin dashboard, and create-quiz screen). This is a
    // defense-in-depth fallback in case it is ever reached directly —
    // bail out immediately instead of showing any generation UI.
    if (AiQuizAccessService.isBlockedOnWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        AiQuizAccessService.showBlockedMessage(context);
        Navigator.of(context).pop();
      });
      return;
    }

    try {
      groqAIService = GroqAIService();
    } catch (e) {
      _initError = e.toString().replaceFirst('Exception: ', '');
    }
    quizService = AdminQuizService();
    _loadQuizTopic();
  }

  Future<void> _loadQuizTopic() async {
    final snap = await FirebaseFirestore.instance
        .collection('quizzes')
        .doc(widget.quizId)
        .get();

    final data = snap.data();
    if (mounted) {
      setState(() => topicTitle = data?['topicTitle']);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // GENERATE — entry point when user taps the button
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> generate() async {
    if (AiQuizAccessService.isBlockedOnWeb) {
      AiQuizAccessService.showBlockedMessage(context);
      return;
    }

    if (_initError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_initError!), backgroundColor: Colors.redAccent),
      );
      return;
    }

    // Guard: already running
    if (loading || _adLoading || topicTitle == null) return;

    if (questionCount < 1 || questionCount > maxQuestionsAllowed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Questions must be between 1 and $maxQuestionsAllowed.',
          ),
        ),
      );
      return;
    }

    // ── Platform check ────────────────────────────────────────────────
    // Web: Google Mobile Ads isn't supported there — never attempt to load
    // or show an ad, and never block quiz generation. (This screen is
    // already unreachable on web via the isBlockedOnWeb guard above; this
    // check makes the ad-gating logic correct and reusable on its own too,
    // e.g. if it's ever wired into another entry point that doesn't share
    // that guard.)
    if (AiQuizAccessService.isBlockedOnWeb) {
      await _doGenerate();
      return;
    }

    // Any platform other than Android (iOS, desktop, …): skip ads
    // gracefully, same rule — never block generation.
    if (defaultTargetPlatform != TargetPlatform.android) {
      await _doGenerate();
      return;
    }

    // ── Premium check ─────────────────────────────────────────────────
    // Premium users must never see ads.
    final isPremium = ref.read(isPremiumProvider);
    if (isPremium) {
      await _doGenerate();
      return;
    }

    // ── Free user on Android: gate generation behind a rewarded ad ─────
    if (!RewardedAdService.instance.isAdReady) {
      // Ad didn't finish preloading in time (or failed to load) — do NOT
      // block a free user just because the ad system isn't cooperating.
      await _doGenerate();
      return;
    }

    setState(() => _adLoading = true);

    RewardedAdService.instance.showAd(
      onReward: () {
        // Reward earned — this is the only path allowed to generate.
        if (!mounted) return;
        setState(() => _adLoading = false);
        _doGenerate();
      },
      onAdDismissed: () {
        // Closed before earning the reward — per spec, do NOT generate.
        // Just restore the button so the user can tap Generate again.
        if (!mounted) return;
        setState(() => _adLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Watch the full ad to generate your quiz for free.'),
          ),
        );
      },
      onAdFailedToShow: () {
        // Ad was cached but couldn't be displayed (rare) — fail open, same
        // as "ad not ready".
        if (!mounted) return;
        setState(() => _adLoading = false);
        _doGenerate();
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DO GENERATE — actual API call
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _doGenerate() async {
    if (!mounted || topicTitle == null) return;

    setState(() => loading = true);

    try {
      final result = await groqAIService.generateMCQs(
        topic: topicTitle!,
        difficulty: difficulty,
        count: questionCount,
      );

      if (!mounted) return;
      setState(() {
        questions = result.map((q) {
          return {
            ...q,
            'difficulty': difficulty,
            'solution': q['solution'] ?? 'No explanation provided',
          };
        }).toList();
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 6),
        ),
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // REGENERATE SINGLE
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> regenerateOne(int index) async {
    if (AiQuizAccessService.isBlockedOnWeb) {
      AiQuizAccessService.showBlockedMessage(context);
      return;
    }

    if (_initError != null || topicTitle == null) return;

    try {
      final result = await groqAIService.generateMCQs(
        topic: topicTitle!,
        difficulty: questions[index]['difficulty'],
        count: 1,
      );

      if (!mounted) return;
      if (result.isNotEmpty) {
        setState(() {
          questions[index] = {
            ...result.first,
            'difficulty': questions[index]['difficulty'],
          };
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SAVE ALL
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> saveAll() async {
    if (saving) return;
    setState(() => saving = true);

    try {
      for (final q in questions) {
        final String type = (q['type'] ?? 'mcq').toString();

        if (type == 'mcq') {
          final title = q['title'] ?? q['question'];
          if (title == null || q['options'] == null) {
            throw Exception('Invalid MCQ data: $q');
          }
          await quizService.addMcqQuestion(
            quizId: widget.quizId,
            data: {
              'type': 'mcq',
              'question': title,
              'title': title,
              'options': List<String>.from(q['options']),
              'correctIndex': q['correctIndex'] ?? 0,
              'difficulty': q['difficulty'] ?? 'Medium',
              'solution': q['solution'] ?? '',
            },
          );
        } else if (type == 'coding') {
          final title = q['title'] ?? q['question'];
          if (title == null) throw Exception('Invalid coding question: $q');
          await quizService.addCodingQuestion(
            quizId: widget.quizId,
            data: {
              'type': 'coding',
              'title': title,
              'visibleTestCases': List<Map<String, String>>.from(
                q['visibleTestCases'] ?? [],
              ),
              'hiddenTestCases': List<Map<String, String>>.from(
                q['hiddenTestCases'] ?? [],
              ),
              'pointsPerTestCase': q['pointsPerTestCase'] ?? 10,
            },
          );
        }
      }

      final countSnapshot = await FirebaseFirestore.instance
          .collection('quizzes')
          .doc(widget.quizId)
          .collection('questions')
          .count()
          .get();

      await FirebaseFirestore.instance
          .collection('quizzes')
          .doc(widget.quizId)
          .update({'totalQuestions': countSnapshot.count ?? 0});

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) {
              return AdminDashboardScreen();
            },
          ),
        );
      }
    } catch (e) {
      debugPrint('SAVE ERROR: $e');
      rethrow;
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // UI
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    // Web fallback: initState() already scheduled a pop + message for this
    // frame. Render an empty shell instead of the generation UI so no
    // web user ever sees (or can interact with) the AI generation screen,
    // even for a single frame.
    if (AiQuizAccessService.isBlockedOnWeb) {
      return const Scaffold(backgroundColor: Color(0xFF0F2027));
    }

    // Determine the overlay message based on which stage we're in
    final String overlayMessage = _adLoading
        ? 'Loading ad…\nPlease wait a moment'
        : saving
        ? 'Saving questions…'
        : 'Generating questions…';

    return Scaffold(
      backgroundColor: const Color(0xFF0F2027),
      appBar: AppBar(
        title: const Text(
          "AI Question Generator",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: _gradientBg(),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: Colors.white),
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(child: _gradientBg()),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _controls(),
                const SizedBox(height: 16),
                Expanded(
                  child: questions.isEmpty
                      ? const Center(
                          child: Text(
                            "No questions generated yet.\nTap Generate to start.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 15,
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: questions.length,
                          itemBuilder: (_, i) => _editableQuestion(i),
                        ),
                ),
                if (questions.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.tealAccent,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: saving ? null : saveAll,
                        icon: const Icon(Icons.save_alt),
                        label: const Text(
                          "Save All",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ── Loading / ad-loading / saving overlay ─────────────────────
          // FIX: overlay now shows for ALL three states:
          //   _adLoading → "Loading ad… Please wait"
          //   loading    → "Generating questions…"
          //   saving     → "Saving…"
          if (loading || saving || _adLoading)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.7),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(
                        color: Colors.tealAccent,
                        strokeWidth: 2.5,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        overlayMessage,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          height: 1.5,
                        ),
                      ),
                      if (_adLoading) ...[
                        const SizedBox(height: 8),
                        const Text(
                          'Watch a short ad to generate for free',
                          style: TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CONTROLS SECTION
  // ─────────────────────────────────────────────────────────────────────────
  Widget _controls() {
    return _card(
      child: Column(
        children: [
          Text(
            topicTitle ?? "Loading topic...",
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),

          DropdownButtonFormField<String>(
            value: difficulty,
            dropdownColor: const Color(0xFF203A43),
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration.copyWith(labelText: "Difficulty"),
            items: const [
              DropdownMenuItem(
                value: "Easy",
                child: Text("Easy", style: TextStyle(color: Colors.white)),
              ),
              DropdownMenuItem(
                value: "Medium",
                child: Text("Medium", style: TextStyle(color: Colors.white)),
              ),
              DropdownMenuItem(
                value: "Hard",
                child: Text("Hard", style: TextStyle(color: Colors.white)),
              ),
            ],
            onChanged: (v) => setState(() => difficulty = v!),
          ),

          const SizedBox(height: 12),

          TextFormField(
            initialValue: questionCount.toString(),
            keyboardType: TextInputType.number,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
            decoration: _inputDecoration.copyWith(
              labelText: "Number of Questions (max $maxQuestionsAllowed)",
            ),
            onChanged: (v) => questionCount = int.tryParse(v) ?? 5,
          ),

          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              // Disable button while any loading is happening
              onPressed: (loading || saving || _adLoading) ? null : generate,
              icon: const Icon(Icons.auto_awesome),
              label: Text(
                _adLoading
                    ? "Loading Ad…"
                    : loading
                    ? "Generating…"
                    : _generateLabel(),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Families Policy: a button that triggers an ad must say so. Free users
  /// on Android see "Watch Ad & Generate"; Premium / other platforms see
  /// plain "Generate".
  String _generateLabel() {
    final bool showsAd = !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android &&
        !ref.watch(isPremiumProvider);
    return showsAd ? "Watch Ad & Generate" : "Generate";
  }

  // ─────────────────────────────────────────────────────────────────────────
  // EDITABLE QUESTION CARD
  // ─────────────────────────────────────────────────────────────────────────
  Widget _editableQuestion(int index) {
    final q = questions[index];

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Q${index + 1}",
            style: const TextStyle(
              color: Colors.tealAccent,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),

          TextFormField(
            initialValue: q['question'],
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration.copyWith(labelText: "Question"),
            onChanged: (v) => q['question'] = v,
          ),

          const SizedBox(height: 8),

          for (int i = 0; i < (q['options'] as List).length; i++)
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: q['options'][i],
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration.copyWith(
                      labelText: "Option ${i + 1}",
                    ),
                    onChanged: (v) => q['options'][i] = v,
                  ),
                ),
                Radio<int>(
                  value: i,
                  groupValue: q['correctIndex'],
                  activeColor: Colors.tealAccent,
                  onChanged: (v) => setState(() => q['correctIndex'] = v),
                ),
              ],
            ),

          const SizedBox(height: 10),

          TextFormField(
            initialValue: q['solution'] ?? '',
            style: const TextStyle(color: Colors.white),
            maxLines: 2,
            decoration: _inputDecoration.copyWith(
              labelText: "Solution / Explanation",
            ),
            onChanged: (v) => q['solution'] = v,
          ),

          const SizedBox(height: 8),

          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => regenerateOne(index),
              icon: const Icon(Icons.refresh, size: 16, color: Colors.white60),
              label: const Text(
                "Regenerate",
                style: TextStyle(color: Colors.white60),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // UI HELPERS
  // ─────────────────────────────────────────────────────────────────────────
  Widget _gradientBg() => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
      ),
    ),
  );

  Widget _card({required Widget child}) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(18),
      color: Colors.white.withOpacity(0.10),
      border: Border.all(color: Colors.white.withOpacity(0.20)),
    ),
    child: child,
  );
}
