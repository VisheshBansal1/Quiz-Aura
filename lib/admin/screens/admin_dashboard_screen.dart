import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quiz_app/home/leaderboard/quiz_leaderboard_screen.dart';

import '../../login/login_screen.dart';
import 'create_quiz_screen.dart';
import 'add_question_screen.dart';
import 'ai_generate_questions_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  Widget build(BuildContext context) {
    // 🔐 AUTH GUARD
    if (_auth.currentUser == null) {
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const CreateQuizScreen(),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text("Create Quiz"),
      ),

      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('quizzes')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(child: Text("Something went wrong"));
          }

          final quizzes = snapshot.data?.docs ?? [];

          if (quizzes.isEmpty) {
            return const Center(child: Text("No quizzes created yet"));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: quizzes.length,
            itemBuilder: (context, i) {
              final doc = quizzes[i];
              final data = doc.data();

              final title = data['title'] ?? 'Quiz';

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  title: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Topic: ${data['topic'] ?? 'N/A'}"),
                      Text("Join Code: ${data['joinCode'] ?? 'N/A'}"),
                    ],
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'add') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                AddQuestionScreen(quizId: doc.id),
                          ),
                        );
                      } 
                      else if (value == 'ai') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                AiGenerateQuestionsScreen(quizId: doc.id),
                          ),
                        );
                      } 
                      else if (value == 'leaderboard') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => QuizLeaderboardScreen(
                              quizId: doc.id,
                              quizTitle: title,
                            ),
                          ),
                        );
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'add',
                        child: Text("Add Question"),
                      ),
                      PopupMenuItem(
                        value: 'ai',
                        child: Text("Generate with AI"),
                      ),
                      PopupMenuDivider(),
                      PopupMenuItem(
                        value: 'leaderboard',
                        child: Text("View Leaderboard"),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // 🔓 LOGOUT
  Future<void> _handleLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Logout"),
        content: const Text("Are you sure you want to logout?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Logout"),
          ),
        ],
      ),
    );

    if (shouldLogout != true) return;

    await _auth.signOut();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }
}
