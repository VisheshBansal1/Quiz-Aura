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

class _AiGenerateQuestionsScreenState extends State<AiGenerateQuestionsScreen> {
  late GroqAIService groqAIService;
  late AdminQuizService quizService;

  bool loading = false;
  bool saving = false;

  String difficulty = "Medium";
  String? topic;
  int questionCount = 5;

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

    final t = snap.data()?['topic'];
    setState(() {
      topic = (t is String && t.trim().isNotEmpty) ? t : null;
    });
  }

  // ================= GENERATE QUESTIONS =================
  Future<void> generate() async {
    if (loading || topic == null) return;

    setState(() {
      loading = true;
      questions.clear();
    });

    final result = await groqAIService.generateMCQs(
      topic: topic!,
      difficulty: difficulty,
      count: questionCount,
    );

    setState(() {
      questions = result
          .map(
            (q) => {
              ...q,
              'difficulty': difficulty, // ✅ TAGGING
            },
          )
          .toList();
      loading = false;
    });
  }

  // ================= REGENERATE SINGLE =================
  Future<void> regenerateOne(int index) async {
    if (topic == null) return;

    final result = await groqAIService.generateMCQs(
      topic: topic!,
      difficulty: questions[index]['difficulty'],
      count: 1,
    );

    if (result.isNotEmpty) {
      setState(() {
        questions[index] = {
          ...result.first,
          'difficulty': questions[index]['difficulty'],
        };
      });
    }
  }

  // ================= SAVE ALL =================
  Future<void> saveAll() async {
    if (saving) return;
    setState(() => saving = true);

    for (final q in questions) {
      await quizService.addQuestion(
        quizId: widget.quizId,
        question: q['question'],
        options: List<String>.from(q['options']),
        correctIndex: q['correctIndex'],
        difficulty: q['difficulty'], // ✅ STORED
      );
    }

    if (mounted) Navigator.pop(context);
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          "AI Question Generator",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: Icon(Icons.arrow_back, color: Colors.white),
        ),
        elevation: 0,
        flexibleSpace: _bg(),
      ),
      body: Stack(
        children: [
          _bg(),

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
                            "No questions generated",
                            style: TextStyle(color: Colors.white70),
                          ),
                        )
                      : ListView.builder(
                          itemCount: questions.length,
                          itemBuilder: (_, i) => _editableQuestion(i),
                        ),
                ),

                if (questions.isNotEmpty)
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: saving ? null : saveAll,
                      child: const Text("Save All"),
                    ),
                  ),
              ],
            ),
          ),

          if (loading || saving)
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

  // ================= CONTROLS =================
  Widget _controls() {
    return _card(
      child: Column(
        children: [
          Text(
            topic ?? "Loading topic...",
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          DropdownButtonFormField<String>(
            value: difficulty,
            dropdownColor: const Color.fromARGB(255, 140, 137, 145),
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
            decoration: const InputDecoration(
              labelText: "Difficulty",
              fillColor: Color.fromARGB(255, 139, 218, 215),
              labelStyle: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          const SizedBox(height: 12),

          TextFormField(
            style: TextStyle(color: Colors.white),
            initialValue: questionCount.toString(),
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: "Number of Questions",
              fillColor: Color.fromARGB(255, 250, 250, 250),
              labelStyle: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            onChanged: (v) => questionCount = int.tryParse(v) ?? 5,
          ),

          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: generate,
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.zero,
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Ink(
                decoration: BoxDecoration(
                  
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7C3AED), Color(0xFF9333EA)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.auto_awesome, size: 22, color: Colors.white,),
                    SizedBox(width: 8),
                    Text(
                      "Generate",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white
                      ),
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

  // ================= EDITABLE QUESTION =================
  Widget _editableQuestion(int index) {
    final q = questions[index];

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // QUESTION EDIT
          TextFormField(
            initialValue: q['question'],
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(labelText: "Question"),
            onChanged: (v) => q['question'] = v,
          ),

          const SizedBox(height: 8),

          // OPTIONS
          for (int i = 0; i < q['options'].length; i++)
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: q['options'][i],
                    style: const TextStyle(color: Colors.white),
                    onChanged: (v) => q['options'][i] = v,
                  ),
                ),
                Radio<int>(
                  value: i,
                  groupValue: q['correctIndex'],
                  onChanged: (v) => setState(() => q['correctIndex'] = v),
                ),
              ],
            ),

          const SizedBox(height: 8),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Difficulty: ${q['difficulty']}",
                style: const TextStyle(color: Colors.white70),
              ),
              TextButton.icon(
                onPressed: () => regenerateOne(index),
                icon: const Icon(Icons.refresh, color: Colors.white60,),
                label: const Text("Regenerate",style: TextStyle(color: Colors.white60),),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ================= UI HELPERS =================
  Widget _bg() => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
      ),
    ),
  );

  Widget _card({required Widget child}) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(18),
      color: Colors.white.withOpacity(0.12),
      border: Border.all(color: Colors.white.withOpacity(0.25)),
    ),
    child: child,
  );
}
