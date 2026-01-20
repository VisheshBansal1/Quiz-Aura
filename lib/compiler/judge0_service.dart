import 'dart:convert';
import 'package:http/http.dart' as http;

class Judge0Service {
  // static const String _baseUrl = 'http://192.168.1.18:2358';
  static const String _baseUrl = 'http://127.0.0.1:2358';


  static Future<String> submit({
    required String code,
    required String input,
    required int languageId,
  }) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/submissions'),
      headers: const {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({
        'source_code': code,
        'stdin': input,
        'language_id': languageId,
        'base64_encoded': false,
      }),
    );

    if (res.statusCode != 201) {
      throw Exception('Submit failed: ${res.body}');
    }

    return jsonDecode(res.body)['token'];
  }

  static Future<Map<String, dynamic>> getResult(String token) async {
    final res = await http.get(
      Uri.parse(
        '$_baseUrl/submissions/$token?base64_encoded=false&fields=*',
      ),
      headers: const {
        'Accept': 'application/json',
        'Connection': 'close',
      },
    );

    if (res.statusCode != 200) {
      throw Exception('Result failed: ${res.body}');
    }

    return jsonDecode(res.body);
  }
}
