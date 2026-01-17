import 'dart:async';
import 'package:flutter/material.dart';

class QuizRulesScreen extends StatefulWidget {
  final DateTime startAt;
  final VoidCallback onConfirmedStart;

  const QuizRulesScreen({
    super.key,
    required this.startAt,
    required this.onConfirmedStart,
  });

  @override
  State<QuizRulesScreen> createState() => _QuizRulesScreenState();
}

class _QuizRulesScreenState extends State<QuizRulesScreen> {
  Timer? _timer;
  Duration remaining = Duration.zero;
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    _updateRemaining();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateRemaining();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _updateRemaining() {
    final now = DateTime.now();
    final diff = widget.startAt.difference(now);

    if (diff.isNegative || diff == Duration.zero) {
      _timer?.cancel();
      if (mounted) {
        setState(() => remaining = Duration.zero);
      }
    } else {
      if (mounted) {
        setState(() => remaining = diff);
      }
    }
  }

  String _format(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);

    if (h > 0) return "${h}h ${m}m ${s}s";
    return "${m}m ${s}s";
  }

  Future<void> _confirmAndStart() async {
    if (_starting) return;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text("Start Quiz"),
        content: const Text(
          "Once you start:\n\n"
          "• You cannot go back\n"
          "• Timer starts immediately\n"
          "• Leaving app may submit quiz\n\n"
          "Do you want to continue?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Start"),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _starting = true);

      // 🔥 THIS IS THE FIX
      Navigator.pop(context); // remove rules screen
      widget.onConfirmedStart(); // start quiz
    }
  }

  @override
  Widget build(BuildContext context) {
    final canStart = remaining == Duration.zero;

    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Quiz Rules"),
          automaticallyImplyLeading: false,
        ),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Quiz Rules",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              const Text("• No back navigation during quiz"),
              const Text("• Timer-based quiz"),
              const Text("• Auto submit when time ends"),
              const Text("• Leaving app may submit quiz"),

              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),

              Center(
                child: Column(
                  children: [
                    Text(
                      canStart ? "Quiz is live" : "Quiz starts in",
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      canStart ? "READY" : _format(remaining),
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: canStart ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: canStart ? _confirmAndStart : null,
                  child: Text(
                    canStart ? "Join Quiz" : "Waiting for start time",
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
