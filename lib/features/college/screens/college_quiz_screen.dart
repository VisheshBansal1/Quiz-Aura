// NEW FEATURE: College Quiz Screen
// Admins/members can create a quiz that is linked to their college.
// This quiz appears in college leaderboard and college quiz tab.
// Connected to: CollegeService, AdminQuizService, BattleService (quiz pool)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../quizes/admin/services/Admin_quiz_service.dart';
import '../../../quizes/admin/screens/add_question_screen.dart';
import '../../../quizes/admin/screens/ai_generate_questions_screen.dart';
import '../../../core/services/ai_quiz_access_service.dart';

class CollegeQuizScreen extends StatefulWidget {
  final String collegeId;
  final String collegeName;

  const CollegeQuizScreen({
    super.key,
    required this.collegeId,
    required this.collegeName,
  });

  @override
  State<CollegeQuizScreen> createState() => _CollegeQuizScreenState();
}

class _CollegeQuizScreenState extends State<CollegeQuizScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0F2027),
                  Color(0xFF203A43),
                  Color(0xFF2C5364),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                // ── Header ──────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 12, 16, 0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios,
                            color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'College Quizzes',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              widget.collegeName,
                              style: const TextStyle(
                                color: Colors.tealAccent,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // ✅ FIX: Wrap in SizedBox to prevent infinite width crash
                      SizedBox(
                        width: 100,
                        child: ElevatedButton.icon(
                          onPressed: () => _showCreateQuizDialog(context),
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text(
                            'Create',
                            style: TextStyle(fontSize: 12),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // ── Tabs ─────────────────────────────────────────────────
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TabBar(
                    controller: _tabs,
                    indicator: BoxDecoration(
                      color: Colors.teal,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white60,
                    dividerColor: Colors.transparent,
                    tabs: const [
                      Tab(text: 'Active Quizzes'),
                      Tab(text: 'All Quizzes'),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // ── Tab views ─────────────────────────────────────────────
                Expanded(
                  child: TabBarView(
                    controller: _tabs,
                    children: [
                      _CollegeQuizList(
                        collegeId: widget.collegeId,
                        activeOnly: true,
                      ),
                      _CollegeQuizList(
                        collegeId: widget.collegeId,
                        activeOnly: false,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showCreateQuizDialog(BuildContext context) {
    final titleCtrl = TextEditingController();
    final durationCtrl = TextEditingController(text: '30');
    DateTime? startTime;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF203A43),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            '🏫 Create Quiz for ${widget.collegeName}',
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Title
                TextField(
                  controller: titleCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Quiz Title',
                    labelStyle: const TextStyle(color: Colors.white70),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.08),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Duration
                TextField(
                  controller: durationCtrl,
                  style: const TextStyle(color: Colors.white),
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Duration (minutes)',
                    labelStyle: const TextStyle(color: Colors.white70),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.08),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Start time
                GestureDetector(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: ctx,
                      initialDate:
                          DateTime.now().add(const Duration(minutes: 5)),
                      firstDate: DateTime.now(),
                      lastDate:
                          DateTime.now().add(const Duration(days: 30)),
                      builder: (c, child) => Theme(
                        data: ThemeData.dark().copyWith(
                          colorScheme: const ColorScheme.dark(
                              primary: Colors.teal),
                        ),
                        child: child!,
                      ),
                    );
                    if (date == null) return;
                    final time = await showTimePicker(
                      context: ctx,
                      initialTime: TimeOfDay.now(),
                      builder: (c, child) => Theme(
                        data: ThemeData.dark().copyWith(
                          colorScheme: const ColorScheme.dark(
                              primary: Colors.teal),
                        ),
                        child: child!,
                      ),
                    );
                    if (!ctx.mounted) return;
                    setDialogState(() {
                      startTime = DateTime(
                        date.year,
                        date.month,
                        date.day,
                        time?.hour ?? 0,
                        time?.minute ?? 0,
                      );
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.schedule,
                            color: Colors.white70, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          startTime == null
                              ? 'Tap to set start time'
                              : '${startTime!.day}/${startTime!.month} ${startTime!.hour}:${startTime!.minute.toString().padLeft(2, '0')}',
                          style: TextStyle(
                            color: startTime == null
                                ? Colors.white38
                                : Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel',
                  style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              onPressed: () async {
                final title = titleCtrl.text.trim();
                final duration = int.tryParse(durationCtrl.text) ?? 30;
                if (title.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Enter a quiz title')));
                  return;
                }

                final start = startTime ??
                    DateTime.now().add(const Duration(minutes: 1));
                final end = start.add(Duration(minutes: duration));

                Navigator.pop(ctx);

                try {
                  final uid = FirebaseAuth.instance.currentUser!.uid;
                  final ref = await FirebaseFirestore.instance
                      .collection('quizzes')
                      .add({
                    'title': title,
                    'topicId': widget.collegeId,
                    'topicTitle': widget.collegeName,
                    'visibility': 'college',
                    'collegeId': widget.collegeId,
                    'collegeName': widget.collegeName,
                    'createdBy': uid,
                    'createdAt': FieldValue.serverTimestamp(),
                    'isActive': true,
                    'startAt': Timestamp.fromDate(start),
                    'endAt': Timestamp.fromDate(end),
                    'durationMinutes': duration,
                  });

                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content:
                          Text('College quiz created! Now add questions.'),
                      backgroundColor: Colors.teal,
                    ),
                  );

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddQuestionScreen(quizId: ref.id),
                    ),
                  );
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')));
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Create Quiz'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── College quiz list ─────────────────────────────────────────────────────────
class _CollegeQuizList extends StatelessWidget {
  final String collegeId;
  final bool activeOnly;

  const _CollegeQuizList(
      {required this.collegeId, required this.activeOnly});

  @override
  Widget build(BuildContext context) {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('quizzes')
        .where('collegeId', isEqualTo: collegeId)
        .orderBy('createdAt', descending: true);

    if (activeOnly) query = query.where('isActive', isEqualTo: true);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Colors.white));
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline,
                    color: Colors.redAccent, size: 40),
                const SizedBox(height: 12),
                Text(
                  'Error loading quizzes',
                  style: const TextStyle(color: Colors.white60, fontSize: 14),
                ),
              ],
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('📝', style: TextStyle(fontSize: 40)),
                const SizedBox(height: 12),
                Text(
                  activeOnly
                      ? 'No active college quizzes'
                      : 'No quizzes created yet',
                  style:
                      const TextStyle(color: Colors.white60, fontSize: 14),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Tap "Create" above to add one',
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final doc = docs[i];
            final data = doc.data();
            final title = data['title'] ?? 'Quiz';
            final isActive = (data['isActive'] ?? false) as bool;
            final startTs = data['startAt'] as Timestamp?;
            final endTs = data['endAt'] as Timestamp?;
            final duration = data['durationMinutes'] ?? 30;
            final now = DateTime.now();
            final started =
                startTs != null && now.isAfter(startTs.toDate());
            final ended = endTs != null && now.isAfter(endTs.toDate());

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Colors.white.withOpacity(0.09),
                border:
                    Border.all(color: Colors.white.withOpacity(0.15)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title row + status badge
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: ended
                              ? Colors.grey.withOpacity(0.2)
                              : started
                                  ? Colors.green.withOpacity(0.2)
                                  : Colors.orange.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          ended
                              ? 'Ended'
                              : started
                                  ? 'Live'
                                  : 'Upcoming',
                          style: TextStyle(
                            color: ended
                                ? Colors.grey
                                : started
                                    ? Colors.greenAccent
                                    : Colors.orangeAccent,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 6),

                  // Duration info
                  Row(
                    children: [
                      const Icon(Icons.timer_outlined,
                          color: Colors.white38, size: 13),
                      const SizedBox(width: 4),
                      Text(
                        '$duration min',
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 12),
                      ),
                      if (startTs != null) ...[
                        const SizedBox(width: 12),
                        const Icon(Icons.calendar_today_outlined,
                            color: Colors.white38, size: 13),
                        const SizedBox(width: 4),
                        Text(
                          '${startTs.toDate().day}/${startTs.toDate().month} ${startTs.toDate().hour}:${startTs.toDate().minute.toString().padLeft(2, '0')}',
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 12),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Action buttons
                  Row(
                    children: [
                      _ActionBtn(
                        icon: Icons.add_circle_outline,
                        label: 'Add Question',
                        onTap: isActive
                            ? () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      AddQuestionScreen(quizId: doc.id),
                                ))
                            : null,
                      ),
                      const SizedBox(width: 8),
                      _ActionBtn(
                        icon: AiQuizAccessService.buttonIcon(
                            Icons.auto_awesome),
                        label: AiQuizAccessService.buttonLabel(
                            'AI Generate'),
                        onTap: isActive
                            ? () => AiQuizAccessService.guard(
                                context,
                                () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          AiGenerateQuestionsScreen(
                                              quizId: doc.id),
                                    )))
                            : null,
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _ActionBtn(
      {required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: enabled
              ? Colors.teal.withOpacity(0.2)
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: enabled
                ? Colors.teal.withOpacity(0.5)
                : Colors.white12,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: enabled ? Colors.tealAccent : Colors.white30,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: enabled ? Colors.tealAccent : Colors.white30,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
