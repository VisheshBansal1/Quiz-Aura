import 'package:QuizSphere/quizes/admin/services/Admin_quiz_service.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

  String? selectedTopicId;
  String? selectedTopicTitle;

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

  // ================= TOPIC =================

  Future<void> _createOrSelectTopic() async {
    final name = topicCtrl.text.trim();
    if (name.isEmpty) {
      _error("Topic name required");
      return;
    }

    final normalized = name.toLowerCase();

    try {
      final existing = await FirebaseFirestore.instance
          .collection('topics')
          .where('normalizedTitle', isEqualTo: normalized)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        final doc = existing.docs.first;
        setState(() {
          selectedTopicId = doc.id;
          selectedTopicTitle = doc['title'];
          showCreateTopic = false;
          topicCtrl.clear();
        });
        return;
      }

      final doc = await FirebaseFirestore.instance.collection('topics').add({
        'title': name,
        'normalizedTitle': normalized,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        selectedTopicId = doc.id;
        selectedTopicTitle = name;
        showCreateTopic = false;
        topicCtrl.clear();
      });
    } catch (_) {
      _error("Failed to create topic");
    }
  }

  // ================= QUIZ =================

  Future<void> _createQuiz() async {
    if (loading || quizId != null) return;

    if (!_formKey.currentState!.validate()) {
      _error("Fix form errors");
      return;
    }

    if (selectedTopicId == null) {
      _error("Select or create topic");
      return;
    }

    if (startTime == null) {
      final instant = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            backgroundColor: const Color(0xFF203A43),
            title: const Text(
              "Start Instantly?",
              style: TextStyle(color: Colors.white),
            ),
            content: const Text(
              "You did not select start time.\nDo you want to start the quiz instantly?",
              style: TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text(
                  "No",
                  style: TextStyle(color: Colors.redAccent),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text("Yes"),
              ),
            ],
          );
        },
      );

      if (instant != true) return;

      startTime = DateTime.now().add(const Duration(seconds: 60));
    }

    final now = DateTime.now();
    if (startTime!.isBefore(now.add(const Duration(seconds: 30)))) {
      _error("Start time must be in future");
      return;
    }

    setState(() => loading = true);

    try {
      final endTime = startTime!.add(Duration(minutes: durationMinutes));

      final result = await service.createQuiz(
        title: titleCtrl.text.trim(),
        topicId: selectedTopicId!,
        topicTitle: selectedTopicTitle!,
        isPrivate: isPrivate,
        startAt: startTime!,
        endAt: endTime,
        durationMinutes: durationMinutes,
      );

      quizId = result['quizId'];
      joinCode = result['joinCode'];
      setState(() {});
    } catch (e) {
      _error(e.toString());
    } finally {
      loading = false;
      setState(() {});
    }
  }

  void _error(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
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
            "Create Quiz",
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
        ),
        body: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    _glassInput(
                      controller: titleCtrl,
                      label: "Quiz Title",
                      validator: (v) =>
                          v == null || v.isEmpty ? "Required" : null,
                    ),

                    const SizedBox(height: 16),

                    if (quizId == null)
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('topics')
                            .where('isActive', isEqualTo: true)
                            .orderBy(
                              'createdAt',
                              descending: true,
                            ) // newest topic first
                            .snapshots(),
                        builder: (c, s) {
                          if (!s.hasData) {
                            return const CircularProgressIndicator();
                          }

                          final topics = s.data!.docs;

                          if (topics.isEmpty || showCreateTopic) {
                            return Column(
                              children: [
                                _glassInput(
                                  controller: topicCtrl,
                                  label: "New Topic",
                                ),
                                ElevatedButton(
                                  onPressed: _createOrSelectTopic,
                                  child: const Text("Create Topic"),
                                ),
                              ],
                            );
                          }

                          return Column(
                            children: [
                              DropdownButtonFormField<String>(
                                dropdownColor: const Color(0xFF203A43),
                                value: selectedTopicId,
                                hint: const Text(
                                  "Select Topic",
                                  style: TextStyle(color: Colors.white70),
                                ),
                                items: topics.map((d) {
                                  return DropdownMenuItem(
                                    value: d.id,
                                    child: Text(
                                      d['title'],
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (v) {
                                  final doc = topics.firstWhere(
                                    (d) => d.id == v,
                                  );
                                  setState(() {
                                    selectedTopicId = doc.id;
                                    selectedTopicTitle = doc['title'];
                                  });
                                },
                              ),
                              TextButton(
                                onPressed: () =>
                                    setState(() => showCreateTopic = true),
                                child: const Text("+ Create new topic"),
                              ),
                            ],
                          );
                        },
                      ),

                    const SizedBox(height: 16),

                    ListTile(
                      title: Text(
                        startTime == null
                            ? "Select Start Time"
                            : startTime.toString(),
                        style: const TextStyle(color: Colors.white),
                      ),
                      trailing: const Icon(Icons.schedule, color: Colors.white),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(
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
                      },
                    ),

                    const SizedBox(height: 12),

                    _glassInput(
                      label: "Duration (minutes)",
                      initialValue: "30",
                      keyboardType: TextInputType.number,
                      onChanged: (v) => durationMinutes = int.tryParse(v) ?? 30,
                    ),

                    // SwitchListTile(
                    //   title: const Text(
                    //     "Private Quiz",
                    //     style: TextStyle(color: Colors.white),
                    //   ),
                    //   value: isPrivate,
                    //   onChanged: (v) => setState(() => isPrivate = v),
                    // ),
                    const SizedBox(height: 16),

                    ElevatedButton(
                      onPressed: quizId == null ? _createQuiz : null,
                      child: const Text("Create Quiz"),
                    ),

                    if (quizId != null) ...[
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  AddQuestionScreen(quizId: quizId!),
                            ),
                          );
                        },
                        child: const Text("Add Questions"),
                      ),
                      SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  AiGenerateQuestionsScreen(quizId: quizId!),
                                  
                            ),
                          );
                        },
                        child: const Text("Generate with AI"),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (loading)
              Container(
                color: Colors.black45,
                child: const Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }
}

// ================= HELPERS =================

Widget _glassInput({
  TextEditingController? controller,
  String? initialValue,
  required String label,
  TextInputType? keyboardType,
  FormFieldValidator<String>? validator,
  ValueChanged<String>? onChanged,
}) {
  return TextFormField(
    controller: controller,
    initialValue: initialValue,
    keyboardType: keyboardType,
    validator: validator,
    onChanged: onChanged,
    style: const TextStyle(color: Colors.white),
    decoration: InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      filled: true,
      fillColor: Colors.white.withOpacity(0.15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
    ),
  );
}
