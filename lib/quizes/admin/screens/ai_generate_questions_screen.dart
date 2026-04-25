import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/groq_ai_service.dart';
import '../services/admin_quiz_service.dart';

class AiGenerateQuestionsScreen extends StatefulWidget {
  final String quizId;
  const AiGenerateQuestionsScreen({super.key, required this.quizId});

  @override
  State<AiGenerateQuestionsScreen> createState() =>
      _AiGenerateQuestionsScreenState();
}

class _AiGenerateQuestionsScreenState extends State<AiGenerateQuestionsScreen> {
  late GroqAIService groqAIService;
  late AdminQuizService quizService;

  bool loading = false;
  bool saving = false;

  String difficulty = "Medium";
  String? topicTitle;
  int questionCount = 5;
  static const int maxQuestionsAllowed = 15;

  List<Map<String, dynamic>> questions = [];

  // ── Input decoration shared across all fields ──────────────────────────
  static const _inputDecoration = InputDecoration(
    labelStyle: TextStyle(color: Colors.white70),
    enabledBorder: UnderlineInputBorder(
      borderSide: BorderSide(color: Colors.white38),
    ),
    focusedBorder: UnderlineInputBorder(
      borderSide: BorderSide(color: Colors.tealAccent),
    ),
  );

  String? _initError; // FIX: capture constructor errors (e.g. missing .env key)

  @override
  void initState() {
    super.initState();
    // FIX: GroqAIService constructor used to throw when the API key was absent
    // (common on Flutter web where dotenv loading may fail). Catch it here so
    // the screen still renders and shows the user an actionable error message.
    try {
      groqAIService = GroqAIService();
    } catch (e) {
      _initError = e.toString().replaceFirst('Exception: ', '');
    }
    quizService = AdminQuizService();
    _loadQuizTopic();
  }

  // ================= LOAD QUIZ TOPIC =================
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

  // ================= GENERATE QUESTIONS =================
  Future<void> generate() async {
    // FIX: guard against uninitialised service (missing API key / .env error)
    if (_initError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_initError!), backgroundColor: Colors.redAccent),
      );
      return;
    }
    if (loading || topicTitle == null) return;

    if (questionCount > maxQuestionsAllowed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You can generate maximum 15 questions at a time.'),
        ),
      );
      return;
    }

    setState(() {
      loading = true;
      questions.clear();
    });

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
      // FIX: surface AI/network errors to the user instead of silently failing
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

  // ================= REGENERATE SINGLE =================
  Future<void> regenerateOne(int index) async {
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

  // ================= SAVE ALL =================
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

      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint('SAVE ERROR: $e');
      rethrow;
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ✅ FIX 1: Set the scaffold color directly — no outer Container wrapper.
      // Wrapping Scaffold in a Container + backgroundColor: transparent is
      // unreliable on Android; the theme's white scaffold background bleeds through.
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
          // ✅ FIX 2: Use Positioned.fill so the gradient Container is explicitly
          // constrained to fill the Stack. An unsized Container inside a Stack
          // collapses to 0×0 — that's why the background was invisible before.
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

          // ── Loading / saving overlay ──────────────────────────────────
          if (loading || saving)
            Positioned.fill(
              child: Container(
                color: Colors.black54,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: Colors.tealAccent),
                      const SizedBox(height: 16),
                      Text(
                        loading ? 'Generating questions…' : 'Saving…',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ================= CONTROLS =================
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
              onPressed: generate,
              icon: const Icon(Icons.auto_awesome),
              label: const Text(
                "Generate",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ================= EDITABLE QUESTION =================
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

  // ================= UI HELPERS =================
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
