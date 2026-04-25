import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class EditQuizQuestionsScreen extends StatefulWidget {
  final String quizId;
  final String quizTitle;

  const EditQuizQuestionsScreen({
    super.key,
    required this.quizId,
    required this.quizTitle,
  });

  @override
  State<EditQuizQuestionsScreen> createState() =>
      _EditQuizQuestionsScreenState();
}

class _EditQuizQuestionsScreenState extends State<EditQuizQuestionsScreen> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  final questionCtrl = TextEditingController();
  final optionCtrls = List.generate(4, (_) => TextEditingController());

  int correctIndex = 0;
  String editingQuestionId = "";
  bool loading = false;

  @override
  void dispose() {
    questionCtrl.dispose();
    for (final c in optionCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  void loadQuestion(String id, Map<String, dynamic> data) {
    editingQuestionId = id;

    // FIXED: questions may be stored under 'question' (add_question_screen)
    // or 'title' (ai_generate_questions_screen legacy). Read both.
    questionCtrl.text =
        (data['question'] as String?)?.trim() ??
        (data['text'] as String?)?.trim() ??
        (data['title'] as String?)?.trim() ??
        '';

    // FIXED: guard against null / missing options list
    final rawOptions = data['options'];
    final List options = (rawOptions is List && rawOptions.isNotEmpty)
        ? rawOptions
        : [];

    for (int i = 0; i < optionCtrls.length; i++) {
      optionCtrls[i].text = i < options.length ? options[i].toString() : '';
    }

    correctIndex = (data['correctIndex'] as int?) ?? 0;

    setState(() {});
  }

  Future<void> updateQuestion() async {
    if (editingQuestionId.isEmpty) return;

    setState(() => loading = true);

    try {
      await firestore
          .collection('quizzes')
          .doc(widget.quizId)
          .collection('questions')
          .doc(editingQuestionId)
          .update({
            // FIXED: save as 'question' (the canonical field name used by
            // add_question_screen, tournament_round_quiz_creator, and
            // battle_quiz_screen). Also write 'title' so legacy readers
            // (ai_generate flow) still see the updated text.
            "question": questionCtrl.text.trim(),
            "title": questionCtrl.text.trim(),
            "options": optionCtrls.map((e) => e.text.trim()).toList(),
            "correctIndex": correctIndex,
          });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Question updated"),
          backgroundColor: Colors.green,
        ),
      );

      clear();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      setState(() => loading = false);
    }
  }

  void clear() {
    editingQuestionId = "";
    questionCtrl.clear();

    for (var c in optionCtrls) {
      c.clear();
    }

    correctIndex = 0;

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false,

      appBar: AppBar(
        title: Text(
          widget.quizTitle,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: _bg(),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: Colors.white),
        ),
      ),

      body: Stack(
        children: [
          /// Gradient background
          Positioned.fill(child: _bg()),

          /// Questions list
          Positioned.fill(child: _questionsList()),

          /// Editor panel
          if (editingQuestionId.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom: keyboardHeight,
              child: _editor(),
            ),

          /// Loading overlay
          if (loading)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  Widget _questionsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: firestore
          .collection('quizzes')
          .doc(widget.quizId)
          .collection('questions')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final questions = snapshot.data!.docs;

        if (questions.isEmpty) {
          return const Center(
            child: Text(
              "No questions found",
              style: TextStyle(color: Colors.white70),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 200),
          itemCount: questions.length,
          itemBuilder: (context, index) {
            final doc = questions[index];
            final data = doc.data() as Map<String, dynamic>;

            // FIXED: read question text with full fallback chain
            final questionText =
                (data['question'] as String?)?.trim() ??
                (data['text'] as String?)?.trim() ??
                (data['title'] as String?)?.trim() ??
                'No question text';

            // FIXED: guard null options
            final rawOptions = data['options'];
            final List options = (rawOptions is List && rawOptions.isNotEmpty)
                ? rawOptions
                : [];

            final correctIdx = (data['correctIndex'] as int?) ?? 0;
            final correctAnswer =
                (options.isNotEmpty && correctIdx < options.length)
                ? options[correctIdx].toString()
                : '—';

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Colors.white.withOpacity(0.12),
                border: Border.all(color: Colors.white24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    questionText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Correct: $correctAnswer',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      icon: const Icon(Icons.edit, color: Colors.white),
                      onPressed: () {
                        loadQuestion(doc.id, data);
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _editor() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFF203A43),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _input(questionCtrl, "Question"),
            const SizedBox(height: 16),
            _mcqBlock(),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: updateQuestion,
                    child: const Text("Update"),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: clear,
                    child: const Text("Cancel"),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _mcqBlock() {
    return Column(
      children: List.generate(4, (i) {
        final isSelected = correctIndex == i;

        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? Colors.greenAccent : Colors.white24,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: optionCtrls[i],
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "Option ${i + 1}",
                      hintStyle: const TextStyle(color: Colors.white54),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                Radio<int>(
                  value: i,
                  groupValue: correctIndex,
                  activeColor: Colors.greenAccent,
                  onChanged: (v) {
                    setState(() => correctIndex = v!);
                  },
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _input(TextEditingController c, String label) {
    return TextField(
      controller: c,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _bg() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
        ),
      ),
    );
  }
}
