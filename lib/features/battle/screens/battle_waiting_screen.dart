// ============================================================
// FILE: lib/features/battle/screens/battle_waiting_screen.dart
// Host sees this screen after creating a battle.
// Shows the invite link and waits for the opponent to join.
// Auto-navigates to BattleActiveScreen when status → active.
// ============================================================

import 'package:QuizSphere/core/models/battle_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/glass_card.dart';
import '../services/battle_v2_service.dart';
import 'battle_active_screen.dart';

class BattleWaitingScreen extends StatefulWidget {
  final String battleId;

  const BattleWaitingScreen({super.key, required this.battleId});

  @override
  State<BattleWaitingScreen> createState() => _BattleWaitingScreenState();
}

class _BattleWaitingScreenState extends State<BattleWaitingScreen> {
  bool _navigated = false;

  String get _inviteLink => BattleV2Service.buildInviteLink(widget.battleId);

  void _copyLink() {
    Clipboard.setData(ClipboardData(text: _inviteLink));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Invite link copied! 📋'),
        backgroundColor: Colors.teal,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _copyCode() {
    Clipboard.setData(ClipboardData(text: widget.battleId));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Battle code copied! 📋'),
        backgroundColor: Colors.teal,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _cancel() async {
    try {
      await BattleV2Service.cancelBattle(battleId: widget.battleId);
    } catch (_) {}
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: const Color(0xFF203A43),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text(
              'Cancel Battle?',
              style: TextStyle(color: Colors.white),
            ),
            content: const Text(
              'This will cancel the battle and your friend will not be able to join.',
              style: TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Stay', style: TextStyle(color: Colors.teal)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Cancel Battle',
                  style: TextStyle(color: Colors.redAccent),
                ),
              ),
            ],
          ),
        );
        if (leave == true) _cancel();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Container(
              decoration: const BoxDecoration(gradient: AppColors.mainGradient),
            ),
            SafeArea(
              child: StreamBuilder<BattleV2Model>(
                stream: BattleV2Service.battleStream(widget.battleId),
                builder: (context, snap) {
                  final battle = snap.data;

                  // Auto-navigate when opponent joins
                  if (battle != null && battle.isActive && !_navigated) {
                    _navigated = true;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                BattleActiveScreen(battleId: widget.battleId),
                          ),
                        );
                      }
                    });
                  }

                  if (battle?.status == BattleV2Status.cancelled) {
                    return const Center(
                      child: Text(
                        'Battle cancelled',
                        style: TextStyle(color: Colors.redAccent, fontSize: 16),
                      ),
                    );
                  }

                  return Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Back/cancel button
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.close,
                                color: Colors.white,
                              ),
                              onPressed: _cancel,
                              tooltip: 'Cancel Battle',
                            ),
                            const Expanded(
                              child: Text(
                                'Waiting for Opponent',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 48),
                          ],
                        ),

                        const Spacer(),

                        // Animated waiting indicator
                        const _PulsingIcon(),

                        const SizedBox(height: 24),

                        const Text(
                          'Your battle is ready!',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 8),

                        const Text(
                          'Share the invite link below with your friend.\nThe battle starts as soon as they join.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white60, fontSize: 14),
                        ),

                        const SizedBox(height: 32),

                        // Invite link card
                        GlassCard(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              const Text(
                                'Invite Link',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                  letterSpacing: 1,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _inviteLink,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.tealAccent,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: _copyLink,
                                      icon: const Icon(Icons.copy, size: 16),
                                      label: const Text('Copy Link'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.white,
                                        side: const BorderSide(
                                          color: Colors.white24,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: _copyCode,
                                      icon: const Icon(Icons.tag, size: 16),
                                      label: const Text('Copy Code'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.white,
                                        side: const BorderSide(
                                          color: Colors.white24,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Battle code (large)
                        GlassCard(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                          backgroundColor: Colors.white.withOpacity(0.05),
                          child: Column(
                            children: [
                              const Text(
                                'Battle Code',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                widget.battleId,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.5,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),

                        const Spacer(),

                        // Cancel button
                        TextButton(
                          onPressed: _cancel,
                          child: const Text(
                            'Cancel Battle',
                            style: TextStyle(
                              color: Colors.redAccent,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PulsingIcon extends StatefulWidget {
  const _PulsingIcon();

  @override
  State<_PulsingIcon> createState() => _PulsingIconState();
}

class _PulsingIconState extends State<_PulsingIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    _scale = Tween<double>(
      begin: 0.9,
      end: 1.1,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.teal.withOpacity(0.15),
          border: Border.all(color: Colors.teal.withOpacity(0.4), width: 2),
        ),
        child: const Center(child: Text('⚔️', style: TextStyle(fontSize: 44))),
      ),
    );
  }
}
