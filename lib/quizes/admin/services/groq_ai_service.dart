import 'dart:convert';

import 'package:QuizSphere/core/services/ai_quiz_access_service.dart';

import 'quiz_api_manager.dart';

/// Public API is UNCHANGED on purpose: `GroqAIService()` + `generateMCQs(...)`
/// so every existing call site (ai_generate_questions_screen.dart,
/// admin_daily_quiz_screen.dart) keeps working exactly as before.
///
/// What changed internally: the actual HTTP call is now delegated to
/// [QuizApiManager], which automatically fails over across up to 3
/// configured APIs (quota/rate-limit/5xx/timeout/network -> rotate;
/// malformed request/invalid key/params -> surfaced immediately). The name
/// "GroqAIService" is kept for backward compatibility even though it may no
/// longer only be Groq under the hood -- rename at the call sites later if
/// you want, it's purely cosmetic.
class GroqAIService {
  GroqAIService();

  bool get isConfigured => QuizApiManager.instance.hasAnyConfiguredApi;

  Future<List<Map<String, dynamic>>> generateMCQs({
    required String topic,
    required String difficulty,
    int count = 5,
  }) async {
    // AI Quiz Generation is mobile-only. Every known UI entry point already
    // stops before reaching this call on web -- this check is a final
    // backstop so no network call can ever run on web, no matter which code
    // path gets here.
    if (AiQuizAccessService.isBlockedOnWeb) {
      throw Exception(AiQuizAccessService.blockedMessage);
    }

    if (!isConfigured) {
      throw Exception(
        'AI API key is not configured.\n'
        'Add at least one of Quiz_API / QUIZ_API_2_KEY / QUIZ_API_3_KEY to '
        'your .env file and ensure it is listed in pubspec.yaml assets.',
      );
    }

    // max_tokens must scale with question count, otherwise the AI truncates
    // the JSON mid-object for larger counts (e.g. 15 hard MCQs with
    // solutions easily exceeds 2500 tokens) -> jsonDecode fails. ~180-220
    // tokens per MCQ (question + 4 options + solution) is a safe estimate;
    // we pad generously and clamp to a sane ceiling.
    final int maxTokens = (count * 260 + 800).clamp(1500, 8000);

    try {
      final questions = await _requestMCQs(
        topic: topic,
        difficulty: difficulty,
        count: count,
        maxTokens: maxTokens,
      );
      return questions;
    } on Exception catch (e) {
      // One retry on parse/format failure -- the AI occasionally emits
      // malformed JSON on the first pass for larger counts; a fresh attempt
      // (with the same generous token budget) usually succeeds. This retry
      // goes through the API manager again, so it may also land on a
      // different API if the current one has since failed.
      final msg = e.toString();
      final isRecoverable =
          msg.contains('JSON') ||
          msg.contains('Invalid') ||
          msg.contains('Empty response');
      if (!isRecoverable) rethrow;

      try {
        return await _requestMCQs(
          topic: topic,
          difficulty: difficulty,
          count: count,
          maxTokens: maxTokens,
        );
      } catch (_) {
        rethrow; // surface the original, clearer error
      }
    }
  }

  Future<List<Map<String, dynamic>>> _requestMCQs({
    required String topic,
    required String difficulty,
    required int count,
    required int maxTokens,
  }) async {
    final prompt =
        '''
Generate exactly $count UNIQUE multiple-choice questions on topic "$topic".
Difficulty: $difficulty.

Respond ONLY with a JSON object in this exact shape (no markdown, no text outside the JSON):
{
  "questions": [
    {
      "question": "string",
      "options": ["A","B","C","D"],
      "correctIndex": 0,
      "solution": "Short clear explanation why the correct answer is right"
    }
  ]
}

Rules:
- "questions" must contain exactly $count items.
- Exactly 4 options per question.
- correctIndex must be an integer between 0 and 3.
- Keep each "solution" concise (under 25 words) so the full response fits.
- Do not include any keys other than question, options, correctIndex, solution.
''';

    final content = await QuizApiManager.instance.generateChatContent(
      prompt: prompt,
      maxTokens: maxTokens,
    );

    final cleanJson = _extractJsonObject(content);
    return _safeParseQuestions(cleanJson, count);
  }

  /// Extracts the outermost {...} object, tolerant of any stray text
  /// the model might still wrap around it despite response_format.
  String _extractJsonObject(String raw) {
    final start = raw.indexOf('{');
    final end = raw.lastIndexOf('}');
    if (start == -1 || end == -1 || end < start) {
      throw Exception("No valid JSON object found in AI response");
    }
    return raw.substring(start, end + 1);
  }

  List<Map<String, dynamic>> _safeParseQuestions(
    String raw,
    int expectedCount,
  ) {
    final parsed = jsonDecode(raw);

    // Accept either {"questions": [...]} (new format) or a bare [...]
    // (defensive fallback in case the model ever ignores response_format).
    final List rawList;
    if (parsed is Map<String, dynamic> && parsed['questions'] is List) {
      rawList = parsed['questions'] as List;
    } else if (parsed is List) {
      rawList = parsed;
    } else {
      throw Exception("Response JSON did not contain a questions array");
    }

    if (rawList.isEmpty) {
      throw Exception("AI returned zero questions. Please try again.");
    }

    final questions = rawList.map<Map<String, dynamic>>((q) {
      if (q is! Map<String, dynamic>) {
        throw Exception("Invalid question object");
      }

      final question = q['question'];
      final options = q['options'];
      final correctIndex = q['correctIndex'];
      final solution = q['solution'];

      if (question is! String || question.trim().isEmpty) {
        throw Exception("Invalid question text");
      }
      if (options is! List || options.length != 4) {
        throw Exception("Invalid options — need exactly 4");
      }
      if (correctIndex is! int || correctIndex < 0 || correctIndex > 3) {
        throw Exception("Invalid correctIndex");
      }
      if (solution is! String || solution.trim().length < 5) {
        throw Exception("Invalid solution text");
      }

      return {
        'question': question,
        'options': List<String>.from(options),
        'correctIndex': correctIndex,
        'solution': solution,
      };
    }).toList();

    return questions;
  }
}
