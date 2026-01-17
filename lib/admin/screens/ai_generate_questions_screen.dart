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

  /// 🔹 Fetch quiz topic
  Future<void> _loadQuizTopic() async {
    final snap = await FirebaseFirestore.instance
        .collection('quizzes')
        .doc(widget.quizId)
        .get();

    print("QUIZ DOC EXISTS => ${snap.exists}");
    print("QUIZ DOC DATA => ${snap.data()}");

    if (!mounted) return;

    setState(() {
      final data = snap.data();
      final t = data?['topic'];

      // ✅ Safe assignment
      topic = (t is String && t.trim().isNotEmpty) ? t : null;
    });
  }

  /// 🤖 Generate questions
  Future<void> generate() async {
    if (loading) return;

    if (topic == null) {
      _error("Quiz topic not found. Check Firestore field name.");
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

      print("AI QUESTIONS COUNT => ${result.length}");
      print(result);

      if (!mounted) return;

      if (result.isEmpty) {
        _error("AI returned no questions");
      } else {
        setState(() => questions = result);
      }
    } catch (e, s) {
      print("AI ERROR => $e");
      print(s);
      _error(e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  /// 💾 Save questions
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("AI Question Generator")),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  topic == null
                      ? "Loading quiz topic..."
                      : "Topic: $topic",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),

                const SizedBox(height: 16),

                DropdownButtonFormField<String>(
                  value: difficulty,
                  items: const [
                    DropdownMenuItem(value: "Easy", child: Text("Easy")),
                    DropdownMenuItem(value: "Medium", child: Text("Medium")),
                    DropdownMenuItem(value: "Hard", child: Text("Hard")),
                  ],
                  onChanged:
                      loading ? null : (v) => setState(() => difficulty = v!),
                  decoration: const InputDecoration(
                    labelText: "Difficulty",
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 16),

                ElevatedButton.icon(
                  onPressed: loading ? null : generate, // ✅ ALWAYS clickable
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text("Generate Questions"),
                ),

                const SizedBox(height: 20),

                Expanded(
                  child: questions.isEmpty
                      ? const Center(
                          child: Text("No AI questions generated yet"),
                        )
                      : ListView.builder(
                          itemCount: questions.length,
                          itemBuilder: (_, i) {
                            final q = questions[i];
                            return Card(
                              child: ListTile(
                                title: Text(q['question']),
                                subtitle: Text(
                                  "Correct: ${q['options'][q['correctIndex']]}",
                                ),
                              ),
                            );
                          },
                        ),
                ),

                if (questions.isNotEmpty)
                  ElevatedButton(
                    onPressed: saving ? null : saveAll,
                    child: const Text("Save All to Quiz"),
                  ),
              ],
            ),
          ),

          if (loading || saving)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
