import 'dart:async';
import 'dart:convert';
import 'package:QuizSphere/quizes/home/quiz_result_screen.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'backend_service.dart';
import 'language_constants.dart';

// ================= GROQ SERVICE =================
class GroqService {
  // FIX: API key loaded from .env (never hardcode secrets in source)
  static String get _apiKey => dotenv.env['GROQ_API_KEY_COMPILER'] ?? '';
  static const _url = 'https://api.groq.com/openai/v1/chat/completions';

  static Future<bool> validateCode({
    required String problem,
    required String expected,
    required String code,
    required String language,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_url),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'llama-3.1-8b-instant',
          'temperature': 0,
          'messages': [
            {
              'role': 'user',
              'content': '''
You are a strict programming judge.

Problem:
$problem

Expected Output:
$expected

User Code ($language):
$code

Respond ONLY in JSON:
{
  "is_correct": true | false
}
'''
            }
          ]
        }),
      );

      if (response.statusCode != 200) return false;

      final data = jsonDecode(response.body);
      final content = data['choices'][0]['message']['content'];

      final clean = content
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();

      final result = jsonDecode(clean);
      return result['is_correct'] == true;
    } catch (_) {
      return false;
    }
  }
}

// ================= SCREEN =================
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
  late Language selectedLang;

  bool running = false;
  bool submitting = false;
  String output = "";

  Timer? _timer;
  late int remainingSeconds;

  @override
  void initState() {
    super.initState();
    selectedLang = supportedLanguages.first;

    remainingSeconds = widget.endAt
        .difference(DateTime.now())
        .inSeconds
        .clamp(0, 1 << 31);

    if (remainingSeconds > 0) {
      _startTimer();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _submitCoding(auto: true);
      });
    }
  }

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
  Future<Map<String, String>?> runCode({
    bool silent = false,
    String stdin = "",
  }) async {
    if (running) return null;

    if (codeCtrl.text.trim().isEmpty) {
      if (!silent) {
        setState(() => output = "⚠️ Write some code first");
      }
      return null;
    }

    setState(() {
      running = true;
      if (!silent) output = "Running...\n";
    });

    try {
      final result = await BackendService.runCode(
        quizId: widget.quizId,
        questionId: widget.questionId,
        code: codeCtrl.text,
        language: selectedLang.pistonKey,
        version: selectedLang.version,
        stdin: stdin,
      );

      final stdout = (result['stdout'] ?? '').toString();
      final stderr = (result['stderr'] ?? '').toString();
      final compile = (result['compile_output'] ?? '').toString();

      if (!silent) {
        setState(() {
          if (compile.isNotEmpty) {
            output = "❌ Compile Error:\n$compile";
          } else if (stderr.isNotEmpty && stdout.isEmpty) {
            output = "⚠️ Runtime Error:\n$stderr";
          } else if (stdout.isNotEmpty) {
            output = stdout;
          } else {
            output = "⚠️ Program produced no output";
          }
        });
      }

      return {
        'stdout': stdout,
        'stderr': stderr,
        'compileError': compile,
      };
    } finally {
      if (mounted) setState(() => running = false);
    }
  }

  // ================= SUBMIT =================
  Future<void> _submitCoding({bool auto = false}) async {
  if (submitting) return;

  setState(() => submitting = true);
  _timer?.cancel();

  try {
    final user = FirebaseAuth.instance.currentUser!;
    
    // 🔥 GET QUIZ META (title + pass rule)
    final quizSnap = await FirebaseFirestore.instance
        .collection('quizzes')
        .doc(widget.quizId)
        .get();

    final quizData = quizSnap.data() ?? {};
    final String quizTitle = quizData['title'] ?? "Quiz";
    final double passPercentage =
        (quizData['passPercentage'] ?? 60).toDouble();

    // 🔥 GET QUESTION
    final qSnap = await FirebaseFirestore.instance
        .collection('quizzes')
        .doc(widget.quizId)
        .collection('questions')
        .doc(widget.questionId)
        .get();

    final q = qSnap.data()!;
    final input = (q['input'] ?? '').toString();
    final expected = (q['expectedOutput'] ?? '').toString();
    final problem =
        (q['description'] ?? q['problem'] ?? '').toString();
    final maxScore = (q['score'] ?? 1) as int;

    final result = await runCode(silent: true, stdin: input);

    final stdout = result?['stdout'] ?? '';
    final compileError = result?['compileError'] ?? '';

    bool passed = false;

    if (compileError.isNotEmpty) {
      passed = false;
    } else if (outputsMatch(stdout, expected)) {
      passed = true;
    } else {
      passed = await GroqService.validateCode(
        problem: problem,
        expected: expected,
        code: codeCtrl.text,
        language: selectedLang.name,
      );
    }

    final score = passed ? maxScore : 0;
    final int total = maxScore;
    final double percentage =
        total == 0 ? 0.0 : (score / total) * 100;

    // 🔥 USE DYNAMIC PASS RULE
    final bool finalPassed = percentage >= passPercentage;

    final timeTaken =
        widget.endAt.difference(DateTime.now()).inSeconds.abs();

    final attempt = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('attempts')
        .add({
      'quizId': widget.quizId,
      'quizTitle': quizTitle,
      'questionId': widget.questionId,
      'type': 'coding',
      'language': selectedLang.name,
      'code': codeCtrl.text,
      'passed': finalPassed,
      'score': score,
      'total': total,
      'percentage': percentage,
      'passPercentage': passPercentage,
      'stdout': stdout,
      'submittedAt': FieldValue.serverTimestamp(),
      'autoSubmitted': auto,
      'section': 'coding',
      'timeTakenSeconds': timeTaken,
    });

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => QuizResultScreen(
          quizId: widget.quizId,
          attemptId: attempt.id,
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
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }
}


  // ================= HELPERS =================
  bool outputsMatch(String actual, String expected) {
    String norm(String s) =>
        s.replaceAll(RegExp(r'\s+'), ' ').trim().toLowerCase();
    return norm(actual) == norm(expected);
  }

  @override
  void dispose() {
    _timer?.cancel();
    codeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Coding Section"),
        actions: [
          Text(
            "${remainingSeconds ~/ 60}:${(remainingSeconds % 60).toString().padLeft(2, '0')}",
            style: const TextStyle(color: Colors.red),
          ),
          TextButton(
            onPressed: submitting ? null : _submitCoding,
            child: const Text("SUBMIT"),
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: TextField(
                controller: codeCtrl,
                maxLines: null,
                expands: true,
                style: const TextStyle(fontFamily: 'monospace'),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: "Write your code here...",
                ),
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: running ? null : () => runCode(),
              child: const Text("RUN"),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: SingleChildScrollView(child: Text(output)),
            ),
          ],
        ),
      ),
    );
  }
}
