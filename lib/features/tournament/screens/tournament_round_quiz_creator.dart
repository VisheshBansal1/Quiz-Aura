// ============================================================
// FILE: lib/features/tournament/screens/tournament_round_quiz_creator.dart
//
// PURPOSE: Create a quiz specifically for a tournament round.
//   - Quiz is stored in `quizzes` collection tagged with tournamentId
//   - Fully independent of global quiz system
//   - Admin builds questions inline with multi-step wizard
//   - Returns {quizId, quizTitle} to caller on save
// ============================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/glass_card.dart';

// ─── Data class for a question being built ────────────────────────────────────
class _QuestionDraft {
  String question = '';
  List<String> options = ['', '', '', ''];
  int correctIndex = 0;

  bool get isValid =>
      question.trim().isNotEmpty &&
      options.every((o) => o.trim().isNotEmpty) &&
      correctIndex >= 0 &&
      correctIndex < options.length;
}

class TournamentRoundQuizCreator extends StatefulWidget {
  final String tournamentId;
  final int roundNumber;
  // Called with (quizId, quizTitle) when quiz is successfully saved
  final void Function(String quizId, String quizTitle) onQuizCreated;

  const TournamentRoundQuizCreator({
    super.key,
    required this.tournamentId,
    required this.roundNumber,
    required this.onQuizCreated,
  });

  @override
  State<TournamentRoundQuizCreator> createState() =>
      _TournamentRoundQuizCreatorState();
}

class _TournamentRoundQuizCreatorState
    extends State<TournamentRoundQuizCreator> {
  // ── Step state (0 = info, 1 = questions) ──────────────────────────────
  int _step = 0;

  // ── Step 0: Quiz metadata ──────────────────────────────────────────────
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _difficulty = 'Medium';

  // ── Step 1: Questions ──────────────────────────────────────────────────
  final List<_QuestionDraft> _questions = [_QuestionDraft()];
  int _editingIndex = 0;

  bool _saving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SAVE QUIZ TO FIRESTORE
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _saveQuiz() async {
    final validQuestions = _questions.where((q) => q.isValid).toList();

    if (validQuestions.isEmpty) {
      _snack('Add at least one complete question');
      return;
    }

    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      _snack('Quiz title is required');
      return;
    }

    setState(() => _saving = true);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final db = FirebaseFirestore.instance;

      // 1. Create quiz doc
      final quizRef = await db.collection('quizzes').add({
        'title': title,
        'description': _descCtrl.text.trim(),
        'difficulty': _difficulty,
        'createdBy': uid,
        'isActive': true,
        // Tag this quiz as tournament-specific
        'isTournamentQuiz': true,
        'tournamentId': widget.tournamentId,
        'roundNumber': widget.roundNumber,
        'topicTitle': 'Round ${widget.roundNumber}',
        'questionCount': validQuestions.length,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 2. Add questions as subcollection
      final batch = db.batch();
      for (int i = 0; i < validQuestions.length; i++) {
        final q = validQuestions[i];
        final qRef = quizRef.collection('questions').doc();
        batch.set(qRef, {
          'question': q.question.trim(),
          'options': q.options.map((o) => o.trim()).toList(),
          'correctIndex': q.correctIndex,
          'order': i,
          'isActive': true,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();

      if (!mounted) return;
      _snack('Quiz created! ${validQuestions.length} questions', success: true);
      widget.onQuizCreated(quizRef.id, title);
      Navigator.pop(context);
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
      setState(() => _saving = false);
    }
  }

  void _snack(String msg, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: success ? Colors.teal : Colors.redAccent,
    ));
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Container(
              decoration:
                  const BoxDecoration(gradient: AppColors.mainGradient)),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                _buildStepIndicator(),
                Expanded(
                  child: _step == 0 ? _buildInfoStep() : _buildQuestionsStep(),
                ),
                _buildBottomBar(),
              ],
            ),
          ),
          if (_saving)
            Container(
              color: Colors.black54,
              child: const Center(
                  child: CircularProgressIndicator(color: Colors.tealAccent)),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 16, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Column(
              children: [
                const Text(
                  'Create Round Quiz',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold),
                ),
                Text(
                  'Round ${widget.roundNumber} • Tournament Quiz',
                  textAlign: TextAlign.center,
                  style:
                      const TextStyle(color: Colors.tealAccent, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Row(
        children: [
          _StepDot(index: 0, current: _step, label: 'Info'),
          Expanded(
              child: Container(
                  height: 2, color: Colors.white.withOpacity(0.2))),
          _StepDot(index: 1, current: _step, label: 'Questions'),
        ],
      ),
    );
  }

  // ── STEP 0: Quiz Info ────────────────────────────────────────────────────
  Widget _buildInfoStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Quiz Title *',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 8),
                TextField(
                  controller: _titleCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  decoration: const InputDecoration(
                    hintText: 'e.g. DSA Round 1 — Arrays & Strings',
                    hintStyle: TextStyle(color: Colors.white30),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Description (optional)',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 8),
                TextField(
                  controller: _descCtrl,
                  maxLines: 2,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: const InputDecoration(
                    hintText: 'Brief description of this round\'s quiz...',
                    hintStyle: TextStyle(color: Colors.white30),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Difficulty',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 12),
                Row(
                  children: ['Easy', 'Medium', 'Hard'].map((d) {
                    final isSelected = d == _difficulty;
                    final color = d == 'Easy'
                        ? Colors.greenAccent
                        : d == 'Medium'
                            ? Colors.amber
                            : Colors.redAccent;
                    return GestureDetector(
                      onTap: () => setState(() => _difficulty = d),
                      child: Container(
                        margin: const EdgeInsets.only(right: 10),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? color.withOpacity(0.2)
                              : Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: isSelected
                                  ? color.withOpacity(0.6)
                                  : Colors.white24),
                        ),
                        child: Text(d,
                            style: TextStyle(
                                color: isSelected ? color : Colors.white54,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                fontSize: 13)),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.teal.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.teal.withOpacity(0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.tealAccent, size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Next you\'ll add questions with 4 options each.\nRecommended: 10–20 questions per round.',
                    style: TextStyle(
                        color: Colors.white70, fontSize: 12, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── STEP 1: Questions ────────────────────────────────────────────────────
  Widget _buildQuestionsStep() {
    final validCount = _questions.where((q) => q.isValid).length;

    return Row(
      children: [
        // ── Questions sidebar ──────────────────────────────────────────
        Container(
          width: 70,
          color: Colors.black.withOpacity(0.3),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: _questions.length + 1,
                  itemBuilder: (_, i) {
                    if (i == _questions.length) {
                      return _AddQBtn(onTap: () {
                        setState(() {
                          _questions.add(_QuestionDraft());
                          _editingIndex = _questions.length - 1;
                        });
                      });
                    }
                    final q = _questions[i];
                    final isSelected = i == _editingIndex;
                    return GestureDetector(
                      onTap: () => setState(() => _editingIndex = i),
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        height: 50,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: isSelected
                              ? Colors.teal.withOpacity(0.3)
                              : Colors.white.withOpacity(0.06),
                          border: Border.all(
                            color: isSelected
                                ? Colors.tealAccent.withOpacity(0.5)
                                : q.isValid
                                    ? Colors.green.withOpacity(0.4)
                                    : Colors.white.withOpacity(0.12),
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Q${i + 1}',
                              style: TextStyle(
                                  color: isSelected
                                      ? Colors.tealAccent
                                      : Colors.white60,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12),
                            ),
                            if (q.isValid)
                              const Icon(Icons.check_circle,
                                  size: 10, color: Colors.greenAccent),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  '$validCount/${_questions.length}\nDone',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white54, fontSize: 10),
                ),
              ),
            ],
          ),
        ),

        // ── Question editor ────────────────────────────────────────────
        Expanded(
          child: _QuestionEditor(
            key: ValueKey(_editingIndex),
            draft: _questions[_editingIndex],
            questionNumber: _editingIndex + 1,
            // FIX: notify parent so sidebar validity badges refresh live
            onChanged: () => setState(() {}),
            onDelete: _questions.length > 1
                ? () {
                    setState(() {
                      _questions.removeAt(_editingIndex);
                      if (_editingIndex >= _questions.length) {
                        _editingIndex = _questions.length - 1;
                      }
                    });
                  }
                : null,
          ),
        ),
      ],
    );
  }

  // ── BOTTOM NAV BAR ────────────────────────────────────────────────────────
  Widget _buildBottomBar() {
    // Compute live so the label is always accurate
    final validCount = _questions.where((q) => q.isValid).length;

    // FIX: shared button style with explicit minimumSize so the button never
    // tries to expand to infinite width (happens when the global theme sets
    // minimumSize: Size(double.infinity, 50), a very common pattern).
    const _btnShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
    );
    const _minSize = Size(0, 44); // no forced width expansion
    const _tapTarget = MaterialTapTargetSize.shrinkWrap;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.4),
        border:
            Border(top: BorderSide(color: Colors.white.withOpacity(0.08))),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        children: [
          // ── Back button (step 1 only) ──────────────────────────────
          if (_step > 0)
            OutlinedButton.icon(
              onPressed: () => setState(() => _step = 0),
              icon: const Icon(Icons.arrow_back, size: 14),
              label: const Text('Info'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white70,
                side: const BorderSide(color: Colors.white24),
                minimumSize: _minSize,           // FIX
                tapTargetSize: _tapTarget,       // FIX
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                ),
              ),
            ),

          const Spacer(),

          // ── Next / Save button ─────────────────────────────────────
          if (_step == 0)
            ElevatedButton.icon(
              onPressed: () {
                if (_titleCtrl.text.trim().isEmpty) {
                  _snack('Enter quiz title first');
                  return;
                }
                setState(() => _step = 1);
              },
              icon: const Icon(Icons.arrow_forward, size: 14),
              label: const Text('Add Questions'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                minimumSize: _minSize,           // FIX
                tapTargetSize: _tapTarget,       // FIX
                shape: _btnShape,
              ),
            )
          else
            ElevatedButton.icon(
              onPressed: _saving ? null : _saveQuiz,
              icon: const Icon(Icons.save_rounded),
              label: Text(
                'Save Quiz ($validCount Q)',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                minimumSize: _minSize,           // FIX
                tapTargetSize: _tapTarget,       // FIX
                shape: _btnShape,
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// QUESTION EDITOR — edits a _QuestionDraft in place
// ─────────────────────────────────────────────────────────────────────────────
class _QuestionEditor extends StatefulWidget {
  final _QuestionDraft draft;
  final int questionNumber;
  final VoidCallback? onDelete;
  // FIX: callback so parent can setState and refresh sidebar badges
  final VoidCallback onChanged;

  const _QuestionEditor({
    super.key,
    required this.draft,
    required this.questionNumber,
    required this.onChanged,
    this.onDelete,
  });

  @override
  State<_QuestionEditor> createState() => _QuestionEditorState();
}

class _QuestionEditorState extends State<_QuestionEditor> {
  late final TextEditingController _qCtrl;
  late final List<TextEditingController> _optCtrl;

  @override
  void initState() {
    super.initState();
    _qCtrl = TextEditingController(text: widget.draft.question);
    _optCtrl = widget.draft.options
        .map((o) => TextEditingController(text: o))
        .toList();

    // Sync changes into the draft AND notify parent for sidebar refresh
    _qCtrl.addListener(() {
      widget.draft.question = _qCtrl.text;
      widget.onChanged();
    });
    for (int i = 0; i < _optCtrl.length; i++) {
      final idx = i;
      _optCtrl[idx].addListener(() {
        widget.draft.options[idx] = _optCtrl[idx].text;
        widget.onChanged();
      });
    }
  }

  @override
  void dispose() {
    _qCtrl.dispose();
    for (final c in _optCtrl) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final letters = ['A', 'B', 'C', 'D'];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row ──────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: Text(
                  'Question ${widget.questionNumber}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14),
                ),
              ),
              if (widget.onDelete != null)
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: Colors.redAccent, size: 18),
                  onPressed: widget.onDelete,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
          const SizedBox(height: 8),

          // ── Question text ────────────────────────────────────────────
          GlassCard(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _qCtrl,
              maxLines: 3,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: const InputDecoration(
                hintText: 'Type the question here...',
                hintStyle: TextStyle(color: Colors.white30, fontSize: 13),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),

          const SizedBox(height: 12),
          const Text('Options (tap row to mark correct)',
              style: TextStyle(color: Colors.white54, fontSize: 11)),
          const SizedBox(height: 8),

          // ── Options ──────────────────────────────────────────────────
          ...List.generate(4, (i) {
            final isCorrect = widget.draft.correctIndex == i;
            return GestureDetector(
              onTap: () {
                setState(() => widget.draft.correctIndex = i);
                widget.onChanged(); // FIX: notify parent on correct-index change
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.only(bottom: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: isCorrect
                      ? Colors.green.withOpacity(0.15)
                      : Colors.white.withOpacity(0.05),
                  border: Border.all(
                    color: isCorrect
                        ? Colors.greenAccent.withOpacity(0.5)
                        : Colors.white.withOpacity(0.12),
                  ),
                ),
                child: Row(
                  children: [
                    // Letter / check badge
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isCorrect
                            ? Colors.green.withOpacity(0.4)
                            : Colors.white.withOpacity(0.08),
                      ),
                      child: Center(
                        child: isCorrect
                            ? const Icon(Icons.check,
                                size: 14, color: Colors.greenAccent)
                            : Text(
                                letters[i],
                                style: const TextStyle(
                                    color: Colors.white54,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11),
                              ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _optCtrl[i],
                        style: TextStyle(
                            color:
                                isCorrect ? Colors.greenAccent : Colors.white,
                            fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Option ${letters[i]}...',
                          hintStyle: const TextStyle(
                              color: Colors.white24, fontSize: 12),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────────────────────────────────────
class _StepDot extends StatelessWidget {
  final int index;
  final int current;
  final String label;

  const _StepDot(
      {required this.index, required this.current, required this.label});

  @override
  Widget build(BuildContext context) {
    final isDone = index < current;
    final isCurrent = index == current;
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDone
                ? Colors.teal
                : isCurrent
                    ? Colors.teal.withOpacity(0.3)
                    : Colors.white.withOpacity(0.1),
            border: Border.all(
              color: isCurrent || isDone ? Colors.teal : Colors.white24,
              width: isCurrent ? 2 : 1,
            ),
          ),
          child: Center(
            child: isDone
                ? const Icon(Icons.check, color: Colors.white, size: 16)
                : Text(
                    '${index + 1}',
                    style: TextStyle(
                        color: isCurrent ? Colors.tealAccent : Colors.white54,
                        fontWeight: FontWeight.bold,
                        fontSize: 13),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
              color: isCurrent ? Colors.tealAccent : Colors.white38,
              fontSize: 10),
        ),
      ],
    );
  }
}

class _AddQBtn extends StatelessWidget {
  final VoidCallback onTap;
  const _AddQBtn({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        height: 42,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: Colors.teal.withOpacity(0.1),
          border: Border.all(color: Colors.teal.withOpacity(0.3)),
        ),
        child: const Center(
          child: Icon(Icons.add, color: Colors.tealAccent, size: 18),
        ),
      ),
    );
  }
}