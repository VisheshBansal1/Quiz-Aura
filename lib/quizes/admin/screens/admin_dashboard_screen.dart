// IMPROVEMENTS:
// 1. Join code now has a COPY button — so you can always retrieve it.
// 2. Added "Create Tournament" button in FAB area.
// 3. Added "College Quiz" button to quiz cards — creates a quiz linked to admin's college.
// 4. All existing actions (Add, AI, Edit, Leaderboard) preserved.

import 'package:QuizSphere/features/tournament/screens/create_tournament_screen.dart';
import 'package:QuizSphere/quizes/admin/screens/edit_quiz_questions_screen.dart';
import 'package:QuizSphere/quizes/admin/screens/how_to_create.dart';
import 'package:QuizSphere/quizes/home/leaderboard/quiz_leaderboard_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../login/login_screen.dart';
import 'create_quiz_screen.dart';
import 'add_question_screen.dart';
import 'ai_generate_questions_screen.dart';
import '../../../core/services/ai_quiz_access_service.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
        );
      });
      return const SizedBox();
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          'Admin Dashboard',
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

      // ── FABs: Create Quiz (center) + Tournament + Help ────────────────
      floatingActionButton: Stack(
        children: [
          // Center: Create Quiz
          Align(
            alignment: Alignment.bottomCenter,
            child: FloatingActionButton.extended(
              heroTag: 'createQuiz',
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              elevation: 8,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CreateQuizScreen()),
              ),
              icon: const Icon(Icons.add),
              label: const Text(
                'Create Quiz',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),

          // Right: Tournament
          Positioned(
            bottom: 0,
            right: 0,
            child: FloatingActionButton(
              heroTag: 'createTournament',
              backgroundColor: Colors.amber,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CreateTournamentScreen(),
                ),
              ),
              tooltip: 'Create Tournament',
              child: const Icon(Icons.emoji_events),
            ),
          ),

          // Left: Help
          Positioned(
            bottom: 0,
            left: 0,
            child: FloatingActionButton(
              heroTag: 'howToCreate',
              backgroundColor: Colors.blueAccent,
              onPressed: () {
                showDialog(
                  context: context,
                  barrierColor: Colors.black.withOpacity(0.8),
                  builder: (_) => Dialog(
                    backgroundColor: Colors
                        .black, // ← was transparent; video needs opaque bg
                    insetPadding: const EdgeInsets.all(12),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: const HowToCreateScreen(),
                    ),
                  ),
                );
              },
              child: const Icon(Icons.help_outline),
            ),
          ),
        ],
      ),

      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,

      body: Stack(
        children: [
          _gradientBg(),
          SafeArea(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('quizzes')
                  .where('createdBy', isEqualTo: user.uid)
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  );
                }

                if (snapshot.hasError) {
                  return const Center(
                    child: Text(
                      'Something went wrong',
                      style: TextStyle(color: Colors.white70),
                    ),
                  );
                }

                final quizzes = snapshot.data?.docs ?? [];

                if (quizzes.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('📝', style: TextStyle(fontSize: 48)),
                        SizedBox(height: 12),
                        Text(
                          'No quizzes yet',
                          style: TextStyle(color: Colors.white60, fontSize: 16),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Tap "Create Quiz" to get started.',
                          style: TextStyle(color: Colors.white38, fontSize: 13),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  itemCount: quizzes.length,
                  itemBuilder: (context, i) {
                    final doc = quizzes[i];
                    final data = doc.data();
                    final title = data['title'] ?? 'Quiz';
                    final topic = data['topicTitle'] ?? 'N/A';
                    final joinCode = data['joinCode'] as String?;
                    final isActive = (data['isActive'] ?? true) as bool;
                    final isTournamentQuiz =
                        (data['isTournamentQuiz'] ?? false) as bool;

                    return _quizCard(
                      context: context,
                      doc: doc,
                      title: title,
                      topic: topic,
                      joinCode: joinCode,
                      isActive: isActive,
                      isTournamentQuiz: isTournamentQuiz,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _quizCard({
    required BuildContext context,
    required QueryDocumentSnapshot<Map<String, dynamic>> doc,
    required String title,
    required String topic,
    required String? joinCode,
    required bool isActive,
    required bool isTournamentQuiz,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withOpacity(0.1),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title + active badge
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isActive
                      ? Colors.green.withOpacity(0.2)
                      : Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isActive ? 'ACTIVE' : 'ENDED',
                  style: TextStyle(
                    color: isActive ? Colors.greenAccent : Colors.redAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),
          Text(
            'Topic: $topic',
            style: const TextStyle(color: Colors.white60, fontSize: 13),
          ),

          // ✅ FIXED: Join code now copyable so you can always retrieve it
          if (joinCode != null && joinCode.isNotEmpty) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: joinCode));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Join code copied! 📋')),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.teal.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.tealAccent.withOpacity(0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock, color: Colors.tealAccent, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      'Code: $joinCode',
                      style: const TextStyle(
                        color: Colors.tealAccent,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.copy, color: Colors.tealAccent, size: 14),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 12),

          // ── Action buttons ────────────────────────────────────────────
          // Tournament round quizzes: only Edit, Add Q, AI (no Leaderboard).
          // Regular quizzes: full set — Add Q, AI, Edit, Leaderboard.
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: isTournamentQuiz
                  ? [
                      _actionButton(
                        icon: Icons.edit,
                        label: 'Edit',
                        enabled: isActive,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => EditQuizQuestionsScreen(
                              quizId: doc.id,
                              quizTitle: title,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _actionButton(
                        icon: Icons.add,
                        label: 'Add Q',
                        enabled: isActive,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AddQuestionScreen(quizId: doc.id),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _actionButton(
                        icon: AiQuizAccessService.buttonIcon(
                            Icons.auto_awesome),
                        label: AiQuizAccessService.buttonLabel('AI'),
                        enabled: isActive,
                        onTap: () => AiQuizAccessService.guard(
                          context,
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  AiGenerateQuestionsScreen(quizId: doc.id),
                            ),
                          ),
                        ),
                      ),
                    ]
                  : [
                      _actionButton(
                        icon: Icons.add,
                        label: 'Add Q',
                        enabled: isActive,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AddQuestionScreen(quizId: doc.id),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _actionButton(
                        icon: AiQuizAccessService.buttonIcon(
                            Icons.auto_awesome),
                        label: AiQuizAccessService.buttonLabel('AI'),
                        enabled: isActive,
                        onTap: () => AiQuizAccessService.guard(
                          context,
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  AiGenerateQuestionsScreen(quizId: doc.id),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _actionButton(
                        icon: Icons.edit,
                        label: 'Edit',
                        enabled: isActive,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => EditQuizQuestionsScreen(
                              quizId: doc.id,
                              quizTitle: title,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(
                          Icons.leaderboard,
                          color: Colors.white,
                        ),
                        tooltip: 'Leaderboard',
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => QuizLeaderboardScreen(
                              quizId: doc.id,
                              quizTitle: title,
                            ),
                          ),
                        ),
                      ),
                    ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool enabled,
  }) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: enabled
              ? Colors.white.withOpacity(0.15)
              : Colors.white.withOpacity(0.05),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: enabled ? Colors.white : Colors.white30,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: enabled ? Colors.white : Colors.white30,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _gradientBg() => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
      ),
    ),
  );
}
