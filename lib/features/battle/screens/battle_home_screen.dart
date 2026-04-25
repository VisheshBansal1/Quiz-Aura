// ============================================================
// FILE: lib/features/battle/screens/battle_home_screen.dart
// Entry screen for the 1v1 battle system.
// Users can:
//   1. Create a new battle (pick a quiz)
//   2. Join via invite link/code
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/glass_card.dart';
import '../services/battle_v2_service.dart';
import 'battle_waiting_screen.dart';
import 'battle_active_screen.dart';

class BattleHomeScreen extends StatefulWidget {
  // Optional: pass a battleId directly from a deep link
  final String? initialBattleId;

  const BattleHomeScreen({super.key, this.initialBattleId});

  @override
  State<BattleHomeScreen> createState() => _BattleHomeScreenState();
}

class _BattleHomeScreenState extends State<BattleHomeScreen> {
  final _joinController = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    // Auto-join if arrived via deep link
    if (widget.initialBattleId != null &&
        widget.initialBattleId!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _joinBattle(widget.initialBattleId!);
      });
    }
  }

  @override
  void dispose() {
    _joinController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _openQuizPicker() async {
    final quizId = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF1A2A35),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => const _QuizPickerSheet(),
    );

    if (quizId == null || !mounted) return;
    await _createBattle(quizId);
  }

  Future<void> _createBattle(String quizId) async {
    setState(() => _loading = true);
    try {
      final battleId = await BattleV2Service.createBattle(quizId: quizId);
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BattleWaitingScreen(battleId: battleId),
        ),
      );
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _joinBattle(String battleId) async {
    if (battleId.isEmpty) {
      _snack('Enter a valid battle code');
      return;
    }
    setState(() => _loading = true);
    try {
      await BattleV2Service.joinBattle(battleId: battleId);
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BattleActiveScreen(battleId: battleId),
        ),
      );
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Container(
              decoration:
                  const BoxDecoration(gradient: AppColors.mainGradient)),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Hero banner
                  GlassCard(
                    child: Column(
                      children: [
                        const Text('⚔️',
                            style: TextStyle(fontSize: 52)),
                        const SizedBox(height: 12),
                        const Text(
                          'Challenge a Friend',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Create a battle, share the link,\nand see who scores higher!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Colors.white60, fontSize: 13),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Create battle card
                  const Text(
                    'HOST A BATTLE',
                    style: TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),

                  GlassCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '1. Pick a quiz topic',
                          style: TextStyle(
                              color: Colors.white70, fontSize: 13),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          '2. Share invite link with your friend',
                          style: TextStyle(
                              color: Colors.white70, fontSize: 13),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          '3. Both play the same quiz — highest score wins!',
                          style: TextStyle(
                              color: Colors.white70, fontSize: 13),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton.icon(
                            onPressed: _loading ? null : _openQuizPicker,
                            icon: _loading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2))
                                : const Icon(Icons.add_circle_outline),
                            label: const Text('Create Battle',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(14)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Join battle card
                  const Text(
                    'JOIN A BATTLE',
                    style: TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),

                  GlassCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        TextField(
                          controller: _joinController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Paste battle link or code...',
                            hintStyle:
                                const TextStyle(color: Colors.white38),
                            prefixIcon: const Icon(Icons.link,
                                color: Colors.white38),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.06),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onSubmitted: (_) {
                            final id = BattleV2Service.parseInviteLink(
                                _joinController.text.trim());
                            _joinBattle(id);
                          },
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton.icon(
                            onPressed: _loading
                                ? null
                                : () {
                                    final id =
                                        BattleV2Service.parseInviteLink(
                                            _joinController.text
                                                .trim());
                                    _joinBattle(id);
                                  },
                            icon: const Icon(Icons.login),
                            label: const Text('Join Battle',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2196F3),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(14)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// QUIZ PICKER SHEET
// Lists all active quizzes for the host to pick from
// ─────────────────────────────────────────────────────────────────────────────
class _QuizPickerSheet extends StatelessWidget {
  const _QuizPickerSheet();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 10),
          child: Text(
            'Choose a Quiz for the Battle',
            style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold),
          ),
        ),
        const Divider(color: Colors.white12),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('quizzes')
                .where('isActive', isEqualTo: true)
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                    child:
                        CircularProgressIndicator(color: Colors.white));
              }
              final docs = snap.data?.docs ?? [];
              if (docs.isEmpty) {
                return const Center(
                    child: Text('No active quizzes found',
                        style: TextStyle(color: Colors.white54)));
              }
              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (_, i) {
                  final d = docs[i].data();
                  final title = d['title'] as String? ?? 'Quiz';
                  final topic = d['topic'] as String? ?? '';
                  final questionCount =
                      (d['questionCount'] ?? 0) as int;

                  return ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFF1B3A4B),
                      child: Text('⚡',
                          style: TextStyle(fontSize: 18)),
                    ),
                    title: Text(title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w500)),
                    subtitle: Text(
                      '${topic.isNotEmpty ? '$topic • ' : ''}${questionCount > 0 ? '$questionCount Qs' : ''}',
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 12),
                    ),
                    trailing: const Icon(Icons.chevron_right,
                        color: Colors.white38),
                    onTap: () =>
                        Navigator.pop(context, docs[i].id),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
