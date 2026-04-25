import 'dart:async';
import 'package:QuizSphere/quizes/home/quiz_result_screen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Ensure these imports exist in your project structure
import 'backend_service.dart';
import 'language_constants.dart';

class CodingQuizScreen extends StatefulWidget {
  final String quizId;
  final String questionId;
  final DateTime endAt;

  const CodingQuizScreen({
    super.key,
    required this.quizId,
    required this.questionId,
    required this.endAt,
  });

  @override
  State<CodingQuizScreen> createState() => _CodingQuizScreenState();
}

class _CodingQuizScreenState extends State<CodingQuizScreen> {
  final TextEditingController codeCtrl = TextEditingController();

  // Assuming 'supportedLanguages' is a global List<Language> from language_constants.dart
  late Language selectedLang;
  
  bool running = false;
  bool submitting = false;
  String output = "";

  Timer? _timer;
  late int remainingSeconds;

  @override
  void initState() {
    super.initState();

    // Initialize with the first supported language (Safety check included)
    selectedLang = supportedLanguages.isNotEmpty 
        ? supportedLanguages.first 
        : throw Exception("No supported languages defined");

    // Calculate remaining time
    remainingSeconds = widget.endAt
        .difference(DateTime.now())
        .inSeconds
        .clamp(0, 1 << 31); // Clamps to prevent negative overflow

    if (remainingSeconds > 0) {
      _startTimer();
    } else {
      // If time is already up, submit immediately after the first frame
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _submitCoding(auto: true);
      });
    }
  }

  // ================= TIMER =================
  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || submitting) {
        timer.cancel();
        return;
      }

      setState(() {
        if (remainingSeconds <= 0) {
          timer.cancel();
          _submitCoding(auto: true);
        } else {
          remainingSeconds--;
        }
      });
    });
  }

  // ================= RUN CODE =================
  Future<Map<String, dynamic>?> runCode({bool silent = false}) async {
    if (running) return null;

    if (codeCtrl.text.trim().isEmpty) {
      if (!silent) {
        setState(() => output = "⚠️ Please write some code first.");
      }
      return null;
    }

    setState(() {
      running = true;
      if (!silent) output = "Running...\n";
    });

    try {
      // Execute code via your backend service
      final result = await BackendService.runCode(
        quizId: widget.quizId,
        questionId: widget.questionId,
        code: codeCtrl.text,
        language: selectedLang.pistonKey, // Ensure Language model has this getter
        version: selectedLang.version,    // Ensure Language model has this getter
      );

      if (!mounted) return null; // Safety check if user left screen

      final stdout = (result['stdout'] ?? "").toString();
      final stderr = (result['stderr'] ?? "").toString();
      final compileError = (result['compile_output'] ?? "").toString();

      if (!silent) {
        setState(() {
          if (compileError.isNotEmpty) {
            output = "❌ Compile Error:\n$compileError";
          } else if (stderr.isNotEmpty) {
            output = "⚠️ Runtime Error:\n$stderr";
          } else {
            output = stdout.isEmpty ? "(no output)" : stdout;
          }
        });
      }

      return {'stdout': stdout, 'compileError': compileError};
    } catch (e) {
      if (mounted && !silent) {
        setState(() => output = "❌ Error: $e");
      }
      return null;
    } finally {
      if (mounted) {
        setState(() => running = false);
      }
    }
  }

  // ================= SUBMIT =================
  Future<void> _submitCoding({bool auto = false}) async {
  if (submitting) return;

  if (!auto) {
    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text("Submit Coding Test"),
        content: const Text(
          "Once submitted, you cannot modify your solution.\n\nSubmit now?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Submit"),
          ),
        ],
      ),
    );

    if (confirm != true) return;
  }

  setState(() => submitting = true);
  _timer?.cancel();

  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("User not logged in");

    // 🔥 GET QUIZ META
    final quizSnap = await FirebaseFirestore.instance
        .collection('quizzes')
        .doc(widget.quizId)
        .get();

    final quizData = quizSnap.data() ?? {};
    final String quizTitle = quizData['title'] ?? "Quiz";
    final double passPercentage =
        (quizData['passPercentage'] ?? 60).toDouble();

    // 🔥 GET QUESTION
    final questionSnap = await FirebaseFirestore.instance
        .collection('quizzes')
        .doc(widget.quizId)
        .collection('questions')
        .doc(widget.questionId)
        .get();

    if (!questionSnap.exists) {
      throw Exception("Question not found");
    }

    final data = questionSnap.data()!;
    final String expectedOutput =
        (data['expectedOutput'] ?? "").toString();
    final int maxScore =
        (data['score'] is int) ? data['score'] : 1;

    // 🔥 RUN CODE
    final result = await runCode(silent: true);

    final String actualOutput = result?['stdout'] ?? "";
    final String compileError = result?['compileError'] ?? "";

    final bool logicPassed =
        compileError.isEmpty &&
        outputsMatch(actualOutput, expectedOutput);

    final int score = logicPassed ? maxScore : 0;
    final int total = maxScore;

    final double percentage =
        total == 0 ? 0.0 : (score / total) * 100;

    // 🔥 FINAL PASS RULE (DYNAMIC)
    final bool finalPassed =
        percentage >= passPercentage;

    final int timeTakenSeconds =
        widget.endAt.difference(DateTime.now()).inSeconds.abs();

    // 🔥 SAVE ATTEMPT (CONSISTENT STRUCTURE)
    final attemptRef = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('attempts')
        .add({
      'quizId': widget.quizId,
      'quizTitle': quizTitle,
      'questionId': widget.questionId,
      'type': 'coding',
      'section': 'coding',
      'language': selectedLang.name,
      'code': codeCtrl.text,
      'passed': finalPassed,
      'score': score,
      'total': total,
      'percentage': percentage,
      'passPercentage': passPercentage,
      'expectedOutput': expectedOutput,
      'actualOutput': actualOutput,
      'compileError': compileError,
      'timeTakenSeconds': timeTakenSeconds,
      'submittedAt': FieldValue.serverTimestamp(),
      'autoSubmitted': auto,
    });

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => QuizResultScreen(
          quizId: widget.quizId,
          attemptId: attemptRef.id,
          quizTitle: quizTitle,
          score: score,
          total: total,
          percentage: percentage,
          endAt: widget.endAt,
          passed: finalPassed,
          passPercentage: passPercentage,
        ),
      ),
    );
  } catch (e) {
    if (mounted) {
      setState(() => submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Submission Error: $e")),
      );
    }
  }
}


  // ================= OUTPUT COMPARISON =================
  bool outputsMatch(String actual, String expected) {
    List<String> tokenize(String s) {
      return s
          .replaceAll('\r\n', '\n')
          .replaceAll('\r', '\n')
          .trim()
          .split(RegExp(r'\s+')) // split by ANY whitespace sequence
          .where((e) => e.isNotEmpty)
          .toList();
    }

    final a = tokenize(actual);
    final b = tokenize(expected);

    if (a.length != b.length) return false;

    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }

    return true;
  }

  @override
  void dispose() {
    _timer?.cancel();
    codeCtrl.dispose();
    super.dispose();
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    // PopScope replaces the deprecated WillPopScope
    return PopScope(
      canPop: false, // Prevents the user from going back via hardware button/gesture
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        appBar: AppBar(
          title: const Text("Coding Section"),
          backgroundColor: const Color(0xFF020617),
          automaticallyImplyLeading: false, // Hides the back arrow
          actions: [
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: Text(
                  "${remainingSeconds ~/ 60}:${(remainingSeconds % 60).toString().padLeft(2, '0')}",
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            TextButton(
              onPressed: submitting ? null : _submitCoding,
              child: const Text(
                "SUBMIT",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- Language Selector ---
          _sectionTitle("Language"),
          DropdownButtonFormField<Language>(
            value: selectedLang,
            dropdownColor: const Color(0xFF020617),
            isExpanded: true, // Prevents overflow if language name is long
            items: supportedLanguages.map((l) {
                return DropdownMenuItem(
                  value: l,
                  child: Text(
                    l.name,
                    style: const TextStyle(color: Colors.white),
                  ),
                );
              }).toList(),
            onChanged: (v) {
              if (v != null) setState(() => selectedLang = v);
            },
            decoration: _inputDecoration(),
          ),
          const SizedBox(height: 16),

          // --- Code Editor (Takes more space) ---
          _sectionTitle("Source Code"),
          Expanded(
            flex: 3, // Gives Editor 3 portions of available space
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: _editorBox(),
              child: TextField(
                controller: codeCtrl,
                maxLines: null,
                expands: true,
                keyboardType: TextInputType.multiline,
                style: const TextStyle(
                  fontFamily: "monospace",
                  color: Colors.white,
                  fontSize: 14,
                ),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: "// Write your solution here...",
                  hintStyle: TextStyle(color: Colors.white30),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // --- Run Button ---
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: running ? null : runCode,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: running 
                ? const SizedBox(
                    width: 20, height: 20, 
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
                  )
                : const Icon(Icons.play_arrow),
              label: Text(running ? "Processing..." : "Run Code"),
            ),
          ),
          const SizedBox(height: 16),

          // --- Output Console (Takes less space) ---
          _sectionTitle("Output"),
          Expanded(
            flex: 2, // Gives Output 2 portions of available space
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: _outputBox(),
              child: SingleChildScrollView(
                child: SelectableText( // Allows user to copy error messages
                  output.isEmpty ? "Ready to run..." : output,
                  style: const TextStyle(
                    color: Colors.white, 
                    fontFamily: "monospace",
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ================= HELPERS =================
Widget _sectionTitle(String text) => Padding(
  padding: const EdgeInsets.only(bottom: 6),
  child: Text(
    text,
    style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
  ),
);

InputDecoration _inputDecoration() => InputDecoration(
  filled: true,
  fillColor: const Color(0xFF020617),
  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide.none,
  ),
);

BoxDecoration _editorBox() => BoxDecoration(
  color: const Color(0xFF020617),
  borderRadius: BorderRadius.circular(12),
  border: Border.all(color: Colors.white12),
);

BoxDecoration _outputBox() => BoxDecoration(
  color: Colors.black54, // Slightly transparent for a polished look
  borderRadius: BorderRadius.circular(12),
  border: Border.all(color: Colors.white12),
);