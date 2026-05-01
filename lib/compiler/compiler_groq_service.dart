// compiler_groq_service.dart
// This file contains ONLY the GroqService AI validator.
// CodingQuizScreen lives in coding_quiz_screen.dart — do NOT duplicate it here.

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class GroqService {
  // API key is loaded from .env — never hardcode secrets
  static String get _apiKey => dotenv.env['GROQ_API_KEY_COMPILER'] ?? '';
  static const _url = 'https://api.groq.com/openai/v1/chat/completions';

  /// Returns true if the user's [code] correctly solves [problem]
  /// and produces output equivalent to [expected].
  static Future<bool> validateCode({
    required String problem,
    required String expected,
    required String code,
    required String language,
  }) async {
    if (_apiKey.isEmpty) return false;

    try {
      final response = await http
          .post(
            Uri.parse(_url),
            headers: {
              'Authorization': 'Bearer $_apiKey',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'model': 'llama-3.1-8b-instant',
              'temperature': 0,
              'max_tokens': 64,
              'messages': [
                {
                  'role': 'system',
                  'content':
                      'You are a strict programming judge. Respond ONLY with valid JSON. '
                      'No explanation. No markdown. No code fences.',
                },
                {
                  'role': 'user',
                  'content': '''
Problem:
$problem

Expected Output:
$expected

User Code ($language):
$code

Does the user's code correctly solve the problem and produce the expected output?
Respond ONLY with this exact JSON (nothing else):
{"is_correct": true}
or
{"is_correct": false}
''',
                }
              ],
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) return false;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final content = data['choices']?[0]?['message']?['content'] ?? '';

      // Strip markdown code fences if model misbehaves
      final clean = content
          .replaceAll(RegExp(r'```json\s*'), '')
          .replaceAll(RegExp(r'```\s*'), '')
          .trim();

      final result = jsonDecode(clean) as Map<String, dynamic>;
      return result['is_correct'] == true;
    } catch (_) {
      return false;
    }
  }
}
