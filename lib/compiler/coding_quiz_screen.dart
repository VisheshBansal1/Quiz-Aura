import 'package:flutter/material.dart';
import 'judge0_service.dart';
import 'language_constants.dart';

class CodingQuizScreen extends StatefulWidget {
  const CodingQuizScreen({super.key});

  @override
  State<CodingQuizScreen> createState() => _CodingQuizScreenState();
}

class _CodingQuizScreenState extends State<CodingQuizScreen> {
  final TextEditingController codeCtrl = TextEditingController();
  final TextEditingController inputCtrl = TextEditingController();

  late String selectedLang;
  bool running = false;
  String output = "";

  @override
  void initState() {
    super.initState();
    selectedLang = languageIds.keys.first;
  }

  // ===============================
  // RUN CODE (NO POLLING)
  // ===============================
  Future<void> runCode() async {
  if (running) return;

  setState(() {
    running = true;
    output = "Running...";
  });

  try {
    final token = await Judge0Service.submit(
      code: codeCtrl.text,
      input: inputCtrl.text,
      languageId: languageIds[selectedLang]!,
    );

    await Future.delayed(const Duration(seconds: 2));

    final result = await Judge0Service.getResult(token);

    setState(() {
      output = result['stdout']?.toString().trim() ?? 'No output';
    });
  } catch (e) {
    setState(() {
      output = "❌ Error: $e";
    });
  } finally {
    running = false;
  }
}


  // ===============================
  // OUTPUT FORMATTER
  // ===============================
  String _formatResult(Map<String, dynamic> r) {
    final statusId = r['status']?['id'];
    final statusText = r['status']?['description'] ?? 'Unknown';

    if (statusId == 6 && r['compile_output'] != null) {
      return "❌ Compilation Error\n\n${_clean(r['compile_output'])}";
    }

    if ((statusId == 11 || statusId == 12) && r['stderr'] != null) {
      return "❌ Runtime Error\n\n${_clean(r['stderr'])}";
    }

    if (statusId == 5) {
      return "⏱️ Time Limit Exceeded";
    }

    return """
✅ Status: $statusText

Output:
${_clean(r['stdout'])}

Time: ${r['time']} sec
Memory: ${r['memory']} KB
""";
  }

  String _clean(String? text) {
    if (text == null) return '';
    return text.trim().replaceAll('\r\n', '\n');
  }

  @override
  void dispose() {
    codeCtrl.dispose();
    inputCtrl.dispose();
    super.dispose();
  }

  // ===============================
  // UI
  // ===============================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Coding Quiz Compiler")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              value: selectedLang,
              items: languageIds.keys
                  .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                  .toList(),
              onChanged: (v) => setState(() => selectedLang = v!),
              decoration: const InputDecoration(labelText: "Language"),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: codeCtrl,
              maxLines: 8,
              decoration: const InputDecoration(
                labelText: "Source Code",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: inputCtrl,
              decoration: const InputDecoration(
                labelText: "Input (stdin)",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: running ? null : runCode,
                child: running
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text("Run Code"),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  output,
                  style: const TextStyle(fontFamily: "monospace"),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
