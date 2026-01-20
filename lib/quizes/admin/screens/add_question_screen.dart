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

  // ================= SAVE QUESTION =================
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

  // ================= UI HELPERS =================
  void _error(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
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

  // ================= BUILD =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Add Question", style: TextStyle(color: Colors.white),),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: Icon(Icons.arrow_back, color: Colors.white,),
        ),
        flexibleSpace: _gradientBg(),
      ),
      body: Stack(
        children: [
          _gradientBg(),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    // ===== QUESTION =====
                    _glassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Question",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _glassInput(
                            controller: questionCtrl,
                            hint: "Enter the question here",
                            validator: (v) =>
                                v == null || v.trim().isEmpty
                                    ? "Question is required"
                                    : null,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ===== OPTIONS =====
                    _glassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Options (select correct answer)",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          for (int i = 0; i < 4; i++) _optionTile(i),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),

                    // ===== SAVE BUTTON =====
                    SizedBox(
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: loading ? null : saveQuestion,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        icon: const Icon(Icons.save),
                        label: const Text(
                          "Save Question",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          if (loading)
            Container(
              color: Colors.black.withOpacity(0.4),
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  // ================= WIDGET BUILDERS =================

  Widget _gradientBg() {
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

  Widget _glassCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withOpacity(0.12),
        border: Border.all(color: Colors.white.withOpacity(0.25)),
      ),
      child: child,
    );
  }

  Widget _glassInput({
    required TextEditingController controller,
    required String hint,
    FormFieldValidator<String>? validator,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white60),
        filled: true,
        fillColor: Colors.white.withOpacity(0.15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _optionTile(int index) {
    final isSelected = correctIndex == index;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: isSelected
            ? Colors.green.withOpacity(0.25)
            : Colors.white.withOpacity(0.12),
        border: Border.all(
          color: isSelected
              ? Colors.greenAccent
              : Colors.white.withOpacity(0.25),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: optionCtrls[index],
              validator: (v) =>
                  v == null || v.trim().isEmpty
                      ? "Option ${index + 1} required"
                      : null,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Option ${index + 1}",
                hintStyle: const TextStyle(color: Colors.white60),
                border: InputBorder.none,
              ),
            ),
          ),
          Radio<int>(
            value: index,
            groupValue: correctIndex,
            activeColor: Colors.greenAccent,
            onChanged:
                loading ? null : (v) => setState(() => correctIndex = v!),
          ),
        ],
      ),
    );
  }
}
