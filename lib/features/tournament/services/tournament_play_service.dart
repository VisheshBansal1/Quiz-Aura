// ============================================================
// FILE: lib/features/tournament/services/tournament_play_service.dart
// Handles all tournament play logic:
//   - Round eligibility validation
//   - Attempt saving (quiz + participant update)
//   - Admin: advance round
// DOES NOT modify any existing Firestore collections.
// ============================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/models/tournament_model.dart';

/// Enum describing the current play state of a round for the local user.
enum RoundPlayState {
  /// User is not registered in this tournament.
  notRegistered,

  /// User has been eliminated.
  eliminated,

  /// The round belongs to a later round than user's current round.
  lockedFutureRound,

  /// The round hasn't started yet.
  upcoming,

  /// The round window has closed.
  ended,

  /// User already submitted an attempt for this round.
  completed,

  /// User is eligible — show the Play button.
  playable,
}

class TournamentPlayService {
  static final _db = FirebaseFirestore.instance;

  // ─────────────────────────────────────────────────────────────────────────
  // ELIGIBILITY CHECK
  // Returns the current RoundPlayState for the logged-in user + given round.
  // ─────────────────────────────────────────────────────────────────────────
  static Future<RoundPlayState> getRoundPlayState({
    required String tournamentId,
    required TournamentRound round,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return RoundPlayState.notRegistered;

    // 1. Check participant doc
    final participantSnap = await _db
        .collection('tournaments')
        .doc(tournamentId)
        .collection('participants')
        .doc(uid)
        .get();

    if (!participantSnap.exists) return RoundPlayState.notRegistered;

    final participant = TournamentParticipant.fromFirestore(participantSnap);

    // 2. Check elimination
    if (participant.eliminated) return RoundPlayState.eliminated;

    // 3. Check round access.
    //
    // OLD LOGIC (buggy): blocked anyone whose currentRound < round.roundNumber,
    // which meant round 2 was always locked until the admin manually ran
    // "Advance Round" — even for users who had already completed round 1.
    //
    // FIX — Self-progression:
    //   A player may access round N if they have a completed roundScores entry
    //   for round N-1, regardless of whether the admin has bumped currentRound
    //   yet.  We only look one round ahead at a time (no round-skipping).
    //   If the admin later eliminates the player, the `eliminated` check above
    //   already handles that case.
    if (participant.currentRound < round.roundNumber) {
      final isNextRound = round.roundNumber == participant.currentRound + 1;
      if (isNextRound) {
        final completedPrevious = _hasAttemptedRound(
          participant: participant,
          roundNumber: round.roundNumber - 1,
        );
        if (!completedPrevious) return RoundPlayState.lockedFutureRound;
        // completedPrevious == true → fall through to time-window & attempt checks
      } else {
        // Trying to skip multiple rounds — still locked
        return RoundPlayState.lockedFutureRound;
      }
    }
    if (participant.currentRound > round.roundNumber) {
      // They've already advanced past this — treat as completed
      return RoundPlayState.completed;
    }

    // 4. Time window
    final now = DateTime.now();
    if (now.isBefore(round.startAt)) return RoundPlayState.upcoming;
    if (now.isAfter(round.endAt)) return RoundPlayState.ended;

    // 5. Already attempted THIS tournament round?
    // BUG FIX: Previously checked quizzes/{quizId}/attempts/{uid}.
    // That path is shared with regular (non-tournament) quiz attempts, so a
    // user who had done the same quiz outside the tournament was incorrectly
    // shown as "Completed ✓" and blocked from playing the tournament round.
    // Now we check the participant's own roundScores list, which is only
    // written by saveTournamentAttempt() — it's tournament-scoped.
    final alreadyAttempted = _hasAttemptedRound(
      participant: participant,
      roundNumber: round.roundNumber,
    );
    if (alreadyAttempted) return RoundPlayState.completed;

    return RoundPlayState.playable;
  }

  /// Returns true if the participant has a score entry for [roundNumber].
  /// Pure in-memory check — no extra Firestore read needed.
  static bool _hasAttemptedRound({
    required TournamentParticipant participant,
    required int roundNumber,
  }) {
    return participant.roundScores.any(
      (s) => (s['round'] as int?) == roundNumber,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SAVE TOURNAMENT ATTEMPT
  // Called after quiz submission in a tournament context.
  // Saves to:
  //   quizzes/{quizId}/attempts/{uid}         ← for leaderboard / stats
  //   tournaments/{id}/participants/{uid}      ← roundScores list
  // ─────────────────────────────────────────────────────────────────────────
  static Future<void> saveTournamentAttempt({
    required String tournamentId,
    required String quizId,
    required int roundNumber,
    required int score,
    required int total,
    required double percentage,
    Map<String, int> answers = const {}, // questionId → selectedOptionIndex
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('Not logged in');

    // BUG FIX: double-submission guard now uses the tournament-scoped
    // roundScores list instead of quizzes/{quizId}/attempts/{uid}.
    // The old path is shared with regular quiz attempts, so users who had
    // previously done the same quiz outside the tournament were blocked here
    // with "Already attempted this round" even on their first tournament play.
    final participantRef = _db
        .collection('tournaments')
        .doc(tournamentId)
        .collection('participants')
        .doc(uid);

    final participantSnap = await participantRef.get();
    if (participantSnap.exists) {
      final existing = TournamentParticipant.fromFirestore(participantSnap);
      if (_hasAttemptedRound(participant: existing, roundNumber: roundNumber)) {
        throw Exception('Already attempted this round');
      }
    }

    final batch = _db.batch();

    // 1. Save quiz attempt (kept for leaderboard / performance stats)
    final attemptRef = _db
        .collection('quizzes')
        .doc(quizId)
        .collection('attempts')
        .doc(uid);

    batch.set(
      attemptRef,
      {
        'uid': uid,
        'quizId': quizId,
        'score': score,
        'total': total,
        'percentage': percentage,
        'passed': percentage >= 60.0,
        'submittedAt': FieldValue.serverTimestamp(),
        // Tournament context metadata
        'tournamentId': tournamentId,
        'roundNumber': roundNumber,
      },
      // Use merge so that if the user has done this quiz outside the
      // tournament, we update rather than overwrite their existing attempt.
      SetOptions(merge: true),
    );

    // 2. Append to participant's roundScores.
    // Also keep currentRound >= roundNumber so subsequent rounds can
    // self-progress through _hasAttemptedRound without waiting for
    // the admin to manually call advanceRound.
    final existingCurrentRound =
        (participantSnap.data()?['currentRound'] as int?) ?? 1;
    batch.update(participantRef, {
      'roundScores': FieldValue.arrayUnion([
        {
          'round': roundNumber,
          'score': score,
          'total': total,
          'percentage': percentage,
          'submittedAt': Timestamp.now(),
          // FIX: store per-question answers so the review screen can show
          // what the user selected (instead of marking everything as Skipped).
          'answers': answers.entries
              .map((e) => {'qId': e.key, 'idx': e.value})
              .toList(),
        },
      ]),
      // Only write if we'd actually be moving forward — never regress
      if (existingCurrentRound < roundNumber) 'currentRound': roundNumber,
    });

    await batch.commit();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ADMIN: ADVANCE ROUND
  // Reads quiz attempts, sorts by percentage, promotes top N, eliminates rest,
  // increments currentRound on the tournament doc.
  // ─────────────────────────────────────────────────────────────────────────
  static Future<AdvanceRoundResult> advanceRound({
    required String tournamentId,
    required String quizId,
    required int roundNumber,
    required int qualifyCount,
    required int totalRounds,
  }) async {
    // 1. Fetch attempts sorted by percentage desc
    final attemptsSnap = await _db
        .collection('quizzes')
        .doc(quizId)
        .collection('attempts')
        .where('tournamentId', isEqualTo: tournamentId)
        .where('roundNumber', isEqualTo: roundNumber)
        .orderBy('percentage', descending: true)
        .get();

    final qualifierUids = attemptsSnap.docs
        .take(qualifyCount)
        .map((d) => d.id)
        .toSet();

    // 2. Fetch all participants at this round
    final participantsSnap = await _db
        .collection('tournaments')
        .doc(tournamentId)
        .collection('participants')
        .where('currentRound', isEqualTo: roundNumber)
        .where('eliminated', isEqualTo: false)
        .get();

    final batch = _db.batch();
    int advanced = 0;
    int eliminated = 0;

    for (final doc in participantsSnap.docs) {
      final uid = doc.id;
      final qualifies = qualifierUids.contains(uid);

      if (qualifies) {
        batch.update(doc.reference, {
          'currentRound': roundNumber + 1,
          'eliminated': false,
        });
        advanced++;
      } else {
        batch.update(doc.reference, {'eliminated': true});
        eliminated++;
      }
    }

    // 3. Update tournament state
    final tRef = _db.collection('tournaments').doc(tournamentId);
    final isLastRound = roundNumber >= totalRounds;

    batch.update(tRef, {
      'currentRound': roundNumber + 1,
      if (isLastRound) 'status': 'finished',
    });

    await batch.commit();

    return AdvanceRoundResult(
      advanced: advanced,
      eliminated: eliminated,
      isFinished: isLastRound,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STREAM: participant's own data (for reactive UI)
  // ─────────────────────────────────────────────────────────────────────────
  static Stream<TournamentParticipant?> myParticipantStream(
    String tournamentId,
  ) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Stream.value(null);

    return _db
        .collection('tournaments')
        .doc(tournamentId)
        .collection('participants')
        .doc(uid)
        .snapshots()
        .map((snap) {
          if (!snap.exists) return null;
          return TournamentParticipant.fromFirestore(snap);
        });
  }
}

/// Result object returned from advanceRound.
class AdvanceRoundResult {
  final int advanced;
  final int eliminated;
  final bool isFinished;

  const AdvanceRoundResult({
    required this.advanced,
    required this.eliminated,
    required this.isFinished,
  });
}