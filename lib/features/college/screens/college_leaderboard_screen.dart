// College Hub / Leaderboard Screen
// ADDED: View Join Code option via overflow menu
// ADDED: Leave/Quit College option with confirmation dialog
// FIXED: Professional layout with proper constraints

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/models/college_model.dart';
import '../services/college_service.dart';
import 'college_quiz_screen.dart';

class CollegeLeaderboardScreen extends StatefulWidget {
  final String collegeId;
  final String collegeName;

  const CollegeLeaderboardScreen({
    super.key,
    required this.collegeId,
    required this.collegeName,
  });

  @override
  State<CollegeLeaderboardScreen> createState() =>
      _CollegeLeaderboardScreenState();
}

class _CollegeLeaderboardScreenState
    extends State<CollegeLeaderboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  bool _actionLoading = false;

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

  // ── View Join Code ────────────────────────────────────────────────────────
  Future<void> _showJoinCode() async {
    setState(() => _actionLoading = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('colleges')
          .doc(widget.collegeId)
          .get();
      final code = snap.data()?['code'] as String? ?? 'N/A';
      if (!mounted) return;
      _showCodeDialog(code);
    } catch (e) {
      if (!mounted) return;
      _snack('Could not load code: $e');
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  void _showCodeDialog(String code) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF203A43),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text(
          '🔑 College Join Code',
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Share this code with your college mates so they can join.',
              style: TextStyle(color: Colors.white70, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.teal, width: 2),
              ),
              child: Column(
                children: [
                  Text(
                    code,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.tealAccent,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: code));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Code copied! 📋'),
                          backgroundColor: Colors.teal,
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 7),
                      decoration: BoxDecoration(
                        color: Colors.teal.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: Colors.teal.withOpacity(0.4)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.copy,
                              color: Colors.tealAccent, size: 15),
                          SizedBox(width: 6),
                          Text(
                            'Copy Code',
                            style: TextStyle(
                                color: Colors.tealAccent,
                                fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 44),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Close'),
            ),
          ),
        ],
      ),
    );
  }

  // ── Leave College ─────────────────────────────────────────────────────────
  Future<void> _confirmLeaveCollege() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF203A43),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text(
          '🚪 Leave College?',
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'You will be removed from the college leaderboard and your XP '
          'contribution will be deducted.\n\nYou can rejoin anytime using the code.',
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Leave College'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _actionLoading = true);
    try {
      await CollegeService.leaveCollege();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You have left the college.'),
          backgroundColor: Colors.teal,
        ),
      );
      Navigator.pop(context, true); // return to profile/home
    } catch (e) {
      if (!mounted) return;
      _snack('Error: ${e.toString().replaceFirst('Exception: ', '')}');
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  void _snack(String msg, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: success ? Colors.teal : Colors.redAccent,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background gradient
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
                // ── Header ────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
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
                              'College Hub',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
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

                      // ── Quizzes Button ─────────────────────────────────
                      TextButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CollegeQuizScreen(
                              collegeId: widget.collegeId,
                              collegeName: widget.collegeName,
                            ),
                          ),
                        ),
                        icon: const Icon(Icons.quiz_outlined,
                            color: Colors.tealAccent, size: 18),
                        label: const Text(
                          'Quizzes',
                          style: TextStyle(
                              color: Colors.tealAccent, fontSize: 13),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                        ),
                      ),

                      // ── Overflow Menu (Code + Leave) ───────────────────
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert,
                            color: Colors.white),
                        color: const Color(0xFF1A3340),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        onSelected: (value) {
                          if (value == 'view_code') _showJoinCode();
                          if (value == 'leave') _confirmLeaveCollege();
                        },
                        itemBuilder: (_) => [
                          PopupMenuItem<String>(
                            value: 'view_code',
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color:
                                        Colors.teal.withOpacity(0.15),
                                    borderRadius:
                                        BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.tag,
                                      color: Colors.tealAccent,
                                      size: 16),
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  'View Join Code',
                                  style:
                                      TextStyle(color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                          const PopupMenuDivider(),
                          PopupMenuItem<String>(
                            value: 'leave',
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.15),
                                    borderRadius:
                                        BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                      Icons.exit_to_app,
                                      color: Colors.redAccent,
                                      size: 16),
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  'Leave College',
                                  style: TextStyle(
                                      color: Colors.redAccent),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // ── Tabs ──────────────────────────────────────────────────
                Container(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16),
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
                      Tab(text: 'Leaderboard'),
                      Tab(text: 'Members'),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                Expanded(
                  child: TabBarView(
                    controller: _tabs,
                    children: [
                      _LeaderboardTab(collegeId: widget.collegeId),
                      _MembersTab(collegeId: widget.collegeId),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Loading overlay
          if (_actionLoading)
            Container(
              color: Colors.black45,
              child: const Center(
                child: CircularProgressIndicator(
                    color: Colors.tealAccent),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Leaderboard Tab ───────────────────────────────────────────────────────────
class _LeaderboardTab extends StatelessWidget {
  final String collegeId;
  const _LeaderboardTab({required this.collegeId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<CollegeMemberModel>>(
      stream: CollegeService.membersStream(collegeId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Colors.tealAccent));
        }

        final members = snapshot.data ?? [];

        if (members.isEmpty) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('🏆', style: TextStyle(fontSize: 40)),
                SizedBox(height: 12),
                Text('No members yet',
                    style:
                        TextStyle(color: Colors.white60, fontSize: 14)),
              ],
            ),
          );
        }

        // Sort by XP descending
        final sorted = [...members]
          ..sort((a, b) => b.xp.compareTo(a.xp));

        // Top 3 podium
        final top3 = sorted.take(3).toList();
        final rest = sorted.skip(3).toList();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // ── Podium ────────────────────────────────────────────────
              if (top3.isNotEmpty) _buildPodium(top3),

              const SizedBox(height: 16),

              // ── Rest of leaderboard ───────────────────────────────────
              ...rest.asMap().entries.map((e) {
                final rank = e.key + 4;
                final member = e.value;
                return _buildRankRow(rank, member);
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPodium(List<CollegeMemberModel> top3) {
    // Podium order: 2nd, 1st, 3rd
    final order = [
      if (top3.length > 1) MapEntry(1, top3[1]),
      if (top3.isNotEmpty) MapEntry(0, top3[0]),
      if (top3.length > 2) MapEntry(2, top3[2]),
    ];

    final podiumData = {
      0: {'emoji': '👑', 'color': const Color(0xFFFFD700), 'height': 90.0, 'size': 16.0},
      1: {'emoji': '🥈', 'color': const Color(0xFFC0C0C0), 'height': 70.0, 'size': 14.0},
      2: {'emoji': '🥉', 'color': const Color(0xFFCD7F32), 'height': 55.0, 'size': 13.0},
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.center,
      children: order.map((entry) {
        final rankIdx = entry.key;
        final member = entry.value;
        final pd = podiumData[rankIdx]!;
        final color = pd['color'] as Color;
        final podiumHeight = pd['height'] as double;
        final fontSize = pd['size'] as double;
        final isFirst = rankIdx == 0;

        return Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(pd['emoji'] as String,
                  style: TextStyle(fontSize: isFirst ? 28 : 22)),
              const SizedBox(height: 4),
              Text(
                member.name,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isFirst ? color : Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: fontSize,
                ),
              ),
              Text(
                '${member.xp} XP',
                style: TextStyle(
                    color: color.withOpacity(0.9), fontSize: 11),
              ),
              const SizedBox(height: 6),
              Container(
                height: podiumHeight,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12)),
                  border: Border.all(color: color.withOpacity(0.4)),
                ),
                child: Center(
                  child: Text(
                    '#${rankIdx + 1}',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRankRow(int rank, CollegeMemberModel member) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white.withOpacity(0.07),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text(
              '#$rank',
              style: const TextStyle(
                  color: Colors.white54,
                  fontWeight: FontWeight.bold,
                  fontSize: 13),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.name,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14),
                ),
                if (member.branch.isNotEmpty)
                  Text(
                    member.branch,
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 11),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.teal.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
              border:
                  Border.all(color: Colors.teal.withOpacity(0.3)),
            ),
            child: Text(
              '${member.xp} XP',
              style: const TextStyle(
                color: Colors.tealAccent,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Members Tab ───────────────────────────────────────────────────────────────
class _MembersTab extends StatelessWidget {
  final String collegeId;
  const _MembersTab({required this.collegeId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<CollegeMemberModel>>(
      stream: CollegeService.membersStream(collegeId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(
                  color: Colors.tealAccent));
        }

        final members = snapshot.data ?? [];

        if (members.isEmpty) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('👥', style: TextStyle(fontSize: 40)),
                SizedBox(height: 12),
                Text('No members yet',
                    style: TextStyle(
                        color: Colors.white60, fontSize: 14)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: members.length,
          itemBuilder: (_, i) {
            final m = members[i];
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: Colors.white.withOpacity(0.07),
                border: Border.all(
                    color: Colors.white.withOpacity(0.1)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.teal.withOpacity(0.2),
                    child: Text(
                      m.name.isNotEmpty
                          ? m.name[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                          color: Colors.tealAccent,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          m.name,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14),
                        ),
                        Text(
                          m.branch,
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${m.xp} XP',
                    style: const TextStyle(
                        color: Colors.tealAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 13),
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
