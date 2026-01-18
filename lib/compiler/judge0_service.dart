// import 'dart:convert';
// import 'package:http/http.dart' as http;

// class Judge0Service {
//   static const _baseUrl = 'https://judge0-ce.p.rapidapi.com';
//   static const _apiKey = 'YOUR_RAPIDAPI_KEY';

//   static const _headers = {
//     'Content-Type': 'application/json',
//     'X-RapidAPI-Key': _apiKey,
//     'X-RapidAPI-Host': 'judge0-ce.p.rapidapi.com',
//   };

//   static int languageId(String lang) {
//     switch (lang) {
//       case 'python':
//         return 71;
//       case 'cpp':
//         return 54;
//       default:
//         throw Exception("Unsupported language");
//     }
//   }

//   static Future<String> submit({
//     required String code,
//     required String input,
//     required String language,
//   }) async {
//     final res = await http.post(
//       Uri.parse('$_baseUrl/submissions?wait=true'),
//       headers: _headers,
//       body: jsonEncode({
//         'source_code': code,
//         'language_id': languageId(language),
//         'stdin': input,
//       }),
//     );

//     final data = jsonDecode(res.body);
//     return (data['stdout'] ?? '').toString().trim();
//   }
// }
