// ============================================================
// FILE: lib/quizes/profile/services/level_service.dart
//
// BUGS FIXED vs original:
//  FIX 1: Removed dead `_unused` Map variable — it was built
//          inside the transaction but never read or returned.
//          This was a code smell but also masked a subtle risk:
//          if the transaction retried, `_unused` could hold
//          stale data from a previous attempt.
//  FIX 2: `earnedXp` guard — if 0 or negative is passed we
//          skip the write entirely to avoid polluting Firestore
//          with no-op increments.
//  FIX 3: `totalQuizzes` increment moved inside transaction so
//          it is always atomic with XP — previously a crash
//          between the transaction commit and the post-quiz
//          rewards block could leave totalQuizzes un-incremented
//          while XP was already updated.
//  FIX 4: CollegeService.syncMemberXp() was never called (the
//          call was present but collegeId was read from a
//          second Firestore fetch that could race with the
//          transaction; now uses the same fresh snapshot).
//  All existing XP/level logic PRESERVED exactly.
// ============================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/services/coin_service.dart';
import '../../../core/services/badge_service.dart';
import '../../../core/services/performance_service.dart';
import '../../../features/college/services/college_service.dart';

class LevelService {
  static Future<void> addXp({
    required String userId,
    required int earnedXp,
    double percentage      = 0,
    bool   isDaily         = false,
    String topicId         = '',
    String topicTitle      = '',
    int    correctAnswers  = 0,
    int    totalQuestions  = 0,
  }) async {
    // FIX 2: Skip entirely for zero / negative XP values
    if (earnedXp <= 0) return;

    final docRef =
        FirebaseFirestore.instance.collection('users').doc(userId);

    // Values we need after the transaction for the rewards block
    int newTotalXp = 0;
    String? collegeId;

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);

      // If user document does not exist → create it
      if (!snapshot.exists) {
        transaction.set(docRef, {
          'xp':           earnedXp,
          'level':        1,
          'requiredXp':   100,
          'totalXp':      earnedXp,
          'streakCount':  0,
          'totalQuizzes': 1,           // FIX 3: inside transaction
          'weeklyXp':     earnedXp,
          'monthlyXp':    earnedXp,
          'coins':        0,
          'badges':       [],
          'createdAt':    FieldValue.serverTimestamp(),
          'updatedAt':    FieldValue.serverTimestamp(),
        });
        newTotalXp = earnedXp;
        return;
      }

      final data = snapshot.data() as Map<String, dynamic>;

      int xp         = (data['xp']         ?? 0)   as int;
      int level      = (data['level']       ?? 1)   as int;
      int requiredXp = (data['requiredXp']  ?? 100) as int;
      int totalXp    = (data['totalXp']     ?? 0)   as int;

      // Capture college id for post-transaction sync (FIX 4)
      collegeId = data['collegeId'] as String?;

      xp      += earnedXp;
      totalXp += earnedXp;

      // Multi-level up support (existing logic — unchanged)
      while (xp >= requiredXp) {
        xp         -= requiredXp;
        level++;
        requiredXp *= 2;
      }

      newTotalXp = totalXp; // expose for college sync below

      // FIX 3: totalQuizzes increment is now INSIDE the transaction
      transaction.update(docRef, {
        'xp':           xp,
        'level':        level,
        'requiredXp':   requiredXp,
        'totalXp':      totalXp,
        'totalQuizzes': FieldValue.increment(1),
        'weeklyXp':     FieldValue.increment(earnedXp),
        'monthlyXp':    FieldValue.increment(earnedXp),
        'updatedAt':    FieldValue.serverTimestamp(),
      });
    });

    // ── Post-quiz rewards (fire-and-forget, non-critical) ─────────────────
    try {
      // 1. Award coins
      await CoinService.rewardQuizCompletion(
        userId:     userId,
        percentage: percentage,
        isDaily:    isDaily,
      );

      // 2. Check and award badges
      final freshSnap = await docRef.get();
      if (freshSnap.exists) {
        final freshData = freshSnap.data() ?? {};

        await BadgeService.checkAll(
          userId:   userId,
          userData: freshData,
        );

        if (percentage >= 100) {
          await BadgeService.checkPerfectScore(
              userId: userId, percentage: percentage);
        }
      }

      // 3. Update per-topic performance stats
      if (topicId.isNotEmpty && totalQuestions > 0) {
        await PerformanceService.recordAttempt(
          userId:     userId,
          topicId:    topicId,
          topicTitle: topicTitle,
          correct:    correctAnswers,
          total:      totalQuestions,
          percentage: percentage,
        );
      }

      // FIX 4: Sync XP to college member record using collegeId captured
      // inside the transaction (avoids a second redundant Firestore fetch
      // and the race condition that existed before)
      if (collegeId != null && collegeId!.isNotEmpty) {
        await CollegeService.syncMemberXp(
          collegeId:  collegeId!,
          userId:     userId,
          newTotalXp: newTotalXp,
          xpGained:   earnedXp,
        );
      }
    } catch (e) {
      // Rewards are non-critical — never break the quiz flow
      // In production: FirebaseCrashlytics.instance.recordError(e, null)
      debugPrint('[LevelService] post-quiz rewards error: $e');
    }
  }

  static String getRankTitle(int level) {
    if (level < 5)  return 'Beginner';
    if (level < 10) return 'Explorer';
    if (level < 20) return 'Challenger';
    if (level < 30) return 'Master';
    return 'Legend';
  }
}