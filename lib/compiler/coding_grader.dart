// import 'judge0_service.dart';

// class CodingGrader {
//   static Future<Map<String, dynamic>> grade({
//     required String code,
//     required String language,
//     required List<Map<String, String>> visible,
//     required List<Map<String, String>> hidden,
//     required int pointsPerCase,
//   }) async {
//     int passed = 0;
//     int totalCases = visible.length + hidden.length;

//     Future<void> run(List<Map<String, String>> cases) async {
//       for (final tc in cases) {
//         final output = await Judge0Service.submit(
//           code: code,
//           input: tc['input']!,
//           language: language,
//         );

//         if (output == tc['output']!.trim()) {
//           passed++;
//         }
//       }
//     }

//     await run(visible);
//     await run(hidden);

//     return {
//       'passed': passed,
//       'total': totalCases,
//       'score': passed * pointsPerCase,
//     };
//   }
// }
