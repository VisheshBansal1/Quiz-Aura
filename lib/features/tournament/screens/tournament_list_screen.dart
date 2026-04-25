import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/tournament_model.dart';
import '../../../core/widgets/glass_card.dart';
import '../services/tournament_service.dart';
import 'tournament_detail_screen.dart';

class TournamentListScreen extends StatelessWidget {
  const TournamentListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Container(decoration: const BoxDecoration(gradient: AppColors.mainGradient)),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: StreamBuilder<List<TournamentModel>>(
                    stream: TournamentService.allTournamentsStream(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                            child: CircularProgressIndicator(color: Colors.white));
                      }

                      final tournaments = snapshot.data ?? [];

                      if (tournaments.isEmpty) {
                        return const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('🏆', style: TextStyle(fontSize: 48)),
                              SizedBox(height: 12),
                              Text('No tournaments yet',
                                  style: TextStyle(
                                      color: Colors.white60, fontSize: 16)),
                              SizedBox(height: 6),
                              Text('Check back soon!',
                                  style: TextStyle(color: Colors.white38)),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: tournaments.length,
                        itemBuilder: (_, i) =>
                            _TournamentCard(tournament: tournaments[i]),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TournamentCard extends StatefulWidget {
  final TournamentModel tournament;

  const _TournamentCard({required this.tournament});

  @override
  State<_TournamentCard> createState() => _TournamentCardState();
}

class _TournamentCardState extends State<_TournamentCard> {
  // ── Effective status ──────────────────────────────────────────────────────
  // Delegated to TournamentModel.effectiveStatus which handles:
  //   • Admin-set finished/cancelled states
  //   • endAt check: if now > endAt → finished (even if Firestore still says active)
  //   • Fallback time-based upcoming → active
  TournamentStatus get _effectiveStatus => widget.tournament.effectiveStatus;

  Color get _statusColor {
    switch (_effectiveStatus) {
      case TournamentStatus.upcoming:  return Colors.blue;
      case TournamentStatus.active:    return Colors.green;
      case TournamentStatus.finished:  return Colors.grey;
      case TournamentStatus.cancelled: return Colors.red;
    }
  }

  String get _statusLabel {
    switch (_effectiveStatus) {
      case TournamentStatus.upcoming:  return 'Upcoming';
      case TournamentStatus.active:    return 'Live';
      case TournamentStatus.finished:  return 'Finished';
      case TournamentStatus.cancelled: return 'Cancelled';
    }
  }

  bool get _isLive => _effectiveStatus == TournamentStatus.active;
  bool get _isFinished =>
      _effectiveStatus == TournamentStatus.finished ||
      _effectiveStatus == TournamentStatus.cancelled;

  // Refresh every 30 s so the badge flips without a full stream rebuild.
  late final Timer _refreshTimer;

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) { if (mounted) setState(() {}); },
    );
  }

  @override
  void dispose() {
    _refreshTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tournament;
    final dateStr = DateFormat('MMM dd, yyyy • h:mm a').format(t.startAt);

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 14),
      borderRadius: 20,
      elevation: 6,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  t.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              // ── Status badge ─────────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _statusColor.withOpacity(0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isLive) ...[
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: Colors.greenAccent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                    ],
                    Text(
                      _statusLabel,
                      style: TextStyle(
                          color: _statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (t.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(t.description,
                style: const TextStyle(color: Colors.white60, fontSize: 13),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ],

          const SizedBox(height: 14),

          // ── Stats row ──────────────────────────────────────────────────
          Row(
            children: [
              _StatChip(icon: Icons.calendar_today, label: dateStr, color: Colors.blue),
              const SizedBox(width: 8),
              _StatChip(
                  icon: Icons.layers,
                  label: '${t.totalRounds} rounds',
                  color: Colors.purple),
            ],
          ),

          const SizedBox(height: 8),

          Row(
            children: [
              _StatChip(
                  icon: Icons.people,
                  label: 'Max ${t.maxParticipants}',
                  color: Colors.teal),
              const SizedBox(width: 8),
              if (t.prizeDescription.isNotEmpty)
                _StatChip(
                    icon: Icons.emoji_events,
                    label: t.prizeDescription,
                    color: Colors.amber),
              if (t.entryCoins > 0) ...[
                const SizedBox(width: 8),
                _StatChip(
                    icon: Icons.monetization_on,
                    label: '${t.entryCoins} coins',
                    color: Colors.orange),
              ],
            ],
          ),

          // ── End time chip (if known) ───────────────────────────────────
          if (t.endAt != null) ...[
            const SizedBox(height: 8),
            _StatChip(
              icon: _isFinished ? Icons.flag : Icons.timer_off_outlined,
              label: _isFinished
                  ? 'Ended ${DateFormat('MMM dd • h:mm a').format(t.endAt!)}'
                  : 'Ends ${DateFormat('MMM dd • h:mm a').format(t.endAt!)}',
              color: _isFinished ? Colors.grey : Colors.orangeAccent,
            ),
          ],

          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TournamentDetailScreen(tournament: t),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _isLive
                    ? Colors.green.withOpacity(0.85)
                    : _isFinished
                        ? Colors.white.withOpacity(0.08)
                        : Colors.teal,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                _isLive
                    ? 'Play Now 🔴'
                    : _isFinished
                        ? 'View Results'
                        : 'View & Register',
                style: TextStyle(
                  color: (_isLive || _effectiveStatus == TournamentStatus.upcoming)
                      ? Colors.white
                      : Colors.white54,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(color: color, fontSize: 11),
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}
