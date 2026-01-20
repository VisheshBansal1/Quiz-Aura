import 'judge0_service.dart';

class CodingGrader {
  static Future<Map<String, dynamic>> grade({
    required String code,
    required int languageId,
    required List<Map<String, String>> visible,
    required List<Map<String, String>> hidden,
    required int pointsPerCase,
  }) async {
    int passed = 0;
    final int totalCases = visible.length + hidden.length;
    String? compilationError;

    Future<void> runCases(List<Map<String, String>> cases) async {
      for (final tc in cases) {
        // 1️⃣ submit code
        final token = await Judge0Service.submit(
          code: code,
          input: tc['input'] ?? '',
          languageId: languageId,
        );

        // 2️⃣ wait briefly (Judge0 needs time)
        await Future.delayed(const Duration(seconds: 2));

        // 3️⃣ get result
        final result = await Judge0Service.getResult(token);
        final int statusId = result['status']?['id'] ?? -1;

        // ❌ Compilation error → stop everything
        if (statusId == 6) {
          compilationError =
              _normalize(result['compile_output'] ?? 'Compilation error');
          return;
        }

        // ❌ Runtime error / TLE → test failed
        if (statusId != 3) {
          continue;
        }

        final actual = _normalize(result['stdout']);
        final expected = _normalize(tc['output']);

        if (actual == expected) {
          passed++;
        }
      }
    }

    await runCases(visible);

    if (compilationError != null) {
      return {
        'passed': 0,
        'total': totalCases,
        'score': 0,
        'error': 'Compilation Error',
        'details': compilationError,
      };
    }

    await runCases(hidden);

    return {
      'passed': passed,
      'total': totalCases,
      'score': passed * pointsPerCase,
    };
  }

  // ===============================
  // OUTPUT NORMALIZATION
  // ===============================
  static String _normalize(String? text) {
    if (text == null) return '';
    return text.trim().replaceAll('\r\n', '\n');
  }
}
