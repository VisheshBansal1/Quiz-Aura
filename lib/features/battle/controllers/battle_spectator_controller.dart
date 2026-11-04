// ============================================================
// FILE: lib/features/battle/controllers/battle_spectator_controller.dart
// The ORGANIZER's view of a battle. The organizer never plays:
//   • cannot answer (the rules refuse any answer from a non-player)
//   • sees every question and its CORRECT answer from the moment a round opens
//   • sees both players' answers live, who has answered, and how fast
//   • sees live scores, connection state and the final result
//   • can end the battle (no result, no stats)
// Same server-schedule clock as the players, no per-second writes.
// ============================================================

import 'dart:async';

import 'package:flutter/widgets.dart';

import '../engine/battle_engine.dart';
import '../models/battle_models.dart';
import '../services/battle_duel_service.dart';
import '../services/battle_repository.dart';
import '../services/server_clock.dart';

enum SpectatorPhase { loading, waiting, prematch, countdown, question, reveal, finishing, result, cancelled }

class SpectatorRound {
  final int index;
  final BattleQuestion? question;
  final int? correctIndex;
  final Map<String, PlayerAnswer> answers; // uid -> answer (live)

  const SpectatorRound({
    required this.index,
    required this.question,
    required this.correctIndex,
    required this.answers,
  });
}

class BattleSpectatorController extends ChangeNotifier {
  final String battleId;
  final String myUid;

  BattleSpectatorController(this.battleId) : myUid = BattleRepository.uid;

  BattleMatch? match;
  BattleOutcome? outcome;
  String? errorMessage;

  final Map<int, BattleQuestion> _questions = <int, BattleQuestion>{};
  final Map<int, int> _keys = <int, int>{};
  final Map<int, Map<String, PlayerAnswer>> _answers = <int, Map<String, PlayerAnswer>>{};
  final Map<String, OpponentPresence> _presence = <String, OpponentPresence>{};

  StreamSubscription<BattleMatch?>? _matchSub;
  final Map<String, StreamSubscription<OpponentPresence>> _presSubs = {};
  final List<StreamSubscription<dynamic>> _roundSubs = [];
  Timer? _ticker;
  bool _disposed = false;
  bool _started = false;
  int _subscribedRound = -1;
  final Set<int> _loading = <int>{};
  final Set<int> _backfilled = <int>{};
  String _lastKey = '';

  void start() {
    if (_started) return;
    _started = true;
    ServerClock.sync(force: true);
    _matchSub = BattleRepository.matchStream(battleId).listen(_onMatch, onError: (Object _) {
      errorMessage = 'Lost connection. Retrying…';
      _notify();
    });
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) => _tick());
  }

  @override
  void dispose() {
    _disposed = true;
    _ticker?.cancel();
    _matchSub?.cancel();
    for (final s in _presSubs.values) {
      s.cancel();
    }
    for (final s in _roundSubs) {
      s.cancel();
    }
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _onMatch(BattleMatch? m) {
    if (m == null) {
      errorMessage = 'This battle no longer exists.';
      _notify();
      return;
    }
    match = m;
    errorMessage = null;
    for (final uid in m.playerIds) {
      if (_presSubs.containsKey(uid)) continue;
      _presSubs[uid] = BattleRepository.presenceStream(battleId, uid).listen(
        (p) => _presence[uid] = p,
        onError: (Object _) {},
      );
    }
    _notify();
  }

  // ── derived ──────────────────────────────────────────────────────────────
  int get _now => ServerClock.nowMs;

  List<BattlePlayer> get players {
    final m = match;
    if (m == null) return const [];
    return m.playerIds.map((id) => m.players[id]).whereType<BattlePlayer>().toList();
  }

  SpectatorPhase get phase {
    final m = match;
    if (m == null) return SpectatorPhase.loading;
    if (m.status == BattleStatus.cancelled) return SpectatorPhase.cancelled;
    if (m.status != BattleStatus.live) return SpectatorPhase.waiting;
    if (outcome != null) return SpectatorPhase.result;
    if (m.forfeit != null) return SpectatorPhase.finishing;
    final start = m.startAtMs;
    final end = m.endsAtMs;
    if (start == null || end == null) return SpectatorPhase.waiting;
    final now = _now;
    if (now < start - 3000) return SpectatorPhase.prematch;
    if (now < start) return SpectatorPhase.countdown;
    if (now >= end) return SpectatorPhase.finishing;
    final off = (now - start) % m.settings.periodMs;
    return off < m.settings.questionSeconds * 1000 ? SpectatorPhase.question : SpectatorPhase.reveal;
  }

  int get totalRounds => match?.settings.questionCount ?? 10;

  int get currentRound {
    final m = match;
    final start = m?.startAtMs;
    if (m == null || start == null || _now < start) return 0;
    final i = (_now - start) ~/ m.settings.periodMs;
    return i >= m.settings.questionCount ? m.settings.questionCount - 1 : i;
  }

  int get msLeftInPhase {
    final m = match;
    final start = m?.startAtMs;
    if (m == null || start == null) return 0;
    final s = m.settings;
    final off = (_now - start) - currentRound * s.periodMs;
    final q = s.questionSeconds * 1000;
    final left = off < q ? q - off : s.periodMs - off;
    return left < 0 ? 0 : left;
  }

  double get questionFractionLeft {
    final m = match;
    if (m == null) return 0;
    final f = msLeftInPhase / (m.settings.questionSeconds * 1000);
    return f < 0 ? 0 : (f > 1 ? 1 : f);
  }

  int get countdownNumber {
    final start = match?.startAtMs;
    if (start == null) return 0;
    final ms = start - _now;
    return ms <= 0 ? 0 : (ms / 1000).ceil();
  }

  SpectatorRound roundData(int i) => SpectatorRound(
        index: i,
        question: _questions[i],
        correctIndex: _keys[i],
        answers: _answers[i] ?? const <String, PlayerAnswer>{},
      );

  /// Response time in ms for a player's answer in round [i].
  int? responseMs(int i, String uid) {
    final m = match;
    final a = _answers[i]?[uid];
    final start = m?.startAtMs;
    if (m == null || a == null || start == null) return null;
    return BattleEngine.responseMs(a, start, i, m.settings);
  }

  /// Score from rounds whose reveal time has passed (same rule as the players).
  int scoreOf(String uid) {
    final m = match;
    final start = m?.startAtMs;
    if (m == null || start == null) return 0;
    final done = BattleEngine.revealedRounds(_now, start, m.settings);
    var n = 0;
    for (var r = 0; r < done; r++) {
      final a = _answers[r]?[uid];
      final key = _keys[r];
      if (a != null && key != null && a.choice == key) n++;
    }
    return n * BattleConfig.basePoints;
  }

  String linkText(String uid) {
    final m = match;
    final start = m?.startAtMs;
    if (m == null || start == null || _now < start) return '';
    final p = _presence[uid];
    final last = p?.lastSeenMs ?? start;
    switch (BattleEngine.presenceState(_now, last, p?.state ?? 'fg')) {
      case 'reconnecting':
        return 'reconnecting…';
      case 'away':
        return 'left the app';
      case 'disconnected':
        return 'disconnected';
      default:
        return '';
    }
  }

  // ── actions ──────────────────────────────────────────────────────────────
  Future<String?> endBattle() async {
    try {
      await BattleDuelService.organizerAbort(battleId);
      return null;
    } on BattleException catch (e) {
      return e.message;
    }
  }

  // ── ticker ───────────────────────────────────────────────────────────────
  void _tick() {
    if (_disposed) return;
    final m = match;
    if (m == null || m.status != BattleStatus.live || m.startAtMs == null) return;
    final p = phase;
    if (p == SpectatorPhase.question || p == SpectatorPhase.reveal) {
      _watchRound(m, currentRound);
    }
    if (outcome == null) {
      _backfill(m);
      _maybeFinish(m);
    }
    final key = '${p.index}:$currentRound:${(msLeftInPhase / 1000).ceil()}:$countdownNumber';
    if (key != _lastKey) {
      _lastKey = key;
      _notify();
    }
  }

  /// Organizer may read the question, the key and both answers at any time.
  void _watchRound(BattleMatch m, int r) {
    if (_subscribedRound == r) return;
    _subscribedRound = r;
    for (final s in _roundSubs) {
      s.cancel();
    }
    _roundSubs.clear();
    _loadRound(r);
    for (final uid in m.playerIds) {
      _roundSubs.add(BattleRepository.answerStream(battleId, r, uid).listen((a) {
        if (a != null) {
          (_answers[r] ??= <String, PlayerAnswer>{})[uid] = a;
          _notify();
        }
      }, onError: (Object _) {}));
    }
  }

  Future<void> _loadRound(int r) async {
    if (_questions.containsKey(r) && _keys.containsKey(r)) return;
    if (!_loading.add(r)) return;
    try {
      for (var attempt = 0; attempt < 5 && !_disposed; attempt++) {
        try {
          final q = _questions[r] ?? await BattleRepository.fetchQuestion(battleId, r);
          final k = _keys[r] ?? await BattleRepository.fetchKey(battleId, r);
          if (q != null) _questions[r] = q;
          if (k != null) _keys[r] = k;
          if (q != null && k != null) {
            _notify();
            return;
          }
        } catch (_) {}
        await Future<void>.delayed(Duration(milliseconds: 400 + attempt * 300));
      }
    } finally {
      _loading.remove(r);
    }
  }

  /// Rounds before the one on screen (joined late / reconnected).
  void _backfill(BattleMatch m) {
    final start = m.startAtMs;
    if (start == null) return;
    final upto = BattleEngine.revealedRounds(_now - 300, start, m.settings);
    for (var r = 0; r < upto; r++) {
      if (_backfilled.contains(r) || _loading.contains(r)) continue;
      _loading.add(r);
      () async {
        try {
          final k = await BattleRepository.fetchKey(battleId, r);
          if (k != null) _keys[r] = k;
          for (final uid in m.playerIds) {
            final a = await BattleRepository.fetchAnswer(battleId, r, uid);
            if (a != null) (_answers[r] ??= <String, PlayerAnswer>{})[uid] = a;
          }
          _answers.putIfAbsent(r, () => <String, PlayerAnswer>{});
          if (k != null) _backfilled.add(r);
          _notify();
        } catch (_) {
        } finally {
          _loading.remove(r);
        }
      }();
    }
  }

  void _maybeFinish(BattleMatch m) {
    final start = m.startAtMs;
    final end = m.endsAtMs;
    if (start == null || end == null) return;
    if (m.forfeit == null && _now < end) return;
    final need = m.forfeit != null
        ? BattleEngine.revealedRounds(_now - 300, start, m.settings)
        : m.settings.questionCount;
    for (var r = 0; r < need; r++) {
      if (!_keys.containsKey(r) || !_answers.containsKey(r)) return; // still loading
    }
    final rounds = <RoundData>[];
    _keys.forEach((i, key) {
      rounds.add(RoundData(
        index: i,
        correctIndex: key,
        answers: {for (final uid in m.playerIds) uid: _answers[i]?[uid]},
      ));
    });
    outcome = BattleEngine.computeOutcome(
      rounds: rounds,
      uids: m.playerIds,
      settings: m.settings,
      startMs: start,
      forfeit: m.forfeit,
    );
    _notify();
  }
}
