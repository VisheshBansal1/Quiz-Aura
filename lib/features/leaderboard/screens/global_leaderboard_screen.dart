import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/glass_card.dart';

/// Global leaderboard with All-Time / Weekly / Monthly tabs.
/// Reads from the users collection — no separate leaderboard collection needed.
/// Weekly/monthly use weeklyXp / monthlyXp fields updated by LevelService.
class GlobalLeaderboardScreen extends StatefulWidget {
  const GlobalLeaderboardScreen({super.key});

  @override
  State<GlobalLeaderboardScreen> createState() =>
      _GlobalLeaderboardScreenState();
}

class _GlobalLeaderboardScreenState extends State<GlobalLeaderboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final _myUid = FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
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
              decoration:
                  const BoxDecoration(gradient: AppColors.mainGradient)),
          SafeArea(
            child: Column(
              children: [
                // ── Header ─────────────────────────────────────────────
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
                          '🌍 Global Leaderboard',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ── Tabs ───────────────────────────────────────────────
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
                        borderRadius: BorderRadius.circular(10)),
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white60,
                    dividerColor: Colors.transparent,
                    tabs: const [
                      Tab(text: 'All Time'),
                      Tab(text: 'Weekly'),
                      Tab(text: 'Monthly'),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                Expanded(
                  child: TabBarView(
                    controller: _tabs,
                    children: [
                      _LeaderboardList(
                        field: 'totalXp',
                        label: 'Total XP',
                        myUid: _myUid,
                      ),
                      _LeaderboardList(
                        field: 'weeklyXp',
                        label: 'Weekly XP',
                        myUid: _myUid,
                      ),
                      _LeaderboardList(
                        field: 'monthlyXp',
                        label: 'Monthly XP',
                        myUid: _myUid,
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
}

// ── Safe XP parser ──────────────────────────────────────────────────────────
// FIX 2: Firestore can return XP as int OR double (e.g. via FieldValue.increment).
// Casting directly with `as int` throws a runtime CastError when it's a double.
// Use (value as num).toInt() to handle both safely.
int _safeXp(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is num) return value.toInt();
  return 0;
}

class _LeaderboardList extends StatelessWidget {
  final String field;
  final String label;
  final String myUid;

  const _LeaderboardList({
    required this.field,
    required this.label,
    required this.myUid,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .orderBy(field, descending: true)
          .limit(100)
          .snapshots(),
      builder: (context, snapshot) {
        // ── Loading ──────────────────────────────────────────────────
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Colors.white));
        }

        // FIX 1: Handle Firestore errors explicitly.
        // Previously, snapshot.hasError was never checked — so any Firestore
        // error (missing index, permission denied, network issue) caused
        // snapshot.data to be null, making docs = [] and showing "No data yet"
        // instead of the real problem.
        if (snapshot.hasError) {
          final err = snapshot.error.toString();
          // Detect missing Firestore index error and give actionable guidance
          final isMissingIndex = err.contains('failed-precondition') ||
              err.contains('index') ||
              err.contains('FAILED_PRECONDITION');

          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isMissingIndex ? Icons.warning_amber_rounded : Icons.error_outline,
                    color: Colors.amber,
                    size: 48,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isMissingIndex
                        ? 'Firestore index required for "$field".\nPlease create a descending index on the "$field" field in your Firebase Console.'
                        : 'Failed to load leaderboard.\n$err',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.leaderboard_outlined, color: Colors.white38, size: 48),
                SizedBox(height: 12),
                Text('No data yet',
                    style: TextStyle(color: Colors.white60)),
                SizedBox(height: 4),
                Text('Complete quizzes to appear here!',
                    style: TextStyle(color: Colors.white38, fontSize: 12)),
              ],
            ),
          );
        }

        // Find my rank — iterate all docs
        // FIX 4: myRank = -1 when not in top 100.
        // Previously: `if (myRank > 10)` was the banner condition, but -1 > 10
        // is false so the banner would never show when user is outside top 100.
        // Fixed to: myRank != -1 && myRank > 10  (banner) OR myRank == -1 (not in list)
        int myRank = -1;
        for (int i = 0; i < docs.length; i++) {
          if (docs[i].id == myUid) {
            myRank = i + 1;
            break;
          }
        }

        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            // My rank banner — show if I'm outside top 10 OR not in the list at all
            if (myRank > 10 || myRank == -1) ...[
              _MyRankBanner(rank: myRank, field: field, myUid: myUid),
              const SizedBox(height: 12),
            ],

            // Top 3 podium
            if (docs.length >= 3)
              _Podium(
                  docs: docs.take(3).toList(), field: field, myUid: myUid),

            const SizedBox(height: 16),

            // Rest of the list (rank 4 onward)
            ...docs.skip(3).take(97).toList().asMap().entries.map((e) {
              final rank = e.key + 4;
              final doc  = e.value;
              final data = doc.data();
              final isMe = doc.id == myUid;
              // FIX 2: use _safeXp instead of direct `as int` cast
              final xp   = _safeXp(data[field]);
              final name = (data['name'] as String?) ?? 'User';

              return GlassCard(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                backgroundColor:
                    isMe ? Colors.teal.withOpacity(0.15) : null,
                borderColor: isMe
                    ? Colors.tealAccent.withOpacity(0.4)
                    : null,
                child: Row(
                  children: [
                    SizedBox(
                      width: 36,
                      child: Text(
                        '#$rank',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    _Avatar(name: name, isMe: isMe),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isMe ? '$name (You)' : name,
                            style: TextStyle(
                              color: isMe ? Colors.tealAccent : Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          if (((data['collegeName'] as String?) ?? '').isNotEmpty)
                            Text(
                              data['collegeName'] as String,
                              style: const TextStyle(
                                  color: Colors.white38, fontSize: 11),
                            ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '$xp',
                          style: const TextStyle(
                            color: Colors.amber,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          label,
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 10),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),

            const SizedBox(height: 100),
          ],
        );
      },
    );
  }
}

class _Podium extends StatelessWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  final String field;
  final String myUid;

  const _Podium(
      {required this.docs, required this.field, required this.myUid});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (docs.length > 1)
            Expanded(
                child: _PodiumItem(
              rank: 2,
              doc: docs[1],
              field: field,
              myUid: myUid,
              height: 130,
            )),
          const SizedBox(width: 8),
          Expanded(
              child: _PodiumItem(
            rank: 1,
            doc: docs[0],
            field: field,
            myUid: myUid,
            height: 180,
          )),
          const SizedBox(width: 8),
          if (docs.length > 2)
            Expanded(
                child: _PodiumItem(
              rank: 3,
              doc: docs[2],
              field: field,
              myUid: myUid,
              height: 100,
            )),
        ],
      ),
    );
  }
}

class _PodiumItem extends StatelessWidget {
  final int rank;
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final String field;
  final String myUid;
  final double height;

  const _PodiumItem({
    required this.rank,
    required this.doc,
    required this.field,
    required this.myUid,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final data   = doc.data();
    final isMe   = doc.id == myUid;
    final name   = (data['name'] as String?) ?? 'User';
    // FIX 2: safe XP parsing
    final xp     = _safeXp(data[field]);
    final color  = AppColors.rankColor(rank);
    final medal  = rank == 1 ? '👑' : rank == 2 ? '🥈' : '🥉';

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: isMe
            ? Colors.teal.withOpacity(0.2)
            : Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.5), width: 1.5),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(medal, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              name.split(' ').first,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isMe ? Colors.tealAccent : Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Text('$xp XP',
              style: TextStyle(color: color, fontSize: 10)),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _MyRankBanner extends StatelessWidget {
  final int rank;
  final String field;
  final String myUid;

  const _MyRankBanner(
      {required this.rank, required this.field, required this.myUid});

  @override
  Widget build(BuildContext context) {
    // FIX 3: If myUid is empty (user not logged in), skip silently
    if (myUid.isEmpty) return const SizedBox.shrink();

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance.collection('users').doc(myUid).get(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }
        if (snap.hasError || !snap.hasData || !snap.data!.exists) {
          return const SizedBox.shrink();
        }

        final data = snap.data!.data() ?? {};
        // FIX 2: safe XP parsing
        final xp   = _safeXp(data[field]);

        return GlassCard(
          backgroundColor: Colors.teal.withOpacity(0.15),
          borderColor: Colors.tealAccent.withOpacity(0.4),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              const Icon(Icons.person, color: Colors.tealAccent, size: 18),
              const SizedBox(width: 8),
              Text(
                // FIX 4: show "Not in top 100" when rank is -1
                rank == -1 ? 'Your rank: Outside top 100' : 'Your rank: #$rank',
                style: const TextStyle(
                  color: Colors.tealAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              Text('$xp XP',
                  style: const TextStyle(
                    color: Colors.amber,
                    fontWeight: FontWeight.bold,
                  )),
            ],
          ),
        );
      },
    );
  }
}

class _Avatar extends StatelessWidget {
  final String name;
  final bool isMe;

  const _Avatar({required this.name, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 18,
      backgroundColor:
          isMe ? Colors.teal.withOpacity(0.4) : Colors.white.withOpacity(0.15),
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: TextStyle(
          color: isMe ? Colors.tealAccent : Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }
}