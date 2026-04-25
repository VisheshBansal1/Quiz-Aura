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
    _tick();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _tick() {
    if (!mounted) return;

    final diff = widget.startAt.difference(DateTime.now());

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
    return "${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";
  }

  Future<void> _confirmAndStart() async {
    if (_starting) return;

    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text("Start Test"),
        content: const Text(
          "• Timer starts immediately\n"
          "• No back navigation allowed\n"
          "• Switching apps may submit your test\n"
          "• Test auto-submits on timeout\n\n"
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

    if (confirm == true && mounted) {
      setState(() => _starting = true);
      widget.onConfirmedStart(); // 🚀 clean single exit
    }
  }

  @override
  Widget build(BuildContext context) {
    final canStart = remaining == Duration.zero;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Test Instructions", style: TextStyle(color: Colors.white),),
        backgroundColor: Colors.transparent,
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: Icon(Icons.arrow_back, color: Colors.white,),
        ),
        elevation: 0,
        flexibleSpace: _gradientBg(),
      ),
      body: Stack(
        children: [
          _gradientBg(),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // ===== RULES =====
                _glassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        "Important Instructions",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 14),
                      _Rule("This is a time-bound test"),
                      _Rule("You cannot navigate back"),
                      _Rule("Do not leave or minimize the app"),
                      _Rule("Test auto-submits when time ends"),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // ===== COUNTDOWN =====
                _glassCard(
                  child: Column(
                    children: [
                      Text(
                        canStart ? "TEST IS LIVE" : "TEST STARTS IN",
                        style: TextStyle(
                          color: canStart
                              ? Colors.greenAccent
                              : Colors.white70,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        canStart ? "READY" : _format(remaining),
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: canStart
                              ? Colors.greenAccent
                              : Colors.redAccent,
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // ===== START BUTTON =====
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: canStart ? _confirmAndStart : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          canStart ? Colors.greenAccent : Colors.grey,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      canStart ? "START TEST" : "WAITING FOR START",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
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
        border: Border.all(color: Colors.white.withOpacity(0.25)),
      ),
      child: child,
    );
  }
}

// ===== SMALL RULE WIDGET =====
class _Rule extends StatelessWidget {
  final String text;

  const _Rule(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const Icon(Icons.circle, size: 6, color: Colors.white70),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }
}
