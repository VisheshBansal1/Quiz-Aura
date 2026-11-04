// ============================================================
// FILE: lib/features/battle/screens/battle_matchmaking_screen.dart
// Quick Match search: animated radar, elapsed time, cancel, timeout.
// Matching = enqueue myself, poll for a compatible waiting player and
// claim them in a Firestore transaction (see BattleDuelService.tryMatch).
// ============================================================

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../services/battle_repository.dart';
import '../services/battle_duel_service.dart';
import '../widgets/battle_widgets.dart';
import 'battle_match_screen.dart';

class BattleMatchmakingScreen extends StatefulWidget {
  final String category;

  const BattleMatchmakingScreen({super.key, this.category = ''});

  @override
  State<BattleMatchmakingScreen> createState() => _BattleMatchmakingScreenState();
}

class _BattleMatchmakingScreenState extends State<BattleMatchmakingScreen>
    with SingleTickerProviderStateMixin {
  static const int _timeoutSeconds = 60;

  late final AnimationController _anim;
  Timer? _timer;
  StreamSubscription<QueueClaim>? _claimSub;
  int _elapsed = 0;
  String? _error;
  bool _timedOut = false;
  bool _navigating = false;
  bool _polling = false;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
    _begin();
  }

  Future<void> _begin() async {
    setState(() {
      _elapsed = 0;
      _error = null;
      _timedOut = false;
    });
    try {
      await BattleDuelService.enqueue(widget.category);
    } on BattleException catch (e) {
      if (mounted) setState(() => _error = e.message);
      return;
    }
    if (!mounted) return;
    _claimSub?.cancel();
    _claimSub = BattleRepository.myQueueStream().listen((c) {
      if (c.battleId.isNotEmpty) _go(c.battleId);
    }, onError: (Object _) {});
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    if (!mounted || _navigating) return;
    setState(() => _elapsed++);
    if (_elapsed >= _timeoutSeconds) {
      _giveUp();
      return;
    }
    if (_elapsed % 4 == 1) _poll();
  }

  Future<void> _poll() async {
    if (_polling || _navigating) return;
    _polling = true;
    try {
      final id = await BattleDuelService.tryMatch(
        category: widget.category,
        elapsedSec: _elapsed,
      );
      if (id != null) _go(id);
    } on BattleException catch (e) {
      // Transient problems are fine — the next poll retries.
      if (!e.isRetryable && e.code != 'aborted' && mounted) {
        setState(() => _error = e.message);
        _timer?.cancel();
        BattleDuelService.cancelQueue();
      }
    } finally {
      _polling = false;
    }
  }

  void _giveUp() {
    _timer?.cancel();
    BattleDuelService.cancelQueue();
    if (mounted) setState(() => _timedOut = true);
  }

  void _go(String battleId) {
    if (_navigating || !mounted) return;
    _navigating = true;
    _timer?.cancel();
    _claimSub?.cancel();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => BattleMatchScreen(battleId: battleId)),
    );
  }

  Future<void> _cancel() async {
    _timer?.cancel();
    await BattleDuelService.cancelQueue();
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _claimSub?.cancel();
    _anim.dispose();
    if (!_navigating) BattleDuelService.cancelQueue(); // never leave a stale entry
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      // ignore: deprecated_member_use
      onWillPop: () async {
        await _cancel();
        return false;
      },
      child: BattleScaffold(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: _error != null
                ? _message(Icons.error_outline, _error!, 'Try again', _begin)
                : _timedOut
                    ? _message(
                        Icons.search_off,
                        'No opponent found right now.\nTry again, or challenge a friend.',
                        'Search again',
                        _begin)
                    : _searching(),
          ),
        ),
      ),
    );
  }

  Widget _searching() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 220,
          height: 220,
          child: AnimatedBuilder(
            animation: _anim,
            builder: (context, _) => CustomPaint(painter: _RadarPainter(_anim.value)),
          ),
        ),
        const SizedBox(height: 24),
        const Text('Searching for an opponent…',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(formatSeconds(_elapsed),
            style: const TextStyle(color: AppColors.battleGold, fontSize: 28)),
        const SizedBox(height: 6),
        const Text('Matching players of similar skill',
            style: TextStyle(color: Colors.white60, fontSize: 12)),
        const SizedBox(height: 28),
        OutlinedButton(
          onPressed: _cancel,
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: const BorderSide(color: Colors.white38),
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
          ),
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  Widget _message(IconData icon, String text, String action, VoidCallback onAction) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 64, color: Colors.white54),
        const SizedBox(height: 16),
        Text(text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 16)),
        const SizedBox(height: 24),
        ElevatedButton(onPressed: onAction, child: Text(action)),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Back', style: TextStyle(color: Colors.white70)),
        ),
      ],
    );
  }
}

class _RadarPainter extends CustomPainter {
  final double t;
  _RadarPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final maxR = size.width / 2;
    for (var i = 0; i < 3; i++) {
      final p = (t + i / 3) % 1.0;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = AppColors.accentTeal.withOpacity((1 - p) * 0.8);
      canvas.drawCircle(c, maxR * p, paint);
    }
    canvas.drawCircle(c, 10, Paint()..color = AppColors.battleGold);
  }

  @override
  bool shouldRepaint(covariant _RadarPainter old) => old.t != t;
}
