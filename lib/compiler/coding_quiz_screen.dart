// import 'dart:async';
// import 'package:flutter/material.dart';
// import 'judge0_service.dart';
// import 'language_constants.dart';

// class CodingQuizScreen extends StatefulWidget {
//   const CodingQuizScreen({super.key});

//   @override
//   State<CodingQuizScreen> createState() => _CodingQuizScreenState();
// }

// class _CodingQuizScreenState extends State<CodingQuizScreen> {
//   final TextEditingController codeCtrl = TextEditingController();
//   final TextEditingController inputCtrl = TextEditingController();

//   String selectedLang = "Python";
//   bool running = false;
//   String output = "";

//   Future<void> runCode() async {
//     if (running) return;

//     setState(() {
//       running = true;
//       output = "Running...";
//     });

//     try {
//       final token = await Judge0Service.submitCode(
//         sourceCode: codeCtrl.text,
//         languageId: languageIds[selectedLang]!,
//         stdin: inputCtrl.text,
//       );

//       Map<String, dynamic> result;

//       do {
//         await Future.delayed(const Duration(seconds: 1));
//         result = await Judge0Service.getResult(token);
//       } while (result['status']['id'] <= 2);

//       setState(() {
//         output = _formatResult(result);
//       });
//     } catch (e) {
//       setState(() {
//         output = "Error: $e";
//       });
//     } finally {
//       setState(() => running = false);
//     }
//   }

//   String _formatResult(Map<String, dynamic> r) {
//     final status = r['status']['description'];

//     if (r['compile_output'] != null) {
//       return "❌ Compilation Error\n\n${r['compile_output']}";
//     }

//     if (r['stderr'] != null) {
//       return "❌ Runtime Error\n\n${r['stderr']}";
//     }

//     return """
// ✅ Status: $status

// Output:
// ${r['stdout'] ?? ''}

// Time: ${r['time']} sec
// Memory: ${r['memory']} KB
// """;
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text("Coding Quiz Compiler")),
//       body: Padding(
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           children: [
//             DropdownButtonFormField<String>(
//               value: selectedLang,
//               items: languageIds.keys
//                   .map(
//                     (l) => DropdownMenuItem(
//                       value: l,
//                       child: Text(l),
//                     ),
//                   )
//                   .toList(),
//               onChanged: (v) => setState(() => selectedLang = v!),
//               decoration: const InputDecoration(
//                 labelText: "Language",
//               ),
//             ),

//             const SizedBox(height: 12),

//             TextField(
//               controller: codeCtrl,
//               maxLines: 8,
//               decoration: const InputDecoration(
//                 labelText: "Source Code",
//                 border: OutlineInputBorder(),
//               ),
//             ),

//             const SizedBox(height: 12),

//             TextField(
//               controller: inputCtrl,
//               decoration: const InputDecoration(
//                 labelText: "Input (stdin)",
//                 border: OutlineInputBorder(),
//               ),
//             ),

//             const SizedBox(height: 16),

//             SizedBox(
//               width: double.infinity,
//               child: ElevatedButton(
//                 onPressed: runCode,
//                 child: running
//                     ? const CircularProgressIndicator(color: Colors.white)
//                     : const Text("Run Code"),
//               ),
//             ),

//             const SizedBox(height: 16),

//             Expanded(
//               child: SingleChildScrollView(
//                 child: Text(
//                   output,
//                   style: const TextStyle(fontFamily: "monospace"),
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
