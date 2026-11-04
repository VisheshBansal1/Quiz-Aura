// ============================================================
// FILE: lib/features/battle/services/battle_question_pool.dart
// Shared pool of AI-generated battle questions (Firestore, free plan).
//
// WHY: calling the AI for every battle would burn quota fast. Instead:
//   • questions are generated in BATCHES (one call = 20 questions)
//   • they are stored once in battleQuestionPool and re-used by everyone
//   • battles only DRAW from the pool (cheap reads) — drawing never uses
//     questions up, so the pool does not shrink
//   • AI is called only while a topic's pool is below LOW_WATER (60), once
//     every 7 days to refresh (up to MAX_POOL), and never more than one
//     player at a time (soft lock in battlePoolMeta/{category})
//   • each device also waits 60 s between AI calls
// ⇒ a topic needs ~3 AI calls EVER to reach 60 questions, then ~1/week.
// ============================================================

import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart' show FirebaseException;

import '../../../core/constants/firestore_paths.dart';
import '../../../core/services/ai_quiz_access_service.dart';
import '../../../quizes/admin/services/groq_ai_service.dart';
import '../engine/battle_engine.dart';
import 'server_clock.dart';

class BattleQuestionPool {
  BattleQuestionPool._();

  static const String collection = 'battleQuestionPool';
  static const String metaCollection = 'battlePoolMeta';
  static const String poolId = '_pool'; // srcQuizId marker used in battle docs

  static const int lowWater = 60; // generate until the pool reaches this
  static const int maxPool = 300; // never grow past this
  static const int batchSize = 20; // questions per AI call (fits token budget)
  static const int refreshAfterMs = 7 * 24 * 60 * 60 * 1000;
  static const int deviceCooldownMs = 60 * 1000;
  static const int lockMs = 100 * 1000;

  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static int _lastAiCallMs = 0;
  static bool _aiInFlight = false;

  static String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  // ── helpers ──────────────────────────────────────────────────────────────
  static String _normalize(String t) =>
      t.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();

  /// Deterministic doc id so the same question can never be stored twice
  /// (the rules make pool docs create-only, so a duplicate write is refused).
  static String docIdFor(String category, String text) {
    final s = '$category|${_normalize(text)}';
    var h1 = 0x811c9dc5;
    var h2 = 0x01000193;
    for (final c in s.codeUnits) {
      h1 = ((h1 ^ c) * 16777619) & 0xFFFFFFFF;
      h2 = ((h2 + c) * 2246822519) & 0xFFFFFFFF;
    }
    return '${h1.toRadixString(16).padLeft(8, '0')}${h2.toRadixString(16).padLeft(8, '0')}';
  }

  static Future<String> labelFor(String category) async {
    if (category == 'general' || category.isEmpty) {
      return 'general knowledge, aptitude and current affairs (mixed topics)';
    }
    try {
      final s = await _db.collection(FirestorePaths.topics).doc(category).get();
      final t = s.data()?['title'];
      if (t is String && t.trim().isNotEmpty) return t.trim();
    } catch (_) {}
    return category;
  }

  /// Pool key for a battle category ('' = any topic = 'general').
  static String keyFor(String category) => category.isEmpty ? 'general' : category;

  // ── draw (cheap: ~14 reads, never calls AI) ─────────────────────────────
  static Future<List<BankQuestion>> draw(String category, int need) async {
    final key = keyFor(category);
    final col = _db.collection(collection);
    final r = Random().nextDouble();
    final out = <BankQuestion>[];

    void addAll(QuerySnapshot<Map<String, dynamic>> snap) {
      for (final d in snap.docs) {
        final bq = BankQuestion.fromBank(poolId, d.id, d.data());
        if (bq != null) out.add(bq);
      }
    }

    final take = need + 4; // a few spare for de-duplication
    final a = await col
        .where('category', isEqualTo: key)
        .where('rand', isGreaterThanOrEqualTo: r)
        .orderBy('rand')
        .limit(take)
        .get();
    addAll(a);
    if (out.length < take) {
      final b = await col
          .where('category', isEqualTo: key)
          .where('rand', isLessThan: r)
          .orderBy('rand')
          .limit(take - out.length)
          .get();
      addAll(b);
    }
    return out;
  }

  // ── fill (the only place AI is called) ──────────────────────────────────
  /// Makes sure the pool for [category] is stocked. Returns the questions it
  /// just created (so the caller can use them immediately), or an empty list
  /// if nothing needed to be / could be generated.
  static Future<List<BankQuestion>> ensureFilled(String category) async {
    final key = keyFor(category);
    final metaRef = _db.collection(metaCollection).doc(key);

    int size = 0;
    int last = 0;
    try {
      final snap = await metaRef.get();
      size = (snap.data()?['size'] as num?)?.toInt() ?? 0;
      last = (snap.data()?['lastRefillMs'] as num?)?.toInt() ?? 0;
    } catch (_) {
      return const [];
    }
    final now = ServerClock.nowMs;
    final stale = last > 0 && size < maxPool && now - last > refreshAfterMs;
    if (size >= lowWater && !stale) return const [];

    if (AiQuizAccessService.isBlockedOnWeb) return const []; // AI is mobile-only
    final localNow = DateTime.now().millisecondsSinceEpoch;
    if (_aiInFlight || localNow - _lastAiCallMs < deviceCooldownMs) return const [];

    // Soft lock: only one player at a time refills a topic.
    bool locked = false;
    try {
      locked = await _db.runTransaction<bool>((tx) async {
        final m = await tx.get(metaRef);
        final until = (m.data()?['refillUntilMs'] as num?)?.toInt() ?? 0;
        if (until > ServerClock.nowMs) return false;
        final lockUntil = ServerClock.nowMs + lockMs;
        if (!m.exists) {
          tx.set(metaRef, {
            'size': 0,
            'lastRefillMs': 0,
            'refillUntilMs': lockUntil,
            'by': _uid,
          });
        } else {
          tx.update(metaRef, {'refillUntilMs': lockUntil, 'by': _uid});
        }
        return true;
      });
    } catch (_) {
      return const [];
    }
    if (!locked) return const [];

    _aiInFlight = true;
    _lastAiCallMs = localNow;
    final created = <BankQuestion>[];
    try {
      final label = await labelFor(key);
      final raw = await GroqAIService().generateMCQs(
        topic: label,
        difficulty: 'Mixed (easy, medium and hard)',
        count: batchSize,
      );
      created.addAll(await _store(key, raw));
    } catch (_) {
      // AI unavailable / quota hit: fall through, release the lock below.
    } finally {
      _aiInFlight = false;
      try {
        await metaRef.update({
          if (created.isNotEmpty) 'size': FieldValue.increment(created.length),
          if (created.isNotEmpty) 'lastRefillMs': ServerClock.nowMs,
          'refillUntilMs': 0,
        });
      } catch (_) {}
    }
    return created;
  }

  /// Validates AI output and writes each question once.
  static Future<List<BankQuestion>> _store(
    String key,
    List<Map<String, dynamic>> raw,
  ) async {
    final col = _db.collection(collection);
    final seen = <String>{};
    final valid = <Map<String, dynamic>>[];
    for (final q in raw) {
      final text = q['question'];
      final opts = q['options'];
      final ci = q['correctIndex'];
      if (text is! String || text.trim().length < 8 || text.length > 500) continue;
      if (opts is! List || opts.length != 4) continue;
      final options = <String>[];
      var ok = true;
      for (final o in opts) {
        if (o is! String || o.trim().isEmpty) {
          ok = false;
          break;
        }
        options.add(o.trim());
      }
      if (!ok) continue;
      if (options.map((o) => o.toLowerCase()).toSet().length != 4) continue; // distinct
      if (ci is! num || ci.toInt() < 0 || ci.toInt() > 3) continue;
      if (!seen.add(_normalize(text))) continue;
      valid.add({'title': text.trim(), 'options': options, 'correctIndex': ci.toInt()});
    }

    final created = <BankQuestion>[];
    final rnd = Random();
    for (var i = 0; i < valid.length; i += 10) {
      final chunk = valid.sublist(i, min(i + 10, valid.length));
      await Future.wait(chunk.map((q) async {
        final id = docIdFor(key, q['title'] as String);
        try {
          await col.doc(id).set({
            'category': key,
            'title': q['title'],
            'options': q['options'],
            'correctIndex': q['correctIndex'],
            'rand': rnd.nextDouble(),
            'createdBy': _uid,
            'createdAt': FieldValue.serverTimestamp(),
            'source': 'ai',
          });
          final bq = BankQuestion.fromBank(poolId, id, q);
          if (bq != null) created.add(bq);
        } on FirebaseException catch (_) {
          // Already in the pool (create-only rule) — skip silently.
        }
      }));
    }
    return created;
  }
}
