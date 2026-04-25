import 'package:cloud_firestore/cloud_firestore.dart';

/// Tracks and updates per-topic accuracy statistics.
/// Called after every quiz submission to keep stats current.
class PerformanceService {
  static final _db = FirebaseFirestore.instance;

  /// Update accuracy stats for a topic after a quiz attempt.
  static Future<void> recordAttempt({
    required String userId,
    required String topicId,
    required String topicTitle,
    required int correct,
    required int total,
    required double percentage,
  }) async {
    if (total <= 0) return;

    final ref = _db.collection('performanceStats').doc(userId);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data() ?? {};

      // Per-topic stats
      final Map<String, dynamic> byTopic =
          Map<String, dynamic>.from(data['byTopic'] ?? {});

      final existing = Map<String, dynamic>.from(byTopic[topicId] ?? {});
      final prevTotal   = (existing['total']   ?? 0) as int;
      final prevCorrect = (existing['correct']  ?? 0) as int;

      final newTotal   = prevTotal   + total;
      final newCorrect = prevCorrect + correct;

      byTopic[topicId] = {
        'title':    topicTitle,
        'total':    newTotal,
        'correct':  newCorrect,
        'accuracy': newCorrect / newTotal * 100,
      };

      // Progress history (limit to last 30 entries)
      final List<dynamic> history =
          List<dynamic>.from(data['progressHistory'] ?? []);

      history.add({
        'date':       DateTime.now().toIso8601String(),
        'topicId':    topicId,
        'topicTitle': topicTitle,
        'correct':    correct,
        'total':      total,
        'percentage': percentage,
      });

      // Keep last 90 records only (sliding window)
      final trimmed = history.length > 90
          ? history.sublist(history.length - 90)
          : history;

      // Detect weak topics (accuracy < 60%)
      final weakTopics = byTopic.entries
          .where((e) => ((e.value['accuracy'] ?? 0) as num) < 60.0)
          .map((e) => e.key)
          .toList();

      if (snap.exists) {
        tx.update(ref, {
          'byTopic':         byTopic,
          'progressHistory': trimmed,
          'weakTopics':      weakTopics,
          'updatedAt':       FieldValue.serverTimestamp(),
        });
      } else {
        tx.set(ref, {
          'byTopic':         byTopic,
          'progressHistory': trimmed,
          'weakTopics':      weakTopics,
          'createdAt':       FieldValue.serverTimestamp(),
          'updatedAt':       FieldValue.serverTimestamp(),
        });
      }
    });
  }

  /// Get performance stats as a single future (for dashboard load).
  static Future<Map<String, dynamic>> getStats(String userId) async {
    final snap = await _db.collection('performanceStats').doc(userId).get();
    return snap.data() ?? {};
  }

  /// Stream performance stats for real-time updates.
  static Stream<DocumentSnapshot<Map<String, dynamic>>> statsStream(String userId) {
    return _db.collection('performanceStats').doc(userId).snapshots();
  }
}
