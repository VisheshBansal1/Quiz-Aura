import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/glass_card.dart';

class BranchLeaderboardScreen extends StatefulWidget {
  const BranchLeaderboardScreen({super.key});

  @override
  State<BranchLeaderboardScreen> createState() =>
      _BranchLeaderboardScreenState();
}

class _BranchLeaderboardScreenState extends State<BranchLeaderboardScreen> {
  final List<String> _branches = [
    'CSE', 'ECE', 'ME', 'CE', 'EE', 'IT', 'BT', 'Other'
  ];
  String _selected = 'CSE';
  final _myUid = FirebaseAuth.instance.currentUser?.uid ?? '';

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
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 12, 16, 0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios,
                            color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Expanded(
                        child: Text(
                          '🎓 Branch Leaderboard',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ── Branch filter chips ────────────────────────────────
                SizedBox(
                  height: 44,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _branches.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final b       = _branches[i];
                      final selected = b == _selected;
                      return GestureDetector(
                        onTap: () => setState(() => _selected = b),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: selected
                                ? Colors.teal
                                : Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: selected
                                  ? Colors.teal
                                  : Colors.white.withOpacity(0.2),
                            ),
                          ),
                          child: Text(
                            b,
                            style: TextStyle(
                              color:
                                  selected ? Colors.white : Colors.white70,
                              fontWeight: selected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 16),

                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .where('branch', isEqualTo: _selected)
                        .orderBy('totalXp', descending: true)
                        .limit(50)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(
                            child: CircularProgressIndicator(
                                color: Colors.white));
                      }

                      final docs = snapshot.data?.docs ?? [];

                      if (docs.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('🎓',
                                  style: TextStyle(fontSize: 48)),
                              const SizedBox(height: 12),
                              Text(
                                'No $_selected students yet',
                                style: const TextStyle(
                                    color: Colors.white60,
                                    fontSize: 16),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: docs.length,
                        itemBuilder: (_, i) {
                          final rank  = i + 1;
                          final data  = docs[i].data();
                          final isMe  = docs[i].id == _myUid;
                          final name  = data['name'] ?? 'User';
                          final xp    = (data['totalXp'] ?? 0) as int;
                          final level = (data['level'] ?? 1) as int;

                          return GlassCard(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            backgroundColor: isMe
                                ? Colors.teal.withOpacity(0.15)
                                : null,
                            borderColor: isMe
                                ? Colors.tealAccent.withOpacity(0.4)
                                : null,
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 40,
                                  child: rank <= 3
                                      ? Text(
                                          rank == 1
                                              ? '🥇'
                                              : rank == 2
                                                  ? '🥈'
                                                  : '🥉',
                                          style: const TextStyle(
                                              fontSize: 22),
                                        )
                                      : Text(
                                          '#$rank',
                                          style: TextStyle(
                                            color: AppColors.rankColor(rank),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                ),
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor:
                                      Colors.teal.withOpacity(0.3),
                                  child: Text(
                                    name.isNotEmpty
                                        ? name[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        isMe ? '$name (You)' : name,
                                        style: TextStyle(
                                          color: isMe
                                              ? Colors.tealAccent
                                              : Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      Text(
                                        'Lv.$level • $_selected',
                                        style: const TextStyle(
                                            color: Colors.white54,
                                            fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '$xp XP',
                                  style: const TextStyle(
                                    color: Colors.amber,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
