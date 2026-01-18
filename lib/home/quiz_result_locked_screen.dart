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

      if (!mounted) return;

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
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: const Text("Result Locked"),
          automaticallyImplyLeading: false,
          backgroundColor: Colors.transparent,
          elevation: 0,
          flexibleSpace: _gradientBg(),
        ),
        body: Stack(
          children: [
            _gradientBg(),

            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: _glassCard(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ===== ICON =====
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.orangeAccent.withOpacity(0.2),
                        ),
                        child: const Icon(
                          Icons.lock,
                          size: 52,
                          color: Colors.orangeAccent,
                        ),
                      ),

                      const SizedBox(height: 20),

                      // ===== TITLE =====
                      const Text(
                        "Quiz is still running",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),

                      const SizedBox(height: 10),

                      // ===== MESSAGE =====
                      const Text(
                        "Results will be available once the quiz ends.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),

                      const SizedBox(height: 24),

                      // ===== COUNTDOWN =====
                      Text(
                        _format(remaining),
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.redAccent,
                        ),
                      ),

                      const SizedBox(height: 6),

                      const Text(
                        "Remaining",
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
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
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.white.withOpacity(0.12),
        border: Border.all(
          color: Colors.white.withOpacity(0.25),
        ),
      ),
      child: child,
    );
  }
}
