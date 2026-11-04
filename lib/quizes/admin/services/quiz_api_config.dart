import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Configuration for a single quiz-generation API endpoint.
///
/// All 3 quiz APIs are expected to speak the OpenAI-compatible
/// "chat/completions" protocol — this is what Groq, OpenRouter, Together AI,
/// Cerebras, etc. all use — so the same request/response handling code in
/// [QuizApiManager] works for all of them unchanged. If a future provider
/// needs a genuinely different protocol, branch on [QuizApiConfig.id] inside
/// `QuizApiManager._callApi` instead of duplicating the whole flow.
class QuizApiConfig {
  /// Short label used only for internal logs (e.g. "API 1"). Never shown to
  /// the user and never logged alongside the key.
  final String id;

  final String baseUrl;
  final String apiKey;
  final String model;

  /// Any provider-specific headers beyond Authorization/Content-Type.
  final Map<String, String> extraHeaders;

  const QuizApiConfig({
    required this.id,
    required this.baseUrl,
    required this.apiKey,
    required this.model,
    this.extraHeaders = const {},
  });

  /// An API with no key configured is simply skipped everywhere — this lets
  /// the app run fine with 1, 2, or 3 APIs active.
  bool get isConfigured => apiKey.trim().isNotEmpty && baseUrl.trim().isNotEmpty;

  static String sanitizeKey(String raw) =>
      raw.trim().replaceAll('"', '').replaceAll("'", '');
}

/// Loads the 3 quiz-API configs from the `.env` file.
///
/// Add whichever of these you need to your `.env`:
///
/// ```env
/// # API 1 — existing key is reused automatically, nothing to change here.
/// Quiz_API=gsk_xxx
/// # Optional overrides for API 1 (defaults shown):
/// # QUIZ_API_1_BASE_URL=https://api.groq.com/openai/v1/chat/completions
/// # QUIZ_API_1_MODEL=openai/gpt-oss-20b
///
/// # API 2 — new, optional. Leave blank / omit to run with just API 1.
/// QUIZ_API_2_KEY=your_second_provider_key
/// QUIZ_API_2_BASE_URL=https://api.groq.com/openai/v1/chat/completions
/// QUIZ_API_2_MODEL=openai/gpt-oss-20b
///
/// # API 3 — new, optional.
/// QUIZ_API_3_KEY=your_third_provider_key
/// QUIZ_API_3_BASE_URL=https://api.groq.com/openai/v1/chat/completions
/// QUIZ_API_3_MODEL=openai/gpt-oss-20b
/// ```
///
/// Point `QUIZ_API_2_BASE_URL` / `QUIZ_API_3_BASE_URL` at any other
/// OpenAI-chat-completions-compatible provider if you want real provider
/// diversity instead of 3 keys on the same provider.
class QuizApiConfigs {
  static const String _defaultBaseUrl =
      "https://api.groq.com/openai/v1/chat/completions";
  static const String _defaultModel = "openai/gpt-oss-20b";

  static String _env(String key) =>
      (dotenv.maybeGet(key) ?? dotenv.env[key] ?? '').trim();

  static List<QuizApiConfig> load() {
    return [
      QuizApiConfig(
        id: 'API 1',
        baseUrl: _env('QUIZ_API_1_BASE_URL').isNotEmpty
            ? _env('QUIZ_API_1_BASE_URL')
            : _defaultBaseUrl,
        // Backward compatible: falls back to the pre-existing `Quiz_API` key
        // if QUIZ_API_1_KEY isn't set, so nothing breaks for anyone already
        // running with a single key.
        apiKey: QuizApiConfig.sanitizeKey(
          _env('QUIZ_API_1_KEY').isNotEmpty
              ? _env('QUIZ_API_1_KEY')
              : _env('Quiz_API'),
        ),
        model: _env('QUIZ_API_1_MODEL').isNotEmpty
            ? _env('QUIZ_API_1_MODEL')
            : _defaultModel,
      ),
      QuizApiConfig(
        id: 'API 2',
        baseUrl: _env('QUIZ_API_2_BASE_URL').isNotEmpty
            ? _env('QUIZ_API_2_BASE_URL')
            : _defaultBaseUrl,
        apiKey: QuizApiConfig.sanitizeKey(_env('QUIZ_API_2_KEY')),
        model: _env('QUIZ_API_2_MODEL').isNotEmpty
            ? _env('QUIZ_API_2_MODEL')
            : _defaultModel,
      ),
      QuizApiConfig(
        id: 'API 3',
        baseUrl: _env('QUIZ_API_3_BASE_URL').isNotEmpty
            ? _env('QUIZ_API_3_BASE_URL')
            : _defaultBaseUrl,
        apiKey: QuizApiConfig.sanitizeKey(_env('QUIZ_API_3_KEY')),
        model: _env('QUIZ_API_3_MODEL').isNotEmpty
            ? _env('QUIZ_API_3_MODEL')
            : _defaultModel,
      ),
    ];
  }
}
