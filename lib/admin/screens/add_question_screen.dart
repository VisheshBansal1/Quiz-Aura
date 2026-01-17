import 'package:flutter/material.dart';
import '../services/Admin_quiz_service.dart';

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

  int correctIndex = 0;
  bool loading = false;

  final service = AdminQuizService();

  @override
  void dispose() {
    questionCtrl.dispose();
    for (final c in optionCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> saveQuestion() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;
    if (loading) return;

    setState(() => loading = true);

    try {
      await service.addQuestion(
        quizId: widget.quizId,
        question: questionCtrl.text.trim(),
        options: optionCtrls.map((e) => e.text.trim()).toList(),
        correctIndex: correctIndex,
      );

      questionCtrl.clear();
      for (final c in optionCtrls) {
        c.clear();
      }

      setState(() => correctIndex = 0);

      _success("Question added successfully");
    } catch (e) {
      _error(e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _error(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _success(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Add Question"),
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: ListView(
                children: [
                  TextFormField(
                    controller: questionCtrl,
                    decoration: const InputDecoration(
                      labelText: "Question",
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        v == null || v.trim().isEmpty
                            ? "Question is required"
                            : null,
                  ),
                  const SizedBox(height: 20),

                  const Text(
                    "Options (select correct one)",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),

                  for (int i = 0; i < 4; i++)
                    RadioListTile<int>(
                      value: i,
                      groupValue: correctIndex,
                      onChanged: loading
                          ? null
                          : (v) => setState(() => correctIndex = v!),
                      title: TextFormField(
                        controller: optionCtrls[i],
                        decoration: InputDecoration(
                          labelText: "Option ${i + 1}",
                          border: const OutlineInputBorder(),
                        ),
                        validator: (v) =>
                            v == null || v.trim().isEmpty
                                ? "Option ${i + 1} required"
                                : null,
                      ),
                    ),

                  const SizedBox(height: 24),

                  ElevatedButton.icon(
                    onPressed: loading ? null : saveQuestion,
                    icon: const Icon(Icons.save),
                    label: const Text("Save Question"),
                  ),
                ],
              ),
            ),
          ),

          // 🔄 Full screen loader
          if (loading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}
