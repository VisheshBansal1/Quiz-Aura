import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/admin_quiz_service.dart';

class AddQuestionScreen extends StatefulWidget {
  final String quizId;
  const AddQuestionScreen({super.key, required this.quizId});

  @override
  State<AddQuestionScreen> createState() => _AddQuestionScreenState();
}

class _AddQuestionScreenState extends State<AddQuestionScreen> {
  final _formKey = GlobalKey<FormState>();

  final questionCtrl = TextEditingController();
  final optionCtrls = List.generate(4, (_) => TextEditingController());
  final inputCtrl = TextEditingController();
  final outputCtrl = TextEditingController();

  String questionType = "mcq";
  int correctIndex = 0;
  bool loading = false;

  final AdminQuizService service = AdminQuizService();

  @override
  void dispose() {
    questionCtrl.dispose();
    inputCtrl.dispose();
    outputCtrl.dispose();
    for (final c in optionCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  // ================= SAVE =================
  Future<void> saveQuestion() async {
  FocusScope.of(context).unfocus();
  if (!_formKey.currentState!.validate() || loading) return;

  setState(() => loading = true);

  try {
    final quizRef = FirebaseFirestore.instance
        .collection('quizzes')
        .doc(widget.quizId);

    // 1️⃣ Add Question
    if (questionType == "mcq") {
      await service.addMcqQuestion(
        quizId: widget.quizId,
        data: {
          "type": "mcq",
          "question": questionCtrl.text.trim(),
          "options": optionCtrls.map((e) => e.text.trim()).toList(),
          "correctIndex": correctIndex,
          "createdAt": FieldValue.serverTimestamp(),
        },
      );
    } else {
      await service.addCodingQuestion(
        quizId: widget.quizId,
        data: {
          "type": "coding",
          "title": questionCtrl.text.trim(),
          "visibleTestCases": [
            {
              "input": inputCtrl.text.trim(),
              "output": outputCtrl.text.trim(),
            },
          ],
          "hiddenTestCases": [],
          "createdAt": FieldValue.serverTimestamp(),
        },
      );
    }

    // 2️⃣ Count actual questions from subcollection
    final countSnapshot = await quizRef
        .collection('questions')
        .count()
        .get();

    final int updatedCount = countSnapshot.count ?? 0;

    // 3️⃣ Update quiz document
    await quizRef.update({
      "totalQuestions": updatedCount,
    });

    _clear();
    _success("Question added");

  } catch (e) {
    _error(e.toString());
  } finally {
    if (mounted) setState(() => loading = false);
  }
}

  void _clear() {
    questionCtrl.clear();
    inputCtrl.clear();
    outputCtrl.clear();
    for (final c in optionCtrls) {
      c.clear();
    }
    correctIndex = 0;
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text(
            "Add Question",
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            onPressed: () {
              Navigator.pop(context);
            },
            icon: Icon(Icons.arrow_back, color: Colors.white,),
          ),
        ),
        body: Stack(
          children: [
            _bg(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    // _dropdown(),
                    const SizedBox(height: 16),
                    _input(questionCtrl, "Question"),
                    const SizedBox(height: 16),
                    if (questionType == "mcq") _mcqBlock(),
                    if (questionType == "coding") _codingBlock(),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: loading ? null : saveQuestion,
                      child: const Text("Save Question"),
                    ),
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

  // ================= BLOCKS =================
  Widget _dropdown() {
    return DropdownButtonFormField<String>(
      value: questionType,
      items: const [
        DropdownMenuItem(
          value: "mcq",
          child: Text("MCQ", style: TextStyle(color: Colors.white70)),
        ),
        DropdownMenuItem(
          value: "coding",
          child: Text("Coding", style: TextStyle(color: Colors.white70)),
        ),
      ],
      onChanged: (v) => setState(() => questionType = v!),
      decoration: const InputDecoration(labelText: "Question Type"),
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
                color: isSelected
                    ? Colors.greenAccent
                    : Colors.white.withOpacity(0.2),
                width: 1.2,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
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
                  fillColor: MaterialStateProperty.all(Colors.white),
                  onChanged: (v) => setState(() => correctIndex = v!),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _codingBlock() {
    return Column(
      children: [
        _input(inputCtrl, "Sample Input"),
        const SizedBox(height: 12),
        _input(outputCtrl, "Expected Output"),
      ],
    );
  }

  // ================= HELPERS =================
  Widget _input(TextEditingController c, String label) {
    return TextFormField(
      controller: c,
      validator: (v) => v == null || v.trim().isEmpty ? "Required" : null,
      style: TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
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

  void _error(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _success(String msg) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.green));
  }
}
