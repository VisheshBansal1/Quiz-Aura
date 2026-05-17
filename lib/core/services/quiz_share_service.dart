// ============================================================
// FILE: lib/core/services/quiz_share_service.dart
//
// Provides share functionality for quizzes and tournaments.
// - Copies join-code/link to clipboard
// - Posts to college chat (if user is in one)
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/firestore_paths.dart';
import '../../features/college/services/college_chat_service.dart';

class QuizShareService {
  // Real Netlify URL — links open quiz.html / tournament.html
  static const _baseUrl = 'https://quizaura.netlify.app';

  // ── Share a Quiz ──────────────────────────────────────────────────────────
  static Future<void> showQuizShareSheet({
    required BuildContext context,
    required String quizId,
    required String quizTitle,
    required String joinCode,
  }) async {
    final link = '$_baseUrl/quiz/$quizId';
    await _showShareSheet(
      context: context,
      icon: '📚',
      title: quizTitle,
      subtitle: 'Tap to open in QuizAura app',
      copyLabel: 'Copy Quiz Link',
      copyValue: link,
      onShareToChat: (collegeId, collegeName) async {
        await CollegeChatService.shareQuiz(
          collegeId: collegeId,
          quizId: quizId,
          quizTitle: quizTitle,
        );
      },
    );
  }

  // ── Share a Tournament ────────────────────────────────────────────────────
  /// Call from tournament detail screen. Shows a bottom sheet with options:
  ///   1. Share to College Chat
  ///   2. Copy Tournament Link
  static Future<void> showTournamentShareSheet({
    required BuildContext context,
    required String tournamentId,
    required String tournamentName,
  }) async {
    final link = '$_baseUrl/tournament/$tournamentId';
    await _showShareSheet(
      context: context,
      icon: '🏆',
      title: tournamentName,
      subtitle: 'Tournament',
      copyLabel: 'Copy Link',
      copyValue: link,
      onShareToChat: (collegeId, collegeName) async {
        await CollegeChatService.shareTournament(
          collegeId: collegeId,
          tournamentId: tournamentId,
          tournamentName: tournamentName,
        );
      },
    );
  }

  // ── Internal: Generic share bottom sheet ─────────────────────────────────
  static Future<void> _showShareSheet({
    required BuildContext context,
    required String icon,
    required String title,
    required String subtitle,
    required String copyLabel,
    required String copyValue,
    required Future<void> Function(String collegeId, String collegeName)
        onShareToChat,
  }) async {
    // Fetch user's college info
    final uid = FirebaseAuth.instance.currentUser?.uid;
    String? collegeId;
    String? collegeName;
    if (uid != null) {
      try {
        final userSnap = await FirebaseFirestore.instance
            .collection(FirestorePaths.users)
            .doc(uid)
            .get();
        collegeId = userSnap.data()?['collegeId'] as String?;
        collegeName = userSnap.data()?['collegeName'] as String?;
      } catch (_) {}
    }

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ShareBottomSheet(
        icon: icon,
        title: title,
        subtitle: subtitle,
        copyLabel: copyLabel,
        copyValue: copyValue,
        collegeId: collegeId,
        collegeName: collegeName,
        onShareToChat: onShareToChat,
      ),
    );
  }
}

// ── Bottom Sheet Widget ───────────────────────────────────────────────────────

class _ShareBottomSheet extends StatefulWidget {
  final String icon;
  final String title;
  final String subtitle;
  final String copyLabel;
  final String copyValue;
  final String? collegeId;
  final String? collegeName;
  final Future<void> Function(String collegeId, String collegeName)
      onShareToChat;

  const _ShareBottomSheet({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.copyLabel,
    required this.copyValue,
    this.collegeId,
    this.collegeName,
    required this.onShareToChat,
  });

  @override
  State<_ShareBottomSheet> createState() => _ShareBottomSheetState();
}

class _ShareBottomSheetState extends State<_ShareBottomSheet> {
  bool _sharing = false;
  bool _shared = false;

  Future<void> _shareToChat() async {
    if (_sharing || _shared) return;
    if (widget.collegeId == null) return;
    setState(() => _sharing = true);
    try {
      await widget.onShareToChat(
          widget.collegeId!, widget.collegeName ?? '');
      if (!mounted) return;
      setState(() {
        _sharing = false;
        _shared = true;
      });
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Shared to College Chat!'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _sharing = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _copy() {
    Clipboard.setData(ClipboardData(text: widget.copyValue));
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('📋 ${widget.copyLabel} copied!'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: MediaQuery.of(context).padding.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white30,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // Card preview
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.15)),
            ),
            child: Row(
              children: [
                Text(widget.icon, style: const TextStyle(fontSize: 32)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.title,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text(widget.subtitle,
                          style: const TextStyle(
                              color: Colors.white60, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          const Text('Share via',
              style: TextStyle(
                  color: Colors.white60,
                  fontSize: 12,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 14),

          // Share to College Chat button
          if (widget.collegeId != null)
            _ShareOption(
              icon: Icons.chat_bubble_outline,
              color: Colors.teal,
              label: 'Share to College Chat',
              sublabel: widget.collegeName ?? 'Your College',
              loading: _sharing,
              done: _shared,
              onTap: _shareToChat,
            ),
          if (widget.collegeId != null) const SizedBox(height: 10),

          // Copy button
          _ShareOption(
            icon: Icons.copy_rounded,
            color: Colors.blueAccent,
            label: widget.copyLabel,
            sublabel: widget.copyValue,
            loading: false,
            done: false,
            onTap: _copy,
          ),

          if (widget.collegeId == null) ...[
            const SizedBox(height: 12),
            const Text(
              'Join a college to share directly to your college chat!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }
}

class _ShareOption extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String sublabel;
  final bool loading;
  final bool done;
  final VoidCallback onTap;

  const _ShareOption({
    required this.icon,
    required this.color,
    required this.label,
    required this.sublabel,
    required this.loading,
    required this.done,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading || done ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: loading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: color))
                  : Icon(done ? Icons.check : icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(done ? 'Shared!' : label,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14)),
                  Text(sublabel,
                      style:
                          const TextStyle(color: Colors.white38, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Icon(Icons.chevron_right,
                color: Colors.white30, size: 20),
          ],
        ),
      ),
    );
  }
}