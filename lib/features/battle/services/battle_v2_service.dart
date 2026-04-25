// ============================================================
// FILE: lib/features/battle/services/battle_v2_service.dart
// Complete 1v1 battle service:
//   - createBattle(quizId) → generates battleId, status: waiting
//   - joinBattle(battleId) → opponent joins, status → active
//   - submitResult(battleId, score) → saves to players/{uid}
//   - resolveWinner(battleId) → compares scores, sets winnerId
//   - Streams for live UI updates
// SEPARATE from existing BattleService — does not modify it.
// ============================================================

import 'package:QuizSphere/core/models/battle_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BattleV2Service {
  static final _db = FirebaseFirestore.instance;

  // ─────────────────────────────────────────────────────────────────────────
  // CREATE BATTLE
  // Host selects a quiz → battle created with status "waiting"
  // Returns the battleId (used to generate the invite link)
  // ─────────────────────────────────────────────────────────────────────────
  static Future<String> createBattle({required String quizId}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Not logged in');

    final uid = user.uid;
    final name = user.displayName ?? 'Player';

    // Verify quiz exists
    final quizSnap =
        await _db.collection('quizzes').doc(quizId).get();
    if (!quizSnap.exists) throw Exception('Quiz not found');

    final ref = _db.collection('battles').doc();

    await _db.runTransaction((tx) async {
      tx.set(ref, {
        'hostId': uid,
        'opponentId': '',
        'quizId': quizId,
        'status': 'waiting',
        'winnerId': null,
        'createdAt': FieldValue.serverTimestamp(),
        // Store quiz title for display
        'quizTitle': quizSnap.data()?['title'] ?? 'Quiz Battle',
      });

      // Register host in players subcollection
      tx.set(ref.collection('players').doc(uid), {
        'name': name,
        'score': 0,
        'submitted': false,
        'joinedAt': FieldValue.serverTimestamp(),
      });
    });

    return ref.id;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // JOIN BATTLE VIA LINK
  // Opponent joins using the deep link battleId
  // Status changes to "active" only when opponent joins
  // ─────────────────────────────────────────────────────────────────────────
  static Future<void> joinBattle({required String battleId}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Not logged in');

    final uid = user.uid;
    final name = user.displayName ?? 'Player';

    final battleRef = _db.collection('battles').doc(battleId);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(battleRef);
      if (!snap.exists) throw Exception('Battle not found');

      final data = snap.data()!;
      final status = data['status'] as String?;
      final hostId = data['hostId'] as String?;
      final existingOpponent = data['opponentId'] as String?;

      if (status != 'waiting') {
        throw Exception('This battle has already started or is finished');
      }
      if (hostId == uid) {
        throw Exception("You can't join your own battle");
      }
      if (existingOpponent != null && existingOpponent.isNotEmpty) {
        throw Exception('Battle already has an opponent');
      }

      // Update battle doc
      tx.update(battleRef, {
        'opponentId': uid,
        'status': 'active',
        'startedAt': FieldValue.serverTimestamp(),
      });

      // Register opponent in players subcollection
      tx.set(battleRef.collection('players').doc(uid), {
        'name': name,
        'score': 0,
        'submitted': false,
        'joinedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SUBMIT RESULT
  // Called when a player finishes the quiz in the battle context
  // ─────────────────────────────────────────────────────────────────────────
  static Future<void> submitResult({
    required String battleId,
    required int score,
    required int total,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('Not logged in');

    final playerRef =
        _db.collection('battles').doc(battleId).collection('players').doc(uid);

    await playerRef.update({
      'score': score,
      'total': total,
      'submitted': true,
      'submittedAt': FieldValue.serverTimestamp(),
    });

    // Attempt to resolve winner (will only resolve if both submitted)
    await _tryResolveWinner(battleId);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // RESOLVE WINNER (internal)
  // Called after each submission — only acts if both players submitted
  // ─────────────────────────────────────────────────────────────────────────
  static Future<void> _tryResolveWinner(String battleId) async {
    final battleRef = _db.collection('battles').doc(battleId);

    await _db.runTransaction((tx) async {
      final battleSnap = await tx.get(battleRef);
      if (!battleSnap.exists) return;

      final data = battleSnap.data()!;
      if (data['status'] == 'finished') return; // Already resolved

      final playersSnap =
          await battleRef.collection('players').get();

      final players = playersSnap.docs;

      // Only resolve when both players have submitted
      final allSubmitted =
          players.every((p) => p.data()['submitted'] == true);
      if (!allSubmitted) return;
      if (players.length < 2) return;

      // Determine winner by score (highest score wins)
      players.sort((a, b) {
        final sA = (a.data()['score'] ?? 0) as int;
        final sB = (b.data()['score'] ?? 0) as int;
        return sB.compareTo(sA); // descending
      });

      final topScore = (players.first.data()['score'] ?? 0) as int;
      final secondScore = (players.last.data()['score'] ?? 0) as int;

      String? winnerId;
      if (topScore != secondScore) {
        winnerId = players.first.id;
      }
      // If scores are equal → draw (winnerId stays null)

      tx.update(battleRef, {
        'status': 'finished',
        'winnerId': winnerId,
        'endedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CANCEL BATTLE (host can cancel a waiting battle)
  // ─────────────────────────────────────────────────────────────────────────
  static Future<void> cancelBattle({required String battleId}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final ref = _db.collection('battles').doc(battleId);
    final snap = await ref.get();
    if (!snap.exists) return;

    if (snap.data()?['hostId'] != uid) {
      throw Exception('Only the host can cancel this battle');
    }

    await ref.update({'status': 'cancelled'});
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STREAMS
  // ─────────────────────────────────────────────────────────────────────────
  static Stream<BattleV2Model> battleStream(String battleId) {
    return _db
        .collection('battles')
        .doc(battleId)
        .snapshots()
        .map((snap) => BattleV2Model.fromFirestore(snap));
  }

  static Stream<List<BattleV2Player>> playersStream(String battleId) {
    return _db
        .collection('battles')
        .doc(battleId)
        .collection('players')
        .snapshots()
        .map((s) => s.docs
            .map((d) => BattleV2Player.fromFirestore(d))
            .toList());
  }

  // ─────────────────────────────────────────────────────────────────────────
  // FETCH BATTLE (one-time)
  // ─────────────────────────────────────────────────────────────────────────
  static Future<BattleV2Model?> fetchBattle(String battleId) async {
    final snap = await _db.collection('battles').doc(battleId).get();
    if (!snap.exists) return null;
    return BattleV2Model.fromFirestore(snap);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DEEP LINK URL BUILDER
  // ─────────────────────────────────────────────────────────────────────────
  static String buildInviteLink(String battleId) {
    // For real deep linking, configure this domain in AndroidManifest + Info.plist
    // Using a fallback HTTPS link that can be redirected to the app
    return 'https://quizaura.app/battle/$battleId';
  }

  static String parseInviteLink(String url) {
    // Extracts battleId from deep link
    // Handles: app://battle/{id}, https://quizaura.app/battle/{id}
    final uri = Uri.tryParse(url);
    if (uri == null) return '';

    final segments = uri.pathSegments;
    if (segments.length >= 2 && segments[0] == 'battle') {
      return segments[1];
    }
    // Also handle as plain battleId
    return url.trim();
  }
}
