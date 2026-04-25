import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/models/tournament_model.dart';
import '../../../core/services/coin_service.dart';
import '../../../core/services/badge_service.dart';
import '../../../core/services/fcm_service.dart';

class TournamentService {
  static final _db = FirebaseFirestore.instance;

  // ───────────────── CREATE TOURNAMENT ─────────────────
  static Future<String> createTournament({
    required String title,
    required String description,
    required DateTime startAt,
    required int maxParticipants,
    required int totalRounds,
    required String prizeDescription,
    required int entryCoins,
    DateTime? endAt, // auto-set after rounds are added
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('Not logged in');

    final ref = await _db.collection('tournaments').add({
      'title': title.trim(),
      'description': description.trim(),
      'createdBy': uid,
      'status': 'upcoming',
      'maxParticipants': maxParticipants,
      'participantCount': 0,
      'currentRound': 0,
      'totalRounds': totalRounds,
      'startAt': Timestamp.fromDate(startAt),
      if (endAt != null) 'endAt': Timestamp.fromDate(endAt),
      'prizeDescription': prizeDescription.trim(),
      'entryCoins': entryCoins,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return ref.id;
  }

  // ───────────────── SET / UPDATE endAt ─────────────────
  /// Called after rounds are created.
  /// endAt is typically lastRound.endAt + 30 minutes, but can be any value.
  static Future<void> updateEndAt({
    required String tournamentId,
    required DateTime endAt,
  }) async {
    await _db.collection('tournaments').doc(tournamentId).update({
      'endAt': Timestamp.fromDate(endAt),
    });
  }

  // ───────────────── END TOURNAMENT NOW (Admin) ─────────────────
  /// Admin action: immediately close the tournament.
  /// Sets status = finished and endAt = now so all clients
  /// detect it as finished via TournamentModel.effectiveStatus.
  static Future<void> endTournamentNow({
    required String tournamentId,
  }) async {
    await _db.collection('tournaments').doc(tournamentId).update({
      'status': 'finished',
      'endAt': Timestamp.fromDate(DateTime.now()),
      'endedAt': FieldValue.serverTimestamp(),
    });
  }

  // ───────────────── JOIN TOURNAMENT ─────────────────
  static Future<void> joinTournament({required String tournamentId}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Not logged in');

    final uid = user.uid;
    final name = user.displayName ?? 'Player';

    final tRef = _db.collection('tournaments').doc(tournamentId);

    await _db.runTransaction((tx) async {
      final tSnap = await tx.get(tRef);
      if (!tSnap.exists) throw Exception('Tournament not found');

      final data = tSnap.data()!;
      final status = (data['status'] ?? '').toString().toLowerCase();

      if (status != 'upcoming') {
        throw Exception('Tournament not open for registration');
      }

      final count = data['participantCount'] ?? 0;
      final max = data['maxParticipants'] ?? 0;

      if (count >= max) {
        throw Exception('Tournament full');
      }

      final userRef = tRef.collection('participants').doc(uid);
      final userSnap = await tx.get(userRef);

      if (userSnap.exists) {
        throw Exception('Already joined');
      }

      final entryCoins = data['entryCoins'] ?? 0;
      if (entryCoins > 0) {
        final paid = await CoinService.deductCoins(
          userId: uid,
          amount: entryCoins,
          reason: 'Tournament entry',
        );
        if (!paid) throw Exception('Not enough coins');
      }

      tx.set(userRef, {
        'name': name,
        'currentRound': 1,
        'eliminated': false,
        'roundScores': [],
        'joinedAt': FieldValue.serverTimestamp(),
      });

      tx.update(tRef, {'participantCount': FieldValue.increment(1)});
    });
  }

  static Future<void> addRound({
    required String tournamentId,
    required int roundNumber,
    required String quizId,
    required DateTime startAt,
    required DateTime endAt,
    required int qualifyCount,
  }) async {
    final tRef = FirebaseFirestore.instance
        .collection('tournaments')
        .doc(tournamentId);

    final tSnap = await tRef.get();
    if (!tSnap.exists) throw Exception('Tournament not found');

    final quizSnap = await FirebaseFirestore.instance
        .collection('quizzes')
        .doc(quizId)
        .get();
    if (!quizSnap.exists) throw Exception('Quiz not found');

    final existingRounds = await tRef
        .collection('rounds')
        .where('roundNumber', isEqualTo: roundNumber)
        .get();
    if (existingRounds.docs.isNotEmpty) {
      throw Exception('Round $roundNumber already exists');
    }

    await tRef.collection('rounds').add({
      'roundNumber': roundNumber,
      'quizId': quizId,
      'startAt': Timestamp.fromDate(startAt),
      'endAt': Timestamp.fromDate(endAt),
      'qualifyCount': qualifyCount,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ───────────────── ADVANCE ROUND ─────────────────
  static Future<void> advanceRound({
    required String tournamentId,
    required String quizId,
    required int roundNumber,
    required int qualifyCount,
  }) async {
    final attempts = await _db
        .collection('quizzes')
        .doc(quizId)
        .collection('attempts')
        .orderBy('percentage', descending: true)
        .get();

    final qualifiers = attempts.docs
        .take(qualifyCount)
        .map((e) => e.id)
        .toSet();

    final tRef = _db.collection('tournaments').doc(tournamentId);
    final participants = await tRef.collection('participants').get();

    final batch = _db.batch();

    for (final doc in participants.docs) {
      final uid = doc.id;
      final qualifies = qualifiers.contains(uid);

      batch.update(doc.reference, {
        'eliminated': !qualifies,
        'currentRound': qualifies ? roundNumber + 1 : roundNumber,
      });
    }

    batch.update(tRef, {'currentRound': roundNumber + 1, 'status': 'active'});

    await batch.commit();
  }

  // ───────────────── FINISH TOURNAMENT ─────────────────
  static Future<void> finishTournament({
    required String tournamentId,
    required String winnerUid,
    required String winnerName,
  }) async {
    final tRef = _db.collection('tournaments').doc(tournamentId);
    final tSnap = await tRef.get();
    final data = tSnap.data() ?? {};

    final title = data['title'] ?? '';
    final prize = data['prizeDescription'] ?? '';

    await tRef.update({
      'status': 'finished',
      'winnerUid': winnerUid,
      'endAt': Timestamp.fromDate(DateTime.now()),
      'endedAt': FieldValue.serverTimestamp(),
    });

    await CoinService.addCoins(
      userId: winnerUid,
      amount: CoinService.tournamentWinReward,
      reason: 'Tournament win',
    );

    await BadgeService.checkTournamentWin(userId: winnerUid, isWinner: true);

    await FcmService.createNotification(
      targetUid: winnerUid,
      title: '🏆 You Won!',
      body: 'You won $title ($prize)',
      type: 'tournament',
      metadata: {'tournamentId': tournamentId},
    );
  }

  // ───────────────── STREAMS ─────────────────
  static Stream<List<TournamentModel>> allTournamentsStream() {
    return _db
        .collection('tournaments')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) {
          return snap.docs
              .map((doc) {
                try {
                  return TournamentModel.fromFirestore(doc);
                } catch (e) {
                  print("Error parsing tournament: $e");
                  return null;
                }
              })
              .whereType<TournamentModel>()
              .toList();
        });
  }

  static Future<bool> isRegistered({
    required String tournamentId,
    required String uid,
  }) async {
    final doc = await _db
        .collection('tournaments')
        .doc(tournamentId)
        .collection('participants')
        .doc(uid)
        .get();

    return doc.exists;
  }

  static Stream<List<TournamentRound>> roundsStream(String tournamentId) {
    return _db
        .collection('tournaments')
        .doc(tournamentId)
        .collection('rounds')
        .orderBy('roundNumber')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => TournamentRound.fromFirestore(doc))
              .toList();
        });
  }

  static Stream<List<TournamentParticipant>> participantsStream(
    String tournamentId,
  ) {
    return _db
        .collection('tournaments')
        .doc(tournamentId)
        .collection('participants')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => TournamentParticipant.fromFirestore(doc))
              .toList();
        });
  }
}
