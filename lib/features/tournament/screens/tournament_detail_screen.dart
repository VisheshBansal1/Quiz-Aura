// ============================================================
// FILE: lib/features/tournament/screens/tournament_detail_screen.dart
// ============================================================

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/tournament_model.dart';
import '../../../core/widgets/glass_card.dart';
import '../services/tournament_service.dart';
import '../services/tournament_play_service.dart';
import 'tournament_quiz_bridge_screen.dart';
import 'admin_advance_round_screen.dart';
import 'tournament_answer_review_screen.dart';

class TournamentDetailScreen extends StatefulWidget {
  final TournamentModel tournament;
  const TournamentDetailScreen({super.key, required this.tournament});

  @override
  State<TournamentDetailScreen> createState() => _TournamentDetailScreenState();
}

class _TournamentDetailScreenState extends State<TournamentDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  bool _registering = false;
  bool _isRegistered = false;

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';
  bool get _isAdmin =>
      FirebaseAuth.instance.currentUser?.email == 'admin741@gmail.com';

  /// Client-side effective status (includes endAt check).
  TournamentStatus get _effectiveStatus => widget.tournament.effectiveStatus;

  bool get _isEnded =>
      _effectiveStatus == TournamentStatus.finished ||
      _effectiveStatus == TournamentStatus.cancelled;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _checkRegistration();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _checkRegistration() async {
    if (_uid.isEmpty) return;
    try {
      final registered = await TournamentService.isRegistered(
        tournamentId: widget.tournament.id,
        uid: _uid,
      );
      if (mounted) setState(() => _isRegistered = registered);
    } catch (e) {
      debugPrint('Registration check: $e');
    }
  }

  Future<void> _register() async {
    if (_uid.isEmpty) {
      _snack('Login required');
      return;
    }
    if (_registering || _isRegistered) return;
    setState(() => _registering = true);
    try {
      await TournamentService.joinTournament(
        tournamentId: widget.tournament.id,
      );
      await _checkRegistration();
      _snack('Registered! You\'re in 🎉', success: true);
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _registering = false);
    }
  }

  void _snack(String msg, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: success ? Colors.teal : Colors.redAccent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tournament;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(gradient: AppColors.mainGradient),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildAppBar(t),
                const SizedBox(height: 16),
                _buildHeroCard(t),
                const SizedBox(height: 16),
                _buildTabs(),
                const SizedBox(height: 8),
                Expanded(
                  child: TabBarView(
                    controller: _tabs,
                    children: [
                      _RoundsTab(
                        tournament: t,
                        uid: _uid,
                        isRegistered: _isRegistered,
                        tournamentEnded: _isEnded,
                        onPlayRound: (round) => _launchRound(round),
                      ),
                      _ParticipantsTab(tournamentId: t.id, myUid: _uid),
                      _LeaderboardTab(tournamentId: t.id, myUid: _uid),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _launchRound(TournamentRound round) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TournamentQuizBridgeScreen(
          tournament: widget.tournament,
          round: round,
        ),
      ),
    ).then((_) => _checkRegistration());
  }

  Widget _buildAppBar(TournamentModel t) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 16, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Text(
              t.title,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (_isAdmin)
            IconButton(
              icon: const Icon(Icons.admin_panel_settings, color: Colors.amber),
              tooltip: 'Admin Panel',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      AdminAdvanceRoundScreen(tournament: widget.tournament),
                ),
              ),
            )
          else
            const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildHeroCard(TournamentModel t) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GlassCard(
        elevation: 8,
        borderRadius: 24,
        child: Column(
          children: [
            const Text('🏆', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text(
              t.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (t.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                t.description,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white60, fontSize: 13),
              ),
            ],
            const SizedBox(height: 16),
            _InfoGrid(tournament: t, effectiveStatus: _effectiveStatus),
            const SizedBox(height: 16),
            _RegisterButton(
              tournament: t,
              effectiveStatus: _effectiveStatus,
              isRegistered: _isRegistered,
              isLoading: _registering,
              onRegister: _register,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabs,
        indicator: BoxDecoration(
          color: Colors.teal,
          borderRadius: BorderRadius.circular(10),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white60,
        dividerColor: Colors.transparent,
        tabs: const [
          Tab(text: 'Rounds'),
          Tab(text: 'Participants'),
          Tab(text: 'Leaderboard'),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ROUNDS TAB
// ─────────────────────────────────────────────────────────────────────────────
class _RoundsTab extends StatelessWidget {
  final TournamentModel tournament;
  final String uid;
  final bool isRegistered;
  final bool tournamentEnded;
  final void Function(TournamentRound) onPlayRound;

  const _RoundsTab({
    required this.tournament,
    required this.uid,
    required this.isRegistered,
    required this.tournamentEnded,
    required this.onPlayRound,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<TournamentRound>>(
      stream: TournamentService.roundsStream(tournament.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }
        final rounds = snapshot.data ?? [];
        if (rounds.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text('📋', style: TextStyle(fontSize: 40)),
                SizedBox(height: 12),
                Text('Rounds not scheduled yet',
                    style: TextStyle(color: Colors.white60, fontSize: 14)),
                SizedBox(height: 4),
                Text('Check back soon!',
                    style: TextStyle(color: Colors.white38, fontSize: 12)),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: rounds.length,
          itemBuilder: (_, i) => _RoundCard(
            round: rounds[i],
            tournament: tournament,
            uid: uid,
            isRegistered: isRegistered,
            tournamentEnded: tournamentEnded,
            onPlay: () => onPlayRound(rounds[i]),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ROUND CARD
// ─────────────────────────────────────────────────────────────────────────────
class _RoundCard extends StatefulWidget {
  final TournamentRound round;
  final TournamentModel tournament;
  final String uid;
  final bool isRegistered;
  final bool tournamentEnded;
  final VoidCallback onPlay;

  const _RoundCard({
    required this.round,
    required this.tournament,
    required this.uid,
    required this.isRegistered,
    required this.tournamentEnded,
    required this.onPlay,
  });

  @override
  State<_RoundCard> createState() => _RoundCardState();
}

class _RoundCardState extends State<_RoundCard> {
  RoundPlayState _state = RoundPlayState.upcoming;
  bool _loadingState = true;

  @override
  void initState() {
    super.initState();
    _fetchState();
  }

  Future<void> _fetchState() async {
    if (!widget.isRegistered) {
      if (mounted)
        setState(() {
          _state = RoundPlayState.notRegistered;
          _loadingState = false;
        });
      return;
    }
    try {
      final state = await TournamentPlayService.getRoundPlayState(
        tournamentId: widget.tournament.id,
        round: widget.round,
      );
      if (mounted)
        setState(() {
          _state = state;
          _loadingState = false;
        });
    } catch (_) {
      if (mounted) setState(() => _loadingState = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.round;
    final now = DateTime.now();
    final isLive = now.isAfter(r.startAt) && now.isBefore(r.endAt);
    final isEnded = now.isAfter(r.endAt);

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      borderColor: isLive
          ? Colors.greenAccent.withOpacity(0.4)
          : _state == RoundPlayState.completed
          ? Colors.teal.withOpacity(0.3)
          : Colors.white.withOpacity(0.12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _RoundBadge(
                number: r.roundNumber,
                isLive: isLive,
                ended: isEnded,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Round ${r.roundNumber}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Top ${r.qualifyCount} advance',
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (isLive) _LiveChip(),
              if (isEnded && !isLive)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'ENDED',
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 10),

          Row(
            children: [
              const Icon(Icons.lock_open_rounded, size: 13, color: Colors.white38),
              const SizedBox(width: 6),
              Text(
                'Opens ${DateFormat('MMM dd • h:mm a').format(r.startAt)}',
                style: const TextStyle(color: Colors.white54, fontSize: 11.5),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.lock_outline, size: 13, color: Colors.white38),
              const SizedBox(width: 6),
              Text(
                'Closes ${DateFormat('MMM dd • h:mm a').format(r.endAt)}',
                style: const TextStyle(color: Colors.white54, fontSize: 11.5),
              ),
            ],
          ),

          const SizedBox(height: 14),

          _loadingState
              ? const SizedBox(
                  height: 44,
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white54,
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                )
              : _buildActionButton(),
        ],
      ),
    );
  }

  Widget _buildActionButton() {
    // If the whole tournament has ended, all rounds show as ended regardless.
    if (widget.tournamentEnded && _state != RoundPlayState.completed) {
      return _statusBox(
        color: Colors.grey,
        icon: Icons.flag_rounded,
        label: 'Tournament has ended',
      );
    }

    switch (_state) {
      case RoundPlayState.playable:
        return SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: widget.onPlay,
            icon: const Icon(Icons.play_arrow_rounded, size: 20),
            label: const Text(
              'Play Round Now',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 4,
              shadowColor: Colors.teal.withOpacity(0.5),
            ),
          ),
        );

      case RoundPlayState.completed:
        final roundEnded = DateTime.now().isAfter(widget.round.endAt);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _statusBox(
              color: Colors.teal,
              icon: Icons.check_circle,
              label: 'You completed this round ✓',
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 42,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TournamentAnswerReviewScreen(
                      tournament: widget.tournament,
                      round: widget.round,
                    ),
                  ),
                ),
                icon: Icon(
                  roundEnded ? Icons.rate_review_rounded : Icons.lock_rounded,
                  size: 16,
                  color: roundEnded ? Colors.tealAccent : Colors.orange,
                ),
                label: Text(
                  roundEnded ? 'Review Answers' : 'Answers Locked Until Round Ends',
                  style: TextStyle(
                    color: roundEnded ? Colors.tealAccent : Colors.orange,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: roundEnded
                        ? Colors.tealAccent.withOpacity(0.5)
                        : Colors.orange.withOpacity(0.4),
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        );

      case RoundPlayState.upcoming:
        final now = DateTime.now();
        final diff = widget.round.startAt.difference(now);
        final countdown = diff.inHours > 24
            ? '${diff.inDays}d remaining'
            : diff.inHours > 0
            ? '${diff.inHours}h ${diff.inMinutes % 60}m remaining'
            : 'Opens soon';
        return _statusBox(
          color: Colors.blueAccent,
          icon: Icons.schedule,
          label: 'Upcoming — $countdown',
        );

      case RoundPlayState.ended:
        return _statusBox(
          color: Colors.grey,
          icon: Icons.timer_off,
          label: 'Round window closed',
        );

      case RoundPlayState.eliminated:
        return _statusBox(
          color: Colors.redAccent,
          icon: Icons.remove_circle_outline,
          label: 'You were eliminated',
        );

      case RoundPlayState.lockedFutureRound:
        return _statusBox(
          color: Colors.orange,
          icon: Icons.lock,
          label: 'Complete previous round first',
        );

      case RoundPlayState.notRegistered:
        return _statusBox(
          color: Colors.white38,
          icon: Icons.lock_outline,
          label: 'Register to play',
        );
    }
  }

  Widget _statusBox({
    required Color color,
    required IconData icon,
    required String label,
  }) {
    return Container(
      height: 44,
      width: double.infinity,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundBadge extends StatelessWidget {
  final int number;
  final bool isLive;
  final bool ended;
  const _RoundBadge({
    required this.number,
    required this.isLive,
    required this.ended,
  });

  @override
  Widget build(BuildContext context) {
    final color = ended
        ? Colors.grey
        : isLive
        ? Colors.greenAccent
        : Colors.teal;
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(0.15),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Center(
        child: Text(
          'R$number',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _LiveChip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.greenAccent.withOpacity(0.4)),
      ),
      child: const Text(
        'LIVE',
        style: TextStyle(
          color: Colors.greenAccent,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// INFO GRID
// ─────────────────────────────────────────────────────────────────────────────
class _InfoGrid extends StatelessWidget {
  final TournamentModel tournament;
  final TournamentStatus effectiveStatus;
  const _InfoGrid({required this.tournament, required this.effectiveStatus});

  @override
  Widget build(BuildContext context) {
    final isEnded = effectiveStatus == TournamentStatus.finished ||
        effectiveStatus == TournamentStatus.cancelled;

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 2.8,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      children: [
        _InfoTile(
          icon: '📅',
          label: DateFormat('MMM dd • h:mm a').format(tournament.startAt),
        ),
        _InfoTile(icon: '🎯', label: '${tournament.totalRounds} Rounds'),
        _InfoTile(
          icon: '👥',
          label: '${tournament.participantCount}/${tournament.maxParticipants} players',
        ),
        _InfoTile(
          icon: '🪙',
          label: tournament.entryCoins == 0
              ? 'Free Entry'
              : '${tournament.entryCoins} Coins',
        ),
        if (tournament.prizeDescription.isNotEmpty)
          _InfoTile(icon: '🎁', label: tournament.prizeDescription),
        // Show end time if available
        if (tournament.endAt != null)
          _InfoTile(
            icon: isEnded ? '🏁' : '⏰',
            label: isEnded
                ? 'Ended ${DateFormat('MMM dd • h:mm a').format(tournament.endAt!)}'
                : 'Ends ${DateFormat('MMM dd • h:mm a').format(tournament.endAt!)}',
          ),
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String icon, label;
  const _InfoTile({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// REGISTER BUTTON
// ─────────────────────────────────────────────────────────────────────────────
class _RegisterButton extends StatelessWidget {
  final TournamentModel tournament;
  final TournamentStatus effectiveStatus;
  final bool isRegistered, isLoading;
  final VoidCallback onRegister;

  const _RegisterButton({
    required this.tournament,
    required this.effectiveStatus,
    required this.isRegistered,
    required this.isLoading,
    required this.onRegister,
  });

  @override
  Widget build(BuildContext context) {
    // ── Tournament has ended (finished / cancelled) ──────────────────────
    if (effectiveStatus == TournamentStatus.finished) {
      return _statusBox(
        color: Colors.grey,
        text: 'Tournament has ended',
        icon: Icons.flag_rounded,
      );
    }
    if (effectiveStatus == TournamentStatus.cancelled) {
      return _statusBox(
        color: Colors.red,
        text: 'Tournament was cancelled',
        icon: Icons.cancel_outlined,
      );
    }

    // ── Active — player is in ────────────────────────────────────────────
    if (effectiveStatus == TournamentStatus.active && isRegistered) {
      return _statusBox(
        color: Colors.teal,
        text: "You're In — Tournament Active!",
        icon: Icons.sports_esports,
      );
    }

    // ── Active — not registered ──────────────────────────────────────────
    if (effectiveStatus == TournamentStatus.active) {
      return _statusBox(
        color: Colors.orange,
        text: 'Registration closed — tournament started',
        icon: Icons.lock_clock,
      );
    }

    // ── Upcoming ─────────────────────────────────────────────────────────
    final isFull = tournament.maxParticipants > 0 &&
        tournament.participantCount >= tournament.maxParticipants;

    if (isRegistered) {
      return _statusBox(
        color: Colors.green,
        text: "Registered — You're In!",
        icon: Icons.check_circle,
      );
    }
    if (isFull) {
      return _statusBox(
        color: Colors.red,
        text: 'Tournament Full',
        icon: Icons.lock,
      );
    }

    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        onPressed: isLoading ? null : onRegister,
        icon: isLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.how_to_reg),
        label: Text(
          tournament.entryCoins > 0
              ? 'Register (${tournament.entryCoins} Coins)'
              : 'Register Free',
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.teal,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  Widget _statusBox({
    required Color color,
    required String text,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LEADERBOARD TAB (unchanged logic)
// ─────────────────────────────────────────────────────────────────────────────
class _LeaderboardTab extends StatelessWidget {
  final String tournamentId, myUid;
  const _LeaderboardTab({required this.tournamentId, required this.myUid});

  static int _totalScore(TournamentParticipant p) {
    return p.roundScores.fold<int>(0, (sum, s) {
      final v = s['score'];
      return sum + (v is int ? v : (v as num?)?.toInt() ?? 0);
    });
  }

  static int _totalQuestions(TournamentParticipant p) {
    return p.roundScores.fold<int>(0, (sum, s) {
      final v = s['total'];
      return sum + (v is int ? v : (v as num?)?.toInt() ?? 0);
    });
  }

  static int _latestRound(TournamentParticipant p) {
    if (p.roundScores.isEmpty) return 0;
    return p.roundScores
        .map((s) => (s['round'] as int?) ?? 0)
        .reduce((a, b) => a > b ? a : b);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<TournamentParticipant>>(
      stream: TournamentService.participantsStream(tournamentId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }

        final all = snapshot.data ?? [];

        if (all.isEmpty) {
          return const Center(
            child: Text('No players yet', style: TextStyle(color: Colors.white60)),
          );
        }

        final active = all.where((p) => !p.eliminated).toList()
          ..sort((a, b) => _totalScore(b).compareTo(_totalScore(a)));
        final eliminated = all.where((p) => p.eliminated).toList()
          ..sort((a, b) => _totalScore(b).compareTo(_totalScore(a)));

        final ranked = [...active, ...eliminated];

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount: ranked.length + 1,
          itemBuilder: (_, i) {
            if (i == 0) return _LeaderboardHeader();

            final p = ranked[i - 1];
            final rank = i;
            final isMe = p.uid == myUid;
            final score = _totalScore(p);
            final totalQ = _totalQuestions(p);
            final pct = totalQ > 0 ? score / totalQ * 100 : 0.0;
            final roundsPlayed = p.roundScores.length;
            final latestRound = _latestRound(p);

            return _LeaderboardRow(
              rank: rank,
              name: p.name,
              score: score,
              totalQuestions: totalQ,
              percentage: pct,
              roundsPlayed: roundsPlayed,
              latestRound: latestRound,
              isMe: isMe,
              isEliminated: p.eliminated,
            );
          },
        );
      },
    );
  }
}

class _LeaderboardHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 12),
      child: Row(
        children: [
          const Icon(Icons.emoji_events_rounded, color: Colors.amber, size: 20),
          const SizedBox(width: 8),
          const Text(
            'Live Leaderboard',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.greenAccent.withOpacity(0.4)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.circle, color: Colors.greenAccent, size: 8),
                SizedBox(width: 4),
                Text(
                  'LIVE',
                  style: TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
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

class _LeaderboardRow extends StatelessWidget {
  final int rank;
  final String name;
  final int score;
  final int totalQuestions;
  final double percentage;
  final int roundsPlayed;
  final int latestRound;
  final bool isMe;
  final bool isEliminated;

  const _LeaderboardRow({
    required this.rank,
    required this.name,
    required this.score,
    required this.totalQuestions,
    required this.percentage,
    required this.roundsPlayed,
    required this.latestRound,
    required this.isMe,
    required this.isEliminated,
  });

  Color get _rankColor {
    if (isEliminated) return Colors.grey;
    switch (rank) {
      case 1: return Colors.amber;
      case 2: return const Color(0xFFB0BEC5);
      case 3: return const Color(0xFFCD7F32);
      default: return Colors.teal;
    }
  }

  String get _rankEmoji {
    if (isEliminated) return '❌';
    switch (rank) {
      case 1: return '🥇';
      case 2: return '🥈';
      case 3: return '🥉';
      default: return '#$rank';
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _rankColor;
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      backgroundColor: isMe
          ? Colors.teal.withOpacity(0.12)
          : isEliminated
              ? Colors.red.withOpacity(0.04)
              : null,
      borderColor: isMe
          ? Colors.tealAccent.withOpacity(0.4)
          : rank <= 3 && !isEliminated
              ? color.withOpacity(0.35)
              : Colors.white.withOpacity(0.08),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Center(
              child: rank <= 3 && !isEliminated
                  ? Text(_rankEmoji, style: const TextStyle(fontSize: 22))
                  : Text(
                      _rankEmoji,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: isEliminated ? 18 : 13,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 10),
          CircleAvatar(
            radius: 18,
            backgroundColor: isEliminated
                ? Colors.red.withOpacity(0.25)
                : color.withOpacity(0.2),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: TextStyle(
                color: isEliminated ? Colors.red.shade200 : color,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        isMe ? '$name (You)' : name,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isMe
                              ? Colors.tealAccent
                              : isEliminated
                                  ? Colors.white38
                                  : Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  roundsPlayed == 0
                      ? 'No rounds played'
                      : '$roundsPlayed round${roundsPlayed > 1 ? 's' : ''} played · R$latestRound latest',
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                totalQuestions > 0 ? '$score/$totalQuestions' : '—',
                style: TextStyle(
                  color: isEliminated ? Colors.white38 : color,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              if (totalQuestions > 0)
                Text(
                  '${percentage.toStringAsFixed(0)}%',
                  style: TextStyle(
                    color: isEliminated ? Colors.white24 : color.withOpacity(0.7),
                    fontSize: 11,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PARTICIPANTS TAB (unchanged)
// ─────────────────────────────────────────────────────────────────────────────
class _ParticipantsTab extends StatelessWidget {
  final String tournamentId, myUid;
  const _ParticipantsTab({required this.tournamentId, required this.myUid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<TournamentParticipant>>(
      stream: TournamentService.participantsStream(tournamentId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }
        final participants = snapshot.data ?? [];
        if (participants.isEmpty) {
          return const Center(
            child: Text('No participants yet',
                style: TextStyle(color: Colors.white60)),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: participants.length,
          itemBuilder: (_, i) {
            final p = participants[i];
            final isMe = p.uid == myUid;
            return GlassCard(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              backgroundColor: isMe ? Colors.teal.withOpacity(0.15) : null,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: p.eliminated
                        ? Colors.red.withOpacity(0.3)
                        : Colors.teal.withOpacity(0.3),
                    child: Text(
                      p.name.isNotEmpty ? p.name[0].toUpperCase() : '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isMe ? '${p.name} (You)' : p.name,
                          style: TextStyle(
                            color: isMe ? Colors.tealAccent : Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        if (p.roundScores.isNotEmpty)
                          Text(
                            '${p.roundScores.length} round${p.roundScores.length > 1 ? 's' : ''} played',
                            style: const TextStyle(
                                color: Colors.white38, fontSize: 11),
                          ),
                      ],
                    ),
                  ),
                  if (p.eliminated)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'OUT',
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.teal.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'R${p.currentRound}',
                        style: const TextStyle(
                          color: Colors.tealAccent,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}