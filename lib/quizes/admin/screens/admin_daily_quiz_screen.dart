// ============================================================
// FILE: lib/quizes/admin/screens/admin_daily_quiz_screen.dart
//
// REDESIGNED: Beautiful dark glassmorphism UI + AI auto-generation
//   • One-tap AI generation: picks a random topic from DSA, Aptitude,
//     Logical Reasoning, GK, Verbal, or Mixed and generates 10 questions
//   • Category chip selector (tap to override random pick)
//   • Animated question cards with expand preview
//   • Swipe-to-delete + edit dialog with polished styling
//   • Live progress bar while AI generates
//   • Date picker with formatted display
//   • XP / time chips instead of raw text fields
// ============================================================

import 'dart:math';

import 'package:QuizSphere/login/login_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/groq_ai_service.dart';
import 'package:QuizSphere/core/services/ai_quiz_access_service.dart';

// ─── palette ────────────────────────────────────────────────────────────────
const _bg = Color(0xFF0A0D14);
const _surface = Color(0xFF131720);
const _card = Color(0xFF1A2030);
const _accent = Color(0xFF6C63FF);
const _accentB = Color(0xFF00C2A8);
const _gold = Color(0xFFFFB547);
const _danger = Color(0xFFFF5C5C);
const _textPrimary = Color(0xFFEEF0F6);
const _textSecondary = Color(0xFF7A8099);

// ─── topic categories ───────────────────────────────────────────────────────
class _Category {
  final String label;
  final IconData icon;
  final Color color;
  final List<String> topics;

  const _Category({
    required this.label,
    required this.icon,
    required this.color,
    required this.topics,
  });
}

const List<_Category> _categories = [
  _Category(
    label: 'DSA',
    icon: Icons.account_tree_rounded,
    color: Color(0xFF6C63FF),
    topics: [
      'Arrays and Strings',
      'Linked Lists',
      'Trees and Graphs',
      'Dynamic Programming',
      'Sorting Algorithms',
      'Searching Algorithms',
      'Stack and Queue',
      'Hashing and Hash Maps',
      'Recursion and Backtracking',
      'Heaps and Priority Queues',
      'Binary Search',
      'Greedy Algorithms',
      'Trie Data Structure',
      'Segment Trees',
    ],
  ),
  _Category(
    label: 'Aptitude',
    icon: Icons.calculate_rounded,
    color: Color(0xFF00C2A8),
    topics: [
      'Percentages and Profit-Loss',
      'Time, Speed and Distance',
      'Ratios and Proportions',
      'Simple and Compound Interest',
      'Work and Time Problems',
      'Number Systems',
      'Averages and Mixtures',
      'Permutations and Combinations',
      'Probability',
      'Geometry and Mensuration',
    ],
  ),
  _Category(
    label: 'Logical',
    icon: Icons.psychology_rounded,
    color: Color(0xFFFF8C42),
    topics: [
      'Blood Relations',
      'Direction Sense',
      'Coding and Decoding',
      'Syllogisms',
      'Seating Arrangements',
      'Puzzles and Rankings',
      'Data Sufficiency',
      'Analogies and Series',
      'Statement and Assumptions',
      'Clocks and Calendars',
    ],
  ),
  _Category(
    label: 'Verbal',
    icon: Icons.spellcheck_rounded,
    color: Color(0xFFE040FB),
    topics: [
      'Reading Comprehension',
      'Grammar and Error Spotting',
      'Vocabulary and Synonyms',
      'Sentence Completion',
      'Idioms and Phrases',
      'Para Jumbles',
      'One-word Substitution',
      'Active and Passive Voice',
    ],
  ),
  _Category(
    label: 'GK',
    icon: Icons.public_rounded,
    color: Color(0xFF4CAF50),
    topics: [
      'Indian History and Culture',
      'World Geography',
      'Science and Technology',
      'Sports and Olympics',
      'Books and Authors',
      'Awards and Honours',
      'Current Affairs 2024',
      'Famous Inventions',
      'Space Exploration',
      'Environmental Science',
    ],
  ),
  _Category(
    label: 'Mix',
    icon: Icons.shuffle_rounded,
    color: Color(0xFFFFB547),
    topics: [], // auto-pick across all categories
  ),
];

// ─── model ──────────────────────────────────────────────────────────────────
class QuestionModel {
  String question;
  List<String> options;
  int correctIndex;
  String solution;

  QuestionModel({
    required this.question,
    required this.options,
    required this.correctIndex,
    this.solution = '',
  });
}

// ────────────────────────────────────────────────────────────────────────────

class AdminDailyQuizManagerScreen extends StatefulWidget {
  const AdminDailyQuizManagerScreen({super.key});

  @override
  State<AdminDailyQuizManagerScreen> createState() =>
      _AdminDailyQuizManagerScreenState();
}

class _AdminDailyQuizManagerScreenState
    extends State<AdminDailyQuizManagerScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _timeCtrl = TextEditingController(text: '600');
  final _xpCtrl = TextEditingController(text: '150');

  // Calendar date (IST) stored as y/m/d in a UTC DateTime — matches the
  // quiz id the app and the auto-generator use (see DailyQuizClock).
  DateTime _selectedDate = DateTime.now().toUtc().add(
    const Duration(hours: 5, minutes: 30),
  );
  List<QuestionModel> _questions = [];
  int _selectedCategoryIndex = 5; // Mix by default

  bool _generating = false;
  bool _publishing = false;
  double _genProgress = 0;
  String _genStatus = '';

  late AnimationController _pulseCtrl;
  late AnimationController _shimmerCtrl;

  final _groq = GroqAIService();
  final _rng = Random();

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _shimmerCtrl.dispose();
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _timeCtrl.dispose();
    _xpCtrl.dispose();
    super.dispose();
  }

  // ── helpers ────────────────────────────────────────────────────────────────

  String get _docId {
    return '${_selectedDate.year}-'
        '${_selectedDate.month.toString().padLeft(2, '0')}-'
        '${_selectedDate.day.toString().padLeft(2, '0')}';
  }

  /// 12:00 AM IST of the selected day, as a real instant.
  DateTime get _publishAt => DateTime.utc(
    _selectedDate.year,
    _selectedDate.month,
    _selectedDate.day,
  ).subtract(const Duration(hours: 5, minutes: 30));

  /// 11:59:59 PM IST of the selected day.
  DateTime get _expiresAt =>
      _publishAt.add(const Duration(days: 1, seconds: -1));

  String _pickTopic() {
    final cat = _categories[_selectedCategoryIndex];
    if (cat.topics.isEmpty) {
      // Mix: pick from all categories except Mix
      final allTopics = _categories
          .where((c) => c.topics.isNotEmpty)
          .expand((c) => c.topics)
          .toList();
      return allTopics[_rng.nextInt(allTopics.length)];
    }
    return cat.topics[_rng.nextInt(cat.topics.length)];
  }

  String _buildAutoTitle(String topic) {
    final date =
        '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}';
    return 'Daily Challenge — $date';
  }

  // ── AI generation ──────────────────────────────────────────────────────────

  Future<void> _generateWithAI() async {
    if (_generating) return;

    // AI Quiz Generation is mobile-only. The button that calls this is
    // already gated (see _buildAIGenerateButton), but this check is a
    // defense-in-depth backstop in case _generateWithAI is ever invoked
    // from another path on web.
    if (AiQuizAccessService.isBlockedOnWeb) {
      _showSnack(AiQuizAccessService.blockedMessage, error: true);
      return;
    }

    // For Mix, pick across all categories; otherwise use selected
    final List<String> topicsToUse;
    final cat = _categories[_selectedCategoryIndex];
    if (cat.topics.isEmpty) {
      // Mix: build 10 questions from varied topics
      final allTopics =
          _categories
              .where((c) => c.topics.isNotEmpty)
              .expand((c) => c.topics)
              .toList()
            ..shuffle(_rng);
      topicsToUse = allTopics.take(3).toList(); // pick 3 diverse topics
    } else {
      topicsToUse = [_pickTopic()];
    }

    final primaryTopic = topicsToUse.first;
    final categoryLabel = cat.label == 'Mix'
        ? 'Mixed (DSA, Aptitude, Logical, GK)'
        : cat.label;

    setState(() {
      _generating = true;
      _genProgress = 0;
      _genStatus = 'Picking topic…';
      if (_titleCtrl.text.isEmpty) {
        _titleCtrl.text = _buildAutoTitle(primaryTopic);
      }
      if (_descCtrl.text.isEmpty) {
        _descCtrl.text =
            'Test your $categoryLabel skills with today\'s AI-curated challenge!';
      }
    });

    HapticFeedback.lightImpact();

    try {
      setState(() {
        _genProgress = 0.15;
        _genStatus = 'Connecting to AI…';
      });

      await Future.delayed(const Duration(milliseconds: 400));

      setState(() {
        _genProgress = 0.30;
        _genStatus = 'Crafting questions on "$primaryTopic"…';
      });

      // Generate 10 questions in one call
      final raw = await _groq.generateMCQs(
        topic: cat.topics.isEmpty
            ? 'Mixed topics covering ${topicsToUse.join(', ')}'
            : primaryTopic,
        difficulty: 'Medium',
        count: 10,
      );

      setState(() {
        _genProgress = 0.80;
        _genStatus = 'Parsing ${raw.length} questions…';
      });

      await Future.delayed(const Duration(milliseconds: 300));

      final parsed = raw
          .map(
            (q) => QuestionModel(
              question: q['question'] as String? ?? '',
              options: List<String>.from(q['options'] ?? []),
              correctIndex: (q['correctIndex'] as num?)?.toInt() ?? 0,
              solution: q['solution'] as String? ?? '',
            ),
          )
          .where((q) => q.question.isNotEmpty && q.options.length == 4)
          .toList();

      setState(() {
        _genProgress = 1.0;
        _genStatus = 'Done! ${parsed.length} questions ready ✓';
        _questions = parsed;
      });

      HapticFeedback.mediumImpact();

      await Future.delayed(const Duration(milliseconds: 700));
    } catch (e) {
      if (mounted) {
        _showSnack('AI generation failed: $e', error: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _generating = false;
          _genProgress = 0;
          _genStatus = '';
        });
      }
    }
  }

  // ── publish ────────────────────────────────────────────────────────────────

  Future<void> _publish() async {
    if (!_formKey.currentState!.validate()) return;
    if (_questions.length < 5) {
      _showSnack('Add at least 5 questions', error: true);
      return;
    }
    setState(() => _publishing = true);
    HapticFeedback.lightImpact();

    try {
      final ref = FirebaseFirestore.instance
          .collection('dailyQuizzes')
          .doc(_docId);

      await ref.set({
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'timeLimitSeconds': int.tryParse(_timeCtrl.text) ?? 600,
        'xpReward': int.tryParse(_xpCtrl.text) ?? 150,
        'totalQuestions': _questions.length,
        'publishAt': Timestamp.fromDate(_publishAt),
        'source': 'manual',
        'expiresAt': Timestamp.fromDate(_expiresAt),
        'isPublished': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      final batch = FirebaseFirestore.instance.batch();

      // Remove previously published questions so re-publishing the same
      // day never doubles the question count.
      final oldQuestions = await ref.collection('questions').get();
      for (final d in oldQuestions.docs) {
        batch.delete(d.reference);
      }

      for (final q in _questions) {
        batch.set(ref.collection('questions').doc(), {
          'question': q.question,
          'options': q.options,
          'correctIndex': q.correctIndex,
          'solution': q.solution,
        });
      }
      await batch.commit();

      HapticFeedback.mediumImpact();
      _showSnack('Daily Quiz published successfully! 🎉');
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _showSnack('Publish failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  // ── question dialog ────────────────────────────────────────────────────────

  Future<void> _openQuestionDialog({int? index}) async {
    final q = index != null ? _questions[index] : null;
    final qCtrl = TextEditingController(text: q?.question ?? '');
    final optCtrls = List.generate(
      4,
      (i) => TextEditingController(text: q?.options[i] ?? ''),
    );
    final solCtrl = TextEditingController(text: q?.solution ?? '');
    int correct = q?.correctIndex ?? 0;

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => Dialog(
          backgroundColor: _surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _accent.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          index == null
                              ? Icons.add_rounded
                              : Icons.edit_rounded,
                          color: _accent,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        index == null ? 'Add Question' : 'Edit Question',
                        style: const TextStyle(
                          color: _textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _dialogField(qCtrl, 'Question', maxLines: 3),
                  const SizedBox(height: 14),
                  ...List.generate(
                    4,
                    (i) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () => setS(() => correct = i),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: correct == i
                                    ? _accent
                                    : Colors.transparent,
                                border: Border.all(
                                  color: correct == i
                                      ? _accent
                                      : _textSecondary,
                                  width: 2,
                                ),
                              ),
                              child: correct == i
                                  ? const Icon(
                                      Icons.check,
                                      size: 13,
                                      color: Colors.white,
                                    )
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _dialogField(
                              optCtrls[i],
                              'Option ${['A', 'B', 'C', 'D'][i]}',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  _dialogField(solCtrl, 'Solution / Explanation', maxLines: 2),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: TextButton.styleFrom(
                            foregroundColor: _textSecondary,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(color: Color(0xFF2A3040)),
                            ),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            if (qCtrl.text.isEmpty ||
                                optCtrls.any((e) => e.text.isEmpty)) {
                              _showSnack('All fields required', error: true);
                              return;
                            }
                            final newQ = QuestionModel(
                              question: qCtrl.text.trim(),
                              options: optCtrls
                                  .map((e) => e.text.trim())
                                  .toList(),
                              correctIndex: correct,
                              solution: solCtrl.text.trim(),
                            );
                            setState(() {
                              if (index == null) {
                                _questions.add(newQ);
                              } else {
                                _questions[index] = newQ;
                              }
                            });
                            Navigator.pop(ctx);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _accent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Save',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _dialogField(
    TextEditingController ctrl,
    String label, {
    int maxLines = 1,
  }) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      style: const TextStyle(color: _textPrimary, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: _textSecondary, fontSize: 13),
        filled: true,
        fillColor: _card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _accent, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
      ),
    );
  }

  // ── snackbar ───────────────────────────────────────────────────────────────

  void _showSnack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? _danger : _accentB,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ── date picker ────────────────────────────────────────────────────────────

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: _accent,
            surface: _surface,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(
        () => _selectedDate = DateTime.utc(
          picked.year,
          picked.month,
          picked.day,
        ),
      );
    }
  }

  // ── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(),
      body: Form(
        key: _formKey,
        child: CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
            SliverToBoxAdapter(child: _buildHeroHeader()),
            SliverToBoxAdapter(child: _buildDateRow()),
            SliverToBoxAdapter(child: _buildCategorySelector()),
            SliverToBoxAdapter(child: _buildAIGenerateButton()),
            if (_generating) SliverToBoxAdapter(child: _buildProgressBar()),
            SliverToBoxAdapter(child: _buildDetailsCard()),
            SliverToBoxAdapter(child: _buildQuestionsHeader()),
            if (_questions.isEmpty && !_generating)
              SliverToBoxAdapter(child: _buildEmptyState()),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) => _buildQuestionCard(i),
                childCount: _questions.length,
              ),
            ),
            SliverToBoxAdapter(child: _buildAddButton()),
            SliverToBoxAdapter(child: _buildPublishButton()),
            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: _textPrimary,
            size: 16,
          ),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.logout_rounded, color: _danger, size: 18),
          ),
          onPressed: () async {
            await FirebaseAuth.instance.signOut();
            if (!mounted) return;
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
              (r) => false,
            );
          },
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildHeroHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_accent, _accentB]),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'ADMIN',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: _gold.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _gold.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome_rounded, color: _gold, size: 11),
                    const SizedBox(width: 4),
                    Text(
                      'AI POWERED',
                      style: TextStyle(
                        color: _gold,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Daily Quiz\nManager',
            style: TextStyle(
              color: _textPrimary,
              fontSize: 34,
              fontWeight: FontWeight.w800,
              height: 1.1,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Generate 10 AI-crafted questions in one tap',
            style: TextStyle(color: _textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildDateRow() {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final weekday = days[_selectedDate.weekday - 1];
    final month = months[_selectedDate.month - 1];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: GestureDetector(
        onTap: _pickDate,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF252A3A)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6C63FF), Color(0xFF9B5EFE)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.calendar_month_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Quiz Date',
                    style: TextStyle(color: _textSecondary, fontSize: 11),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$weekday, ${_selectedDate.day} $month ${_selectedDate.year}',
                    style: const TextStyle(
                      color: _textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Change',
                  style: TextStyle(
                    color: _accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategorySelector() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Category',
            style: TextStyle(
              color: _textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(_categories.length, (i) {
                final cat = _categories[i];
                final selected = _selectedCategoryIndex == i;
                return GestureDetector(
                  onTap: () => setState(() => _selectedCategoryIndex = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: selected ? cat.color.withOpacity(0.18) : _surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: selected ? cat.color : const Color(0xFF252A3A),
                        width: selected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          cat.icon,
                          color: selected ? cat.color : _textSecondary,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          cat.label,
                          style: TextStyle(
                            color: selected ? cat.color : _textSecondary,
                            fontSize: 13,
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAIGenerateButton() {
    final cat = _categories[_selectedCategoryIndex];
    final blocked = AiQuizAccessService.isBlockedOnWeb;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: GestureDetector(
        onTap: _generating
            ? null
            : () => AiQuizAccessService.guard(context, _generateWithAI),
        child: AnimatedBuilder(
          animation: _pulseCtrl,
          builder: (_, __) => Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_accent, Color.lerp(_accent, cat.color, 0.6)!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: _accent.withOpacity(
                    _generating ? 0.3 : 0.2 + 0.15 * _pulseCtrl.value,
                  ),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_generating)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                else
                  Icon(
                    blocked
                        ? AiQuizAccessService.webIcon
                        : Icons.auto_awesome_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                const SizedBox(width: 10),
                Text(
                  _generating
                      ? 'Generating…'
                      : blocked
                          ? AiQuizAccessService.webButtonLabel
                          : 'Generate 10 AI Questions  (${cat.label})',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _accent.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AnimatedBuilder(
                  animation: _shimmerCtrl,
                  builder: (_, __) => Icon(
                    Icons.smart_toy_rounded,
                    color: Color.lerp(_accent, _accentB, _shimmerCtrl.value)!,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _genStatus,
                    style: const TextStyle(
                      color: _textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Text(
                  '${(_genProgress * 100).round()}%',
                  style: const TextStyle(
                    color: _accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: _genProgress,
                backgroundColor: _card,
                valueColor: AlwaysStoppedAnimation(
                  Color.lerp(_accent, _accentB, _genProgress)!,
                ),
                minHeight: 6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF252A3A)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.tune_rounded, color: _textSecondary, size: 16),
                SizedBox(width: 8),
                Text(
                  'Quiz Details',
                  style: TextStyle(
                    color: _textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _styledField(_titleCtrl, 'Title', Icons.title_rounded),
            const SizedBox(height: 12),
            _styledField(
              _descCtrl,
              'Description',
              Icons.description_rounded,
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildChipField(
                    _timeCtrl,
                    'Time (sec)',
                    Icons.timer_rounded,
                    _accentB,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildChipField(
                    _xpCtrl,
                    'XP Reward',
                    Icons.star_rounded,
                    _gold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _styledField(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      style: const TextStyle(color: _textPrimary, fontSize: 14),
      validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: _textSecondary, size: 18),
        labelText: label,
        labelStyle: const TextStyle(color: _textSecondary, fontSize: 13),
        filled: true,
        fillColor: _card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _danger, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
      ),
    );
  }

  Widget _buildChipField(
    TextEditingController ctrl,
    String label,
    IconData icon,
    Color color,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: TextFormField(
        controller: ctrl,
        keyboardType: TextInputType.number,
        style: TextStyle(
          color: color,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        textAlign: TextAlign.center,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: color.withOpacity(0.7), fontSize: 11),
          prefixIcon: Icon(icon, color: color.withOpacity(0.6), size: 16),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionsHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
      child: Row(
        children: [
          const Text(
            'Questions',
            style: TextStyle(
              color: _textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _questions.length >= 5
                  ? _accentB.withOpacity(0.15)
                  : _danger.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${_questions.length}/10',
              style: TextStyle(
                color: _questions.length >= 5 ? _accentB : _danger,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 36),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: const Color(0xFF252A3A),
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          children: [
            Icon(
              Icons.quiz_rounded,
              color: _textSecondary.withOpacity(0.3),
              size: 40,
            ),
            const SizedBox(height: 12),
            const Text(
              'No questions yet',
              style: TextStyle(
                color: _textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              AiQuizAccessService.isBlockedOnWeb
                  ? 'Add manually — AI generation needs the mobile app'
                  : 'Tap "Generate" above or add manually',
              style: const TextStyle(color: _textSecondary, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionCard(int index) {
    final q = _questions[index];
    final optionLabels = ['A', 'B', 'C', 'D'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: Dismissible(
        key: ValueKey('q_$index\_${q.question.hashCode}'),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: _danger.withOpacity(0.15),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _danger.withOpacity(0.3)),
          ),
          child: const Icon(Icons.delete_rounded, color: _danger),
        ),
        onDismissed: (_) {
          setState(() => _questions.removeAt(index));
          HapticFeedback.lightImpact();
        },
        child: Container(
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFF252A3A)),
          ),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 4,
              ),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              leading: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _accent.withOpacity(0.8),
                      _accentB.withOpacity(0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              title: Text(
                q.question,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () => _openQuestionDialog(index: index),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: _accent.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.edit_rounded,
                        color: _accent,
                        size: 15,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.expand_more_rounded,
                    color: _textSecondary,
                    size: 18,
                  ),
                ],
              ),
              children: [
                const Divider(color: Color(0xFF252A3A)),
                const SizedBox(height: 6),
                ...List.generate(4, (i) {
                  final isCorrect = i == q.correctIndex;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: isCorrect ? _accentB.withOpacity(0.12) : _card,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isCorrect
                            ? _accentB.withOpacity(0.5)
                            : Colors.transparent,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: isCorrect
                                ? _accentB
                                : _textSecondary.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              optionLabels[i],
                              style: TextStyle(
                                color: isCorrect
                                    ? Colors.white
                                    : _textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            q.options[i],
                            style: TextStyle(
                              color: isCorrect ? _accentB : _textSecondary,
                              fontSize: 13,
                              fontWeight: isCorrect
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ),
                        if (isCorrect)
                          const Icon(
                            Icons.check_circle_rounded,
                            color: _accentB,
                            size: 16,
                          ),
                      ],
                    ),
                  );
                }),
                if (q.solution.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _gold.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _gold.withOpacity(0.2)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.lightbulb_rounded, color: _gold, size: 14),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            q.solution,
                            style: const TextStyle(
                              color: _textSecondary,
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
          ),
        ),
      ),
    );
  }

  Widget _buildAddButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      child: GestureDetector(
        onTap: () => _openQuestionDialog(),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _accent.withOpacity(0.4),
              style: BorderStyle.solid,
            ),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_circle_rounded, color: _accent, size: 18),
              SizedBox(width: 8),
              Text(
                'Add Question Manually',
                style: TextStyle(
                  color: _accent,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPublishButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: GestureDetector(
        onTap: (_publishing || _generating) ? null : _publish,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            gradient: (_publishing || _generating)
                ? null
                : const LinearGradient(
                    colors: [Color(0xFF00C2A8), Color(0xFF00897B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            color: (_publishing || _generating) ? _surface : null,
            borderRadius: BorderRadius.circular(18),
            boxShadow: (_publishing || _generating)
                ? []
                : [
                    BoxShadow(
                      color: _accentB.withOpacity(0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_publishing)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              else
                const Icon(
                  Icons.rocket_launch_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              const SizedBox(width: 10),
              Text(
                _publishing ? 'Publishing…' : 'Publish Daily Quiz',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
