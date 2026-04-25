import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/badge_model.dart';

/// Checks and awards badges after every significant user action.
/// Call `BadgeService.checkAll()` after quiz submit, battle end, level-up.
class BadgeService {
  static final _db = FirebaseFirestore.instance;

  /// Run all badge checks for a user. Returns list of newly awarded badge ids.
  static Future<List<String>> checkAll({
    required String userId,
    required Map<String, dynamic> userData,
  }) async {
    final existing = List<String>.from(userData['badges'] ?? []);
    final newBadges = <String>[];

    Future<void> award(String badgeId) async {
      if (existing.contains(badgeId)) return;
      existing.add(badgeId);
      newBadges.add(badgeId);
    }

    final totalQuizzes  = (userData['totalQuizzes']  ?? 0) as int;
    final streakCount   = (userData['streakCount']   ?? 0) as int;
    final level         = (userData['level']         ?? 1) as int;
    final battleWins    = (userData['battleWins']    ?? 0) as int;

    // Quiz count badges
    if (totalQuizzes >= 1)  await award('first_quiz');
    if (totalQuizzes >= 10) await award('quiz_10');
    if (totalQuizzes >= 50) await award('quiz_50');

    // Streak badges
    if (streakCount >= 3)  await award('streak_3');
    if (streakCount >= 7)  await award('streak_7');
    if (streakCount >= 30) await award('streak_30');

    // Level badges
    if (level >= 10) await award('level_10');
    if (level >= 20) await award('level_20');

    // Battle badges
    if (battleWins >= 1)  await award('battle_win');
    if (battleWins >= 10) await award('battle_win_10');

    if (newBadges.isEmpty) return newBadges;

    // Persist to Firestore
    await _db.collection('users').doc(userId).update({
      'badges': existing,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return newBadges;
  }

  /// Award a specific badge (e.g., perfect score, tournament win).
  static Future<bool> awardBadge({
    required String userId,
    required String badgeId,
  }) async {
    final ref = _db.collection('users').doc(userId);
    bool awarded = false;

    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final badges = List<String>.from(snap.data()?['badges'] ?? []);
      if (badges.contains(badgeId)) return;
      badges.add(badgeId);
      tx.update(ref, {
        'badges': badges,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      awarded = true;
    });

    return awarded;
  }

  /// Award perfect score badge when user scores 100%.
  static Future<bool> checkPerfectScore({
    required String userId,
    required double percentage,
  }) async {
    if (percentage < 100) return false;
    return awardBadge(userId: userId, badgeId: 'perfect_score');
  }

  /// Award top performer badge when user hits rank #1.
  static Future<bool> checkTopPerformer({
    required String userId,
    required int rank,
  }) async {
    if (rank != 1) return false;
    return awardBadge(userId: userId, badgeId: 'top_performer');
  }

  /// Award tournament winner badge.
  static Future<bool> checkTournamentWin({
    required String userId,
    required bool isWinner,
  }) async {
    if (!isWinner) return false;
    return awardBadge(userId: userId, badgeId: 'tournament_winner');
  }
}
