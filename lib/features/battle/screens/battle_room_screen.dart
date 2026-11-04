// ============================================================
// FILE: lib/features/battle/screens/battle_room_screen.dart
// Challenge-a-Friend and Private Battle rooms: share/enter code,
// invitation states (waiting / accepted / declined / expired),
// ready-up, then the host starts the battle when both are ready.
// ============================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/glass_card.dart';
import '../models/battle_models.dart';
import '../services/battle_repository.dart';
import '../services/battle_duel_service.dart';
import '../services/server_clock.dart';
import '../widgets/battle_widgets.dart';
import 'battle_match_screen.dart';
import 'battle_spectator_screen.dart';

class BattleRoomScreen extends StatefulWidget {
  final String battleId;

  const BattleRoomScreen({super.key, required this.battleId});

  @override
  State<BattleRoomScreen> createState() => _BattleRoomScreenState();
}

class _BattleRoomScreenState extends State<BattleRoomScreen> {
  final String _me = BattleRepository.uid;

  StreamSubscription<BattleMatch?>? _matchSub;
  StreamSubscription<BattleInvite?>? _inviteSub;
  Timer? _expiryTimer;
  BattleMatch? _match;
  BattleInvite? _invite;
  String? _error;
  bool _navigated = false;
  bool _starting = false;
  bool _closing = false;
  bool _readyBusy = false;
  int _nextStartTryMs = 0;
  String? _inviteCode;

  @override
  void initState() {
    super.initState();
    ServerClock.sync();
    _matchSub = BattleRepository.matchStream(widget.battleId).listen(
      _onMatch,
      onError: (Object _) => setState(() => _error = 'Lost connection to the room.'),
    );
    _expiryTimer = Timer.periodic(const Duration(seconds: 1), (_) => _checkExpiry());
  }

  void _onMatch(BattleMatch? m) {
    if (!mounted) return;
    if (m == null) {
      setState(() => _error = 'This room no longer exists.');
      return;
    }
    setState(() {
      _match = m;
      _error = null;
    });
    final code = m.roomCode;
    if (code != null && _inviteSub == null && m.hostId == _me) {
      _inviteCode = code;
      _inviteSub = BattleRepository.inviteStream(code).listen(
        (i) {
          if (mounted) setState(() => _invite = i);
          _onInvite(i);
        },
        onError: (Object _) {},
      );
    }

    if (m.status == BattleStatus.live && !_navigated) {
      _navigated = true;
      final watching = m.organizerId == _me;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => watching
              ? BattleSpectatorScreen(battleId: m.id)
              : BattleMatchScreen(battleId: m.id),
        ),
      );
      return;
    }
    _maybeStart(m);
  }

  void _onInvite(BattleInvite? i) {
    final m = _match;
    if (i == null || m == null || m.hostId != _me || _closing) return;
    if (m.status == BattleStatus.waiting && i.status == 'declined') {
      _closing = true;
      BattleDuelService.cancelRoom(m, 'declined').catchError((Object _) {});
    }
  }

  void _checkExpiry() {
    final m = _match;
    final i = _invite;
    if (m == null || i == null || _closing || m.hostId != _me) return;
    if (m.status == BattleStatus.waiting &&
        i.status == 'waiting' &&
        ServerClock.nowMs > i.expiresAtMs) {
      _closing = true;
      BattleDuelService.cancelRoom(m, 'expired').catchError((Object _) {});
    }
  }

  /// Only the host starts: writes the questions, then flips the room live.
  Future<void> _maybeStart(BattleMatch m) async {
    if (m.isOrganized) return; // the organizer starts manually
    if (_starting || m.status != BattleStatus.lobby || m.hostId != _me) return;
    if (m.playerIds.length != 2) return;
    final allReady = m.playerIds.every((id) => m.players[id]?.ready == true);
    if (!allReady || ServerClock.nowMs < _nextStartTryMs) return;
    _starting = true;
    if (mounted) setState(() {});
    try {
      await BattleDuelService.startRoomBattle(m);
    } on BattleException catch (e) {
      _nextStartTryMs = ServerClock.nowMs + 4000;
      if (mounted) showBattleSnack(context, e.message);
      // Retry after a pause (e.g. flaky network): re-evaluated on the next snapshot.
      Timer(const Duration(seconds: 4), () {
        if (mounted && _match != null) _maybeStart(_match!);
      });
    } finally {
      _starting = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _toggleReady() async {
    final m = _match;
    if (m == null || _readyBusy) return;
    final now = m.players[_me]?.ready == true;
    setState(() => _readyBusy = true);
    try {
      await BattleDuelService.setReady(m.id, !now);
    } on BattleException catch (e) {
      showBattleSnack(context, e.message);
    } finally {
      if (mounted) setState(() => _readyBusy = false);
    }
  }

  Future<void> _leave() async {
    final m = _match;
    if (m != null &&
        (m.status == BattleStatus.waiting || m.status == BattleStatus.lobby) &&
        !_closing) {
      _closing = true;
      try {
        await BattleDuelService.cancelRoom(m, 'left');
      } catch (_) {}
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _matchSub?.cancel();
    _inviteSub?.cancel();
    _expiryTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      // ignore: deprecated_member_use
      onWillPop: () async {
        await _leave();
        return false;
      },
      child: BattleScaffold(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: _leave,
                  ),
                  const Text('Battle Room',
                      style: TextStyle(
                          color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
              Expanded(child: _body()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body() {
    final m = _match;
    if (_error != null) {
      return _centerMessage(_error!, Icons.error_outline);
    }
    if (m == null) return const Center(child: CircularProgressIndicator());
    switch (m.status) {
      case BattleStatus.waiting:
        return _waiting(m);
      case BattleStatus.lobby:
        return _lobby(m);
      case BattleStatus.cancelled:
        return _centerMessage(_cancelText(m), Icons.event_busy);
      case BattleStatus.live:
        return const Center(child: CircularProgressIndicator());
      case BattleStatus.unknown:
        return _centerMessage('Unknown room state.', Icons.help_outline);
    }
  }

  String _cancelText(BattleMatch m) {
    switch (m.cancelReason) {
      case 'declined':
        return 'The invitation was declined.';
      case 'expired':
        return 'The invitation expired.';
      case 'left':
        return 'The room was closed.';
      default:
        return 'This room is no longer available.';
    }
  }

  Widget _centerMessage(String text, IconData icon) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: Colors.white54),
          const SizedBox(height: 12),
          Text(text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 16)),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Back'),
          ),
        ],
      ),
    );
  }

  String _inviteLabel() {
    final i = _invite;
    if (i == null) return 'Waiting';
    switch (i.status) {
      case 'accepted':
        return 'Accepted';
      case 'declined':
        return 'Declined';
      case 'expired':
        return 'Expired';
      case 'cancelled':
        return 'Cancelled';
      default:
        return 'Waiting';
    }
  }

  Widget _waiting(BattleMatch m) {
    if (m.isOrganized) return _organizedWaiting(m);
    final code = m.roomCode ?? _inviteCode ?? '';
    final secs = _invite == null
        ? 0
        : ((_invite!.expiresAtMs - ServerClock.nowMs) / 1000).ceil().clamp(0, 99999);
    return ListView(
      children: [
        const SizedBox(height: 24),
        GlassCard(
          child: Column(
            children: [
              Text(m.mode == 'friend' ? 'Friend challenge sent' : 'Share this code',
                  style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 12),
              Text(code,
                  style: const TextStyle(
                      color: AppColors.battleGold,
                      fontSize: 40,
                      letterSpacing: 8,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(
                      text: 'Join my QuizAura 1v1 battle! Room code: $code'));
                  if (mounted) showBattleSnack(context, 'Code copied');
                },
                icon: const Icon(Icons.copy, size: 18),
                label: const Text('Copy invite'),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
                width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 10),
            Text('${_inviteLabel()} · expires in ${formatSeconds(secs)}',
                style: const TextStyle(color: Colors.white70)),
          ],
        ),
        const SizedBox(height: 24),
        Center(
          child: TextButton(
            onPressed: _leave,
            child: const Text('Cancel room', style: TextStyle(color: AppColors.accentRed)),
          ),
        ),
      ],
    );
  }

  Widget _lobby(BattleMatch m) {
    if (m.isOrganized && m.organizerId == _me) return _organizerLobby(m);
    final opp = m.opponentOf(_me);
    final mine = m.players[_me];
    final theirs = opp == null ? null : m.players[opp];
    final iAmReady = mine?.ready == true;
    final bothReady = m.players.values.length == 2 && m.players.values.every((p) => p.ready);
    return Column(
      children: [
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: mine == null
                  ? const SizedBox.shrink()
                  : BattlePlayerCard(
                      player: mine, color: AppColors.battleBlue, showReady: true, isMe: true),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Text('VS',
                  style: TextStyle(
                      color: AppColors.battleGold, fontSize: 22, fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: theirs == null
                  ? const SizedBox.shrink()
                  : BattlePlayerCard(
                      player: theirs, color: AppColors.battleRed, showReady: true),
            ),
          ],
        ),
        const Spacer(),
        if (bothReady)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text('Both ready — starting…', style: TextStyle(color: Colors.white70)),
          ),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: (_readyBusy || _starting || bothReady) ? null : _toggleReady,
            style: ElevatedButton.styleFrom(
              backgroundColor: iAmReady ? Colors.white24 : AppColors.accentGreen,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: Text(iAmReady ? 'Not ready' : "I'm ready!",
                style: const TextStyle(color: Colors.white, fontSize: 16)),
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _leave,
          child: const Text('Leave room', style: TextStyle(color: AppColors.accentRed)),
        ),
      ],
    );
  }

  // ── referee (organized) rooms ────────────────────────────────────────────
  Future<void> _startOrganized() async {
    final m = _match;
    if (m == null || _starting) return;
    setState(() => _starting = true);
    try {
      await BattleDuelService.startRoomBattle(m);
    } on BattleException catch (e) {
      if (mounted) showBattleSnack(context, e.message);
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Widget _slot(BattleMatch m, int index) {
    final ids = m.playerIds;
    if (index < ids.length && m.players[ids[index]] != null) {
      return BattlePlayerCard(
        player: m.players[ids[index]]!,
        color: index == 0 ? AppColors.battleBlue : AppColors.battleRed,
        showReady: m.status == BattleStatus.lobby,
        isMe: ids[index] == _me,
      );
    }
    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.person_add_alt, color: Colors.white38, size: 32),
          const SizedBox(height: 8),
          Text('Player ${index + 1}',
              style: const TextStyle(color: Colors.white54, fontSize: 13)),
          const Text('waiting…', style: TextStyle(color: Colors.white38, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _organizedWaiting(BattleMatch m) {
    final iAmOrganizer = m.organizerId == _me;
    final code = m.roomCode ?? _inviteCode ?? '';
    final secs = _invite == null
        ? 0
        : ((_invite!.expiresAtMs - ServerClock.nowMs) / 1000).ceil().clamp(0, 99999);
    return ListView(
      children: [
        const SizedBox(height: 16),
        if (iAmOrganizer)
          GlassCard(
            child: Column(
              children: [
                const Text('You are the organizer — you will watch, not play',
                    textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 12),
                Text(code,
                    style: const TextStyle(
                        color: AppColors.battleGold,
                        fontSize: 40,
                        letterSpacing: 8,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                const Text('Share this code with the two players',
                    style: TextStyle(color: Colors.white54, fontSize: 12)),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(
                        text: 'Join the QuizAura 1v1 battle! Room code: $code'));
                    if (mounted) showBattleSnack(context, 'Code copied');
                  },
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('Copy invite'),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
                ),
              ],
            ),
          )
        else
          const GlassCard(
            child: Text('You joined! Waiting for the second player…',
                textAlign: TextAlign.center, style: TextStyle(color: Colors.white)),
          ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _slot(m, 0)),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Text('VS',
                  style: TextStyle(
                      color: AppColors.battleGold, fontSize: 22, fontWeight: FontWeight.bold)),
            ),
            Expanded(child: _slot(m, 1)),
          ],
        ),
        const SizedBox(height: 16),
        if (iAmOrganizer)
          Center(
            child: Text('${m.playerIds.length}/2 joined · expires in ${formatSeconds(secs)}',
                style: const TextStyle(color: Colors.white70)),
          ),
        const SizedBox(height: 20),
        Center(
          child: TextButton(
            onPressed: _leave,
            child: Text(iAmOrganizer ? 'Cancel room' : 'Leave room',
                style: const TextStyle(color: AppColors.accentRed)),
          ),
        ),
      ],
    );
  }

  Widget _organizerLobby(BattleMatch m) {
    final bothReady = m.playerIds.length == 2 &&
        m.playerIds.every((id) => m.players[id]?.ready == true);
    return Column(
      children: [
        const SizedBox(height: 16),
        const Text('Both players joined',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(child: _slot(m, 0)),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Text('VS',
                  style: TextStyle(
                      color: AppColors.battleGold, fontSize: 22, fontWeight: FontWeight.bold)),
            ),
            Expanded(child: _slot(m, 1)),
          ],
        ),
        const Spacer(),
        Text(
          _starting
              ? 'Preparing questions… (AI is used only if the question pool is low)'
              : (bothReady ? 'Both players are ready' : 'Waiting for both players to press Ready'),
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: (bothReady && !_starting) ? _startOrganized : null,
            icon: _starting
                ? const SizedBox(
                    width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.play_arrow),
            label: Text(_starting ? 'Starting…' : 'Start battle'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentGreen,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        TextButton(
          onPressed: _leave,
          child: const Text('Cancel room', style: TextStyle(color: AppColors.accentRed)),
        ),
      ],
    );
  }
}
