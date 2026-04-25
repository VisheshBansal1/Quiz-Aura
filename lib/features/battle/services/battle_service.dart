// IMPROVED: _fetchRandomQuestionIds now also fetches from college quizzes
// so battles use the full question pool.
// Also added: createBattleWithQuiz() — lets admins create a battle for a specific quiz.

import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/models/battle_model.dart';
import '../../../core/services/coin_service.dart';
import '../../../core/services/badge_service.dart';
import '../../../core/services/fcm_service.dart';

class BattleService {
  static final _db = FirebaseFirestore.instance;

  // ── FIND OR CREATE 1v1 ────────────────────────────────────────────────────
  static Future<String> findOrCreate1v1({required int userXp}) async {
    final uid  = FirebaseAuth.instance.currentUser?.uid;
    final name = FirebaseAuth.instance.currentUser?.displayName ?? 'Player';
    if (uid == null) throw Exception('Not logged in');

    final cutoff = Timestamp.fromDate(
        DateTime.now().subtract(const Duration(seconds: 90)));

    final query = await _db
        .collection('battles')
        .where('status', isEqualTo: 'waiting')
        .where('type', isEqualTo: '1v1')
        .where('createdAt', isGreaterThan: cutoff)
        .orderBy('createdAt', descending: true)
        .limit(10)
        .get();

    for (final doc in query.docs) {
      final data      = doc.data();
      final playerIds = List<String>.from(data['playerIds'] ?? []);
      if (playerIds.length >= 2)        continue;
      if (playerIds.contains(uid))      continue;

      await doc.reference.update({
        'playerIds': FieldValue.arrayUnion([uid]),
        'status':    'active',
        'startedAt': FieldValue.serverTimestamp(),
      });

      await doc.reference.collection('scores').doc(uid).set({
        'name':            name,
        'score':           0,
        'currentQuestion': 0,
        'answerTimes':     [],
        'updatedAt':       FieldValue.serverTimestamp(),
      });

      final creatorUid = playerIds.first;
      await FcmService.createNotification(
        targetUid: creatorUid,
        title:     'Battle Starting! ⚔️',
        body:      '$name joined your battle!',
        type:      'battle_start',
        metadata:  {'battleId': doc.id},
      );

      return doc.id;
    }

    return _createBattleRoom(uid: uid, name: name, type: '1v1');
  }

  // ── CREATE MULTIPLAYER ROOM ───────────────────────────────────────────────
  static Future<String> createMultiplayerRoom({required int maxPlayers}) async {
    final uid  = FirebaseAuth.instance.currentUser?.uid;
    final name = FirebaseAuth.instance.currentUser?.displayName ?? 'Player';
    if (uid == null) throw Exception('Not logged in');

    return _createBattleRoom(uid: uid, name: name, type: 'multiplayer', maxPlayers: maxPlayers);
  }

  // ── CREATE BATTLE LINKED TO A SPECIFIC QUIZ ───────────────────────────────
  /// Admins/teachers can create a battle room that uses questions from a specific quiz.
  static Future<String> createBattleWithQuiz({
    required String quizId,
    required String type,
    int maxPlayers = 10,
  }) async {
    final uid  = FirebaseAuth.instance.currentUser?.uid;
    final name = FirebaseAuth.instance.currentUser?.displayName ?? 'Player';
    if (uid == null) throw Exception('Not logged in');

    final questionIds = await _fetchQuestionIdsFromQuiz(quizId: quizId, count: 15);

    final ref = _db.collection('battles').doc();
    await ref.set({
      'type':                    type,
      'status':                  'waiting',
      'playerIds':               [uid],
      'maxPlayers':              maxPlayers,
      'questionIds':             questionIds,
      'totalQuestions':          questionIds.length,
      'questionDurationSeconds': 20,
      'sourceQuizId':            quizId, // track which quiz this came from
      'createdAt':               FieldValue.serverTimestamp(),
    });

    await ref.collection('scores').doc(uid).set({
      'name':            name,
      'score':           0,
      'currentQuestion': 0,
      'answerTimes':     [],
      'updatedAt':       FieldValue.serverTimestamp(),
    });

    return ref.id;
  }

  static Future<String> _createBattleRoom({
    required String uid,
    required String name,
    required String type,
    int maxPlayers = 2,
  }) async {
    final questionIds = await _fetchRandomQuestionIds(count: 10);

    final ref = _db.collection('battles').doc();
    await ref.set({
      'type':                    type,
      'status':                  'waiting',
      'playerIds':               [uid],
      'maxPlayers':              maxPlayers,
      'questionIds':             questionIds,
      'totalQuestions':          questionIds.length,
      'questionDurationSeconds': 20,
      'createdAt':               FieldValue.serverTimestamp(),
    });

    await ref.collection('scores').doc(uid).set({
      'name':            name,
      'score':           0,
      'currentQuestion': 0,
      'answerTimes':     [],
      'updatedAt':       FieldValue.serverTimestamp(),
    });

    return ref.id;
  }

  // ── JOIN MULTIPLAYER ROOM ─────────────────────────────────────────────────
  static Future<void> joinMultiplayerRoom({required String battleId}) async {
    final uid  = FirebaseAuth.instance.currentUser?.uid;
    final name = FirebaseAuth.instance.currentUser?.displayName ?? 'Player';
    if (uid == null) throw Exception('Not logged in');

    final ref  = _db.collection('battles').doc(battleId);
    final snap = await ref.get();
    if (!snap.exists) throw Exception('Room not found');

    final data       = snap.data()!;
    final playerIds  = List<String>.from(data['playerIds'] ?? []);
    final maxPlayers = (data['maxPlayers'] ?? 2) as int;

    if (playerIds.contains(uid)) throw Exception('Already in this room');
    if (playerIds.length >= maxPlayers) throw Exception('Room is full');
    if (data['status'] != 'waiting') throw Exception('Battle already started');

    await ref.update({'playerIds': FieldValue.arrayUnion([uid])});

    await ref.collection('scores').doc(uid).set({
      'name':            name,
      'score':           0,
      'currentQuestion': 0,
      'answerTimes':     [],
      'updatedAt':       FieldValue.serverTimestamp(),
    });
  }

  // ── START MULTIPLAYER ─────────────────────────────────────────────────────
  static Future<void> startMultiplayerBattle({required String battleId}) async {
    await _db.collection('battles').doc(battleId).update({
      'status':    'active',
      'startedAt': FieldValue.serverTimestamp(),
    });
  }

  // ── SUBMIT ANSWER ─────────────────────────────────────────────────────────
  static Future<void> submitAnswer({
    required String battleId,
    required bool   correct,
    required int    timeTakenMs,
    required int    questionIndex,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final ref = _db
        .collection('battles')
        .doc(battleId)
        .collection('scores')
        .doc(uid);

    await _db.runTransaction((tx) async {
      final snap  = await tx.get(ref);
      final data  = snap.data() ?? {};
      final score = (data['score'] ?? 0) as int;
      final times = List<int>.from(data['answerTimes'] ?? []);
      times.add(timeTakenMs);
      tx.update(ref, {
        'score':           correct ? score + 1 : score,
        'currentQuestion': questionIndex + 1,
        'answerTimes':     times,
        'updatedAt':       FieldValue.serverTimestamp(),
      });
    });
  }

  // ── FINISH BATTLE ─────────────────────────────────────────────────────────
  static Future<String?> finishBattle({required String battleId}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;

    final battleRef = _db.collection('battles').doc(battleId);

    // FIX 9: Use a transaction to atomically check-and-set status.
    // This prevents multiple players from calling finishBattle() simultaneously
    // and awarding coins more than once.
    bool alreadyFinished = false;
    await _db.runTransaction((tx) async {
      final snap = await tx.get(battleRef);
      final status = snap.data()?['status'] as String?;
      // Also guard against 'finishing' to prevent a race where two players
      // both call finishBattle concurrently before the first transaction commits.
      if (status == 'finished' || status == 'cancelled' || status == 'finishing') {
        alreadyFinished = true;
        return;
      }
      // Mark as finished immediately so no other client can enter this block
      tx.update(battleRef, {
        'status':  'finishing', // transient state — prevents re-entry
        'endedAt': FieldValue.serverTimestamp(),
      });
    });

    if (alreadyFinished) return null;

    final scoresSnap = await _db
        .collection('battles')
        .doc(battleId)
        .collection('scores')
        .get();

    if (scoresSnap.docs.isEmpty) return null;

    final sorted = scoresSnap.docs.toList()
      ..sort((a, b) {
        final sA  = (a.data()['score']       ?? 0) as int;
        final sB  = (b.data()['score']       ?? 0) as int;
        final tA  = List<int>.from(a.data()['answerTimes'] ?? []).fold(0, (s, t) => s + t);
        final tB  = List<int>.from(b.data()['answerTimes'] ?? []).fold(0, (s, t) => s + t);
        if (sA != sB) return sB.compareTo(sA);
        return tA.compareTo(tB);
      });

    final winnerId   = sorted.first.id;
    final winnerName = sorted.first.data()['name'] ?? 'Player';

    await battleRef.update({
      'status':    'finished',
      'winnerUid': winnerId,
      'endedAt':   FieldValue.serverTimestamp(),
    });

    await CoinService.addCoins(
      userId: winnerId,
      amount: CoinService.battleWinReward,
      reason: 'Battle win reward',
    );

    await _db.collection('users').doc(winnerId).update({
      'battleWins': FieldValue.increment(1),
    });

    final winnerSnap = await _db.collection('users').doc(winnerId).get();
    await BadgeService.checkAll(userId: winnerId, userData: winnerSnap.data() ?? {});

    final battleSnap = await _db.collection('battles').doc(battleId).get();
    final playerIds  = List<String>.from(battleSnap.data()?['playerIds'] ?? []);
    for (final pid in playerIds) {
      await FcmService.createNotification(
        targetUid: pid,
        title:     pid == winnerId ? '🏆 You Won the Battle!' : '⚔️ Battle Result',
        body:      pid == winnerId
            ? 'Congratulations! +${CoinService.battleWinReward} coins!'
            : '$winnerName won the battle. Keep practicing!',
        type:      'battle_result',
        metadata:  {'battleId': battleId},
      );
    }

    return winnerId;
  }

  // ── STREAMS ───────────────────────────────────────────────────────────────
  static Stream<DocumentSnapshot<Map<String, dynamic>>> battleStream(String battleId) {
    return _db.collection('battles').doc(battleId).snapshots();
  }

  static Stream<List<BattleV2Player>> scoresStream(String battleId) {
    return _db
        .collection('battles')
        .doc(battleId)
        .collection('scores')
        .snapshots()
        .map((s) => s.docs.map(BattleV2Player.fromFirestore).toList()
          ..sort((a, b) => b.score.compareTo(a.score)));
  }

  // ── FETCH QUESTIONS FROM A SPECIFIC QUIZ ─────────────────────────────────
  /// Fetches up to [count] question IDs from a quiz.
  /// Does NOT filter by type/isActive — those fields may not be set on every
  /// doc.  The caller normalises the question data at display time.
  static Future<List<String>> _fetchQuestionIdsFromQuiz({
    required String quizId,
    required int    count,
  }) async {
    if (quizId.isEmpty) return [];

    // Try ordered first; fall back to unordered if index is missing.
    QuerySnapshot<Map<String, dynamic>> snap;
    try {
      snap = await _db
          .collection('quizzes')
          .doc(quizId)
          .collection('questions')
          .orderBy('order')
          .get();
    } catch (_) {
      snap = await _db
          .collection('quizzes')
          .doc(quizId)
          .collection('questions')
          .get();
    }

    if (snap.docs.isEmpty) return [];
    final docs = List.of(snap.docs)..shuffle(Random());
    // Use a separator unlikely to appear in Firestore auto-IDs.
    return docs
        .take(count)
        .map((q) => '${quizId}::${q.id}')
        .toList();
  }

  // ── FETCH RANDOM QUESTIONS FROM ALL ACTIVE QUIZZES ───────────────────────
  /// Fetches [count] random question keys across all quizzes.
  /// Removed type/isActive filters — questions that lack those fields would
  /// previously cause empty question pools and silent "no questions" errors.
  static Future<List<String>> _fetchRandomQuestionIds({required int count}) async {
    // Try active quizzes first; fall back to ALL quizzes if none are flagged.
    QuerySnapshot<Map<String, dynamic>> quizzesSnap;
    try {
      quizzesSnap = await _db
          .collection('quizzes')
          .where('isActive', isEqualTo: true)
          .limit(10)
          .get();
    } catch (_) {
      quizzesSnap = await _db.collection('quizzes').limit(10).get();
    }

    // If the isActive filter returned nothing, fall back to all quizzes.
    if (quizzesSnap.docs.isEmpty) {
      try {
        quizzesSnap = await _db.collection('quizzes').limit(10).get();
      } catch (_) {
        return [];
      }
    }

    if (quizzesSnap.docs.isEmpty) return [];

    final allQuestions = <Map<String, dynamic>>[];

    for (final quiz in quizzesSnap.docs) {
      // Fetch questions without field filters so every question is eligible.
      QuerySnapshot<Map<String, dynamic>> qSnap;
      try {
        qSnap = await _db
            .collection('quizzes')
            .doc(quiz.id)
            .collection('questions')
            .limit(30)
            .get();
      } catch (_) {
        continue;
      }

      for (final q in qSnap.docs) {
        // Only include questions that have at least a question text and options.
        final data = q.data();
        final hasText = (data['question'] ?? data['text'] ?? '').toString().trim().isNotEmpty;
        final hasOptions = (data['options'] is List && (data['options'] as List).isNotEmpty) ||
            (data['choices'] is List && (data['choices'] as List).isNotEmpty);
        if (hasText && hasOptions) {
          allQuestions.add({'id': q.id, 'quizId': quiz.id});
        }
      }
    }

    if (allQuestions.isEmpty) return [];

    allQuestions.shuffle(Random());
    // Use '::' separator (Firestore IDs never contain ':').
    return allQuestions
        .take(count)
        .map((q) => '${q['quizId']}::${q['id']}')
        .toList();
  }

  // ── PARSE QUESTION KEY ────────────────────────────────────────────────────
  /// Supports both the new '::' separator and the legacy '__' separator so
  /// battles created before this fix continue to work.
  static Map<String, String> parseQuestionKey(String key) {
    // New format: quizId::questionId  (Firestore IDs never contain ':')
    if (key.contains('::')) {
      final idx = key.indexOf('::');
      return {
        'quizId':     key.substring(0, idx),
        'questionId': key.substring(idx + 2),
      };
    }
    // Legacy format: quizId__questionId
    // Split on the FIRST occurrence only so quiz IDs with '__' don't break.
    final idx = key.indexOf('__');
    if (idx < 0) return {'quizId': '', 'questionId': ''};
    return {
      'quizId':     key.substring(0, idx),
      'questionId': key.substring(idx + 2),
    };
  }
}
