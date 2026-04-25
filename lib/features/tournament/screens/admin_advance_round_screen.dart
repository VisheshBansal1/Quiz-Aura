// ============================================================
// FILE: lib/features/tournament/screens/admin_advance_round_screen.dart
// ============================================================

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/tournament_model.dart';
import '../../../core/widgets/glass_card.dart';
import '../services/tournament_play_service.dart';
import '../services/tournament_service.dart';

class AdminAdvanceRoundScreen extends StatefulWidget {
  final TournamentModel tournament;

  const AdminAdvanceRoundScreen({super.key, required this.tournament});

  @override
  State<AdminAdvanceRoundScreen> createState() =>
      _AdminAdvanceRoundScreenState();
}

class _AdminAdvanceRoundScreenState extends State<AdminAdvanceRoundScreen> {
  bool _isAdmin = false;
  bool _advancing = false;
  bool _ending = false;
  String? _lastResult;

  bool get _isAlreadyEnded =>
      widget.tournament.effectiveStatus == TournamentStatus.finished ||
      widget.tournament.effectiveStatus == TournamentStatus.cancelled;

  @override
  void initState() {
    super.initState();
    final email = FirebaseAuth.instance.currentUser?.email ?? '';
    _isAdmin = email == 'admin741@gmail.com';
  }

  Future<void> _advanceRound(TournamentRound round) async {
    if (!_isAdmin || _advancing) return;

    final confirmed = await _confirm(
      'Advance Round ${round.roundNumber}?',
      'This will select the top ${round.qualifyCount} players based on their quiz scores and eliminate the rest. This action cannot be undone.',
    );
    if (!confirmed) return;

    setState(() => _advancing = true);
    try {
      final result = await TournamentPlayService.advanceRound(
        tournamentId: widget.tournament.id,
        quizId: round.quizId,
        roundNumber: round.roundNumber,
        qualifyCount: round.qualifyCount,
        totalRounds: widget.tournament.totalRounds,
      );

      setState(() {
        _lastResult = result.isFinished
            ? '✅ Tournament finished! ${result.advanced} advanced.'
            : '✅ Round ${round.roundNumber} advanced. ${result.advanced} qualified, ${result.eliminated} eliminated.';
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(e.toString().replaceFirst('Exception: ', '')),
              backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _advancing = false);
    }
  }

  Future<void> _endTournamentNow() async {
    if (!_isAdmin || _ending) return;

    final confirmed = await _confirm(
      'End Tournament Now?',
      'This will immediately close the tournament. Players will no longer be able to play any rounds. The tournament will show as "Finished" for everyone. This cannot be undone.',
      destructive: true,
    );
    if (!confirmed) return;

    setState(() => _ending = true);
    try {
      await TournamentService.endTournamentNow(
        tournamentId: widget.tournament.id,
      );
      setState(() {
        _lastResult = '🏁 Tournament ended. All rounds are now closed.';
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(e.toString().replaceFirst('Exception: ', '')),
              backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _ending = false);
    }
  }

  Future<bool> _confirm(String title, String body,
      {bool destructive = false}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF203A43),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(body, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel',
                  style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: destructive ? Colors.redAccent : Colors.teal),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Container(
              decoration:
                  const BoxDecoration(gradient: AppColors.mainGradient)),
          SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 12, 16, 0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios,
                            color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Expanded(
                        child: Text(
                          'Admin — Manage Tournament',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                if (!_isAdmin) ...[
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: GlassCard(
                      child: Column(
                        children: [
                          Icon(Icons.lock, color: Colors.redAccent, size: 40),
                          SizedBox(height: 12),
                          Text('Admin Access Only',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold)),
                          SizedBox(height: 4),
                          Text('This screen is restricted to administrators.',
                              style: TextStyle(color: Colors.white54),
                              textAlign: TextAlign.center),
                        ],
                      ),
                    ),
                  ),
                ] else ...[

                  // ── Result banner ──────────────────────────────────────
                  if (_lastResult != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: GlassCard(
                        backgroundColor: Colors.green.withOpacity(0.1),
                        borderColor: Colors.green.withOpacity(0.3),
                        child: Text(_lastResult!,
                            style: const TextStyle(color: Colors.greenAccent),
                            textAlign: TextAlign.center),
                      ),
                    ),

                  const SizedBox(height: 12),

                  Expanded(
                    child: StreamBuilder<List<TournamentRound>>(
                      stream: TournamentService.roundsStream(
                          widget.tournament.id),
                      builder: (context, snap) {
                        final rounds = snap.data ?? [];

                        return ListView(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                          children: [
                            // ── Round advance cards ────────────────────
                            if (rounds.isEmpty)
                              const Center(
                                child: Text('No rounds configured',
                                    style:
                                        TextStyle(color: Colors.white54)),
                              ),

                            for (final r in rounds) ...[
                              _buildRoundCard(r),
                              const SizedBox(height: 12),
                            ],

                            // ── End Tournament button ──────────────────
                            const SizedBox(height: 8),
                            _buildEndTournamentSection(),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoundCard(TournamentRound r) {
    final canAdvance =
        r.roundNumber == widget.tournament.currentRound && !_isAlreadyEnded;

    return GlassCard(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Round ${r.roundNumber}',
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            'Quiz: ${r.quizId}',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          Text(
            'Top ${r.qualifyCount} qualify',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: canAdvance && !_advancing
                  ? () => _advanceRound(r)
                  : null,
              icon: _advancing && canAdvance
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.arrow_forward_rounded),
              label: Text(
                _isAlreadyEnded
                    ? 'Tournament already ended'
                    : canAdvance
                        ? 'Advance Round ${r.roundNumber}'
                        : r.roundNumber < widget.tournament.currentRound
                            ? 'Already Advanced'
                            : 'Locked (complete previous round first)',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: canAdvance ? Colors.teal : Colors.white12,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEndTournamentSection() {
    if (_isAlreadyEnded) {
      return GlassCard(
        margin: EdgeInsets.zero,
        backgroundColor: Colors.grey.withOpacity(0.08),
        borderColor: Colors.grey.withOpacity(0.3),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.flag_rounded, color: Colors.grey, size: 18),
            SizedBox(width: 8),
            Text(
              'Tournament is already ended',
              style: TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                  fontSize: 14),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(color: Colors.white.withOpacity(0.1)),
        const SizedBox(height: 8),
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'DANGER ZONE',
            style: TextStyle(
              color: Colors.redAccent,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
        ),
        GlassCard(
          margin: EdgeInsets.zero,
          backgroundColor: Colors.red.withOpacity(0.06),
          borderColor: Colors.redAccent.withOpacity(0.3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'End Tournament Now',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15),
              ),
              const SizedBox(height: 4),
              const Text(
                'Immediately closes the tournament. All rounds will show as ended for all players, even if their time window hasn\'t expired. Use this when all rounds have finished or you want to close early.',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _ending ? null : _endTournamentNow,
                  icon: _ending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.flag_rounded),
                  label: Text(_ending ? 'Ending...' : 'End Tournament Now'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
