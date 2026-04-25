import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/level_service.dart';

/// A polished XP + Level card for the profile screen.
/// Shows: level badge, rank title, animated progress bar,
/// XP numbers, total XP, and milestone hints.
class XpLevelCard extends StatefulWidget {
  final int level;
  final int xp;
  final int requiredXp;
  final int totalXp;

  const XpLevelCard({
    super.key,
    required this.level,
    required this.xp,
    required this.requiredXp,
    required this.totalXp,
  });

  @override
  State<XpLevelCard> createState() => _XpLevelCardState();
}

class _XpLevelCardState extends State<XpLevelCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _progressAnim;
  late Animation<double> _shimmerAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    final progress = widget.requiredXp > 0
        ? (widget.xp / widget.requiredXp).clamp(0.0, 1.0)
        : 0.0;

    _progressAnim = Tween<double>(begin: 0, end: progress).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.8, curve: Curves.easeOutCubic)),
    );
    _shimmerAnim = Tween<double>(begin: -1.5, end: 2.5).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.6, 1.0, curve: Curves.easeInOut)),
    );

    _ctrl.forward();
  }

  @override
  void didUpdateWidget(XpLevelCard old) {
    super.didUpdateWidget(old);
    if (old.xp != widget.xp || old.level != widget.level) {
      final progress = widget.requiredXp > 0
          ? (widget.xp / widget.requiredXp).clamp(0.0, 1.0)
          : 0.0;
      _progressAnim = Tween<double>(
        begin: _progressAnim.value,
        end: progress,
      ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  // Returns rank-specific gradient colors
  List<Color> get _rankGradient {
    final level = widget.level;
    if (level >= 30) return [const Color(0xFFFFD700), const Color(0xFFFF8C00)]; // Legend – gold
    if (level >= 20) return [const Color(0xFFDA70D6), const Color(0xFF9C27B0)]; // Master – purple
    if (level >= 10) return [const Color(0xFF00E5FF), const Color(0xFF0288D1)]; // Challenger – cyan
    if (level >= 5)  return [const Color(0xFF69F0AE), const Color(0xFF00897B)]; // Explorer – teal
    return [const Color(0xFFB0BEC5), const Color(0xFF546E7A)];                  // Beginner – grey
  }

  Color get _barColor => _rankGradient.first;

  String get _rankTitle => LevelService.getRankTitle(widget.level);

  String get _nextRankTitle {
    final level = widget.level;
    if (level < 5)  return 'Explorer (Lv 5)';
    if (level < 10) return 'Challenger (Lv 10)';
    if (level < 20) return 'Master (Lv 20)';
    if (level < 30) return 'Legend (Lv 30)';
    return 'Max Rank 🏆';
  }

  bool get _isMaxRank => widget.level >= 30;

  String _formatXp(int xp) {
    if (xp >= 1000000) return '${(xp / 1000000).toStringAsFixed(1)}M';
    if (xp >= 1000)    return '${(xp / 1000).toStringAsFixed(1)}K';
    return '$xp';
  }

  @override
  Widget build(BuildContext context) {
    final xpLeft = (widget.requiredXp - widget.xp).clamp(0, widget.requiredXp);
    final progressPct = widget.requiredXp > 0
        ? ((widget.xp / widget.requiredXp) * 100).clamp(0, 100).round()
        : 0;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.white.withOpacity(0.07),
        border: Border.all(color: Colors.white.withOpacity(0.13)),
      ),
      child: Column(
        children: [
          // ── Top row: level badge + info ─────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                _LevelBadge(level: widget.level, gradient: _rankGradient),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            _rankTitle,
                            style: TextStyle(
                              color: _barColor,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(width: 6),
                          if (_isMaxRank)
                            const Text('👑', style: TextStyle(fontSize: 14)),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _isMaxRank
                            ? 'You\'ve reached the top!'
                            : 'Next: $_nextRankTitle',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 10),
                      // ── XP progress bar ──────────────────────────────
                      AnimatedBuilder(
                        animation: _ctrl,
                        builder: (_, __) => _XpProgressBar(
                          progress: _progressAnim.value,
                          shimmerPos: _shimmerAnim.value,
                          color: _barColor,
                          gradient: _rankGradient,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${_formatXp(widget.xp)} / ${_formatXp(widget.requiredXp)} XP',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '$progressPct%',
                            style: TextStyle(
                              color: _barColor,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Divider ─────────────────────────────────────────────────────
          Divider(color: Colors.white.withOpacity(0.09), height: 1),

          // ── Bottom row: stats ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                _StatChip(
                  icon: Icons.star_rounded,
                  value: _formatXp(widget.totalXp),
                  label: 'Total XP',
                  color: Colors.amber,
                ),
                _divider(),
                _StatChip(
                  icon: Icons.trending_up_rounded,
                  value: _isMaxRank ? '—' : _formatXp(xpLeft),
                  label: _isMaxRank ? 'Maxed' : 'XP to next',
                  color: Colors.tealAccent,
                ),
                _divider(),
                _StatChip(
                  icon: Icons.flash_on_rounded,
                  value: '${widget.level}',
                  label: 'Level',
                  color: _barColor,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() => Container(
        width: 1,
        height: 38,
        color: Colors.white.withOpacity(0.08),
      );
}

// ── Level badge circle with gradient border ──────────────────────────────────
class _LevelBadge extends StatelessWidget {
  final int level;
  final List<Color> gradient;

  const _LevelBadge({required this.level, required this.gradient});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: gradient.first.withOpacity(0.45),
            blurRadius: 16,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('⚡', style: TextStyle(fontSize: 14)),
            Text(
              '$level',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                height: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Animated XP progress bar with shimmer ────────────────────────────────────
class _XpProgressBar extends StatelessWidget {
  final double progress;
  final double shimmerPos;
  final Color color;
  final List<Color> gradient;

  const _XpProgressBar({
    required this.progress,
    required this.shimmerPos,
    required this.color,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, constraints) {
      final w = constraints.maxWidth;
      final filled = w * progress;

      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          height: 10,
          child: Stack(
            children: [
              // Background track
              Container(color: Colors.white.withOpacity(0.1)),
              // Filled portion with gradient
              Container(
                width: filled,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: gradient),
                ),
              ),
              // Shimmer sweep
              if (progress > 0.05)
                Positioned(
                  left: filled * shimmerPos - 24,
                  top: 0,
                  bottom: 0,
                  width: 40,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withOpacity(0),
                          Colors.white.withOpacity(0.35),
                          Colors.white.withOpacity(0),
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    });
  }
}

// ── Small stat chip ──────────────────────────────────────────────────────────
class _StatChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 10),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
