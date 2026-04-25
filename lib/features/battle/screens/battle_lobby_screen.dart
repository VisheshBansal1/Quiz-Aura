// IMPROVED: Added "Battle from Quiz" option — user can pick a quiz from
// the existing quiz pool and create a battle using those specific questions.
// This connects the quiz creation flow to battles as requested.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/glass_card.dart';
import '../services/battle_service.dart';
import 'battle_quiz_screen.dart';

class BattleLobbyScreen extends StatefulWidget {
  const BattleLobbyScreen({super.key});

  @override
  State<BattleLobbyScreen> createState() => _BattleLobbyScreenState();
}

class _BattleLobbyScreenState extends State<BattleLobbyScreen> {
  bool _loading = false;
  final _roomCodeCtrl = TextEditingController();

  @override
  void dispose() {
    _roomCodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _find1v1() async {
    setState(() => _loading = true);
    try {
      final battleId = await BattleService.findOrCreate1v1(userXp: 0);
      if (!mounted) return;
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => BattleQuizScreen(battleId: battleId)));
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createMultiplayer() async {
    setState(() => _loading = true);
    try {
      final battleId = await BattleService.createMultiplayerRoom(maxPlayers: 10);
      if (!mounted) return;

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => _RoomCodeDialog(
          battleId: battleId,
          onStart: () async {
            await BattleService.startMultiplayerBattle(battleId: battleId);
            if (!mounted) return;
            Navigator.of(context).pop();
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => BattleQuizScreen(battleId: battleId)));
          },
        ),
      );
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _joinRoom() async {
    final code = _roomCodeCtrl.text.trim();
    if (code.isEmpty) { _snack('Enter a room ID'); return; }
    setState(() => _loading = true);
    try {
      await BattleService.joinMultiplayerRoom(battleId: code);
      if (!mounted) return;
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => BattleQuizScreen(battleId: code)));
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ✅ NEW: Create a battle using questions from a specific quiz
  Future<void> _showQuizBattleDialog() async {
    showDialog(
      context: context,
      builder: (_) => _QuizPickerDialog(
        onQuizSelected: (quizId, quizTitle) async {
          Navigator.pop(context);
          setState(() => _loading = true);
          try {
            final battleId = await BattleService.createBattleWithQuiz(
              quizId:     quizId,
              type:       'multiplayer',
              maxPlayers: 10,
            );
            if (!mounted) return;
            await showDialog(
              context: context,
              barrierDismissible: false,
              builder: (_) => _RoomCodeDialog(
                battleId: battleId,
                quizTitle: quizTitle,
                onStart: () async {
                  await BattleService.startMultiplayerBattle(battleId: battleId);
                  if (!mounted) return;
                  Navigator.of(context).pop();
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => BattleQuizScreen(battleId: battleId)));
                },
              ),
            );
          } catch (e) {
            _snack(e.toString().replaceFirst('Exception: ', ''));
          } finally {
            if (mounted) setState(() => _loading = false);
          }
        },
      ),
    );
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.redAccent));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Container(decoration: const BoxDecoration(gradient: AppColors.mainGradient)),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Header
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Expanded(
                        child: Text('⚔️ Live Quiz Battle',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),

                  const SizedBox(height: 4),
                  const Text('Challenge others in real-time quiz battles',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white60, fontSize: 13)),

                  const SizedBox(height: 28),

                  // 1v1
                  GlassCard(
                    borderRadius: 24,
                    elevation: 8,
                    child: Column(
                      children: [
                        _cardHeader('⚔️', '1v1 Quick Match',
                            'Auto-matched opponent. 10 questions, 20 sec each.',
                            AppColors.battleRed),
                        const SizedBox(height: 14),
                        _mainButton('Find Opponent', AppColors.battleRed, _loading ? null : _find1v1),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Multiplayer
                  GlassCard(
                    borderRadius: 24,
                    elevation: 8,
                    child: Column(
                      children: [
                        _cardHeader('🏟️', 'Multiplayer Room',
                            'Up to 10 players. Share Room ID to invite.',
                            AppColors.accentBlue),
                        const SizedBox(height: 14),
                        _mainButton('Create Room', AppColors.accentBlue, _loading ? null : _createMultiplayer),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // ✅ NEW: Battle from a specific quiz
                  GlassCard(
                    borderRadius: 24,
                    elevation: 8,
                    child: Column(
                      children: [
                        _cardHeader('📚', 'Battle from Quiz',
                            'Pick an existing quiz and create a battle from its questions.',
                            Colors.purple),
                        const SizedBox(height: 14),
                        _mainButton('Choose Quiz', Colors.purple, _loading ? null : _showQuizBattleDialog),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Join by ID
                  GlassCard(
                    borderRadius: 24,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Join by Room ID',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _roomCodeCtrl,
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  hintText: 'Paste Room ID...',
                                  hintStyle: const TextStyle(color: Colors.white38),
                                  filled: true,
                                  fillColor: Colors.white.withOpacity(0.08),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 12),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton(
                              onPressed: _loading ? null : _joinRoom,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('Join',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
          if (_loading)
            Container(
              color: Colors.black45,
              child: const Center(
                  child: CircularProgressIndicator(color: Colors.tealAccent)),
            ),
        ],
      ),
    );
  }

  Widget _cardHeader(String emoji, String title, String subtitle, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Text(emoji, style: const TextStyle(fontSize: 26)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(
                  color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
              const SizedBox(height: 3),
              Text(subtitle, style: const TextStyle(color: Colors.white60, fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _mainButton(String label, Color color, VoidCallback? onTap) {
    return SizedBox(
      width: double.infinity,
      height: 46,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(label,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
      ),
    );
  }
}

// ── Room code dialog ──────────────────────────────────────────────────────────
class _RoomCodeDialog extends StatelessWidget {
  final String battleId;
  final String? quizTitle;
  final VoidCallback onStart;

  const _RoomCodeDialog({
    required this.battleId,
    required this.onStart,
    this.quizTitle,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF203A43),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        quizTitle != null ? '🏟️ Room: $quizTitle' : '🏟️ Room Created!',
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Share this Room ID with players:',
              style: TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.tealAccent.withOpacity(0.5)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(battleId,
                      style: const TextStyle(
                          color: Colors.tealAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis),
                ),
                IconButton(
                  icon: const Icon(Icons.copy, color: Colors.white70, size: 18),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: battleId));
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Room ID copied!')));
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('battles')
                .doc(battleId)
                .snapshots(),
            builder: (context, snapshot) {
              final data  = snapshot.data?.data() as Map<String, dynamic>?;
              final count = (data?['playerIds'] as List?)?.length ?? 1;
              return Text('$count player(s) in room',
                  style: const TextStyle(color: Colors.white60, fontSize: 13));
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
        ),
        ElevatedButton(
          onPressed: onStart,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('Start Battle!',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}

// ── Quiz picker dialog ────────────────────────────────────────────────────────
class _QuizPickerDialog extends StatelessWidget {
  final Function(String quizId, String quizTitle) onQuizSelected;

  const _QuizPickerDialog({required this.onQuizSelected});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF203A43),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Choose a Quiz',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      content: SizedBox(
        width: double.maxFinite,
        height: 300,
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('quizzes')
              .where('isActive', isEqualTo: true)
              .orderBy('createdAt', descending: true)
              .limit(20)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                  child: CircularProgressIndicator(color: Colors.white));
            }

            final docs = snapshot.data?.docs ?? [];

            if (docs.isEmpty) {
              return const Center(
                child: Text('No active quizzes available',
                    style: TextStyle(color: Colors.white60)),
              );
            }

            return ListView.builder(
              itemCount: docs.length,
              itemBuilder: (_, i) {
                final data  = docs[i].data();
                final id    = docs[i].id;
                final title = data['title']      ?? 'Quiz';
                final topic = data['topicTitle'] ?? '';

                return ListTile(
                  title: Text(title,
                      style: const TextStyle(color: Colors.white, fontSize: 14)),
                  subtitle: Text(topic,
                      style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  trailing: const Icon(Icons.arrow_forward_ios,
                      color: Colors.tealAccent, size: 14),
                  onTap: () => onQuizSelected(id, title),
                );
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
        ),
      ],
    );
  }
}
