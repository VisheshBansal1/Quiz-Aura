// ============================================================
// FILE: lib/features/battle/services/battle_duel_service.dart
// All battle WRITES (free Spark plan — Firestore + security rules,
// no Cloud Functions). Every method here maps to a rule in
// firestore.battle.rules that independently re-validates it, so a
// modified client cannot skip the checks below.
// ============================================================

import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart' show FirebaseException;

import '../../../core/constants/firestore_paths.dart';
import '../engine/battle_engine.dart';
import '../models/battle_models.dart';
import 'battle_question_pool.dart';
import 'server_clock.dart';

class BattleException implements Exception {
  final String message;
  final String code;

  const BattleException(this.message, [this.code = 'error']);

  bool get isRetryable => code == 'unavailable' || code == 'network' || code == 'timeout';

  @override
  String toString() => message;
}

enum AnswerResult { accepted, duplicate, rejected }

class BattleDuelService {
  BattleDuelService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static String get uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  static CollectionReference<Map<String, dynamic>> get _matches =>
      _db.collection(FirestorePaths.battleMatches);
  static CollectionReference<Map<String, dynamic>> get _queue => _db.collection('battleQueue');
  static CollectionReference<Map<String, dynamic>> get _invites =>
      _db.collection(FirestorePaths.battleInvites);
  static CollectionReference<Map<String, dynamic>> get _stats =>
      _db.collection(FirestorePaths.battleStats);

  static BattleException _wrap(Object e) {
    if (e is BattleException) return e;
    if (e is FirebaseException) {
      switch (e.code) {
        case 'unavailable':
          return const BattleException(
              'Cannot reach the server. Check your connection.', 'unavailable');
        case 'permission-denied':
          return const BattleException(
              'That action is not allowed right now.', 'permission-denied');
        case 'aborted':
          return const BattleException('Busy — please try again.', 'aborted');
        default:
          return BattleException(e.message ?? 'Something went wrong.', e.code);
      }
    }
    if (e is TimeoutException) {
      return const BattleException('The request timed out.', 'timeout');
    }
    return const BattleException('Something went wrong. Please try again.');
  }

  // ── settings / profile ───────────────────────────────────────────────────
  static BattleSettings? _settingsCache;
  static int _settingsAt = 0;

  /// Optional admin override at appConfig/battle (ignored if unreadable).
  static Future<BattleSettings> loadSettings() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_settingsCache != null && now - _settingsAt < 5 * 60 * 1000) return _settingsCache!;
    Map<String, dynamic>? raw;
    try {
      final s = await _db.collection('appConfig').doc('battle').get();
      raw = s.data();
    } catch (_) {
      raw = null;
    }
    _settingsCache = BattleSettings.sanitized(raw);
    _settingsAt = now;
    return _settingsCache!;
  }

  static Future<BattlePlayer> myProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    final id = user?.uid ?? '';
    String name = user?.displayName ?? '';
    String photo = user?.photoURL ?? '';
    try {
      final u = await _db.collection(FirestorePaths.users).doc(id).get();
      final d = u.data();
      if (d != null) {
        if (d['name'] is String && (d['name'] as String).trim().isNotEmpty) {
          name = d['name'] as String;
        }
        final p = d['photoUrl'] ?? d['profileImage'];
        if (p is String && p.isNotEmpty) photo = p;
      }
    } catch (_) {}
    if (name.trim().isEmpty) name = 'Player';
    if (name.length > 40) name = name.substring(0, 40);
    final stats = await _myStats();
    return BattlePlayer(
      uid: id,
      name: name,
      photoUrl: photo,
      rating: stats.rating,
      played: stats.played,
      wins: stats.wins,
      ready: false,
    );
  }

  static Future<BattleStats> _myStats() async {
    final s = await _stats.doc(uid).get();
    return BattleStats.fromDoc(uid, s.data());
  }

  // ── resume guard ─────────────────────────────────────────────────────────
  /// A live, unfinished battle this player is in (client-side guard).
  static Future<String?> findLiveBattleId() async {
    final snap = await _matches
        .where('playerIds', arrayContains: uid)
        .where('endsAtMs', isGreaterThan: ServerClock.nowMs)
        .limit(5)
        .get();
    for (final d in snap.docs) {
      final m = BattleMatch.fromDoc(d);
      if (m.status == BattleStatus.live && m.forfeit == null) return m.id;
    }
    return null;
  }

  // ── question selection ───────────────────────────────────────────────────
  // Order (cheapest first, AI last):
  //   1. your existing question bank (many quizzes sampled until enough)
  //   2. the shared AI pool (battleQuestionPool) — cheap reads, no AI call
  //   3. AI generation of ONE batch into the pool, only while the pool is low
  // Picked questions are cached for 5 minutes (and prefetched while searching
  // / waiting in a room) so the battle never waits on this.
  static List<BankQuestion>? _pickCache;
  static String _pickCacheKey = '';
  static int _pickCacheAt = 0;

  static void _clearPickCache() {
    _pickCache = null;
  }

  /// Fire-and-forget: warm the cache while the player is searching / waiting.
  static Future<void> prefetchQuestions(String category) async {
    try {
      final settings = await loadSettings();
      await pickQuestions(category, settings.questionCount);
    } catch (_) {
      // Surfaced later, when the questions are actually needed.
    }
  }

  static Future<List<BankQuestion>> pickQuestions(String category, int count) async {
    final key = '$category|$count';
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (_pickCache != null &&
        _pickCacheKey == key &&
        nowMs - _pickCacheAt < 5 * 60 * 1000 &&
        _pickCache!.length == count) {
      return _pickCache!;
    }
    final picked = await _collectQuestions(category, count);
    _pickCache = picked;
    _pickCacheKey = key;
    _pickCacheAt = nowMs;
    return picked;
  }

  static Future<List<BankQuestion>> _collectQuestions(String category, int count) async {
    final rnd = Random.secure();
    final seen = <String>{};
    final all = <BankQuestion>[];

    void add(Iterable<BankQuestion> qs) {
      for (final q in qs) {
        if (seen.add(BattleQuestionPool.docIdFor('x', q.text))) all.add(q);
      }
    }

    // 1) existing bank — sample up to 8 quizzes until we have plenty.
    try {
      add(await _fromBank(category, count, rnd));
      if (all.length < count && category.isNotEmpty) {
        add(await _fromBank('', count, rnd)); // widen to every topic
      }
    } catch (_) {
      // Bank unreadable: continue with the pool.
    }

    // 2) shared AI pool (no AI call).
    if (all.length < count) {
      try {
        add(await BattleQuestionPool.draw(category, count - all.length));
      } catch (_) {}
    }

    // 3) pool is low/empty → generate ONE batch (locked + rate-limited), reuse it.
    if (all.length < count) {
      try {
        add(await BattleQuestionPool.ensureFilled(category));
        if (all.length < count) {
          add(await BattleQuestionPool.draw(category, count - all.length));
        }
      } catch (_) {}
    }
    // Specific topic still short? fall back to the general pool.
    if (all.length < count && category.isNotEmpty) {
      try {
        add(await BattleQuestionPool.draw('', count - all.length));
        if (all.length < count) add(await BattleQuestionPool.ensureFilled(''));
        if (all.length < count) {
          add(await BattleQuestionPool.draw('', count - all.length));
        }
      } catch (_) {}
    }

    if (all.length < count) {
      throw const BattleException(
        'Could not prepare questions right now. Please try again in a moment.',
        'no-questions',
      );
    }
    all.shuffle(rnd);
    return all.take(count).toList();
  }

  static Future<List<BankQuestion>> _fromBank(String cat, int count, Random rnd) async {
    Query<Map<String, dynamic>> q = _db.collection(FirestorePaths.quizzes);
    if (cat.isNotEmpty) q = q.where('topicId', isEqualTo: cat);
    var quizzes = await q.where('isActive', isEqualTo: true).limit(30).get();
    var docs = quizzes.docs.where((d) => d.data()['visibility'] != 'private').toList()
      ..shuffle(rnd);
    final out = <BankQuestion>[];
    final seen = <String>{};
    // Sample quizzes one by one until there are enough questions (stops early,
    // so a big bank costs only a few reads).
    for (final quiz in docs.take(8)) {
      final qs = await quiz.reference
          .collection(FirestorePaths.questions)
          .where('isActive', isEqualTo: true)
          .limit(15)
          .get();
      for (final d in qs.docs) {
        final bq = BankQuestion.fromBank(quiz.id, d.id, d.data()); // mcq only
        if (bq != null && seen.add(bq.text)) out.add(bq);
      }
      if (out.length >= count * 2) break;
    }
    return out;
  }

  /// Host-only (rules enforce it). Chunked so each batch stays within the
  /// rules' document-access limit; the marker doc is written last.
  static Future<void> _writeQuestions(String battleId, List<BankQuestion> qs) async {
    final matchRef = _matches.doc(battleId);
    for (var start = 0; start < qs.length; start += 3) {
      final batch = _db.batch();
      final end = min(start + 3, qs.length);
      for (var i = start; i < end; i++) {
        final q = qs[i];
        batch.set(matchRef.collection('questions').doc('$i'), {
          'index': i,
          'text': q.text,
          'options': q.options,
          'srcQuizId': q.quizId,
          'srcQid': q.questionId,
        });
        batch.set(matchRef.collection('keys').doc('$i'), {
          'index': i,
          'correctIndex': q.correctIndex,
          'srcQuizId': q.quizId,
          'srcQid': q.questionId,
        });
      }
      await batch.commit();
    }
    await matchRef.collection('setup').doc('ready').set({'at': FieldValue.serverTimestamp()});
  }

  // ── quick match ──────────────────────────────────────────────────────────
  static Future<void> enqueue(String category) async {
    try {
      await ServerClock.sync();
      final live = await findLiveBattleId();
      if (live != null) {
        throw const BattleException('You already have a battle in progress.', 'active');
      }
      final me = await myProfile();
      final now = ServerClock.nowMs;
      await _queue.doc(uid).set({
        'uid': uid,
        'name': me.name,
        'photoUrl': me.photoUrl,
        'rating': me.rating,
        'played': me.played,
        'wins': me.wins,
        'category': category,
        'enqueuedAtMs': now,
        'expiresAtMs': now + BattleConfig.queueTtlMs,
        'claimedBy': '',
        'battleId': '',
      });
      prefetchQuestions(category); // warm the cache while searching
    } catch (e) {
      throw _wrap(e);
    }
  }

  static Future<void> cancelQueue() async {
    try {
      await _queue.doc(uid).delete();
    } catch (_) {}
  }

  /// Looks for a compatible waiting player and claims them atomically.
  /// Returns the new battle id if THIS device created the match (it is then
  /// the host and writes the questions); null if nobody suitable yet.
  static Future<String?> tryMatch({
    required String category,
    required int elapsedSec,
  }) async {
    try {
      final me = await myProfile();
      final now = ServerClock.nowMs;
      final snap = await _queue
          .where('category', isEqualTo: category)
          .where('claimedBy', isEqualTo: '')
          .where('expiresAtMs', isGreaterThan: now)
          .orderBy('expiresAtMs')
          .limit(20)
          .get();
      final window = BattleEngine.searchWindow(elapsedSec);
      final cands = snap.docs.where((d) {
        if (d.id == uid) return false;
        final r = d.data()['rating'];
        return r is num && (r.toInt() - me.rating).abs() <= window;
      }).toList()
        ..sort((a, b) {
          final da = ((a.data()['rating'] as num).toInt() - me.rating).abs();
          final db = ((b.data()['rating'] as num).toInt() - me.rating).abs();
          return da.compareTo(db);
        });
      if (cands.isEmpty) return null;

      final settings = await loadSettings();
      final questions = await pickQuestions(category, settings.questionCount);

      for (final cand in cands.take(3)) {
        final matchRef = _matches.doc();
        final cd = cand.data();
        final opp = BattlePlayer(
          uid: cand.id,
          name: (cd['name'] ?? 'Player').toString(),
          photoUrl: (cd['photoUrl'] ?? '').toString(),
          rating: (cd['rating'] as num).toInt(),
          played: (cd['played'] as num?)?.toInt() ?? 0,
          wins: (cd['wins'] as num?)?.toInt() ?? 0,
          ready: false,
        );
        final ids = [uid, cand.id]..sort();

        final claimed = await _db.runTransaction<bool>((tx) async {
          final mine = await tx.get(_queue.doc(uid));
          final theirs = await tx.get(cand.reference);
          if (!mine.exists || (mine.data()?['claimedBy'] ?? '') != '') return false;
          final t = theirs.data();
          if (!theirs.exists || t == null || (t['claimedBy'] ?? '') != '') return false;
          if ((t['expiresAtMs'] as num).toInt() <= ServerClock.nowMs) return false;
          // Fresh on every transaction attempt so the rules' time window holds.
          final startAt = ServerClock.nowMs + BattleConfig.quickLeadMs;
          tx.update(cand.reference, {'claimedBy': uid, 'battleId': matchRef.id});
          tx.set(matchRef, {
            'mode': 'quick',
            'status': 'live',
            'category': category,
            'hostId': uid,
            'playerIds': ids,
            'players': {uid: me.toMap(), cand.id: opp.toMap()},
            'settings': settings.toMap(),
            'roomCode': null,
            'startAtMs': startAt,
            'endsAtMs': BattleEngine.endsAtMs(startAt, settings),
            'settled': <String, dynamic>{},
            'createdAt': FieldValue.serverTimestamp(),
          });
          tx.delete(_queue.doc(uid));
          return true;
        });
        if (claimed) {
          _clearPickCache();
          try {
            await _writeQuestions(matchRef.id, questions);
          } catch (e) {
            await cancelBattle(matchRef.id, 'start_failed').catchError((_) {});
            throw _wrap(e);
          }
          return matchRef.id;
        }
      }
      return null;
    } catch (e) {
      throw _wrap(e);
    }
  }

  // ── rooms / invitations ──────────────────────────────────────────────────
  /// mode: 'private' | 'friend' (friend needs targetUid) | 'organized'.
  /// 'organized': the creator is a REFEREE — they never play, they watch both
  /// players live and can see the correct answers. Returns {battleId, code}.
  static Future<Map<String, String>> createRoom({
    required String mode,
    String targetUid = '',
    String category = '',
  }) async {
    try {
      if (mode != 'private' && mode != 'friend' && mode != 'organized') {
        throw const BattleException('Invalid battle mode.');
      }
      if (mode == 'friend' && (targetUid.isEmpty || targetUid == uid)) {
        throw const BattleException('Choose a player to challenge.');
      }
      final organized = mode == 'organized';
      await ServerClock.sync();
      if (!organized) {
        final live = await findLiveBattleId();
        if (live != null) {
          throw const BattleException('You already have a battle in progress.', 'active');
        }
      }
      final me = await myProfile();
      final settings = await loadSettings();
      final now = ServerClock.nowMs;

      for (var attempt = 0; attempt < 5; attempt++) {
        final code = BattleEngine.generateRoomCode();
        final matchRef = _matches.doc();
        final batch = _db.batch();
        batch.set(matchRef, {
          'mode': mode,
          'status': 'waiting',
          'category': category,
          'hostId': uid,
          if (organized) 'organizerId': uid,
          'playerIds': organized ? <String>[] : [uid],
          'players': organized ? <String, dynamic>{} : {uid: me.toMap()},
          'settings': settings.toMap(),
          'roomCode': code,
          'settled': <String, dynamic>{},
          'createdAt': FieldValue.serverTimestamp(),
        });
        batch.set(_invites.doc(code), {
          'code': code,
          'mode': mode,
          'battleId': matchRef.id,
          'hostId': uid,
          'hostName': me.name,
          'targetUid': mode == 'friend' ? targetUid : '',
          'guestId': '',
          'guest2Id': '',
          'status': 'waiting',
          'expiresAtMs': now + BattleConfig.inviteTtlMs,
          'createdAt': FieldValue.serverTimestamp(),
        });
        try {
          await batch.commit();
          // The host picks the questions — warm the cache while players join.
          prefetchQuestions(category);
          return {'battleId': matchRef.id, 'code': code};
        } on FirebaseException catch (e) {
          // A code collision turns the invite 'create' into an update, which
          // the rules refuse — just try another code.
          if (e.code != 'permission-denied' || attempt == 4) rethrow;
        }
      }
      throw const BattleException('Could not create a room. Please try again.');
    } catch (e) {
      throw _wrap(e);
    }
  }

  /// Joins by code. Returns the battle id.
  static Future<String> joinRoom(String rawCode) async {
    try {
      final code = BattleEngine.normalizeRoomCode(rawCode);
      if (code.length < 4) throw const BattleException('Enter a valid room code.');
      await ServerClock.sync();
      final live = await findLiveBattleId();
      if (live != null) {
        throw const BattleException('You already have a battle in progress.', 'active');
      }
      final me = await myProfile();
      final invRef = _invites.doc(code);

      final battleId = await _db.runTransaction<String>((tx) async {
        final inv = await tx.get(invRef);
        if (!inv.exists) throw const BattleException('Room code not found.', 'not-found');
        final i = inv.data()!;
        final status = (i['status'] ?? '').toString();
        if (status != 'waiting') {
          throw BattleException('This invitation is $status.', 'closed');
        }
        if ((i['expiresAtMs'] as num).toInt() <= ServerClock.nowMs) {
          throw const BattleException('This invitation has expired.', 'expired');
        }
        final host = (i['hostId'] ?? '').toString();
        if (host == uid) {
          throw const BattleException('You created this room — share the code with a friend.');
        }
        final target = (i['targetUid'] ?? '').toString();
        if (target.isNotEmpty && target != uid) {
          throw const BattleException('This invitation is for another player.');
        }
        final mRef = _matches.doc((i['battleId'] ?? '').toString());
        final m = await tx.get(mRef);
        final md = m.data();
        final isOrg = md != null && md['mode'] == 'organized';
        final seats = md == null ? 99 : (md['playerIds'] as List).length;
        if (!m.exists || md == null || md['status'] != 'waiting' ||
            (isOrg ? seats > 1 : seats != 1)) {
          throw const BattleException('This room is no longer available.', 'closed');
        }
        if (md['mode'] == 'organized') {
          // Referee room: the first two people to join are the players.
          final current = List<String>.from(md['playerIds'] as List);
          if (current.contains(uid)) {
            throw const BattleException('You already joined this room.');
          }
          if (current.isEmpty) {
            tx.update(invRef, {'guestId': uid});
            tx.update(mRef, {
              'playerIds': [uid],
              'players.$uid': me.toMap(),
            });
          } else {
            final ids = [current.first, uid]..sort();
            tx.update(invRef, {'guest2Id': uid, 'status': 'accepted'});
            tx.update(mRef, {
              'status': 'lobby',
              'playerIds': ids,
              'players.$uid': me.toMap(),
            });
          }
          return mRef.id;
        }
        final ids = [host, uid]..sort();
        tx.update(invRef, {'status': 'accepted', 'guestId': uid});
        tx.update(mRef, {
          'status': 'lobby',
          'playerIds': ids,
          'players.$uid': me.toMap(),
        });
        return mRef.id;
      });
      return battleId;
    } catch (e) {
      throw _wrap(e);
    }
  }

  static Future<void> declineInvite(String code) async {
    try {
      await _invites.doc(code).update({'status': 'declined'});
    } catch (e) {
      throw _wrap(e);
    }
  }

  static Future<void> setReady(String battleId, bool ready) async {
    try {
      await _matches.doc(battleId).update({'players.$uid.ready': ready});
    } catch (e) {
      throw _wrap(e);
    }
  }

  /// Host only, once both players are ready: writes the questions then flips
  /// the room to live with a short synchronized lead-in.
  static Future<void> startRoomBattle(BattleMatch m) async {
    try {
      if (m.hostId != uid) return;
      final qs = await pickQuestions(m.category, m.settings.questionCount);
      await _writeQuestions(m.id, qs);
      final startAt = ServerClock.nowMs + BattleConfig.roomLeadMs;
      await _matches.doc(m.id).update({
        'status': 'live',
        'startAtMs': startAt,
        'endsAtMs': BattleEngine.endsAtMs(startAt, m.settings),
      });
    } catch (e) {
      throw _wrap(e);
    }
  }

  /// Leave/cancel a room (waiting or lobby). reason: left | declined | expired.
  static Future<void> cancelRoom(BattleMatch m, String reason) async {
    try {
      final batch = _db.batch();
      batch.update(_matches.doc(m.id), {'status': 'cancelled', 'cancelReason': reason});
      final code = m.roomCode;
      if (code != null && m.hostId == uid) {
        batch.update(_invites.doc(code),
            {'status': reason == 'expired' ? 'expired' : 'cancelled'});
      }
      await batch.commit();
    } catch (e) {
      throw _wrap(e);
    }
  }

  static Future<List<BattleUserHit>> findUser(String query) async {
    final q = query.trim();
    if (q.length < 3) throw const BattleException('Type at least 3 characters.');
    try {
      final found = <String, BattleUserHit>{};
      final byName = await _db
          .collection(FirestorePaths.users)
          .where('name', isEqualTo: q)
          .limit(5)
          .get();
      for (final d in byName.docs) {
        final m = d.data();
        found[d.id] = BattleUserHit(
          uid: d.id,
          name: (m['name'] ?? 'Player').toString(),
          photoUrl: (m['photoUrl'] ?? m['profileImage'] ?? '').toString(),
        );
      }
      try {
        final byId = await _db.collection(FirestorePaths.users).doc(q).get();
        if (byId.exists && byId.data() != null) {
          final m = byId.data()!;
          found[byId.id] = BattleUserHit(
            uid: byId.id,
            name: (m['name'] ?? 'Player').toString(),
            photoUrl: (m['photoUrl'] ?? m['profileImage'] ?? '').toString(),
          );
        }
      } catch (_) {}
      found.remove(uid);
      return found.values.toList();
    } catch (e) {
      throw _wrap(e);
    }
  }

  // ── gameplay ─────────────────────────────────────────────────────────────
  /// One answer per player per question. The rules reject a second write,
  /// a write outside the round's window, and an out-of-range option.
  static Future<AnswerResult> submitAnswer({
    required String battleId,
    required int round,
    required int choice,
  }) async {
    final base = _matches.doc(battleId).collection('rounds').doc('$round');
    final answerRef = base.collection('answers').doc(uid);
    try {
      final batch = _db.batch();
      batch.set(answerRef, {
        'index': round,
        'choice': choice,
        'at': FieldValue.serverTimestamp(),
      });
      batch.set(base.collection('ack').doc(uid), {'at': FieldValue.serverTimestamp()});
      await batch.commit().timeout(const Duration(seconds: 8));
      return AnswerResult.accepted;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        // Either "already answered" (a retry) or "too late / invalid".
        try {
          final existing = await answerRef.get(const GetOptions(source: Source.server));
          if (existing.exists) {
            return existing.data()?['choice'] == choice
                ? AnswerResult.duplicate
                : AnswerResult.rejected;
          }
        } catch (_) {}
        return AnswerResult.rejected;
      }
      throw _wrap(e);
    } on TimeoutException {
      throw const BattleException('The request timed out.', 'timeout');
    }
  }

  static Future<void> forfeit(String battleId) async {
    try {
      await _matches.doc(battleId).update({
        'forfeit': {'by': uid, 'reason': 'left', 'at': FieldValue.serverTimestamp()},
      });
    } catch (e) {
      throw _wrap(e);
    }
  }

  /// Opponent silent past the grace period — the rules re-check staleness
  /// against their presence heartbeat and refuse if they are still there.
  static Future<void> claimDisconnect(String battleId, String opponentUid) async {
    try {
      await _matches.doc(battleId).update({
        'forfeit': {
          'by': opponentUid,
          'reason': 'disconnect',
          'at': FieldValue.serverTimestamp(),
        },
      });
    } catch (e) {
      throw _wrap(e);
    }
  }

  /// Organizer only: end a live battle (no result, no stats).
  static Future<void> organizerAbort(String battleId) async {
    try {
      await _matches
          .doc(battleId)
          .update({'status': 'cancelled', 'cancelReason': 'organizer_ended'});
    } catch (e) {
      throw _wrap(e);
    }
  }

  static Future<void> cancelBattle(String battleId, String reason) async {
    try {
      await _matches.doc(battleId).update({'status': 'cancelled', 'cancelReason': reason});
    } catch (e) {
      throw _wrap(e);
    }
  }

  static Future<void> writePresence(String battleId, String state) {
    return _matches.doc(battleId).collection('presence').doc(uid).set({
      'lastSeen': FieldValue.serverTimestamp(),
      'state': state,
    });
  }

  // ── settle: record MY result once ────────────────────────────────────────
  /// Updates my rating/stats/history exactly once per battle. The rules only
  /// allow it together with flipping settled.{myUid} false → true, and bound
  /// the change (one game, rating move ≤ 32, direction matches the result).
  static Future<void> settle({
    required BattleMatch match,
    required BattleOutcome outcome,
  }) async {
    if (!outcome.countsForStats) return;
    final me = uid;
    final oppId = match.opponentOf(me);
    if (oppId == null) return;
    final matchRef = _matches.doc(match.id);
    final statsRef = _stats.doc(me);
    final histRef = statsRef.collection('history').doc(match.id);
    final oppRatingSnapshot = match.players[oppId]?.rating ?? BattleConfig.startRating;
    final oppName = match.players[oppId]?.name ?? 'Player';

    try {
      await _db.runTransaction<void>((tx) async {
        final m = await tx.get(matchRef);
        final settled = m.data()?['settled'];
        if (settled is Map && settled[me] == true) return;
        final s = await tx.get(statsRef);
        final old = BattleStats.fromDoc(me, s.data());
        if (old.lastBattleId == match.id) return;

        final won = outcome.winnerId == me;
        final lost = outcome.winnerId != null && outcome.winnerId != me;
        final draw = outcome.winnerId == null;
        final score = won ? 1.0 : (draw ? 0.5 : 0.0);
        final rating = BattleEngine.newRating(old.rating, oppRatingSnapshot, score);
        final result = won ? 'win' : (lost ? 'loss' : 'draw');
        final recent = <Map<String, dynamic>>[
          {'uid': oppId, 'name': oppName},
        ];
        final prev = s.data()?['recentOpponents'];
        if (prev is List) {
          for (final r in prev) {
            if (r is Map && r['uid'] != oppId && recent.length < 5) {
              recent.add({'uid': r['uid'], 'name': r['name']});
            }
          }
        }
        final myTally = outcome.tally[me];
        final oppTally = outcome.tally[oppId];
        final profile = match.players[me];

        tx.update(matchRef, {'settled.$me': true});
        tx.set(statsRef, {
          'name': profile?.name ?? '',
          'photoUrl': profile?.photoUrl ?? '',
          'rating': rating,
          'peakRating': rating > old.peakRating ? rating : old.peakRating,
          'played': old.played + 1,
          'wins': old.wins + (won ? 1 : 0),
          'losses': old.losses + (lost ? 1 : 0),
          'draws': old.draws + (draw ? 1 : 0),
          'recentOpponents': recent,
          'updatedAtMs': ServerClock.nowMs,
          'lastBattleId': match.id,
        });
        tx.set(histRef, {
          'battleId': match.id,
          'opponentId': oppId,
          'opponentName': oppName,
          'myScore': myTally?.score ?? 0,
          'oppScore': oppTally?.score ?? 0,
          'result': result,
          'resultStatus': outcome.resultStatus,
          'mode': match.mode,
          'ratingDelta': rating - old.rating,
          'completedAt': FieldValue.serverTimestamp(),
        });
      });
    } catch (e) {
      throw _wrap(e);
    }
  }
}
