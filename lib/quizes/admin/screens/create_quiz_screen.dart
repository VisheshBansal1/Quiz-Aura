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
  String quizType = 'mcq'; // 'mcq' | 'coding' | 'mixed'
  int passPercentage = 60;

  String? quizId;
  String? joinCode;
  bool loading = false;

  @override
  void dispose() {
    titleCtrl.dispose();
    topicCtrl.dispose();
    super.dispose();
  }

  // ── Topic ────────────────────────────────────────────────────────────────
  Future<void> _createOrSelectTopic() async {
    final name = topicCtrl.text.trim();
    if (name.isEmpty) {
      _error('Topic name required');
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
      _error('Failed to create topic');
    }
  }

  // ── Create Quiz ──────────────────────────────────────────────────────────
  Future<void> _createQuiz() async {
    if (loading || quizId != null) return;
    if (!_formKey.currentState!.validate()) {
      _error('Fix form errors');
      return;
    }
    if (selectedTopicId == null) {
      _error('Select or create a topic');
      return;
    }

    if (startTime == null) {
      final instant = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: const Color(0xFF203A43),
          title: const Text(
            'Start Instantly?',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'No start time selected.\nDo you want to start the quiz instantly?',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text(
                'No',
                style: TextStyle(color: Colors.redAccent),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Yes'),
            ),
          ],
        ),
      );
      if (instant != true) return;
      startTime = DateTime.now().add(const Duration(seconds: 60));
    }

    if (startTime!.isBefore(DateTime.now().add(const Duration(seconds: 30)))) {
      _error('Start time must be in the future');
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
        quizType: quizType,
        passPercentage: passPercentage,
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

  void _error(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  // ── UI ───────────────────────────────────────────────────────────────────
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
            'Create Quiz',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: Colors.white),
          ),
        ),
        body: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _glassInput(
                      controller: titleCtrl,
                      label: 'Quiz Title',
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Required' : null,
                    ),

                    const SizedBox(height: 16),

                    // ── Quiz Type ──────────────────────────────────────────
                    const Text(
                      'Quiz Type',
                      style: TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _typeSelector(),

                    const SizedBox(height: 16),

                    // ── Pass % ─────────────────────────────────────────────
                    _glassInput(
                      label: 'Pass Percentage (%)',
                      initialValue: passPercentage.toString(),
                      keyboardType: TextInputType.number,
                      onChanged: (v) => passPercentage = int.tryParse(v) ?? 60,
                    ),

                    const SizedBox(height: 16),

                    // ── Topic ──────────────────────────────────────────────
                    if (quizId == null) _topicSection(),

                    const SizedBox(height: 16),

                    // ── Start time ─────────────────────────────────────────
                    _startTimeTile(),

                    const SizedBox(height: 12),

                    _glassInput(
                      label: 'Duration (minutes)',
                      initialValue: '30',
                      keyboardType: TextInputType.number,
                      onChanged: (v) => durationMinutes = int.tryParse(v) ?? 30,
                    ),

                    const SizedBox(height: 20),

                    // ── Create button ──────────────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: quizId == null ? _createQuiz : null,
                        icon: const Icon(Icons.rocket_launch),
                        label: const Text(
                          'Create Quiz',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.tealAccent,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),

                    // ── Post-create actions ────────────────────────────────
                    if (quizId != null) ...[
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.check_circle,
                                  color: Colors.greenAccent,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Quiz Created!',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            if (joinCode != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Join Code: $joinCode',
                                style: const TextStyle(
                                  color: Colors.tealAccent,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 2,
                                ),
                              ),
                            ],
                            const SizedBox(height: 16),
                            _actionButton(
                              label: 'Add Questions Manually',
                              icon: Icons.add_circle_outline,
                              color: Colors.blueAccent,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AddQuestionScreen(
                                    quizId: quizId!,
                                    quizType: quizType,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            if (quizType != 'coding')
                              _actionButton(
                                label: 'Generate MCQ with AI',
                                icon: Icons.auto_awesome,
                                color: Colors.deepPurpleAccent,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => AiGenerateQuestionsScreen(
                                      quizId: quizId!,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
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

  // ── Quiz type selector ───────────────────────────────────────────────────
  Widget _typeSelector() {
    return Row(
      children: [
        _typeChip('mcq', 'MCQ', Icons.quiz, Colors.greenAccent),
        const SizedBox(width: 10),
        _typeChip('coding', 'Coding', Icons.code, Colors.deepPurpleAccent),
        const SizedBox(width: 10),
        _typeChip('mixed', 'Mixed', Icons.layers, Colors.orangeAccent),
      ],
    );
  }

  Widget _typeChip(String value, String label, IconData icon, Color color) {
    final selected = quizType == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => quizType = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? color.withOpacity(0.25)
                : Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? color : Colors.white24,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: selected ? color : Colors.white54, size: 22),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: selected ? color : Colors.white54,
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Topic section ────────────────────────────────────────────────────────
  Widget _topicSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('topics')
          .where('isActive', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (c, s) {
        if (!s.hasData) return const CircularProgressIndicator();

        final topics = s.data!.docs;

        if (topics.isEmpty || showCreateTopic) {
          return Column(
            children: [
              _glassInput(controller: topicCtrl, label: 'New Topic Name'),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _createOrSelectTopic,
                  child: const Text('Create Topic'),
                ),
              ),
              if (topics.isNotEmpty)
                TextButton(
                  onPressed: () => setState(() => showCreateTopic = false),
                  child: const Text(
                    '← Select existing',
                    style: TextStyle(color: Colors.white60),
                  ),
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
                'Select Topic',
                style: TextStyle(color: Colors.white70),
              ),
              items: topics
                  .map(
                    (d) => DropdownMenuItem(
                      value: d.id,
                      child: Text(
                        d['title'],
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                final doc = topics.firstWhere((d) => d.id == v);
                setState(() {
                  selectedTopicId = doc.id;
                  selectedTopicTitle = doc['title'];
                });
              },
            ),
            TextButton(
              onPressed: () => setState(() => showCreateTopic = true),
              child: const Text('+ Create new topic'),
            ),
          ],
        );
      },
    );
  }

  // ── Start time tile ──────────────────────────────────────────────────────
  Widget _startTimeTile() {
    return ListTile(
      tileColor: Colors.white.withOpacity(0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text(
        startTime == null
            ? 'Select Start Time (optional)'
            : startTime.toString().substring(0, 16),
        style: const TextStyle(color: Colors.white),
      ),
      trailing: const Icon(Icons.schedule, color: Colors.white70),
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 30)),
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
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────
  Widget _actionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

// ── Shared glass input ─────────────────────────────────────────────────────
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
      fillColor: Colors.white.withOpacity(0.12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
    ),
  );
}
