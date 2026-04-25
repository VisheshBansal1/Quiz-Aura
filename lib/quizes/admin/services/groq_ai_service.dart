import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class GroqAIService {
  static const String _endpoint =
      "https://api.groq.com/openai/v1/chat/completions";

  final String _apiKey;

  // FIX: Constructor no longer throws when the key is missing.
  // On Flutter web, dotenv may not be loaded yet (or the .env file may be
  // missing from the web assets). Throwing here crashes the screen before
  // the user can see any error UI. Instead we store an empty key and let
  // generateMCQs() surface a clean error.
  GroqAIService()
    : _apiKey = dotenv.maybeGet('Quiz_API') ?? dotenv.env['Quiz_API'] ?? '';

  bool get isConfigured => _apiKey.isNotEmpty;

  Future<List<Map<String, dynamic>>> generateMCQs({
    required String topic,
    required String difficulty,
    int count = 5,
  }) async {
    // FIX: Return a clear error entry (not the silent fallback) when the key
    // is absent. The screen can check for this and show a proper message.
    if (_apiKey.isEmpty) {
      throw Exception(
        'AI API key (Quiz_API) is not configured.\n'
        'Add it to your .env file and ensure it is listed in pubspec.yaml assets.',
      );
    }

    final prompt = '''
Generate \$count UNIQUE multiple-choice questions on topic "\$topic".
Difficulty: \$difficulty.

Rules:
- Return ONLY a valid JSON array.
- No markdown.
- No text outside JSON.
- Exactly 4 options per question.
- correctIndex must be between 0 and 3.
- Each question MUST include a "solution" explaining why the correct answer is right.
- Keep solution short but clear.
- If unable to comply, return [].

JSON format:
[
  {
    "question": "string",
    "options": ["A","B","C","D"],
    "correctIndex": 0,
    "solution": "Explanation why correct answer is right"
  }
]
''';

    try {
      final response = await http.post(
        Uri.parse(_endpoint),
        headers: {
          "Authorization": "Bearer \$_apiKey",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "model": "llama-3.1-8b-instant",
          "messages": [
            {"role": "user", "content": prompt},
          ],
          "temperature": 0.3,
          "max_tokens": 1500,
        }),
      );

      // FIX: surface specific HTTP errors instead of silently falling back,
      // so the developer (and user) knows what went wrong.
      if (response.statusCode == 401) {
        throw Exception('Invalid API key. Check Quiz_API in your .env file.');
      }
      if (response.statusCode == 429) {
        throw Exception(
          'Groq API rate limit reached. Please wait a moment and try again.',
        );
      }
      if (response.statusCode != 200) {
        throw Exception(
          'Groq API error \${response.statusCode}: \${response.body}',
        );
      }

      final decoded = jsonDecode(response.body);
      final content = decoded['choices']?[0]?['message']?['content'];

      if (content is! String || content.trim().isEmpty) {
        throw Exception('Empty response from AI. Please try again.');
      }

      final cleanJson = _extractJson(content);
      return _safeParseQuestions(cleanJson);
    } on Exception {
      rethrow; // propagate our clean exceptions to the UI
    } catch (e) {
      // FIX: wrap unknown errors (e.g. SocketException on web CORS) with
      // a helpful message so the catch in the screen can display it.
      throw Exception(
        'Could not reach AI service.\n'
        'On web, ensure the Groq API allows your origin (CORS), '
        'or use a backend proxy function.\nDetail: \$e',
      );
    }
  }

  String _extractJson(String raw) {
    final start = raw.indexOf('[');
    final end = raw.lastIndexOf(']');
    if (start == -1 || end == -1 || end < start) {
      throw Exception("No valid JSON array found in AI response");
    }
    return raw.substring(start, end + 1);
  }

  List<Map<String, dynamic>> _safeParseQuestions(String raw) {
    final parsed = jsonDecode(raw);

    if (parsed is! List) {
      throw Exception("Response is not a JSON array");
    }

    return parsed.map<Map<String, dynamic>>((q) {
      if (q is! Map<String, dynamic>) {
        throw Exception("Invalid question object");
      }

      final question = q['question'];
      final options = q['options'];
      final correctIndex = q['correctIndex'];
      final solution = q['solution'];

      if (question is! String || question.isEmpty) {
        throw Exception("Invalid question text");
      }

      if (options is! List || options.length != 4) {
        throw Exception("Invalid options — need exactly 4");
      }

      if (correctIndex is! int || correctIndex < 0 || correctIndex > 3) {
        throw Exception("Invalid correctIndex");
      }

      if (solution is! String || solution.trim().length < 10) {
        throw Exception("Invalid solution text");
      }

      return {
        'question': question,
        'options': List<String>.from(options),
        'correctIndex': correctIndex,
        'solution': solution,
      };
    }).toList();
  }
}
