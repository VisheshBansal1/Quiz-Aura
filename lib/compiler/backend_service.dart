import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class BackendService {
  static const String _pistonUrl =
      'https://emkc.org/api/v2/piston/execute';

  static Future<Map<String, dynamic>> runCode({
    required String quizId,      // kept for future use
    required String questionId,  // kept for future use
    required String code,
    required String language,
    required String version,
    String stdin = '',
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse(_pistonUrl),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'language': _normalizeLanguage(language),
              'version': version,
              'files': [
                {
                  'name': _fileName(language),
                  'content': code,
                }
              ],
              'stdin': stdin,
              'args': [],
              'compile_timeout': 10000,
              'run_timeout': 5000,
              'compile_memory_limit': -1,
              'run_memory_limit': -1,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        throw Exception(
          'Piston HTTP ${response.statusCode}: ${response.body}',
        );
      }

      final Map<String, dynamic> data = jsonDecode(response.body);

      // 🔍 DEBUG (keep for now)
      print('PISTON RAW RESPONSE => $data');

      return {
        'stdout': data['run']?['stdout']?.toString() ?? '',
        'stderr': data['run']?['stderr']?.toString() ?? '',
        'compile_output':
            data['compile']?['stderr']?.toString() ?? '',
        'exitCode': data['run']?['code'],
      };
    } on SocketException {
      throw Exception('No internet connection');
    } on FormatException {
      throw Exception('Invalid response from execution server');
    } on http.ClientException catch (e) {
      throw Exception('HTTP error: ${e.message}');
    } catch (e) {
      throw Exception('Execution failed: $e');
    }
  }

  // -------- Normalize language names for Piston --------
  static String _normalizeLanguage(String language) {
    switch (language) {
      case 'python':
        return 'python3';
      case 'py':
        return 'python3';
      case 'cpp':
        return 'cpp';
      case 'c++':
        return 'cpp';
      case 'javascript':
        return 'javascript';
      case 'js':
        return 'javascript';
      case 'java':
        return 'java';
      default:
        return language;
    }
  }

  // -------- Correct file names per language --------
  static String _fileName(String language) {
    switch (language) {
      case 'cpp':
      case 'c++':
        return 'main.cpp';
      case 'java':
        return 'Main.java';
      case 'python':
      case 'python3':
      case 'py':
        return 'main.py';
      case 'javascript':
      case 'js':
        return 'main.js';
      default:
        return 'main';
    }
  }
}
