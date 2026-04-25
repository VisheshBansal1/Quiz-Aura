import 'package:QuizSphere/login/login_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AdminDailyQuizManagerScreen extends StatefulWidget {
  const AdminDailyQuizManagerScreen({super.key});

  @override
  State<AdminDailyQuizManagerScreen> createState() =>
      _AdminDailyQuizManagerScreenState();
}

class _AdminDailyQuizManagerScreenState
    extends State<AdminDailyQuizManagerScreen> {
  final _formKey = GlobalKey<FormState>();

  final titleController = TextEditingController();
  final descriptionController = TextEditingController();
  final timeController = TextEditingController(text: "600");
  final xpController = TextEditingController(text: "150");

  DateTime selectedDate = DateTime.now().toUtc();

  List<QuestionModel> questions = [];

  String getQuizDocId() {
    return "${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}";
  }

  DateTime getMidnightExpiry() {
    return DateTime.utc(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      23,
      59,
      59,
    );
  }

  // ================== QUESTION DIALOG ==================

  Future<void> _openQuestionDialog({int? editIndex}) async {
    final questionController = TextEditingController(
      text: editIndex != null ? questions[editIndex].question : "",
    );

    final optionControllers = List.generate(
      4,
      (i) => TextEditingController(
        text: editIndex != null ? questions[editIndex].options[i] : "",
      ),
    );

    int correctIndex = editIndex != null
        ? questions[editIndex].correctIndex
        : 0;

    await showDialog(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, dialogSetState) {
            return AlertDialog(
              title: Text(editIndex == null ? "Add Question" : "Edit Question"),
              content: SingleChildScrollView(
                child: Column(
                  children: [
                    TextFormField(
                      controller: questionController,
                      maxLines: 4,
                      decoration: const InputDecoration(labelText: "Question"),
                    ),
                    const SizedBox(height: 12),

                    ...List.generate(
                      4,
                      (i) => Row(
                        children: [
                          Radio<int>(
                            value: i,
                            groupValue: correctIndex,
                            onChanged: (val) {
                              dialogSetState(() {
                                correctIndex = val!;
                              });
                            },
                          ),
                          Expanded(
                            child: TextFormField(
                              controller: optionControllers[i],
                              maxLines: 2,
                              decoration: InputDecoration(
                                labelText: "Option ${i + 1}",
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (questionController.text.isEmpty ||
                        optionControllers.any((e) => e.text.isEmpty)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("All fields required")),
                      );
                      return;
                    }

                    final newQuestion = QuestionModel(
                      question: questionController.text,
                      options: optionControllers.map((e) => e.text).toList(),
                      correctIndex: correctIndex,
                    );

                    setState(() {
                      if (editIndex == null) {
                        questions.add(newQuestion);
                      } else {
                        questions[editIndex] = newQuestion;
                      }
                    });

                    Navigator.pop(context);
                  },
                  child: const Text("Save"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _deleteQuestion(int index) {
    setState(() {
      questions.removeAt(index);
    });
  }

  // ================== SAVE ==================

  Future<void> _publishQuiz() async {
    if (!_formKey.currentState!.validate()) return;

    if (questions.length < 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Minimum 5 questions required")),
      );
      return;
    }

    final docId = getQuizDocId();

    await FirebaseFirestore.instance.collection("dailyQuizzes").doc(docId).set({
      "title": titleController.text,
      "description": descriptionController.text,
      "timeLimitSeconds": int.parse(timeController.text),
      "xpReward": int.parse(xpController.text),
      "totalQuestions": questions.length,
      "publishAt": Timestamp.fromDate(selectedDate),
      "expiresAt": Timestamp.fromDate(getMidnightExpiry()),
      "isPublished": true,
      "createdAt": FieldValue.serverTimestamp(),
    });

    for (var q in questions) {
      await FirebaseFirestore.instance
          .collection("dailyQuizzes")
          .doc(docId)
          .collection("questions")
          .add({
            "question": q.question,
            "options": q.options,
            "correctIndex": q.correctIndex,
          });
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Daily Quiz Published")));

    Navigator.pop(context);
  }

  // ================== UI ==================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();

              if (!mounted) return;

              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
          ),
        ],
        title: const Text("Daily Quiz Manager"),
        backgroundColor: Colors.transparent,
      ),
      body: Form(
        key: _formKey,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            children: [
              _input(titleController, "Title"),
              _input(descriptionController, "Description", maxLines: 3),
              _input(timeController, "Time Limit (seconds)", number: true),
              _input(xpController, "XP Reward", number: true),

              const SizedBox(height: 20),

              ElevatedButton(
                onPressed: () => _openQuestionDialog(),
                child: const Text("Add Question"),
              ),

              const SizedBox(height: 12),

              Text(
                "Total Questions: ${questions.length}",
                style: const TextStyle(color: Colors.white),
              ),

              const SizedBox(height: 12),

              ...List.generate(
                questions.length,
                (index) => Card(
                  child: ListTile(
                    title: Text(questions[index].question),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () =>
                              _openQuestionDialog(editIndex: index),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => _deleteQuestion(index),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 30),

              ElevatedButton(
                onPressed: _publishQuiz,
                child: const Text("Publish Daily Quiz"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _input(
    TextEditingController controller,
    String label, {
    bool number = false,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: number ? TextInputType.number : TextInputType.text,
        maxLines: maxLines,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white70),
          enabledBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: Colors.white30),
          ),
          focusedBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: Colors.white),
          ),
        ),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return "Required";
          }
          return null;
        },
      ),
    );
  }
}

class QuestionModel {
  final String question;
  final List<String> options;
  final int correctIndex;

  QuestionModel({
    required this.question,
    required this.options,
    required this.correctIndex,
  });
}
