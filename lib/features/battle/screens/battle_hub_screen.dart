// ============================================================
// FILE: lib/features/battle/screens/battle_hub_screen.dart
// Battle home: stats, resume, incoming challenges, the three modes
// (Quick Match / Challenge a Friend / Private Battle), recent results
// and top players.
// ============================================================

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/glass_card.dart';
import '../models/battle_models.dart';
import '../services/battle_repository.dart';
import '../services/battle_duel_service.dart';
import '../services/server_clock.dart';
import '../widgets/battle_widgets.dart';
import 'battle_history_screen.dart';
import 'battle_match_screen.dart';
import 'battle_matchmaking_screen.dart';
import 'battle_room_screen.dart';

class BattleHubScreen extends StatefulWidget {
  const BattleHubScreen({super.key});

  @override
  State<BattleHubScreen> createState() => _BattleHubScreenState();
}

class _BattleHubScreenState extends State<BattleHubScreen> {
  String _category = '';
  bool _busy = false;
  late Future<List<MapEntry<String, String>>> _topics;
  late Future<BattleHistoryPage> _recent;
  late Future<List<BattleStats>> _top;
  late Future<String?> _live;

  @override
  void initState() {
    super.initState();
    ServerClock.sync();
    _reload();
  }

  void _reload() {
    _topics = BattleRepository.topics();
    _recent = BattleRepository.historyPage(limit: 5);
    _top = BattleRepository.topPlayers(limit: 10);
    _live = BattleDuelService.findLiveBattleId();
  }

  Future<void> _guard(Future<void> Function() action) async {
    if (_busy) return; // ignore repeated taps
    setState(() => _busy = true);
    try {
      await action();
    } on BattleException catch (e) {
      showBattleSnack(context, e.message);
    } catch (_) {
      showBattleSnack(context, 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _quick() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => BattleMatchmakingScreen(category: _category)),
    );
    if (mounted) setState(_reload);
  }

  Future<void> _createPrivate() => _guard(() async {
        final r = await BattleDuelService.createRoom(mode: 'private', category: _category);
        if (!mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => BattleRoomScreen(battleId: r['battleId']!)),
        );
        if (mounted) setState(_reload);
      });

  Future<void> _createOrganized() => _guard(() async {
        final r = await BattleDuelService.createRoom(mode: 'organized', category: _category);
        if (!mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => BattleRoomScreen(battleId: r['battleId']!)),
        );
        if (mounted) setState(_reload);
      });

  Future<void> _friendSheet() async {
    final hit = await showModalBottomSheet<BattleUserHit>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgMid,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _FriendSearchSheet(),
    );
    if (hit == null || !mounted) return;
    await _guard(() async {
      final r = await BattleDuelService.createRoom(
          mode: 'friend', targetUid: hit.uid, category: _category);
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => BattleRoomScreen(battleId: r['battleId']!)),
      );
      if (mounted) setState(_reload);
    });
  }

  Future<void> _joinWithCode([String? preset]) async {
    String? code = preset;
    if (code == null) {
      code = await showDialog<String>(
        context: context,
        builder: (_) => const _JoinCodeDialog(),
      );
    }
    if (code == null || code.trim().isEmpty || !mounted) return;
    final c = code;
    await _guard(() async {
      final battleId = await BattleDuelService.joinRoom(c);
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => BattleRoomScreen(battleId: battleId)),
      );
      if (mounted) setState(_reload);
    });
  }

  Future<void> _resume(String id) async {
    await _guard(() async {
      final m = await BattleRepository.matchOnce(id);
      if (!mounted || m == null) return;
      final room = m.status == BattleStatus.waiting || m.status == BattleStatus.lobby;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => room ? BattleRoomScreen(battleId: id) : BattleMatchScreen(battleId: id),
        ),
      );
      if (mounted) setState(_reload);
    });
  }

  @override
  Widget build(BuildContext context) {
    return BattleScaffold(
      child: RefreshIndicator(
        onRefresh: () async => setState(_reload),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                const Expanded(
                  child: Text('1v1 Battle',
                      style: TextStyle(
                          color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                ),
                IconButton(
                  icon: const Icon(Icons.history, color: Colors.white),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const BattleHistoryScreen()),
                  ),
                ),
              ],
            ),
            _liveCard(),
            _statsCard(),
            _incoming(),
            const SizedBox(height: 12),
            _topicChips(),
            const SizedBox(height: 14),
            BattleModeCard(
              icon: Icons.bolt,
              title: 'Quick Match',
              subtitle: 'Find a similar-skill opponent now',
              color: AppColors.battleGold,
              onTap: _busy ? null : _quick,
            ),
            BattleModeCard(
              icon: Icons.person_add_alt_1,
              title: 'Challenge a Friend',
              subtitle: 'Invite by name or user ID',
              color: AppColors.battleBlue,
              onTap: _busy ? null : _friendSheet,
            ),
            BattleModeCard(
              icon: Icons.lock_outline,
              title: 'Private Battle',
              subtitle: 'Create a room and share the code',
              color: AppColors.accentPurple,
              onTap: _busy ? null : _createPrivate,
            ),
            BattleModeCard(
              icon: Icons.visibility,
              title: 'Organize a Battle',
              subtitle: 'Host two players, watch live, see the answers',
              color: AppColors.accentTeal,
              onTap: _busy ? null : _createOrganized,
            ),
            Center(
              child: TextButton.icon(
                onPressed: _busy ? null : _joinWithCode,
                icon: const Icon(Icons.keyboard, color: Colors.white70),
                label: const Text('Have a room code? Join',
                    style: TextStyle(color: Colors.white70)),
              ),
            ),
            const SizedBox(height: 8),
            _recentResults(),
            const SizedBox(height: 12),
            _topPlayers(),
          ],
        ),
      ),
    );
  }

  Widget _liveCard() {
    return FutureBuilder<String?>(
      future: _live,
      builder: (context, snap) {
        final id = snap.data;
        if (id == null) return const SizedBox.shrink();
        return GlassCard(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.all(14),
          borderColor: AppColors.accentGreen,
          child: Row(
            children: [
              const Icon(Icons.play_circle_fill, color: AppColors.accentGreen),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('A battle is in progress',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              ),
              TextButton(onPressed: () => _resume(id), child: const Text('Resume')),
            ],
          ),
        );
      },
    );
  }

  Widget _statsCard() {
    return StreamBuilder<BattleStats>(
      stream: BattleRepository.myStatsStream(),
      builder: (context, snap) {
        if (snap.hasError) {
          return const EmptyOrError(message: 'Could not load your battle stats.');
        }
        final s = snap.data ?? const BattleStats(uid: '');
        return GlassCard(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              StatPill(label: 'Rating', value: '${s.rating}', color: AppColors.battleGold),
              StatPill(label: 'Battles', value: '${s.played}'),
              StatPill(label: 'Win rate', value: '${s.winRate.toStringAsFixed(0)}%'),
              StatPill(
                  label: 'W / L / D', value: '${s.wins}/${s.losses}/${s.draws}'),
            ],
          ),
        );
      },
    );
  }

  Widget _incoming() {
    return StreamBuilder<List<BattleInvite>>(
      stream: BattleRepository.incomingInvites(),
      builder: (context, snap) {
        final list = snap.data ?? const <BattleInvite>[];
        final now = ServerClock.nowMs;
        final live = list.where((i) => i.expiresAtMs > now).toList();
        if (live.isEmpty) return const SizedBox.shrink();
        return Column(
          children: live
              .map((i) => GlassCard(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(12),
                    borderColor: AppColors.battleBlue,
                    child: Row(
                      children: [
                        const Icon(Icons.mail_outline, color: AppColors.battleBlue),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text('${i.hostName} challenged you!',
                              style: const TextStyle(color: Colors.white)),
                        ),
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => _guard(() => BattleDuelService.declineInvite(i.code)),
                          child: const Text('Decline'),
                        ),
                        ElevatedButton(
                          onPressed: _busy ? null : () => _joinWithCode(i.code),
                          child: const Text('Accept'),
                        ),
                      ],
                    ),
                  ))
              .toList(),
        );
      },
    );
  }

  Widget _topicChips() {
    return FutureBuilder<List<MapEntry<String, String>>>(
      future: _topics,
      builder: (context, snap) {
        final topics = snap.data ?? const <MapEntry<String, String>>[];
        if (topics.isEmpty) return const SizedBox.shrink();
        return SizedBox(
          height: 38,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _chip('Any topic', ''),
              ...topics.map((t) => _chip(t.value, t.key)),
            ],
          ),
        );
      },
    );
  }

  Widget _chip(String label, String id) {
    final selected = _category == id;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() => _category = id),
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: selected ? AppColors.accentTeal : Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? AppColors.accentTeal : Colors.white30),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected) ...[
                const Icon(Icons.check, size: 16, color: Colors.white),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _recentResults() {
    return FutureBuilder<BattleHistoryPage>(
      future: _recent,
      builder: (context, snap) {
        Widget body;
        if (snap.connectionState != ConnectionState.done) {
          body = const Padding(
            padding: EdgeInsets.all(12),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        } else if (snap.hasError) {
          body = EmptyOrError(
              message: 'Could not load recent results.',
              onRetry: () => setState(_reload));
        } else if (snap.data!.items.isEmpty) {
          body = const EmptyOrError(message: 'No battles yet — play your first one!');
        } else {
          body = Column(children: snap.data!.items.map(_resultTile).toList());
        }
        return GlassCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Recent results',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              body,
            ],
          ),
        );
      },
    );
  }

  Widget _resultTile(BattleHistoryItem h) {
    final color = h.result == 'win'
        ? AppColors.accentGreen
        : (h.result == 'draw' ? Colors.amber : AppColors.accentRed);
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        radius: 14,
        backgroundColor: color.withOpacity(0.2),
        child: Text(h.result[0].toUpperCase(),
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
      ),
      title: Text('vs ${h.opponentName}', style: const TextStyle(color: Colors.white)),
      trailing: Text('${h.myScore} - ${h.oppScore}',
          style: const TextStyle(color: Colors.white70)),
    );
  }

  Widget _topPlayers() {
    return FutureBuilder<List<BattleStats>>(
      future: _top,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return const SizedBox.shrink();
        if (snap.hasError || snap.data == null || snap.data!.isEmpty) {
          return const SizedBox.shrink();
        }
        return GlassCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Top battlers',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              ...snap.data!.asMap().entries.map((e) {
                final s = e.value;
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: SizedBox(
                    width: 28,
                    child: Text('${e.key + 1}',
                        style: TextStyle(
                            color: AppColors.rankColor(e.key + 1),
                            fontWeight: FontWeight.bold)),
                  ),
                  title: Text(s.name.isEmpty ? 'Player' : s.name,
                      style: const TextStyle(color: Colors.white)),
                  trailing: Text('${s.rating}',
                      style: const TextStyle(color: AppColors.battleGold)),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

class _FriendSearchSheet extends StatefulWidget {
  const _FriendSearchSheet();

  @override
  State<_FriendSearchSheet> createState() => _FriendSearchSheetState();
}

class _FriendSearchSheetState extends State<_FriendSearchSheet> {
  final TextEditingController _ctrl = TextEditingController();
  List<BattleUserHit> _hits = const [];
  bool _loading = false;
  String? _error;
  bool _searched = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await BattleDuelService.findUser(_ctrl.text);
      if (!mounted) return;
      setState(() {
        _hits = r;
        _searched = true;
      });
    } on BattleException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Challenge a friend',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('Enter their exact username or user ID',
              style: TextStyle(color: Colors.white60, fontSize: 12)),
          const SizedBox(height: 12),
          TextField(
            controller: _ctrl,
            style: const TextStyle(color: Colors.white),
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _search(),
            decoration: InputDecoration(
              hintText: 'Username or user ID',
              hintStyle: const TextStyle(color: Colors.white38),
              suffixIcon: IconButton(
                icon: const Icon(Icons.search, color: Colors.white70),
                onPressed: _search,
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: AppColors.accentRed)),
          if (_searched && _hits.isEmpty && _error == null)
            const Text('No player found.', style: TextStyle(color: Colors.white60)),
          ..._hits.map((h) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: BattleAvatar(name: h.name, photoUrl: h.photoUrl, radius: 20),
                title: Text(h.name, style: const TextStyle(color: Colors.white)),
                trailing: const Icon(Icons.send, color: AppColors.battleBlue),
                onTap: () => Navigator.pop(context, h),
              )),
        ],
      ),
    );
  }
}

class _JoinCodeDialog extends StatefulWidget {
  const _JoinCodeDialog();

  @override
  State<_JoinCodeDialog> createState() => _JoinCodeDialogState();
}

class _JoinCodeDialogState extends State<_JoinCodeDialog> {
  final TextEditingController _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.bgMid,
      title: const Text('Join a battle', style: TextStyle(color: Colors.white)),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        textCapitalization: TextCapitalization.characters,
        style: const TextStyle(color: Colors.white, letterSpacing: 4, fontSize: 20),
        decoration: const InputDecoration(
          hintText: 'ROOM CODE',
          hintStyle: TextStyle(color: Colors.white38, letterSpacing: 2),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        TextButton(
          onPressed: () => Navigator.pop(context, _ctrl.text),
          child: const Text('Join'),
        ),
      ],
    );
  }
}
