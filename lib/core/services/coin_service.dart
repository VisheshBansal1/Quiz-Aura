import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Manages the in-app coin economy.
/// Called after quiz completion, battle wins, and tournament rewards.
class CoinService {
  static final _db = FirebaseFirestore.instance;

  // ── Coin reward amounts ────────────────────────────────────────────────────
  static const int quizCompleteReward   = 10;
  static const int perfectScoreBonus    = 25;
  static const int battleWinReward      = 50;
  static const int tournamentWinReward  = 200;
  static const int dailyQuizBonus       = 15;
  static const int streakBonusMultiplier = 2; // multiplied at day 7, 30

  /// Add coins to the current user with transaction safety.
  static Future<void> addCoins({
    required String userId,
    required int amount,
    String reason = '',
  }) async {
    if (amount <= 0) return;

    final ref = _db.collection('users').doc(userId);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final current = (snap.data()?['coins'] ?? 0) as int;
      tx.update(ref, {
        'coins': current + amount,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });

    // Log coin transaction for audit trail
    await _db
        .collection('users')
        .doc(userId)
        .collection('coinHistory')
        .add({
      'amount':    amount,
      'reason':    reason,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Deduct coins (for tournament entry fees, etc.)
  /// Returns false if user doesn't have enough coins.
  static Future<bool> deductCoins({
    required String userId,
    required int amount,
    String reason = '',
  }) async {
    if (amount <= 0) return true;

    final ref = _db.collection('users').doc(userId);
    bool success = false;

    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final current = (snap.data()?['coins'] ?? 0) as int;
      if (current < amount) {
        success = false;
        return;
      }
      tx.update(ref, {
        'coins': current - amount,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      success = true;
    });

    if (success) {
      await _db
          .collection('users')
          .doc(userId)
          .collection('coinHistory')
          .add({
        'amount':    -amount,
        'reason':    reason,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    return success;
  }

  /// Get current coin balance (single read — use StreamBuilder in UI).
  static Future<int> getBalance(String userId) async {
    final snap = await _db.collection('users').doc(userId).get();
    return (snap.data()?['coins'] ?? 0) as int;
  }

  /// Reward coins for quiz completion based on performance.
  static Future<void> rewardQuizCompletion({
    required String userId,
    required double percentage,
    required bool isDaily,
  }) async {
    int coins = isDaily ? dailyQuizBonus : quizCompleteReward;
    if (percentage >= 100) coins += perfectScoreBonus;

    await addCoins(
      userId: userId,
      amount: coins,
      reason: isDaily ? 'Daily quiz reward' : 'Quiz completion reward',
    );
  }
}
