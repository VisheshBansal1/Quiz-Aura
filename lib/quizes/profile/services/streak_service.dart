// ============================================================
// FILE: lib/core/services/streak_service.dart
//
// FIX: Added try/catch around the entire updateStreak() body.
//      An unhandled Firestore exception here (offline, permission
//      denied, etc.) was causing an unhandled async error that
//      crashed the app in release mode.
// ============================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class StreakService {
  /// Call this once per app session.
  /// Safe to call multiple times per day — exits early if streak
  /// was already updated today.
  static Future<void> updateStreak() async {
    // FIX: Wrap entire method in try/catch. Previously an exception
    // from the Firestore transaction (e.g. no network, permission denied)
    // propagated as an unhandled async error → release-mode crash.
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snap = await transaction.get(userRef);
        final data = snap.data() ?? {};

        int currentStreak = (data['streakCount'] ?? 0) as int;
        int maxStreak = (data['maxStreak'] ?? currentStreak) as int;

        final Timestamp? lastPlayedTs = data['lastPlayedDate'] as Timestamp?;

        final today = DateTime.now();
        final todayDate = DateTime(today.year, today.month, today.day);

        DateTime? lastPlayedDate;
        if (lastPlayedTs != null) {
          final lp = lastPlayedTs.toDate();
          lastPlayedDate = DateTime(lp.year, lp.month, lp.day);
        }

        final int dayDiff = lastPlayedDate == null
            ? -99
            : todayDate.difference(lastPlayedDate).inDays;

        if (lastPlayedDate == null || dayDiff == -99) {
          currentStreak = 1;
        } else if (dayDiff == 0) {
          return; // already updated today
        } else if (dayDiff == 1) {
          currentStreak += 1;
        } else if (dayDiff < 0) {
          return;
        } else {
          currentStreak = 1;
        }

        if (currentStreak > maxStreak) {
          maxStreak = currentStreak;
        }

        transaction.set(userRef, {
          'streakCount': currentStreak,
          'maxStreak': maxStreak,
          'lastPlayedDate': Timestamp.fromDate(todayDate),
        }, SetOptions(merge: true));
      });
    } catch (e) {
      // Non-fatal — streak will be updated next session.
      debugPrint('[Streak] updateStreak failed (non-fatal): $e');
    }
  }
}
