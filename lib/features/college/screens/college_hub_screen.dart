// ============================================================
// FILE: lib/features/college/screens/college_hub_screen.dart
//
// REPLACES CollegeLeaderboardScreen as the main college page.
// 3 tabs:
//   1. 💬 Chat   — real-time group chat; quiz/tournament share cards
//   2. 👥 Members — all members ranked by XP
//   3. 🏆 Rankings— global college leaderboard (all colleges by XP)
//
// HOW TO NAVIGATE HERE (from anywhere):
//   Navigator.push(context, MaterialPageRoute(
//     builder: (_) => CollegeHubScreen(
//       collegeId: user.collegeId!,
//       collegeName: user.collegeName!,
//     ),
//   ));
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/firestore_paths.dart';
import '../../../core/models/college_model.dart';
import '../models/chat_message_model.dart';
import '../services/college_chat_service.dart';
import '../services/college_service.dart';

// For navigating to quiz / tournament from a chat card
import '../../../quizes/home/quiz_attempt_screen.dart';
import '../../../quizes/home/quiz_rules_screen.dart';
import '../../../quizes/home/quiz_ended_screen.dart';
import '../../../features/tournament/screens/tournament_detail_screen.dart';
import '../../../features/tournament/services/tournament_service.dart';
import '../../../core/models/tournament_model.dart';

class CollegeHubScreen extends StatefulWidget {
  final String collegeId;
  final String collegeName;

  const CollegeHubScreen({
    super.key,
    required this.collegeId,
    required this.collegeName,
  });

  @override
  State<CollegeHubScreen> createState() => _CollegeHubScreenState();
}

class _CollegeHubScreenState extends State<CollegeHubScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

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

  // ── Show/copy join code ───────────────────────────────────────────────────
  Future<void> _showJoinCode() async {
    final snap = await FirebaseFirestore.instance
        .collection(FirestorePaths.colleges)
        .doc(widget.collegeId)
        .get();
    final code = snap.data()?['code'] as String? ?? 'N/A';
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bgMid,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('🔑 College Join Code',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(code,
                  style: const TextStyle(
                      color: Colors.tealAccent,
                      fontSize: 28,
                      letterSpacing: 6,
                      fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 8),
            const Text('Share this code with your classmates',
                style: TextStyle(color: Colors.white60, fontSize: 12),
                textAlign: TextAlign.center),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Code copied!'),
                  duration: Duration(seconds: 2)));
            },
            child: const Text('Copy', style: TextStyle(color: Colors.tealAccent)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.white60)),
          ),
        ],
      ),
    );
  }

  // ── Leave college ─────────────────────────────────────────────────────────
  Future<void> _leaveCollege() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bgMid,
        title: const Text('Leave College?',
            style: TextStyle(color: Colors.white)),
        content: const Text(
            'You will lose your college membership and ranking.',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Leave',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await CollegeService.leaveCollege();
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: _gradientBg(),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(widget.collegeName,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            const Text('College Hub',
                style: TextStyle(color: Colors.white60, fontSize: 11)),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            color: AppColors.bgMid,
            onSelected: (v) {
              if (v == 'code') _showJoinCode();
              if (v == 'leave') _leaveCollege();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                  value: 'code',
                  child: Row(children: [
                    Icon(Icons.key, color: Colors.tealAccent, size: 18),
                    SizedBox(width: 8),
                    Text('View Join Code',
                        style: TextStyle(color: Colors.white)),
                  ])),
              PopupMenuItem(
                  value: 'leave',
                  child: Row(children: [
                    Icon(Icons.exit_to_app, color: Colors.redAccent, size: 18),
                    SizedBox(width: 8),
                    Text('Leave College',
                        style: TextStyle(color: Colors.white)),
                  ])),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: Colors.tealAccent,
          labelColor: Colors.tealAccent,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(icon: Icon(Icons.chat_bubble_outline, size: 20), text: 'Chat'),
            Tab(icon: Icon(Icons.people_outline, size: 20), text: 'Members'),
            Tab(icon: Icon(Icons.emoji_events_outlined, size: 20), text: 'Rankings'),
          ],
        ),
      ),
      body: Stack(
        children: [
          _gradientBg(),
          TabBarView(
            controller: _tabs,
            children: [
              _ChatTab(collegeId: widget.collegeId),
              _MembersTab(collegeId: widget.collegeId),
              const _RankingsTab(),
            ],
          ),
        ],
      ),
    );
  }

  static Widget _gradientBg() => Container(
      decoration: const BoxDecoration(gradient: AppColors.mainGradient));
}

// ═══════════════════════════════════════════════════════════════════════════════
// TAB 1 — CHAT
// ═══════════════════════════════════════════════════════════════════════════════

class _ChatTab extends StatefulWidget {
  final String collegeId;
  const _ChatTab({required this.collegeId});

  @override
  State<_ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends State<_ChatTab> {
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _sending = false;
  String get _myUid => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void dispose() {
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await CollegeChatService.sendText(
          collegeId: widget.collegeId, text: text);
      _textCtrl.clear();
      _scrollToBottom();
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: StreamBuilder<List<ChatMessage>>(
            stream: CollegeChatService.messagesStream(widget.collegeId),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(color: Colors.white));
              }
              final msgs = snap.data ?? [];
              if (msgs.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('💬', style: TextStyle(fontSize: 48)),
                      SizedBox(height: 12),
                      Text('No messages yet',
                          style: TextStyle(color: Colors.white60, fontSize: 16)),
                      Text('Start the conversation!',
                          style: TextStyle(color: Colors.white38)),
                    ],
                  ),
                );
              }
              WidgetsBinding.instance
                  .addPostFrameCallback((_) => _scrollToBottom());
              return ListView.builder(
                controller: _scrollCtrl,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                itemCount: msgs.length,
                itemBuilder: (_, i) {
                  final msg = msgs[i];
                  final isMe = msg.uid == _myUid;
                  return _ChatBubble(
                    msg: msg,
                    isMe: isMe,
                    collegeId: widget.collegeId,
                  );
                },
              );
            },
          ),
        ),
        // ── Input bar ──────────────────────────────────────────────────────
        Container(
          color: Colors.black.withOpacity(0.3),
          padding: EdgeInsets.only(
              left: 12,
              right: 8,
              top: 8,
              bottom: MediaQuery.of(context).padding.bottom + 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _textCtrl,
                  style: const TextStyle(color: Colors.white),
                  maxLines: null,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: 'Type a message…',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.08),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onSubmitted: (_) => _send(),
                ),
              ),
              const SizedBox(width: 8),
              _sending
                  ? const SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.tealAccent))
                  : IconButton(
                      onPressed: _send,
                      icon: const Icon(Icons.send_rounded,
                          color: Colors.tealAccent),
                    ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Individual chat bubble ────────────────────────────────────────────────────

class _ChatBubble extends StatelessWidget {
  final ChatMessage msg;
  final bool isMe;
  final String collegeId;

  const _ChatBubble({
    required this.msg,
    required this.isMe,
    required this.collegeId,
  });

  @override
  Widget build(BuildContext context) {
    if (msg.type == ChatMessageType.quiz) {
      return _SharedQuizCard(
          msg: msg, isMe: isMe, collegeId: collegeId);
    }
    if (msg.type == ChatMessageType.tournament) {
      return _SharedTournamentCard(
          msg: msg, isMe: isMe, collegeId: collegeId);
    }

    // Plain text bubble
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            _avatar(msg),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isMe
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                if (!isMe)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 2),
                    child: Text(msg.senderName,
                        style: const TextStyle(
                            color: Colors.tealAccent,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: isMe
                        ? Colors.teal.withOpacity(0.35)
                        : Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft:
                          Radius.circular(isMe ? 18 : 4),
                      bottomRight:
                          Radius.circular(isMe ? 4 : 18),
                    ),
                  ),
                  child: Text(msg.text,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 14)),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 2, left: 4, right: 4),
                  child: Text(
                    DateFormat('h:mm a').format(msg.timestamp),
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 10),
                  ),
                ),
              ],
            ),
          ),
          if (isMe) const SizedBox(width: 6),
        ],
      ),
    );
  }

  static Widget _avatar(ChatMessage msg) {
    if (msg.senderPhotoUrl.isNotEmpty) {
      return CircleAvatar(
          radius: 16,
          backgroundImage: NetworkImage(msg.senderPhotoUrl));
    }
    return CircleAvatar(
      radius: 16,
      backgroundColor: Colors.teal.withOpacity(0.5),
      child: Text(
          msg.senderName.isNotEmpty ? msg.senderName[0].toUpperCase() : '?',
          style: const TextStyle(
              color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
    );
  }
}

// ── Shared Quiz Card in Chat ──────────────────────────────────────────────────

class _SharedQuizCard extends StatelessWidget {
  final ChatMessage msg;
  final bool isMe;
  final String collegeId;

  const _SharedQuizCard(
      {required this.msg, required this.isMe, required this.collegeId});

  Future<void> _open(BuildContext context) async {
    if (msg.refId == null) return;

    final snap = await FirebaseFirestore.instance
        .collection(FirestorePaths.quizzes)
        .doc(msg.refId)
        .get();

    if (!context.mounted) return;

    if (!snap.exists) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Quiz not found')));
      return;
    }

    final data = snap.data()!;
    final isActive = data['isActive'] as bool? ?? true;
    final endAt = (data['endAt'] as Timestamp?)?.toDate();
    final isEnded = !isActive ||
        (endAt != null && DateTime.now().isAfter(endAt));

    if (isEnded) {
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => QuizEndedScreen(
                  quizTitle: data['title'] ?? 'Quiz')));
      return;
    }

    final startAt = (data['startAt'] as Timestamp?)?.toDate() ??
        DateTime.now();

    // endAt guaranteed non-null here (isEnded guard above caught null/past)
    final effectiveEndAt = endAt ?? DateTime.now().add(const Duration(hours: 1));

    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => QuizRulesScreen(
                  startAt: startAt,
                  quizType: data['quizType'] ?? 'mcq',
                  onConfirmedStart: () {
                    Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                            builder: (_) => QuizAttemptScreen(
                                  quizId: snap.id,
                                  endAt: effectiveEndAt,
                                  isDaily: false,
                                  topicTitle: data['title'] ?? 'Quiz',
                                )));
                  },
                )));
  }

  @override
  Widget build(BuildContext context) {
    if (msg.refId == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Align(
        alignment:
            isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.72),
          child: StreamBuilder<bool>(
            stream: CollegeChatService.quizEndedStream(msg.refId!),
            builder: (context, snap) {
              final ended = snap.data ?? false;
              return GestureDetector(
                onTap: () => _open(context),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: ended
                        ? const LinearGradient(colors: [
                            Color(0xFF424242),
                            Color(0xFF616161)
                          ])
                        : const LinearGradient(colors: [
                            Color(0xFF004D40),
                            Color(0xFF00796B)
                          ]),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: ended
                            ? Colors.grey.withOpacity(0.4)
                            : Colors.tealAccent.withOpacity(0.5)),
                  ),
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Text(ended ? '🔒' : '📚',
                            style: const TextStyle(fontSize: 20)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            msg.refTitle ?? 'Quiz',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ]),
                      const SizedBox(height: 8),
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: ended
                                ? Colors.red.withOpacity(0.3)
                                : Colors.tealAccent.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            ended ? '⛔ Quiz Ended' : '✅ Quiz Active',
                            style: TextStyle(
                                color: ended
                                    ? Colors.red[200]
                                    : Colors.tealAccent,
                                fontSize: 11,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                        const Spacer(),
                        if (!ended)
                          const Text('Tap to join →',
                              style: TextStyle(
                                  color: Colors.tealAccent,
                                  fontSize: 11)),
                      ]),
                      const SizedBox(height: 4),
                      Text(
                        'Shared by ${msg.senderName} · ${DateFormat('h:mm a').format(msg.timestamp)}',
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 10),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ── Shared Tournament Card in Chat ────────────────────────────────────────────

class _SharedTournamentCard extends StatelessWidget {
  final ChatMessage msg;
  final bool isMe;
  final String collegeId;

  const _SharedTournamentCard(
      {required this.msg, required this.isMe, required this.collegeId});

  Future<void> _open(BuildContext context) async {
    if (msg.refId == null) return;
    try {
      final tournament = await TournamentService.fetchTournament(msg.refId!);
      if (!context.mounted) return;
      if (tournament == null) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tournament not found')));
        return;
      }
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => TournamentDetailScreen(tournament: tournament)));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (msg.refId == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Align(
        alignment:
            isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.72),
          child: StreamBuilder<bool>(
            stream:
                CollegeChatService.tournamentEndedStream(msg.refId!),
            builder: (context, snap) {
              final ended = snap.data ?? false;
              return GestureDetector(
                onTap: () => _open(context),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: ended
                        ? const LinearGradient(colors: [
                            Color(0xFF424242),
                            Color(0xFF616161)
                          ])
                        : const LinearGradient(colors: [
                            Color(0xFF4A148C),
                            Color(0xFF7B1FA2)
                          ]),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: ended
                            ? Colors.grey.withOpacity(0.4)
                            : Colors.purpleAccent.withOpacity(0.5)),
                  ),
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Text(ended ? '🔒' : '🏆',
                            style: const TextStyle(fontSize: 20)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            msg.refTitle ?? 'Tournament',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ]),
                      const SizedBox(height: 8),
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: ended
                                ? Colors.red.withOpacity(0.3)
                                : Colors.purpleAccent.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            ended
                                ? '⛔ Tournament Ended'
                                : '✅ Tournament Active',
                            style: TextStyle(
                                color: ended
                                    ? Colors.red[200]
                                    : Colors.purpleAccent,
                                fontSize: 11,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                        const Spacer(),
                        if (!ended)
                          const Text('Tap to view →',
                              style: TextStyle(
                                  color: Colors.purpleAccent,
                                  fontSize: 11)),
                      ]),
                      const SizedBox(height: 4),
                      Text(
                        'Shared by ${msg.senderName} · ${DateFormat('h:mm a').format(msg.timestamp)}',
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 10),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TAB 2 — MEMBERS
// ═══════════════════════════════════════════════════════════════════════════════

class _MembersTab extends StatelessWidget {
  final String collegeId;
  const _MembersTab({required this.collegeId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<CollegeMemberModel>>(
      stream: CollegeService.membersStream(collegeId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Colors.white));
        }
        final members = snap.data ?? [];
        if (members.isEmpty) {
          return const Center(
              child: Text('No members yet',
                  style: TextStyle(color: Colors.white60)));
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: members.length,
          itemBuilder: (_, i) {
            final m = members[i];
            final rank = i + 1;
            return Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: rank <= 3
                        ? _rankColor(rank).withOpacity(0.5)
                        : Colors.white.withOpacity(0.1)),
              ),
              child: Row(
                children: [
                  // Rank medal
                  SizedBox(
                    width: 36,
                    child: rank <= 3
                        ? Text(_rankEmoji(rank),
                            style: const TextStyle(fontSize: 24),
                            textAlign: TextAlign.center)
                        : Text('#$rank',
                            style: const TextStyle(
                                color: Colors.white60,
                                fontWeight: FontWeight.bold,
                                fontSize: 14),
                            textAlign: TextAlign.center),
                  ),
                  const SizedBox(width: 12),
                  // Avatar placeholder
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: Colors.teal.withOpacity(0.3),
                    child: Text(
                        m.name.isNotEmpty
                            ? m.name[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(m.name,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 15),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        Text(m.branch,
                            style: const TextStyle(
                                color: Colors.white60, fontSize: 12)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('${m.xp} XP',
                          style: const TextStyle(
                              color: Colors.tealAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 14)),
                      const Text('Total XP',
                          style: TextStyle(
                              color: Colors.white38, fontSize: 10)),
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

  static Color _rankColor(int rank) {
    switch (rank) {
      case 1: return AppColors.tournamentGold;
      case 2: return AppColors.tournamentSilver;
      case 3: return AppColors.tournamentBronze;
      default: return Colors.white;
    }
  }

  static String _rankEmoji(int rank) {
    switch (rank) {
      case 1: return '🥇';
      case 2: return '🥈';
      case 3: return '🥉';
      default: return '';
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TAB 3 — GLOBAL COLLEGE RANKINGS
// ═══════════════════════════════════════════════════════════════════════════════

class _RankingsTab extends StatelessWidget {
  const _RankingsTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection(FirestorePaths.colleges)
          .orderBy('totalXp', descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Colors.white));
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(
              child: Text('No colleges yet',
                  style: TextStyle(color: Colors.white60)));
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final d = docs[i].data();
            final rank = i + 1;
            final name = d['name'] as String? ?? 'College';
            final totalXp = (d['totalXp'] as int?) ?? 0;
            final memberCount = (d['memberCount'] as int?) ?? 0;

            return Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                gradient: rank == 1
                    ? LinearGradient(colors: [
                        AppColors.tournamentGold.withOpacity(0.2),
                        Colors.transparent
                      ])
                    : null,
                color: rank == 1 ? null : Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: rank <= 3
                        ? _rankColor(rank).withOpacity(0.5)
                        : Colors.white.withOpacity(0.1)),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 40,
                    child: rank <= 3
                        ? Text(_rankEmoji(rank),
                            style: const TextStyle(fontSize: 26),
                            textAlign: TextAlign.center)
                        : Text('#$rank',
                            style: const TextStyle(
                                color: Colors.white60,
                                fontWeight: FontWeight.bold,
                                fontSize: 15),
                            textAlign: TextAlign.center),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: TextStyle(
                                color: rank == 1
                                    ? AppColors.tournamentGold
                                    : Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        Text('$memberCount members',
                            style: const TextStyle(
                                color: Colors.white60, fontSize: 12)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('${_formatXp(totalXp)} XP',
                          style: TextStyle(
                              color: rank == 1
                                  ? AppColors.tournamentGold
                                  : Colors.tealAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 15)),
                      const Text('Total XP',
                          style:
                              TextStyle(color: Colors.white38, fontSize: 10)),
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

  static Color _rankColor(int rank) {
    switch (rank) {
      case 1: return AppColors.tournamentGold;
      case 2: return AppColors.tournamentSilver;
      case 3: return AppColors.tournamentBronze;
      default: return Colors.white;
    }
  }

  static String _rankEmoji(int rank) {
    switch (rank) {
      case 1: return '🥇';
      case 2: return '🥈';
      case 3: return '🥉';
      default: return '';
    }
  }

  static String _formatXp(int xp) {
    if (xp >= 1000000) return '${(xp / 1000000).toStringAsFixed(1)}M';
    if (xp >= 1000) return '${(xp / 1000).toStringAsFixed(1)}K';
    return xp.toString();
  }
}