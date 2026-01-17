import 'dart:async';
import 'package:flutter/material.dart';

class QuizResultLockedScreen extends StatefulWidget {
  final DateTime endAt;

  const QuizResultLockedScreen({
    super.key,
    required this.endAt,
  });

  @override
  State<QuizResultLockedScreen> createState() =>
      _QuizResultLockedScreenState();
}

class _QuizResultLockedScreenState extends State<QuizResultLockedScreen> {
  Timer? _timer;
  late Duration remaining;

  @override
  void initState() {
    super.initState();
    remaining = widget.endAt.difference(DateTime.now());
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final diff = widget.endAt.difference(DateTime.now());
      if (diff.isNegative) {
        _timer?.cancel();
        setState(() => remaining = Duration.zero);
      } else {
        setState(() => remaining = diff);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _format(Duration d) {
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    return "${m}m ${s}s";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Result Locked"),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock, size: 64, color: Colors.orange),
            const SizedBox(height: 16),
            const Text(
              "Quiz is still running",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              "Results available in",
              style: TextStyle(color: Colors.grey[700]),
            ),
            const SizedBox(height: 8),
            Text(
              _format(remaining),
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
