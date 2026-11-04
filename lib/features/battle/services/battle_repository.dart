// ============================================================
// FILE: lib/features/battle/services/battle_repository.dart
// READ access for battles. Every listener is scoped to one document
// or a small bounded query, and must be cancelled by its owner.
// ============================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/constants/firestore_paths.dart';
import '../models/battle_models.dart';

class BattleHistoryPage {
  final List<BattleHistoryItem> items;
  final DocumentSnapshot<Map<String, dynamic>>? lastDoc;
  final bool hasMore;

  const BattleHistoryPage(this.items, this.lastDoc, this.hasMore);
}

class OpponentPresence {
  final int? lastSeenMs;
  final String state; // fg | bg

  const OpponentPresence(this.lastSeenMs, this.state);
}

class QueueClaim {
  final bool exists;
  final String battleId; // non-empty once someone claimed me

  const QueueClaim(this.exists, this.battleId);
}

class BattleRepository {
  BattleRepository._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static String get uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  static DocumentReference<Map<String, dynamic>> _match(String id) =>
      _db.collection(FirestorePaths.battleMatches).doc(id);

  // ── match ────────────────────────────────────────────────────────────────
  static Stream<BattleMatch?> matchStream(String battleId) {
    return _match(battleId)
        .snapshots()
        .map((s) => s.exists ? BattleMatch.fromDoc(s) : null);
  }

  static Future<BattleMatch?> matchOnce(String battleId) async {
    final s = await _match(battleId).get();
    return s.exists ? BattleMatch.fromDoc(s) : null;
  }

  /// Denied by the rules until the round opens (stops reading ahead).
  static Future<BattleQuestion?> fetchQuestion(String battleId, int index) async {
    final s = await _match(battleId).collection('questions').doc('$index').get();
    if (!s.exists) return null;
    return BattleQuestion.fromMap(s.data()!);
  }

  /// Denied by the rules until the round's reveal time.
  static Future<int?> fetchKey(String battleId, int index) async {
    final s = await _match(battleId).collection('keys').doc('$index').get();
    final v = s.data()?['correctIndex'];
    return v is num ? v.toInt() : null;
  }

  static Future<PlayerAnswer?> fetchAnswer(String battleId, int round, String playerUid) async {
    final s = await _match(battleId)
        .collection('rounds')
        .doc('$round')
        .collection('answers')
        .doc(playerUid)
        .get();
    final d = s.data();
    if (d == null) return null;
    final c = d['choice'];
    final at = d['at'];
    if (c is! num || at is! Timestamp) return null;
    return PlayerAnswer(choice: c.toInt(), atMs: at.millisecondsSinceEpoch);
  }

  /// Live answer of one player in one round (organizer only — the rules let
  /// players read the opponent's answer only after the round is revealed).
  static Stream<PlayerAnswer?> answerStream(String battleId, int round, String playerUid) {
    return _match(battleId)
        .collection('rounds')
        .doc('$round')
        .collection('answers')
        .doc(playerUid)
        .snapshots()
        .map((s) {
      final d = s.data();
      if (d == null) return null;
      final c = d['choice'];
      final at = d['at'];
      if (c is! num || at is! Timestamp) return null; // pending server time
      return PlayerAnswer(choice: c.toInt(), atMs: at.millisecondsSinceEpoch);
    });
  }

  /// "Has the opponent answered this round?" — never reveals their choice.
  static Stream<bool> ackStream(String battleId, int round, String playerUid) {
    return _match(battleId)
        .collection('rounds')
        .doc('$round')
        .collection('ack')
        .doc(playerUid)
        .snapshots()
        .map((s) => s.exists);
  }

  static Stream<OpponentPresence> presenceStream(String battleId, String playerUid) {
    return _match(battleId)
        .collection('presence')
        .doc(playerUid)
        .snapshots()
        .map((s) {
      final d = s.data();
      if (d == null) return const OpponentPresence(null, 'fg');
      final ts = d['lastSeen'];
      return OpponentPresence(
        ts is Timestamp ? ts.millisecondsSinceEpoch : null,
        (d['state'] as String?) ?? 'fg',
      );
    });
  }

  // ── queue / invites ──────────────────────────────────────────────────────
  static Stream<QueueClaim> myQueueStream() {
    return _db.collection('battleQueue').doc(uid).snapshots().map((s) {
      final d = s.data();
      return QueueClaim(s.exists, (d?['battleId'] ?? '').toString());
    });
  }

  static Stream<BattleInvite?> inviteStream(String code) {
    return _db
        .collection(FirestorePaths.battleInvites)
        .doc(code)
        .snapshots()
        .map((s) => s.exists ? BattleInvite.fromDoc(s) : null);
  }

  /// Challenges addressed to me (bounded to 5).
  static Stream<List<BattleInvite>> incomingInvites() {
    return _db
        .collection(FirestorePaths.battleInvites)
        .where('targetUid', isEqualTo: uid)
        .where('status', isEqualTo: 'waiting')
        .limit(5)
        .snapshots()
        .map((s) => s.docs.map(BattleInvite.fromDoc).toList());
  }

  // ── stats / history / leaderboard ────────────────────────────────────────
  static Stream<BattleStats> myStatsStream() {
    final id = uid;
    return _db
        .collection(FirestorePaths.battleStats)
        .doc(id)
        .snapshots()
        .map((s) => BattleStats.fromDoc(id, s.data()));
  }

  static Future<List<BattleStats>> topPlayers({int limit = 10}) async {
    final snap = await _db
        .collection(FirestorePaths.battleStats)
        .orderBy('rating', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map((d) => BattleStats.fromDoc(d.id, d.data())).toList();
  }

  static Future<BattleHistoryPage> historyPage({
    DocumentSnapshot<Map<String, dynamic>>? after,
    int limit = 15,
  }) async {
    Query<Map<String, dynamic>> q = _db
        .collection(FirestorePaths.battleStats)
        .doc(uid)
        .collection('history')
        .orderBy('completedAt', descending: true)
        .limit(limit);
    if (after != null) q = q.startAfterDocument(after);
    final snap = await q.get();
    return BattleHistoryPage(
      snap.docs.map(BattleHistoryItem.fromDoc).toList(),
      snap.docs.isEmpty ? after : snap.docs.last,
      snap.docs.length == limit,
    );
  }

  static Future<List<MapEntry<String, String>>> topics() async {
    final snap = await _db
        .collection(FirestorePaths.topics)
        .where('isActive', isEqualTo: true)
        .limit(20)
        .get();
    return snap.docs
        .map((d) => MapEntry(d.id, (d.data()['title'] ?? 'Topic').toString()))
        .toList();
  }
}
