// ============================================================
// FILE: lib/core/services/streak_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StreakService {
  /// Call this once per app session (e.g. in ProfileScreen.initState
  /// or after completing a quiz).  Safe to call multiple times per day —
  /// it exits early if the streak was already updated today.
  static Future<void> updateStreak() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userRef =
        FirebaseFirestore.instance.collection('users').doc(user.uid);

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snap = await transaction.get(userRef);
      final data = snap.data() ?? {};

      int currentStreak = (data['streakCount'] ?? 0) as int;
      // accounts that pre-date this field)
      int maxStreak     = (data['maxStreak'] ?? currentStreak) as int;

      final Timestamp? lastPlayedTs = data['lastPlayedDate'] as Timestamp?;

      final today = DateTime.now();
      final todayDate = DateTime(today.year, today.month, today.day);

      DateTime? lastPlayedDate;
      if (lastPlayedTs != null) {
        final lp = lastPlayedTs.toDate();
        lastPlayedDate = DateTime(lp.year, lp.month, lp.day);
      }

      final int dayDiff = lastPlayedDate == null
          ? -99 // sentinel: treat like first time
          : todayDate.difference(lastPlayedDate).inDays;

      if (lastPlayedDate == null || dayDiff == -99) {
        // First time ever playing
        currentStreak = 1;
      } else if (dayDiff == 0) {
        // Already updated today — exit early without writing
        return;
      } else if (dayDiff == 1) {
        // Played yesterday → extend streak
        currentStreak += 1;
      } else if (dayDiff < 0) {
        return;
      } else {
        currentStreak = 1;
      }

      if (currentStreak > maxStreak) {
        maxStreak = currentStreak;
      }

      transaction.set(
        userRef,
        {
          'streakCount':    currentStreak,
          'maxStreak':      maxStreak,         // FIX 3
          'lastPlayedDate': Timestamp.fromDate(todayDate),
        },
        SetOptions(merge: true),
      );
    });
  }
}