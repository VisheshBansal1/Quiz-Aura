// ============================================================
// FILE: lib/features/college/services/college_chat_service.dart
// Handles real-time college chat messages stored in Firestore.
// Firestore path: colleges/{collegeId}/chat/{messageId}
// ============================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:QuizSphere/core/constants/firestore_paths.dart';
import '../models/chat_message_model.dart';

class CollegeChatService {
  static final _db = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> _chatCol(
          String collegeId) =>
      _db
          .collection(FirestorePaths.colleges)
          .doc(collegeId)
          .collection('chat');

  // ── Stream of last 100 messages (oldest → newest) ─────────────────────────
  static Stream<List<ChatMessage>> messagesStream(String collegeId) {
    return _chatCol(collegeId)
        .orderBy('timestamp', descending: false)
        .limitToLast(100)
        .snapshots()
        .map((s) => s.docs.map(ChatMessage.fromFirestore).toList());
  }

  // ── Fetch current user's Firestore data ───────────────────────────────────
  static Future<Map<String, dynamic>> _myData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return {};
    final snap =
        await _db.collection(FirestorePaths.users).doc(uid).get();
    return snap.data() ?? {};
  }

  // ── Send plain text message ───────────────────────────────────────────────
  static Future<void> sendText({
    required String collegeId,
    required String text,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Not logged in');
    if (text.trim().isEmpty) return;

    final d = await _myData();
    await _chatCol(collegeId).add({
      'uid': user.uid,
      'senderName': d['name'] ?? 'User',
      'senderPhotoUrl':
          (d['photoUrl'] as String?) ?? (d['profileImage'] as String?) ?? '',
      'text': text.trim(),
      'type': 'text',
      'refId': null,
      'refTitle': null,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // ── Share a quiz to college chat ──────────────────────────────────────────
  /// [quizId]    — Firestore document id under 'quizzes'
  /// [quizTitle] — Displayed in the chat card
  static Future<void> shareQuiz({
    required String collegeId,
    required String quizId,
    required String quizTitle,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Not logged in');

    final d = await _myData();
    await _chatCol(collegeId).add({
      'uid': user.uid,
      'senderName': d['name'] ?? 'User',
      'senderPhotoUrl':
          (d['photoUrl'] as String?) ?? (d['profileImage'] as String?) ?? '',
      'text': '📚 Shared a quiz: $quizTitle',
      'type': 'quiz',
      'refId': quizId,
      'refTitle': quizTitle,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // ── Share a tournament to college chat ────────────────────────────────────
  /// [tournamentId]   — Firestore document id under 'tournaments'
  /// [tournamentName] — Displayed in the chat card
  static Future<void> shareTournament({
    required String collegeId,
    required String tournamentId,
    required String tournamentName,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Not logged in');

    final d = await _myData();
    await _chatCol(collegeId).add({
      'uid': user.uid,
      'senderName': d['name'] ?? 'User',
      'senderPhotoUrl':
          (d['photoUrl'] as String?) ?? (d['profileImage'] as String?) ?? '',
      'text': '🏆 Shared a tournament: $tournamentName',
      'type': 'tournament',
      'refId': tournamentId,
      'refTitle': tournamentName,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // ── Check if a quiz is ended (live Firestore query) ───────────────────────
  /// Returns a stream: true = ended/inactive, false = still active
  static Stream<bool> quizEndedStream(String quizId) {
    return _db
        .collection(FirestorePaths.quizzes)
        .doc(quizId)
        .snapshots()
        .map((snap) {
      if (!snap.exists) return true;
      final d = snap.data() ?? {};
      final isActive = d['isActive'] as bool? ?? true;
      if (!isActive) return true;
      final endAt = (d['endAt'] as Timestamp?)?.toDate();
      if (endAt != null && DateTime.now().isAfter(endAt)) return true;
      return false;
    });
  }

  // ── Check if a tournament is ended (live Firestore query) ────────────────
  /// Returns a stream: true = finished/cancelled, false = still running
  static Stream<bool> tournamentEndedStream(String tournamentId) {
    return _db
        .collection(FirestorePaths.tournaments)
        .doc(tournamentId)
        .snapshots()
        .map((snap) {
      if (!snap.exists) return true;
      final d = snap.data() ?? {};
      final status = d['status'] as String? ?? 'upcoming';
      if (status == 'finished' || status == 'cancelled') return true;
      final endAt = (d['endAt'] as Timestamp?)?.toDate();
      if (endAt != null && DateTime.now().isAfter(endAt)) return true;
      return false;
    });
  }
}