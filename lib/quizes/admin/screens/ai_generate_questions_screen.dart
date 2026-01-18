import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/groq_ai_service.dart';
import '../services/Admin_quiz_service.dart';

class AiGenerateQuestionsScreen extends StatefulWidget {
  final String quizId;
  const AiGenerateQuestionsScreen({super.key, required this.quizId});

  @override
  State<AiGenerateQuestionsScreen> createState() =>
      _AiGenerateQuestionsScreenState();
}

class _AiGenerateQuestionsScreenState
    extends State<AiGenerateQuestionsScreen> {
  late GroqAIService groqAIService;
  late AdminQuizService quizService;

  bool loading = false;
  bool saving = false;

  String difficulty = "Easy";
  String? topic;

  List<Map<String, dynamic>> questions = [];

  @override
  void initState() {
    super.initState();
    groqAIService = GroqAIService();
    quizService = AdminQuizService();
    _loadQuizTopic();
  }

  // ================= LOAD QUIZ TOPIC =================
  Future<void> _loadQuizTopic() async {
    final snap = await FirebaseFirestore.instance
        .collection('quizzes')
        .doc(widget.quizId)
        .get();

    if (!mounted) return;

    final data = snap.data();
    final t = data?['topic'];

    setState(() {
      topic = (t is String && t.trim().isNotEmpty) ? t : null;
    });
  }

  // ================= GENERATE AI QUESTIONS =================
  Future<void> generate() async {
    if (loading) return;

    if (topic == null) {
      _error("Quiz topic not found. Check Firestore field.");
      return;
    }

    setState(() {
      loading = true;
      questions.clear();
    });

    try {
      final result = await groqAIService.generateMCQs(
        topic: topic!,
        difficulty: difficulty,
        count: 5,
      );

      if (!mounted) return;

      if (result.isEmpty) {
        _error("AI returned no questions");
      } else {
        setState(() => questions = result);
      }
    } catch (e) {
      _error(e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  // ================= SAVE QUESTIONS =================
  Future<void> saveAll() async {
    if (saving || questions.isEmpty) return;

    setState(() => saving = true);

    try {
      for (final q in questions) {
        await quizService.addQuestion(
          quizId: widget.quizId,
          question: q['question'],
          options: List<String>.from(q['options']),
          correctIndex: q['correctIndex'],
        );
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      _error("Failed to save questions");
    } finally {
      if (mounted) setState(() => saving = false);
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

  // ================= BUILD =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("AI Question Generator"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: _gradientBg(),
      ),
      body: Stack(
        children: [
          _gradientBg(),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // ===== HEADER =====
                  _glassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Quiz Topic",
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          topic ?? "Loading...",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ===== CONTROLS =====
                  _glassCard(
                    child: Column(
                      children: [
                        DropdownButtonFormField<String>(
                          dropdownColor: const Color(0xFF203A43),
                          value: difficulty,
                          items: const [
                            DropdownMenuItem(
                                value: "Easy", child: Text("Easy")),
                            DropdownMenuItem(
                                value: "Medium", child: Text("Medium")),
                            DropdownMenuItem(
                                value: "Hard", child: Text("Hard")),
                          ],
                          onChanged: loading
                              ? null
                              : (v) => setState(() => difficulty = v!),
                          decoration: const InputDecoration(
                            labelText: "Difficulty",
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: loading ? null : generate,
                            icon: const Icon(Icons.auto_awesome),
                            label: const Text("Generate Questions"),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ===== QUESTIONS =====
                  Expanded(
                    child: questions.isEmpty
                        ? const Center(
                            child: Text(
                              "No AI questions generated yet",
                              style: TextStyle(color: Colors.white70),
                            ),
                          )
                        : ListView.builder(
                            itemCount: questions.length,
                            itemBuilder: (_, i) {
                              final q = questions[i];
                              return _questionPreview(q, i + 1);
                            },
                          ),
                  ),

                  if (questions.isNotEmpty)
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: saving ? null : saveAll,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                        ),
                        child: const Text(
                          "Save All to Quiz",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          if (loading || saving)
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

  // ================= UI HELPERS =================

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

  Widget _questionPreview(Map<String, dynamic> q, int index) {
    final options = List<String>.from(q['options']);
    final correct = q['correctIndex'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withOpacity(0.12),
        border: Border.all(color: Colors.white.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Q$index. ${q['question']}",
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          for (int i = 0; i < options.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                "${i + 1}. ${options[i]}",
                style: TextStyle(
                  color: i == correct
                      ? Colors.greenAccent
                      : Colors.white70,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
