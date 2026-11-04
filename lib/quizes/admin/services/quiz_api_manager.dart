import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;

import 'quiz_api_config.dart';

/// Thrown for failures that must NOT trigger rotation to another API —
/// malformed requests, invalid parameters/keys, truncated/empty AI output,
/// or any other application-level problem. These are surfaced to the caller
/// immediately instead of being hidden behind endless API switching.
class QuizApiPermanentException implements Exception {
  final String message;
  const QuizApiPermanentException(this.message);
  @override
  String toString() => message;
}

/// Thrown when every eligible API failed (each tried at most once) for this
/// request, or when no API is eligible right now (all unconfigured / all
/// cooling down). This is the single, clean "all APIs failed" error.
class QuizApiAllFailedException implements Exception {
  final String message;
  const QuizApiAllFailedException([
    this.message =
        'Unable to generate the quiz right now. Please try again later.',
  ]);
  @override
  String toString() => message;
}

/// Internal only — classifies a failure as temporary (rotate + cooldown).
/// Never leaks outside [QuizApiManager].
class _TemporaryFailure {
  final String reason;
  const _TemporaryFailure(this.reason);
}

/// Tiny FIFO async mutex. Every read/mutation of [QuizApiManager]'s shared
/// state (current-API pointer, per-API cooldown map) happens inside
/// [run], which guarantees concurrent quiz-generation requests can never
/// interleave and corrupt that state — e.g. two requests racing to both
/// decide "API 1 failed, I own the switch to API 2".
class _AsyncLock {
  Future<void> _tail = Future.value();

  Future<T> run<T>(T Function() criticalSection) {
    final previous = _tail;
    final completer = Completer<void>();
    _tail = completer.future;
    return previous.then((_) {
      try {
        return criticalSection();
      } finally {
        completer.complete();
      }
    });
  }
}

/// Automatic failover + rotation across the 3 configured quiz-generation
/// APIs. This is the single place that knows how to talk to whichever API
/// is currently selected — nothing above it (GroqAIService, the quiz
/// screens) needs to know there is more than one API at all.
///
/// Flow per request (see [generateChatContent]):
///   pick eligible APIs starting at the sticky "current" pointer
///     → try each once, in order
///       → success            → return content, stay on this API
///       → temporary failure  → mark unavailable (cooldown), try next
///       → permanent failure  → surface immediately, no rotation
///   → all eligible APIs exhausted → clean "try again later" error
class QuizApiManager {
  QuizApiManager._internal() : _configs = QuizApiConfigs.load();

  static final QuizApiManager instance = QuizApiManager._internal();

  final List<QuizApiConfig> _configs;
  final _AsyncLock _lock = _AsyncLock();

  /// Index of the API to try first for the *next* request. Sticky: stays
  /// put while its API keeps succeeding, only moves forward on failure.
  int _currentIndex = 0;

  /// apiId -> timestamp after which that API is eligible again.
  final Map<String, DateTime> _cooldownUntil = {};

  /// How long a temporarily-failed API stays marked unavailable before it's
  /// automatically retried. No manual reset needed — this just expires.
  static const Duration _cooldown = Duration(minutes: 5);

  static const Duration _requestTimeout = Duration(seconds: 45);

  bool get hasAnyConfiguredApi => _configs.any((c) => c.isConfigured);

  void _log(String msg) => debugPrint('Quiz API: $msg');

  /// Snapshot of which API indices are usable right now, in try-order
  /// starting from the current pointer. Also lazily clears any cooldown
  /// that has expired. Runs inside the lock — safe under concurrency.
  Future<List<int>> _eligibleOrder() => _lock.run(() {
        final order = <int>[];
        for (var i = 0; i < _configs.length; i++) {
          final idx = (_currentIndex + i) % _configs.length;
          final cfg = _configs[idx];
          if (!cfg.isConfigured) continue;

          final until = _cooldownUntil[cfg.id];
          if (until != null) {
            if (DateTime.now().isAfter(until)) {
              _cooldownUntil.remove(cfg.id); // cooldown expired automatically
            } else {
              continue; // still cooling down — not eligible this request
            }
          }
          order.add(idx);
        }
        return order;
      });

  Future<void> _markUnavailable(int index, String reason) => _lock.run(() {
        final cfg = _configs[index];
        _cooldownUntil[cfg.id] = DateTime.now().add(_cooldown);
        _log(
          '${cfg.id} marked unavailable ($reason). '
          'Eligible again in ${_cooldown.inMinutes}m.',
        );
      });

  Future<void> _setCurrent(int index) => _lock.run(() {
        _currentIndex = index;
      });

  /// Sends one chat-completion request, automatically trying each eligible
  /// API at most once (never an infinite API1→API2→API3→API1 loop), and
  /// returns the raw `content` string from whichever API responds first.
  Future<String> generateChatContent({
    required String prompt,
    required int maxTokens,
    double temperature = 0.3,
  }) async {
    final order = await _eligibleOrder();

    if (order.isEmpty) {
      _log('No eligible API right now (unconfigured or all cooling down).');
      throw const QuizApiAllFailedException();
    }

    for (final index in order) {
      final cfg = _configs[index];
      _log('Using ${cfg.id}');

      try {
        final content = await _callApi(
          cfg,
          prompt: prompt,
          maxTokens: maxTokens,
          temperature: temperature,
        );
        _log('${cfg.id} succeeded');
        await _setCurrent(index); // stay here for the next request
        return content;
      } on QuizApiPermanentException {
        rethrow; // application-level problem — never hidden by rotation
      } on _TemporaryFailure catch (e) {
        _log('${cfg.id} ${e.reason}');
        await _markUnavailable(index, e.reason);
        // Advance the shared pointer to the next candidate even though this
        // whole request may still succeed on it below — this keeps state
        // moving forward correctly for the *next* request too.
        await _setCurrent((index + 1) % _configs.length);
        continue;
      }
    }

    _log('All eligible APIs failed for this request.');
    throw const QuizApiAllFailedException();
  }

  Future<String> _callApi(
    QuizApiConfig cfg, {
    required String prompt,
    required int maxTokens,
    required double temperature,
  }) async {
    http.Response response;
    try {
      response = await http
          .post(
            Uri.parse(cfg.baseUrl),
            headers: {
              "Authorization": "Bearer ${cfg.apiKey}",
              "Content-Type": "application/json",
              ...cfg.extraHeaders,
            },
            body: jsonEncode({
              "model": cfg.model,
              "messages": [
                {"role": "user", "content": prompt},
              ],
              "temperature": temperature,
              "max_tokens": maxTokens,
              // Forces syntactically valid JSON output from OpenAI-compatible
              // providers that support it, eliminating most "stray text
              // around the object" parse failures.
              "response_format": {"type": "json_object"},
            }),
          )
          .timeout(_requestTimeout);
    } on TimeoutException {
      throw const _TemporaryFailure('request timed out');
    } on SocketException {
      throw const _TemporaryFailure('network/connection failure');
    } on http.ClientException catch (e) {
      throw _TemporaryFailure('connection failure ($e)');
    }

    final status = response.statusCode;

    // ── Temporary failures → rotate + cooldown ──────────────────────────
    if (status == 429) {
      throw const _TemporaryFailure(
        'returned 429 (rate limit / quota exceeded)',
      );
    }
    if (status == 500 || status == 502 || status == 503 || status == 504) {
      throw _TemporaryFailure('returned $status (temporary provider failure)');
    }

    if (status != 200) {
      // Some providers report quota/rate-limit issues via HTTP 400 with a
      // descriptive body instead of a proper 429 — sniff for that so those
      // still rotate instead of being surfaced as a hard app error.
      final lowerBody = response.body.toLowerCase();
      final looksLikeQuota =
          lowerBody.contains('quota') ||
          lowerBody.contains('rate limit') ||
          lowerBody.contains('rate_limit') ||
          lowerBody.contains('too many requests');
      if (looksLikeQuota) {
        throw _TemporaryFailure('returned $status (quota/rate-limit)');
      }

      if (status == 401) {
        // Permanent (per-API config problem) — surface clearly, don't hide
        // it by silently rotating to a different key.
        throw QuizApiPermanentException(
          '${cfg.id}: Invalid API key. Check the matching key in your .env file.',
        );
      }

      // Everything else (400 malformed request, 403, 404, 422 invalid
      // params, etc.) is a permanent/application-level error.
      throw QuizApiPermanentException(
        '${cfg.id} error $status: ${response.body}',
      );
    }

    // ── Success at the transport level — extract content ────────────────
    final decoded = jsonDecode(response.body);
    final content = decoded['choices']?[0]?['message']?['content'];
    final finishReason = decoded['choices']?[0]?['finish_reason'];

    if (content is! String || content.trim().isEmpty) {
      throw const QuizApiPermanentException(
        'Empty response from AI. Please try again.',
      );
    }

    if (finishReason == 'length') {
      throw const QuizApiPermanentException(
        'AI response was truncated (too many questions requested at once). '
        'Try generating fewer questions, or retry.',
      );
    }

    return content;
  }
}
