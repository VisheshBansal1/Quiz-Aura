// ============================================================
// FILE: lib/features/battle/engine/battle_engine.dart
// PURE battle rules (no Flutter / Firebase imports → unit-testable).
//
// On the free Spark plan nothing trusts a stored score. Every result is
// DERIVED from data the security rules already validated:
//   • each player's single answer + the server timestamp rules stamped on it
//   • the answer key, readable only after a round closes
// Both clients run this same function and always agree.
// ============================================================

import 'dart:math';

import '../models/battle_models.dart';

class BattleConfig {
  BattleConfig._();

  static const int basePoints = 100; // points per correct answer
  static const int quickLeadMs = 10000; // match found → first question
  static const int roomLeadMs = 5000; // both ready → first question
  static const int queueTtlMs = 70000;
  static const int inviteTtlMs = 10 * 60 * 1000;
  static const int reconnectingAfterMs = 20000;
  static const int fgGraceMs = 30000; // silent in foreground ⇒ disconnected
  static const int bgGraceMs = 90000; // app in background ⇒ longer grace
  static const int kFactor = 32;
  static const int startRating = 1000;
  static const int minRating = 100;
  static const int minQuestions = 5;
  static const int maxSearchWindow = 1500;
  static const int startFailureMs = 8000; // no questions after start ⇒ cancel
}

class RoundData {
  final int index;
  final int correctIndex;
  final Map<String, PlayerAnswer?> answers;

  const RoundData({
    required this.index,
    required this.correctIndex,
    required this.answers,
  });
}

class PlayerTally {
  final int score;
  final int correct;
  final int incorrect;
  final int unanswered;
  final int correctMs; // tie-breaker: total time spent on correct answers
  final int answerMs;
  final double accuracy;

  const PlayerTally({
    required this.score,
    required this.correct,
    required this.incorrect,
    required this.unanswered,
    required this.correctMs,
    required this.answerMs,
    required this.accuracy,
  });
}

class BattleOutcome {
  final Map<String, PlayerTally> tally;
  final String? winnerId;
  final String resultStatus; // normal | draw | forfeit | abandoned | cancelled

  const BattleOutcome(this.tally, this.winnerId, this.resultStatus);

  bool get countsForStats =>
      resultStatus == 'normal' || resultStatus == 'draw' || resultStatus == 'forfeit';
}

class BattleEngine {
  BattleEngine._();

  // ── timeline (server epoch ms) ───────────────────────────────────────────
  static int openMs(int startMs, int i, BattleSettings s) => startMs + i * s.periodMs;

  static int closeMs(int startMs, int i, BattleSettings s) =>
      openMs(startMs, i, s) + s.questionSeconds * 1000;

  /// When a round's key and the opponent's answer become readable.
  static int revealMs(int startMs, int i, BattleSettings s) =>
      closeMs(startMs, i, s) + s.answerGraceMs;

  static int endsAtMs(int startMs, BattleSettings s) =>
      startMs + s.questionCount * s.periodMs;

  /// Rounds whose reveal time has passed.
  static int revealedRounds(int nowMs, int startMs, BattleSettings s) {
    final t = nowMs - startMs - s.questionSeconds * 1000 - s.answerGraceMs;
    if (t < 0) return 0;
    final n = t ~/ s.periodMs + 1;
    return n > s.questionCount ? s.questionCount : n;
  }

  // ── result ───────────────────────────────────────────────────────────────
  static int responseMs(PlayerAnswer a, int startMs, int round, BattleSettings s) {
    final ms = a.atMs - openMs(startMs, round, s);
    final max = s.questionSeconds * 1000;
    return ms < 0 ? 0 : (ms > max ? max : ms);
  }

  static BattleOutcome computeOutcome({
    required List<RoundData> rounds,
    required List<String> uids,
    required BattleSettings settings,
    required int startMs,
    BattleForfeit? forfeit,
  }) {
    final tally = <String, PlayerTally>{};
    var totalAnswers = 0;
    for (final uid in uids) {
      var score = 0, correct = 0, incorrect = 0, unanswered = 0;
      var correctMs = 0, answerMs = 0;
      for (var i = 0; i < settings.questionCount; i++) {
        RoundData? rd;
        for (final r in rounds) {
          if (r.index == i) rd = r;
        }
        final a = rd == null ? null : rd.answers[uid];
        if (a == null) {
          unanswered++;
          continue;
        }
        totalAnswers++;
        final ms = responseMs(a, startMs, i, settings);
        answerMs += ms;
        if (rd != null && a.choice == rd.correctIndex) {
          correct++;
          correctMs += ms;
          score += BattleConfig.basePoints;
        } else {
          incorrect++;
        }
      }
      tally[uid] = PlayerTally(
        score: score,
        correct: correct,
        incorrect: incorrect,
        unanswered: unanswered,
        correctMs: correctMs,
        answerMs: answerMs,
        accuracy: (correct * 1000 / settings.questionCount).round() / 10,
      );
    }

    if (forfeit != null && uids.length == 2) {
      final winner = uids[0] == forfeit.by ? uids[1] : uids[0];
      return BattleOutcome(tally, winner, 'forfeit');
    }
    if (uids.length != 2) return BattleOutcome(tally, null, 'abandoned');
    if (totalAnswers == 0) return BattleOutcome(tally, null, 'abandoned');

    final a = tally[uids[0]]!;
    final b = tally[uids[1]]!;
    if (a.score != b.score) {
      return BattleOutcome(tally, a.score > b.score ? uids[0] : uids[1], 'normal');
    }
    if (a.correctMs != b.correctMs) {
      return BattleOutcome(tally, a.correctMs < b.correctMs ? uids[0] : uids[1], 'normal');
    }
    return BattleOutcome(tally, null, 'draw');
  }

  // ── rating ───────────────────────────────────────────────────────────────
  static double expectedScore(int ra, int rb) =>
      1 / (1 + pow(10, (rb - ra) / 400));

  /// My new rating. outcome: 1 win, 0.5 draw, 0 loss.
  static int newRating(int mine, int theirs, double outcome) {
    final delta = (BattleConfig.kFactor * (outcome - expectedScore(mine, theirs))).round();
    final r = mine + delta;
    return r < BattleConfig.minRating ? BattleConfig.minRating : r;
  }

  static int searchWindow(int elapsedSec) {
    final w = 150 + (elapsedSec < 0 ? 0 : elapsedSec) * 30;
    return w > BattleConfig.maxSearchWindow ? BattleConfig.maxSearchWindow : w;
  }

  // ── presence ─────────────────────────────────────────────────────────────
  /// ok | reconnecting | away | disconnected
  static String presenceState(int nowMs, int lastSeenMs, String state) {
    final age = nowMs - lastSeenMs;
    if (state == 'bg') return age > BattleConfig.bgGraceMs ? 'disconnected' : 'away';
    if (age <= BattleConfig.reconnectingAfterMs) return 'ok';
    if (age <= BattleConfig.fgGraceMs) return 'reconnecting';
    return 'disconnected';
  }

  // ── codes ────────────────────────────────────────────────────────────────
  static const String _alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  static String generateRoomCode([int length = 6]) {
    final r = Random.secure();
    final b = StringBuffer();
    for (var i = 0; i < length; i++) {
      b.write(_alphabet[r.nextInt(_alphabet.length)]);
    }
    return b.toString();
  }

  static String normalizeRoomCode(String raw) {
    final up = raw.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    return up.length > 12 ? up.substring(0, 12) : up;
  }
}

/// A question copied from the existing bank. Field choice mirrors the
/// security rules EXACTLY (first present key wins) so the rules can verify
/// the copy against the bank document.
class BankQuestion {
  final String quizId;
  final String questionId;
  final String text;
  final List<String> options;
  final int correctIndex;

  const BankQuestion({
    required this.quizId,
    required this.questionId,
    required this.text,
    required this.options,
    required this.correctIndex,
  });

  static BankQuestion? fromBank(String quizId, String qid, Map<String, dynamic> d) {
    final type = d.containsKey('type') ? d['type'] : 'mcq';
    if (type != 'mcq') return null;
    final dynamic rawText = d.containsKey('title')
        ? d['title']
        : (d.containsKey('question') ? d['question'] : d['text']);
    final dynamic rawOpts = d.containsKey('options') ? d['options'] : d['choices'];
    if (rawText is! String || rawText.trim().isEmpty) return null;
    if (rawOpts is! List || rawOpts.length < 2 || rawOpts.length > 6) return null;
    final opts = <String>[];
    for (final o in rawOpts) {
      if (o is! String || o.trim().isEmpty) return null;
      opts.add(o);
    }
    final ci = d['correctIndex'];
    if (ci is! int || ci < 0 || ci >= opts.length) return null;
    return BankQuestion(
      quizId: quizId,
      questionId: qid,
      text: rawText,
      options: opts,
      correctIndex: ci,
    );
  }
}
