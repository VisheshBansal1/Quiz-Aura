import 'dart:convert';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// Code execution via JDoodle Compiler API.
///
/// Setup (one-time, free):
///   1. Sign up at https://www.jdoodle.com/compiler-api/
///   2. Copy your Client ID and Client Secret
///   3. Add to your .env file:
///        JDOODLE_CLIENT_ID=your_client_id
///        JDOODLE_CLIENT_SECRET=your_client_secret
///
/// Free tier: 200 compilations / day — plenty for a quiz app.
class BackendService {
  static const String _jdoodleUrl =
      'https://api.jdoodle.com/v1/execute';

  static String get _clientId =>
      dotenv.env['JDOODLE_CLIENT_ID'] ?? '';
  static String get _clientSecret =>
      dotenv.env['JDOODLE_CLIENT_SECRET'] ?? '';

  // ── Language → JDoodle language key + versionIndex ──────────────────────
  static Map<String, String> _jdoodleParams(String language) {
    switch (language.toLowerCase().trim()) {
      case 'c':
        return {'language': 'c',       'versionIndex': '5'};
      case 'cpp':
      case 'c++':
        return {'language': 'cpp17',   'versionIndex': '1'};
      case 'java':
        return {'language': 'java',    'versionIndex': '4'};
      case 'python3':
      case 'python':
      case 'py':
        return {'language': 'python3', 'versionIndex': '4'};
      case 'javascript':
      case 'js':
        return {'language': 'nodejs',  'versionIndex': '4'};
      default:
        return {'language': language,  'versionIndex': '0'};
    }
  }

  // ── Main execution entry point ───────────────────────────────────────────
  static Future<Map<String, dynamic>> runCode({
    required String quizId,
    required String questionId,
    required String code,
    required String language,
    required String version,   // kept for API compat — JDoodle uses versionIndex
    String stdin = '',
  }) async {
    if (_clientId.isEmpty || _clientSecret.isEmpty) {
      return {
        'stdout': '',
        'stderr': '',
        'compile_output':
            '⚠️  JDoodle API keys not configured.\n\n'
            'Add these to your .env file:\n'
            '  JDOODLE_CLIENT_ID=your_client_id\n'
            '  JDOODLE_CLIENT_SECRET=your_client_secret\n\n'
            'Get free keys at: https://www.jdoodle.com/compiler-api',
        'exitCode': -1,
      };
    }

    try {
      final params = _jdoodleParams(language);

      final response = await http
          .post(
            Uri.parse(_jdoodleUrl),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'clientId':     _clientId,
              'clientSecret': _clientSecret,
              'script':       code,
              'stdin':        stdin,
              'language':     params['language'],
              'versionIndex': params['versionIndex'],
            }),
          )
          .timeout(const Duration(seconds: 25));

      if (response.statusCode == 401) {
        throw Exception(
          'Invalid JDoodle API credentials.\n'
          'Check JDOODLE_CLIENT_ID and JDOODLE_CLIENT_SECRET in your .env',
        );
      }

      if (response.statusCode == 429) {
        throw Exception(
          'JDoodle daily limit reached (200/day on free plan).\n'
          'Limit resets at midnight IST.',
        );
      }

      if (response.statusCode != 200) {
        throw Exception(
          'JDoodle error ${response.statusCode}: ${response.body}',
        );
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      // JDoodle returns: { output, statusCode, memory, cpuTime, isExecutionSuccess }
      final rawOutput = data['output']?.toString() ?? '';
      final exitCode  = data['statusCode'];

      // JDoodle merges stdout + stderr into `output`.
      // Detect compile errors by common patterns.
      final isCompileError = rawOutput.contains('error:') &&
          (rawOutput.contains('.java:') ||
           rawOutput.contains('.cpp:') ||
           rawOutput.contains('.c:') ||
           rawOutput.contains('File "') ||
           rawOutput.contains('SyntaxError'));

      return {
        'stdout':         isCompileError ? '' : rawOutput,
        'stderr':         '',
        'compile_output': isCompileError ? rawOutput : '',
        'exitCode':       exitCode,
        'memory':         data['memory'],
        'cpuTime':        data['cpuTime'],
      };
    } on SocketException {
      throw Exception(
          'No internet connection. Check your network and try again.');
    } on FormatException {
      throw Exception('Invalid response from JDoodle API.');
    } on http.ClientException catch (e) {
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      rethrow;
    }
  }
}
