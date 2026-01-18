import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class GroqAIService {
  static const String _endpoint =
      "https://api.groq.com/openai/v1/chat/completions";

  final String _apiKey;

  GroqAIService() : _apiKey = dotenv.env['Quiz_API'] ?? '' {
    if (_apiKey.isEmpty) {
      throw Exception("Quiz_API not found in .env");
    }
  }

  Future<List<Map<String, dynamic>>> generateMCQs({
    required String topic,
    required String difficulty,
    int count = 5,
  }) async {
    final prompt =
        '''
Generate $count UNIQUE multiple-choice questions on topic "$topic".
Difficulty: $difficulty.

Rules:
- Return ONLY a valid JSON array.
- No markdown.
- No explanations.
- No text before or after JSON.
- Exactly 4 options per question.
- correctIndex must be between 0 and 3.
- If unable to comply, return [].

JSON format:
[
  {
    "question": "string",
    "options": ["A","B","C","D"],
    "correctIndex": 0
  }
]
''';

    final response = await http.post(
      Uri.parse(_endpoint),
      headers: {
        "Authorization": "Bearer $_apiKey",
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "model": "llama-3.1-8b-instant",
        "messages": [
          {"role": "user", "content": prompt},
        ],
        "temperature": 0.3,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        "Groq API failed (${response.statusCode}): ${response.body}",
      );
    }

    final decoded = jsonDecode(response.body);
    final content = decoded['choices']?[0]?['message']?['content'];

    if (content is! String || content.trim().isEmpty) {
      throw Exception("Empty or invalid AI response");
    }

    final cleanJson = _extractJson(content);
    return _safeParseQuestions(cleanJson);
  }

  String _extractJson(String raw) {
    final start = raw.indexOf('[');
    final end = raw.lastIndexOf(']');
    if (start == -1 || end == -1 || end < start) {
      throw Exception("No valid JSON array found");
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
      if (question is! String || question.isEmpty) {
        throw Exception("Invalid question");
      }

      final options = q['options'];
      if (options is! List || options.length != 4) {
        throw Exception("Invalid options");
      }

      final correctIndex = q['correctIndex'];
      if (correctIndex is! int || correctIndex < 0 || correctIndex > 3) {
        throw Exception("Invalid correctIndex");
      }

      return {
        'question': question,
        'options': List<String>.from(options),
        'correctIndex': correctIndex,
      };
    }).toList();
  }
}
