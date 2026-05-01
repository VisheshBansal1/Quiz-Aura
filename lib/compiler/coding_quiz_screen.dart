import 'dart:async';
import 'package:QuizSphere/quizes/home/quiz_result_screen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'backend_service.dart';
import 'compiler_groq_service.dart';
import 'language_constants.dart';

/// Multi-question coding screen.
///
/// Pass either [questionId] (single) OR [questionIds] (list).
/// If [questionIds] is provided it takes precedence.
class CodingQuizScreen extends StatefulWidget {
  final String quizId;
  final String questionId;          // kept for backward compat (single)
  final List<String> questionIds;   // preferred: list of all coding Q ids
  final DateTime endAt;
  final bool isMixed;               // true when part of a mixed quiz

  const CodingQuizScreen({
    super.key,
    required this.quizId,
    required this.endAt,
    this.questionId  = '',
    this.questionIds = const [],
    this.isMixed = false,
  });

  @override
  State<CodingQuizScreen> createState() => _CodingQuizScreenState();
}

class _CodingQuizScreenState extends State<CodingQuizScreen> {
  // ── Questions ─────────────────────────────────────────────────────────────
  late List<String> _qIds;
  int _qIndex = 0;
  Map<String, dynamic>? _currentQ;  // loaded question data
  bool _loadingQ = true;

  // ── Per-question state ────────────────────────────────────────────────────
  final TextEditingController _codeCtrl = TextEditingController();
  late Language _lang;

  // ── Run/submit state ──────────────────────────────────────────────────────
  bool   _running    = false;
  bool   _submitting = false;
  String _output     = '';

  // ── Timer ─────────────────────────────────────────────────────────────────
  Timer? _timer;
  late int _secs;

  // ── Results accumulator ───────────────────────────────────────────────────
  // qId → {score, maxScore, passed, stdout, compileError}
  final Map<String, Map<String, dynamic>> _results = {};

  // ─────────────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _lang = supportedLanguages.first;

    _qIds = widget.questionIds.isNotEmpty
        ? widget.questionIds
        : (widget.questionId.isNotEmpty ? [widget.questionId] : []);

    _secs = widget.endAt
        .difference(DateTime.now())
        .inSeconds
        .clamp(0, 1 << 31);

    if (_secs > 0) {
      _startTimer();
    } else {
      WidgetsBinding.instance.addPostFrameCallback(
          (_) => _submitAllAndNavigate(auto: true));
    }

    _loadQuestion();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _codeCtrl.dispose();
    super.dispose();
  }

  // ── Load question data ────────────────────────────────────────────────────
  Future<void> _loadQuestion() async {
    if (_qIds.isEmpty) return;
    setState(() { _loadingQ = true; _output = ''; });

    final snap = await FirebaseFirestore.instance
        .collection('quizzes')
        .doc(widget.quizId)
        .collection('questions')
        .doc(_qIds[_qIndex])
        .get();

    if (mounted) {
      setState(() {
        _currentQ = snap.data() ?? {};
        _loadingQ  = false;
      });
    }
  }

  // ── Timer ─────────────────────────────────────────────────────────────────
  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted || _submitting) { t.cancel(); return; }
      setState(() {
        if (_secs <= 0) {
          t.cancel();
          _submitAllAndNavigate(auto: true);
        } else {
          _secs--;
        }
      });
    });
  }

  String get _timerLabel {
    final m = _secs ~/ 60;
    final s = (_secs % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ── Run code ──────────────────────────────────────────────────────────────
  Future<Map<String, String>?> _runCode({
    bool   silent = false,
    String stdin  = '',
  }) async {
    if (_running) return null;
    if (_codeCtrl.text.trim().isEmpty) {
      if (!silent) setState(() => _output = '⚠️ Write some code first.');
      return null;
    }

    setState(() {
      _running = true;
      if (!silent) _output = '⏳ Running…';
    });

    try {
      final result = await BackendService.runCode(
        quizId:     widget.quizId,
        questionId: _qIds[_qIndex],
        code:       _codeCtrl.text,
        language:   _lang.pistonKey,
        version:    _lang.version,
        stdin:      stdin,
      );

      final stdout       = result['stdout']?.toString()         ?? '';
      final stderr       = result['stderr']?.toString()         ?? '';
      final compileError = result['compile_output']?.toString() ?? '';

      if (!silent) {
        setState(() {
          if (compileError.isNotEmpty) {
            _output = '❌ Compile Error:\n$compileError';
          } else if (stderr.isNotEmpty && stdout.isEmpty) {
            _output = '⚠️ Runtime Error:\n$stderr';
          } else if (stdout.isEmpty) {
            _output = '(no output)';
          } else {
            _output = stdout;
          }
        });
      }

      return {
        'stdout':       stdout,
        'stderr':       stderr,
        'compileError': compileError,
      };
    } catch (e) {
      if (!silent && mounted) setState(() => _output = '❌ $e');
      return null;
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  // ── Grade current question ────────────────────────────────────────────────
  Future<void> _gradeCurrentQuestion() async {
    final qId  = _qIds[_qIndex];
    final q    = _currentQ ?? {};
    final stdin    = (q['input']          ?? '').toString();
    final expected = (q['expectedOutput'] ?? '').toString();
    final problem  = (q['description']    ?? q['title'] ?? '').toString();
    final maxScore = (q['score'] is int)  ? q['score'] as int : 10;

    final result      = await _runCode(silent: true, stdin: stdin);
    final stdout      = result?['stdout']       ?? '';
    final compileErr  = result?['compileError'] ?? '';

    bool passed;
    if (compileErr.isNotEmpty) {
      passed = false;
    } else if (_outputsMatch(stdout, expected)) {
      passed = true;
    } else {
      passed = await GroqService.validateCode(
        problem:  problem,
        expected: expected,
        code:     _codeCtrl.text,
        language: _lang.name,
      );
    }

    _results[qId] = {
      'score':        passed ? maxScore : 0,
      'maxScore':     maxScore,
      'passed':       passed,
      'stdout':       stdout,
      'compileError': compileErr,
      'code':         _codeCtrl.text,
      'language':     _lang.name,
    };
  }

  // ── Next question or submit all ───────────────────────────────────────────
  Future<void> _nextOrFinish() async {
    if (_submitting) return;

    if (_codeCtrl.text.trim().isEmpty) {
      final skip = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: const Color(0xFF203A43),
          title: const Text('Skip this problem?', style: TextStyle(color: Colors.white)),
          content: const Text(
            'You have not written any code. Skip and continue?',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Go Back', style: TextStyle(color: Colors.white60)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Skip'),
            ),
          ],
        ),
      );
      if (skip != true) return;
      // Record zero for skipped
      final qId      = _qIds[_qIndex];
      final q        = _currentQ ?? {};
      final maxScore = (q['score'] is int) ? q['score'] as int : 10;
      _results[qId]  = {
        'score': 0, 'maxScore': maxScore, 'passed': false,
        'stdout': '', 'compileError': '', 'code': '', 'language': _lang.name,
      };
    } else {
      // Grade before advancing
      setState(() => _submitting = true);
      await _gradeCurrentQuestion();
      setState(() => _submitting = false);
    }

    if (_qIndex < _qIds.length - 1) {
      // Move to next question
      setState(() {
        _qIndex++;
        _codeCtrl.clear();
        _output = '';
      });
      await _loadQuestion();
    } else {
      // Last question → submit all
      await _submitAllAndNavigate();
    }
  }

  // ── Final submission ──────────────────────────────────────────────────────
  Future<void> _submitAllAndNavigate({bool auto = false}) async {
    if (_submitting) return;
    setState(() => _submitting = true);
    _timer?.cancel();

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not logged in');

      // Grade any un-graded current question
      if (!_results.containsKey(_qIds[_qIndex]) &&
          _codeCtrl.text.trim().isNotEmpty) {
        await _gradeCurrentQuestion();
      }

      // Quiz meta
      final quizSnap   = await FirebaseFirestore.instance
          .collection('quizzes')
          .doc(widget.quizId)
          .get();
      final quizData      = quizSnap.data() ?? {};
      final quizTitle     = quizData['title']?.toString() ?? 'Quiz';
      final passPerc      = (quizData['passPercentage'] ?? 60).toDouble();

      // Aggregate results
      int totalScore = 0, totalMax = 0;
      for (final r in _results.values) {
        totalScore += (r['score'] as int);
        totalMax   += (r['maxScore'] as int);
      }
      final percentage  = totalMax == 0 ? 0.0 : totalScore / totalMax * 100.0;
      final finalPassed = percentage >= passPerc;
      final timeTaken   =
          widget.endAt.difference(DateTime.now()).inSeconds.abs();

      // Save attempt per question
      final batch = FirebaseFirestore.instance.batch();
      for (final entry in _results.entries) {
        final ref = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('attempts')
            .doc();
        batch.set(ref, {
          'quizId':           widget.quizId,
          'quizTitle':        quizTitle,
          'questionId':       entry.key,
          'type':             'coding',
          'isDaily':          false,
          'section':          'coding',
          'language':         entry.value['language'],
          'code':             entry.value['code'],
          'passed':           entry.value['passed'],
          'score':            entry.value['score'],
          'total':            entry.value['maxScore'],
          'percentage':       entry.value['maxScore'] == 0
                                  ? 0.0
                                  : entry.value['score'] / entry.value['maxScore'] * 100.0,
          'passPercentage':   passPerc,
          'actualOutput':     entry.value['stdout'],
          'compileError':     entry.value['compileError'],
          'timeTakenSeconds': timeTaken,
          'submittedAt':      FieldValue.serverTimestamp(),
          'autoSubmitted':    auto,
        });
      }
      await batch.commit();

      // Save summary attempt doc (for result screen)
      final summaryRef = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('history')
          .add({
        'quizId':           widget.quizId,
        'quizTitle':        quizTitle,
        'type':             'coding_summary',
        'section':          'coding',
        'isDaily':          false,
        'totalScore':       totalScore,
        'totalMax':         totalMax,
        'percentage':       percentage,
        'passed':           finalPassed,
        'passPercentage':   passPerc,
        'timeTakenSeconds': timeTaken,
        'submittedAt':      FieldValue.serverTimestamp(),
        'autoSubmitted':    auto,
      });

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => QuizResultScreen(
            quizId:         widget.quizId,
            attemptId:      summaryRef.id,
            quizTitle:      quizTitle,
            score:          totalScore,
            total:          totalMax,
            percentage:     percentage,
            endAt:          widget.endAt,
            passed:         finalPassed,
            passPercentage: passPerc,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  // ── Output comparison ─────────────────────────────────────────────────────
  bool _outputsMatch(String actual, String expected) {
    List<String> tokens(String s) => s
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .trim()
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();
    final a = tokens(actual);
    final b = tokens(expected);
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isLast = _qIndex == _qIds.length - 1;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        appBar: AppBar(
          backgroundColor: const Color(0xFF020617),
          automaticallyImplyLeading: false,
          title: Row(
            children: [
              const Icon(Icons.code, color: Colors.white70, size: 18),
              const SizedBox(width: 8),
              Text(
                'Problem ${_qIndex + 1}/${_qIds.length}',
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
          actions: [
            // Question progress pills
            if (_qIds.length > 1)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                child: Row(
                  children: List.generate(_qIds.length, (i) {
                    Color c;
                    if (i < _qIndex) {
                      final r = _results[_qIds[i]];
                      c = r != null && r['passed'] == true
                          ? Colors.greenAccent
                          : Colors.redAccent;
                    } else if (i == _qIndex) {
                      c = Colors.blueAccent;
                    } else {
                      c = Colors.white24;
                    }
                    return Container(
                      width: 10, height: 10,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(shape: BoxShape.circle, color: c),
                    );
                  }),
                ),
              ),
            // Timer
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  _timerLabel,
                  style: TextStyle(
                    color: _secs <= 60 ? Colors.redAccent : Colors.white70,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
            // Submit all button
            TextButton(
              onPressed: _submitting ? null : () => _submitAllAndNavigate(),
              child: const Text('SUBMIT ALL',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            // Switch to MCQ button for mixed quizzes
            if (widget.isMixed)
              TextButton.icon(
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      backgroundColor: const Color(0xFF203A43),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      title: const Text(
                        'Switch to MCQ?',
                        style: TextStyle(color: Colors.white),
                      ),
                      content: const Text(
                        'Your coding progress will be saved. You can switch back anytime.',
                        style: TextStyle(color: Colors.white70),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel',
                              style: TextStyle(color: Colors.white60)),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.greenAccent,
                            foregroundColor: Colors.black,
                          ),
                          child: const Text('Switch'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true && mounted) {
                    Navigator.pop(context);
                  }
                },
                icon: const Icon(Icons.quiz_outlined, color: Colors.greenAccent, size: 16),
                label: const Text(
                  'MCQ',
                  style: TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        body: _loadingQ
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : _buildBody(isLast),
      ),
    );
  }

  Widget _buildBody(bool isLast) {
    final q           = _currentQ ?? {};
    final title       = (q['title'] ?? 'Problem ${_qIndex + 1}').toString();
    final description = (q['description'] ?? '').toString();
    final sampleIn    = (q['input'] ?? '').toString();
    final sampleOut   = (q['expectedOutput'] ?? '').toString();
    final difficulty  = (q['difficulty'] ?? '').toString();
    final score       = q['score'] ?? 10;

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Problem statement ────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(title,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15)),
                    ),
                    if (difficulty.isNotEmpty)
                      _diffChip(difficulty),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('$score pts',
                          style: const TextStyle(
                              color: Colors.amber, fontSize: 12)),
                    ),
                  ],
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(description,
                      style: const TextStyle(
                          color: Colors.white70, height: 1.4, fontSize: 13)),
                ],
                if (sampleIn.isNotEmpty || sampleOut.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      if (sampleIn.isNotEmpty)
                        Expanded(child: _sampleBox('Input', sampleIn)),
                      if (sampleIn.isNotEmpty && sampleOut.isNotEmpty)
                        const SizedBox(width: 8),
                      if (sampleOut.isNotEmpty)
                        Expanded(child: _sampleBox('Output', sampleOut)),
                    ],
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 10),

          // ── Language selector ────────────────────────────────────────────
          Row(
            children: [
              const Text('Language:', style: TextStyle(color: Colors.white70)),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<Language>(
                  value: _lang,
                  dropdownColor: const Color(0xFF020617),
                  isExpanded: true,
                  items: supportedLanguages.map((l) => DropdownMenuItem(
                    value: l,
                    child: Text(l.name,
                        style: const TextStyle(color: Colors.white)),
                  )).toList(),
                  onChanged: _submitting || _running
                      ? null
                      : (v) { if (v != null) setState(() => _lang = v); },
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFF020617),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // ── Code editor ──────────────────────────────────────────────────
          Expanded(
            flex: 3,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF020617),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: TextField(
                controller: _codeCtrl,
                maxLines:   null,
                expands:    true,
                style:      const TextStyle(
                    fontFamily: 'monospace', color: Colors.white, fontSize: 13),
                decoration: const InputDecoration(
                  border:    InputBorder.none,
                  hintText:  '// Write your solution here…',
                  hintStyle: TextStyle(color: Colors.white24),
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // ── Run button ───────────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: ElevatedButton.icon(
                    onPressed:
                        _running || _submitting ? null : () => _runCode(),
                    icon: _running
                        ? const SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.play_arrow_rounded),
                    label: Text(_running ? 'Running…' : 'Run Code'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: ElevatedButton.icon(
                    onPressed: _submitting || _running ? null : _nextOrFinish,
                    icon: _submitting
                        ? const SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Icon(isLast
                            ? Icons.check_circle_outline
                            : Icons.arrow_forward),
                    label: Text(
                      _submitting ? 'Grading…'
                          : isLast ? 'Finish'
                          : 'Next Problem',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          isLast ? Colors.greenAccent : Colors.white,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // ── Output console ────────────────────────────────────────────────
          Expanded(
            flex: 2,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  _output.isEmpty ? 'Output will appear here…' : _output,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: _output.startsWith('❌')
                        ? Colors.redAccent
                        : _output.startsWith('⚠️')
                            ? Colors.orangeAccent
                            : Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Small helpers ─────────────────────────────────────────────────────────
  Widget _diffChip(String d) {
    final colors = {
      'easy':   Colors.greenAccent,
      'medium': Colors.orangeAccent,
      'hard':   Colors.redAccent,
    };
    final color = colors[d.toLowerCase()] ?? Colors.white54;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(d[0].toUpperCase() + d.substring(1),
          style: TextStyle(color: color, fontSize: 11)),
    );
  }

  Widget _sampleBox(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(color: Colors.white54, fontSize: 11)),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black26,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(value,
              style: const TextStyle(
                  color: Colors.white, fontFamily: 'monospace', fontSize: 12)),
        ),
      ],
    );
  }
}