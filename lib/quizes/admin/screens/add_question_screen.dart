import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/Admin_quiz_service.dart';

class AddQuestionScreen extends StatefulWidget {
  final String quizId;
  // Hint from parent: 'mcq' | 'coding' | 'mixed'
  final String quizType;

  const AddQuestionScreen({
    super.key,
    required this.quizId,
    this.quizType = 'mcq',
  });

  @override
  State<AddQuestionScreen> createState() => _AddQuestionScreenState();
}

class _AddQuestionScreenState extends State<AddQuestionScreen> {
  final _formKey = GlobalKey<FormState>();

  // MCQ fields
  final questionCtrl = TextEditingController();
  final optionCtrls = List.generate(4, (_) => TextEditingController());
  int correctIndex = 0;

  // Coding fields
  final titleCtrl = TextEditingController(); // problem title
  final descCtrl = TextEditingController(); // full problem description
  final inputCtrl = TextEditingController(); // sample stdin
  final outputCtrl = TextEditingController(); // expected stdout
  int questionScore = 10; // score for this problem
  String difficulty = 'medium';

  late String questionType; // 'mcq' | 'coding'
  bool loading = false;

  final AdminQuizService service = AdminQuizService();

  @override
  void initState() {
    super.initState();
    // If quiz is coding-only → default to coding tab
    questionType = widget.quizType == 'coding' ? 'coding' : 'mcq';
  }

  @override
  void dispose() {
    questionCtrl.dispose();
    titleCtrl.dispose();
    descCtrl.dispose();
    inputCtrl.dispose();
    outputCtrl.dispose();
    for (final c in optionCtrls) c.dispose();
    super.dispose();
  }

  // ── Save ─────────────────────────────────────────────────────────────────
  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate() || loading) return;

    setState(() => loading = true);
    try {
      if (questionType == 'mcq') {
        await service.addMcqQuestion(
          quizId: widget.quizId,
          data: {
            'type': 'mcq',
            'question': questionCtrl.text.trim(),
            'options': optionCtrls.map((e) => e.text.trim()).toList(),
            'correctIndex': correctIndex,
          },
        );
      } else {
        await service.addCodingQuestion(
          quizId: widget.quizId,
          data: {
            'type': 'coding',
            'title': titleCtrl.text.trim(),
            'description': descCtrl.text.trim(),
            'input': inputCtrl.text.trim(),
            'expectedOutput': outputCtrl.text.trim(),
            'score': questionScore,
            'difficulty': difficulty,
            'visibleTestCases': [
              {
                'input': inputCtrl.text.trim(),
                'output': outputCtrl.text.trim(),
              },
            ],
            'hiddenTestCases': [],
          },
        );
      }

      _clear();
      _success('Question added ✓');
    } catch (e) {
      _error(e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _clear() {
    questionCtrl.clear();
    titleCtrl.clear();
    descCtrl.clear();
    inputCtrl.clear();
    outputCtrl.clear();
    for (final c in optionCtrls) c.clear();
    setState(() {
      correctIndex = 0;
      questionScore = 10;
      difficulty = 'medium';
    });
  }

  // ── UI ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text(
            'Add Question',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: Colors.white),
          ),
        ),
        body: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    // ── Type toggle ────────────────────────────────────────
                    if (widget.quizType != 'mcq' && widget.quizType != 'coding')
                      _typeToggle(),
                    if (widget.quizType == 'mixed' ||
                        widget.quizType == 'mcq' ||
                        widget.quizType == 'coding')
                      _typeToggle(),

                    const SizedBox(height: 20),

                    // ── Form body ──────────────────────────────────────────
                    if (questionType == 'mcq') ..._mcqForm(),
                    if (questionType == 'coding') ..._codingForm(),

                    const SizedBox(height: 28),

                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: loading ? null : _save,
                        icon: const Icon(Icons.save),
                        label: const Text(
                          'Save Question',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
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
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
            if (loading)
              Container(
                color: Colors.black54,
                child: const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Type toggle ──────────────────────────────────────────────────────────
  Widget _typeToggle() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white24),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          _toggleChip('mcq', 'MCQ', Icons.quiz, Colors.greenAccent),
          const SizedBox(width: 4),
          _toggleChip('coding', 'Coding', Icons.code, Colors.deepPurpleAccent),
        ],
      ),
    );
  }

  Widget _toggleChip(String value, String label, IconData icon, Color color) {
    final selected = questionType == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => questionType = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? color.withOpacity(0.2) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: selected ? color : Colors.white54, size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: selected ? color : Colors.white54,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── MCQ form ─────────────────────────────────────────────────────────────
  List<Widget> _mcqForm() => [
    _sectionLabel('Question Text'),
    _field(questionCtrl, 'Enter the question...', maxLines: 3),
    const SizedBox(height: 20),
    _sectionLabel('Options  (tap radio = correct answer)'),
    ...List.generate(4, (i) {
      final selected = correctIndex == i;
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? Colors.greenAccent : Colors.white24,
              width: selected ? 1.8 : 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: optionCtrls[i],
                  style: const TextStyle(color: Colors.white),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Required' : null,
                  decoration: InputDecoration(
                    hintText: 'Option ${i + 1}',
                    hintStyle: const TextStyle(color: Colors.white38),
                    border: InputBorder.none,
                  ),
                ),
              ),
              Radio<int>(
                value: i,
                groupValue: correctIndex,
                activeColor: Colors.greenAccent,
                onChanged: (v) => setState(() => correctIndex = v!),
              ),
            ],
          ),
        ),
      );
    }),
  ];

  // ── Coding form ───────────────────────────────────────────────────────────
  List<Widget> _codingForm() => [
    _sectionLabel('Problem Title'),
    _field(
      titleCtrl,
      'e.g.  Sum of Two Numbers',
      validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
    ),

    const SizedBox(height: 16),
    _sectionLabel('Problem Description'),
    _field(
      descCtrl,
      'Describe the problem clearly. Include constraints and examples.',
      maxLines: 5,
      validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
    ),

    const SizedBox(height: 16),
    Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionLabel('Difficulty'),
              DropdownButtonFormField<String>(
                value: difficulty,
                dropdownColor: const Color(0xFF203A43),
                items: ['easy', 'medium', 'hard']
                    .map(
                      (d) => DropdownMenuItem(
                        value: d,
                        child: Text(
                          d[0].toUpperCase() + d.substring(1),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => difficulty = v!),
                decoration: _inputDeco(''),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionLabel('Score'),
              TextFormField(
                initialValue: questionScore.toString(),
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                onChanged: (v) => questionScore = int.tryParse(v) ?? 10,
                decoration: _inputDeco('Points'),
              ),
            ],
          ),
        ),
      ],
    ),

    const SizedBox(height: 16),
    _sectionLabel('Sample Input  (stdin)'),
    _field(inputCtrl, 'e.g.  3 5', maxLines: 3),

    const SizedBox(height: 16),
    _sectionLabel('Expected Output  (stdout)'),
    _field(
      outputCtrl,
      'e.g.  8',
      maxLines: 3,
      validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
    ),
  ];

  // ── Helpers ──────────────────────────────────────────────────────────────
  Widget _sectionLabel(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      t,
      style: const TextStyle(
        color: Colors.white70,
        fontWeight: FontWeight.w600,
      ),
    ),
  );

  Widget _field(
    TextEditingController c,
    String hint, {
    int maxLines = 1,
    FormFieldValidator<String>? validator,
  }) {
    return TextFormField(
      controller: c,
      maxLines: maxLines,
      validator: validator,
      style: const TextStyle(color: Colors.white, fontFamily: 'monospace'),
      decoration: _inputDeco(hint),
    );
  }

  InputDecoration _inputDeco(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Colors.white30),
    filled: true,
    fillColor: Colors.white.withOpacity(0.1),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
  );

  void _error(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  void _success(String msg) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.green));
}
