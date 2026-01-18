import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quiz_app/admin/services/admin_quiz_service.dart';

import 'add_question_screen.dart';
import 'ai_generate_questions_screen.dart';

class CreateQuizScreen extends StatefulWidget {
  const CreateQuizScreen({super.key});

  @override
  State<CreateQuizScreen> createState() => _CreateQuizScreenState();
}

class _CreateQuizScreenState extends State<CreateQuizScreen> {
  final _formKey = GlobalKey<FormState>();

  final titleCtrl = TextEditingController();
  final topicCtrl = TextEditingController();

  final AdminQuizService service = AdminQuizService();

  String? selectedTopic;
  bool isPrivate = false;
  bool showCreateTopic = false;

  DateTime? startTime;
  int durationMinutes = 30;

  String? quizId;
  String? joinCode;

  bool loading = false;

  @override
  void dispose() {
    titleCtrl.dispose();
    topicCtrl.dispose();
    super.dispose();
  }

  // ---------------- CREATE / USE TOPIC ----------------
  Future<void> _createTopic() async {
    final name = topicCtrl.text.trim();

    if (name.isEmpty) {
      _error("Topic name required");
      return;
    }

    final normalized = name.toLowerCase();

    try {
      // 🔍 1. Check if topic already exists
      final existing = await FirebaseFirestore.instance
          .collection('topics')
          .where('normalizedTitle', isEqualTo: normalized)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        // ✅ Topic exists → USE it
        setState(() {
          selectedTopic = existing.docs.first['title'];
          showCreateTopic = false;
          topicCtrl.clear();
        });
        return;
      }

      // 🆕 2. Create new topic
      await FirebaseFirestore.instance.collection('topics').add({
        'title': name,
        'normalizedTitle': normalized, // 🔑 critical
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        selectedTopic = name;
        showCreateTopic = false;
        topicCtrl.clear();
      });
    } catch (e) {
      _error("Failed to create or fetch topic");
    }
  }

  Future<void> _createQuiz() async {
    if (loading || quizId != null) return;

    final form = _formKey.currentState;
    if (form == null) {
      _error("Form not initialized");
      return;
    }

    if (!form.validate()) {
      _error("Please fix form errors");
      return;
    }

    final topic = selectedTopic?.trim();
    if (topic == null || topic.isEmpty) {
      _error("Please select or create a topic");
      return;
    }

    if (startTime == null) {
      _error("Please select quiz start time");
      return;
    }

    final now = DateTime.now();
    if (startTime!.isBefore(now.add(const Duration(seconds: 30)))) {
      _error("Quiz start time must be in the future");
      return;
    }

    if (durationMinutes <= 0) {
      _error("Quiz duration must be greater than 0");
      return;
    }

    setState(() => loading = true);

    try {
      final endTime = startTime!.add(Duration(minutes: durationMinutes));

      debugPrint("Creating quiz:");
      debugPrint("Title: ${titleCtrl.text}");
      debugPrint("Topic: $topic");
      debugPrint("Start: $startTime");
      debugPrint("End: $endTime");

      final result = await service.createQuiz(
        title: titleCtrl.text.trim(),
        topic: selectedTopic!.trim(),
        isPrivate: isPrivate,
        startAt: startTime!,
        endAt: endTime,
        durationMinutes: durationMinutes,
      );

      // ✅ VALIDATION THAT MAKES SENSE
      if (result['quizId'] == null) {
        throw Exception("Quiz creation failed.");
      }

      if (isPrivate && result['joinCode'] == null) {
        throw Exception("Join code missing for private quiz.");
      }

      setState(() {
        quizId = result['quizId'] as String;
        joinCode = result['joinCode']; // can be null for public
      });
    } catch (e, st) {
      debugPrint("CREATE QUIZ FAILED");
      debugPrint(e.toString());
      debugPrintStack(stackTrace: st);

      _error(e.toString().replaceFirst("Exception: ", "").trim());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _error(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Create Quiz")),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ---------------- QUIZ INFO ----------------
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          // TITLE
                          TextFormField(
                            controller: titleCtrl,
                            enabled: quizId == null,
                            decoration: const InputDecoration(
                              labelText: "Quiz Title",
                            ),
                            validator: (v) => v == null || v.trim().isEmpty
                                ? "Title required"
                                : null,
                          ),

                          const SizedBox(height: 16),

                          // ---------------- TOPIC ----------------
                          if (quizId == null)
                            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                              stream: FirebaseFirestore.instance
                                  .collection('topics')
                                  .where('isActive', isEqualTo: true)
                                  .snapshots(),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData) {
                                  return const CircularProgressIndicator();
                                }

                                final docs = snapshot.data!.docs;
                                final topics = docs
                                    .map((d) => d.data()['title'] as String)
                                    .toList();

                                if (topics.isEmpty || showCreateTopic) {
                                  return Column(
                                    children: [
                                      TextFormField(
                                        controller: topicCtrl,
                                        decoration: const InputDecoration(
                                          labelText: "New Topic",
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      ElevatedButton(
                                        onPressed: _createTopic,
                                        child: const Text("Create Topic"),
                                      ),
                                    ],
                                  );
                                }

                                return Column(
                                  children: [
                                    DropdownButtonFormField<String>(
                                      value: topics.contains(selectedTopic)
                                          ? selectedTopic
                                          : null,
                                      hint: const Text("Select Topic"),
                                      items: topics
                                          .map(
                                            (t) => DropdownMenuItem(
                                              value: t,
                                              child: Text(t),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (v) =>
                                          setState(() => selectedTopic = v),
                                      validator: (v) =>
                                          v == null ? "Select a topic" : null,
                                    ),
                                    TextButton(
                                      onPressed: () => setState(
                                        () => showCreateTopic = true,
                                      ),
                                      child: const Text("+ Create new topic"),
                                    ),
                                  ],
                                );
                              },
                            ),

                          const SizedBox(height: 16),

                          // ---------------- START TIME ----------------
                          ListTile(
                            title: Text(
                              startTime == null
                                  ? "Select Quiz Start Time"
                                  : "Starts at: ${startTime!.toLocal()}",
                            ),
                            trailing: const Icon(Icons.schedule),
                            onTap: quizId == null
                                ? () async {
                                    final now = DateTime.now();

                                    final date = await showDatePicker(
                                      context: context,
                                      initialDate: now,
                                      firstDate: now,
                                      lastDate: now.add(
                                        const Duration(days: 30),
                                      ),
                                    );
                                    if (date == null) return;

                                    final time = await showTimePicker(
                                      context: context,
                                      initialTime: TimeOfDay.now(),
                                    );
                                    if (time == null) return;

                                    setState(() {
                                      startTime = DateTime(
                                        date.year,
                                        date.month,
                                        date.day,
                                        time.hour,
                                        time.minute,
                                      );
                                    });
                                  }
                                : null,
                          ),

                          const SizedBox(height: 12),

                          // ---------------- DURATION ----------------
                          TextFormField(
                            initialValue: "30",
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: "Duration (minutes)",
                            ),
                            validator: (v) {
                              final m = int.tryParse(v ?? "");
                              if (m == null || m < 1) {
                                return "Invalid duration";
                              }
                              return null;
                            },
                            onChanged: (v) {
                              durationMinutes = int.tryParse(v) ?? 30;
                            },
                          ),

                          const SizedBox(height: 12),

                          // ---------------- PRIVATE ----------------
                          SwitchListTile(
                            title: const Text("Private Quiz"),
                            subtitle: const Text("Requires join code"),
                            value: isPrivate,
                            onChanged: quizId == null
                                ? (v) => setState(() => isPrivate = v)
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ---------------- CREATE ----------------
                  ElevatedButton(
                    onPressed: quizId == null ? _createQuiz : null,
                    child: const Text("Create Quiz"),
                  ),

                  // ---------------- AFTER CREATE ----------------
                  if (quizId != null) ...[
                    const SizedBox(height: 32),

                    if (joinCode != null)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              const Text(
                                "JOIN CODE",
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              SelectableText(
                                joinCode!,
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    const SizedBox(height: 16),

                    ElevatedButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text("Add Questions"),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AddQuestionScreen(quizId: quizId!),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 12),

                    OutlinedButton.icon(
                      icon: const Icon(Icons.auto_awesome),
                      label: const Text("Generate with AI"),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                AiGenerateQuestionsScreen(quizId: quizId!),
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),

          if (loading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
