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
    final diff = widget.startAt.difference(DateTime.now());

    if (!mounted) return;

    if (diff.isNegative) {
      _timer?.cancel();
      setState(() => remaining = Duration.zero);
    } else {
      setState(() => remaining = diff);
    }
  }

  String _format(Duration d) {
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    return "${m}m ${s}s";
  }

  Future<void> _confirmAndStart() async {
    if (_starting) return;

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text("Start Quiz"),
        content: const Text(
          "• Timer will start immediately\n"
          "• You cannot go back\n"
          "• Leaving the app may submit the quiz\n\n"
          "Continue?",
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

    if (ok == true && mounted) {
      setState(() => _starting = true);
      Navigator.pop(context);
      widget.onConfirmedStart();
    }
  }

  @override
  Widget build(BuildContext context) {
    final canStart = remaining == Duration.zero;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Quiz Rules"),
        backgroundColor: Colors.transparent,
        elevation: 0,

        flexibleSpace: _gradientBg(),
      ),
      body: Stack(
        children: [
          _gradientBg(),
    
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ===== RULES CARD =====
                _glassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        "Rules",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 12),
                      Text("• No back navigation",
                          style: TextStyle(color: Colors.white70)),
                      Text("• Timer based quiz",
                          style: TextStyle(color: Colors.white70)),
                      Text("• Auto submit on timeout",
                          style: TextStyle(color: Colors.white70)),
                      Text("• Leaving app may submit quiz",
                          style: TextStyle(color: Colors.white70)),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // ===== COUNTDOWN =====
                Center(
                  child: _glassCard(
                    child: Column(
                      children: [
                        Text(
                          canStart
                              ? "Quiz is live"
                              : "Quiz starts in",
                          style: const TextStyle(
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          canStart ? "READY" : _format(remaining),
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: canStart
                                ? Colors.greenAccent
                                : Colors.redAccent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    
                const Spacer(),

                // ===== START BUTTON =====
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: canStart ? _confirmAndStart : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      canStart
                          ? "Join Quiz"
                          : "Waiting for start time",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ================= UI HELPERS =================

  static Widget _gradientBg() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0F2027),
            Color(0xFF203A43),
            Color(0xFF2C5364),
          ],
        ),
      ),
    );
  }

  static Widget _glassCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withOpacity(0.12),
        border: Border.all(
          color: Colors.white.withOpacity(0.25),
        ),
      ),
      child: child,
    );
  }
}
