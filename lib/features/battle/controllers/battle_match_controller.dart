// ============================================================
// FILE: lib/features/battle/controllers/battle_match_controller.dart
// Drives ONE live battle on the client (free Spark plan).
//   • phase comes from the match's server-time schedule (no per-second
//     writes — the clock is computed locally from startAtMs)
//   • answers are written once; the rules timestamp them
//   • after each round's reveal time the answer key + both answers become
//     readable; scores/winner are DERIVED from them (BattleEngine)
//   • heartbeat + background/disconnect handling, forfeit, settle
// Uses ChangeNotifier (no extra state-management dependency).
// ============================================================

import 'dart:async';

import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:flutter/widgets.dart';

import '../engine/battle_engine.dart';
import '../models/battle_models.dart';
import '../services/battle_repository.dart';
import '../services/battle_duel_service.dart';
import '../services/server_clock.dart';

enum BattlePhase {
  loading,
  preparing,
  prematch,
  countdown,
  question,
  reveal,
  finishing,
  result,
  cancelled,
  error,
}

enum OpponentLink { ok, reconnecting, away, disconnected }

class RoundReveal {
  final int index;
  final int correctIndex;
  final PlayerAnswer? mine;
  final PlayerAnswer? theirs;

  const RoundReveal({
    required this.index,
    required this.correctIndex,
    required this.mine,
    required this.theirs,
  });
}

class BattleMatchController extends ChangeNotifier with WidgetsBindingObserver {
  final String battleId;
  final String myUid;

  BattleMatchController(this.battleId) : myUid = BattleRepository.uid;

  // ── observable state ─────────────────────────────────────────────────────
  BattleMatch? match;
  final Map<int, RoundReveal> reveals = <int, RoundReveal>{};
  final Map<int, int> localAnswers = <int, int>{};
  final Set<int> rejectedRounds = <int>{};
  bool oppAnsweredCurrent = false;
  BattleOutcome? outcome;
  String? errorMessage;
  String? notice;
  OpponentLink opponentLink = OpponentLink.ok;
  bool reconnecting = false;
  bool settleFailed = false;

  // ── internals ────────────────────────────────────────────────────────────
  final Map<int, BattleQuestion> _questions = <int, BattleQuestion>{};
  final Set<int> _loadingQuestions = <int>{};
  final Set<int> _submitting = <int>{};
  final Set<int> _fetchingReveal = <int>{};
  final Map<int, int> _nextRevealTryMs = <int, int>{};

  StreamSubscription<BattleMatch?>? _matchSub;
  StreamSubscription<bool>? _ackSub;
  StreamSubscription<OpponentPresence>? _presSub;
  Timer? _ticker;
  Timer? _heartbeat;

  OpponentPresence _oppPresence = const OpponentPresence(null, 'fg');
  bool _started = false;
  bool _disposed = false;
  bool _inBackground = false;
  bool _oppSubscribed = false;
  int _ackRound = -1;
  bool _claimInFlight = false;
  int _nextClaimMs = 0;
  bool _startFailureHandled = false;
  bool _settling = false;
  bool _settled = false;
  String _lastKey = '';

  // ── lifecycle ────────────────────────────────────────────────────────────
  void start() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);

    ServerClock.sync(force: true);
    BattleDuelService.cancelQueue(); // leave any stale queue entry

    _matchSub = BattleRepository.matchStream(battleId).listen(
      _onMatch,
      onError: (Object e) {
        errorMessage = 'Lost connection to the battle. Retrying…';
        reconnecting = true;
        _notify();
      },
    );
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) => _tick());
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _heartbeat?.cancel();
    _matchSub?.cancel();
    _ackSub?.cancel();
    _presSub?.cancel();
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  // ── app lifecycle: background ≠ disconnect ───────────────────────────────
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_disposed) return;
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _inBackground = true;
      _heartbeat?.cancel();
      if (_isLive) {
        BattleDuelService.writePresence(battleId, 'bg').catchError((Object _) {});
      }
    } else if (state == AppLifecycleState.resumed && _inBackground) {
      _inBackground = false;
      ServerClock.sync(force: true);
      if (_isLive) _startHeartbeat();
      _notify();
    }
  }

  bool get _isLive {
    final m = match;
    return m != null && m.status == BattleStatus.live && outcome == null;
  }

  void _startHeartbeat() {
    _heartbeat?.cancel();
    BattleDuelService.writePresence(battleId, 'fg').catchError((Object _) {});
    _heartbeat = Timer.periodic(const Duration(seconds: 10), (_) {
      if (_disposed || _inBackground || !_isLive) return;
      BattleDuelService.writePresence(battleId, 'fg').catchError((Object _) {});
    });
  }

  // ── match updates ────────────────────────────────────────────────────────
  void _onMatch(BattleMatch? m) {
    if (m == null) {
      errorMessage = 'This battle no longer exists.';
      _notify();
      return;
    }
    final wasLive = match != null && match!.status == BattleStatus.live;
    match = m;
    errorMessage = null;
    reconnecting = false;

    if (!_oppSubscribed) {
      final opp = m.opponentOf(myUid);
      if (opp != null) {
        _oppSubscribed = true;
        _presSub = BattleRepository.presenceStream(battleId, opp).listen(
          (p) => _oppPresence = p,
          onError: (Object _) {},
        );
      }
    }
    if (!wasLive && m.status == BattleStatus.live && !_inBackground) {
      _startHeartbeat();
    }
    if (m.status == BattleStatus.cancelled) _heartbeat?.cancel();
    _notify();
  }

  // ── derived timeline ─────────────────────────────────────────────────────
  BattlePlayer? get me => match?.players[myUid];

  BattlePlayer? get opponent {
    final m = match;
    if (m == null) return null;
    final id = m.opponentOf(myUid);
    return id == null ? null : m.players[id];
  }

  int get _nowMs => ServerClock.nowMs;

  bool get _cancelledBeforeStart {
    final m = match;
    final f = m?.forfeit;
    if (m == null || f == null) return false;
    final start = m.startAtMs;
    return f.atMs != null && start != null && f.atMs! < start;
  }

  BattlePhase get phase {
    final m = match;
    if (m == null) return errorMessage != null ? BattlePhase.error : BattlePhase.loading;
    if (m.status == BattleStatus.cancelled) return BattlePhase.cancelled;
    if (m.status == BattleStatus.waiting ||
        m.status == BattleStatus.lobby ||
        m.status == BattleStatus.unknown) {
      return BattlePhase.preparing;
    }
    if (_cancelledBeforeStart) return BattlePhase.cancelled;
    if (outcome != null) {
      return outcome!.resultStatus == 'abandoned' ? BattlePhase.result : BattlePhase.result;
    }
    if (m.forfeit != null) return BattlePhase.finishing;
    final start = m.startAtMs;
    final end = m.endsAtMs;
    if (start == null || end == null) return BattlePhase.preparing;
    final now = _nowMs;
    if (now < start - 3000) return BattlePhase.prematch;
    if (now < start) return BattlePhase.countdown;
    if (now >= end) return BattlePhase.finishing;
    final off = (now - start) % m.settings.periodMs;
    return off < m.settings.questionSeconds * 1000 ? BattlePhase.question : BattlePhase.reveal;
  }

  int get totalRounds => match?.settings.questionCount ?? 10;

  int get currentRound {
    final m = match;
    final start = m?.startAtMs;
    if (m == null || start == null) return 0;
    final now = _nowMs;
    if (now < start) return 0;
    final i = (now - start) ~/ m.settings.periodMs;
    return i >= m.settings.questionCount ? m.settings.questionCount - 1 : i;
  }

  int get msLeftInPhase {
    final m = match;
    final start = m?.startAtMs;
    if (m == null || start == null) return 0;
    final s = m.settings;
    final off = (_nowMs - start) - currentRound * s.periodMs;
    final qMs = s.questionSeconds * 1000;
    final left = off < qMs ? qMs - off : s.periodMs - off;
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
    final ms = start - _nowMs;
    return ms <= 0 ? 0 : (ms / 1000).ceil();
  }

  int get secondsUntilStart => countdownNumber;

  bool get showBattleFlash {
    final start = match?.startAtMs;
    if (start == null) return false;
    final d = _nowMs - start;
    return d >= 0 && d < 800;
  }

  BattleQuestion? get currentQuestion => _questions[currentRound];
  int? get myChoice => localAnswers[currentRound];
  bool get hasAnsweredCurrent => localAnswers.containsKey(currentRound);
  RoundReveal? get currentReveal => reveals[currentRound];

  /// Score from rounds revealed so far (hidden rounds never leak).
  int liveScore(String uid) {
    var n = 0;
    reveals.forEach((_, r) {
      final a = uid == myUid ? r.mine : r.theirs;
      if (a != null && a.choice == r.correctIndex) n++;
    });
    return n * BattleConfig.basePoints;
  }

  int answeredCount(String uid) {
    var n = 0;
    reveals.forEach((_, r) {
      final a = uid == myUid ? r.mine : r.theirs;
      if (a != null) n++;
    });
    return n;
  }

  /// My rating change for the result screen (null if not counted).
  int? get myRatingDelta {
    final o = outcome;
    final m = match;
    final opp = opponent;
    final mine = me;
    if (o == null || m == null || opp == null || mine == null || !o.countsForStats) return null;
    final score = o.winnerId == myUid ? 1.0 : (o.winnerId == null ? 0.5 : 0.0);
    return BattleEngine.newRating(mine.rating, opp.rating, score) - mine.rating;
  }

  // ── actions ──────────────────────────────────────────────────────────────
  Future<void> selectAnswer(int choice) async {
    if (phase != BattlePhase.question) return;
    final i = currentRound;
    if (localAnswers.containsKey(i)) return;
    final q = _questions[i];
    if (q == null || choice < 0 || choice >= q.options.length) return;
    localAnswers[i] = choice;
    _notify();
    await _submit(i, choice);
  }

  Future<void> _submit(int round, int choice) async {
    if (!_submitting.add(round)) return;
    var delayMs = 400;
    try {
      for (var attempt = 0; attempt < 4 && !_disposed; attempt++) {
        try {
          final r = await BattleDuelService.submitAnswer(
              battleId: battleId, round: round, choice: choice);
          reconnecting = false;
          if (r == AnswerResult.rejected) {
            rejectedRounds.add(round);
            notice = 'Too late — that answer was not counted.';
          }
          return;
        } on BattleException catch (e) {
          if (!e.isRetryable) {
            notice = e.message;
            return;
          }
          reconnecting = true;
          _notify();
          await Future<void>.delayed(Duration(milliseconds: delayMs));
          delayMs *= 2;
        }
      }
      notice = 'Connection problem — your answer may not have been counted.';
    } finally {
      _submitting.remove(round);
      _notify();
    }
  }

  Future<String?> forfeit() async {
    try {
      final m = match;
      if (m != null && (m.status == BattleStatus.waiting || m.status == BattleStatus.lobby)) {
        await BattleDuelService.cancelRoom(m, 'left');
      } else {
        await BattleDuelService.forfeit(battleId);
      }
      return null;
    } on BattleException catch (e) {
      return e.message;
    }
  }

  void clearNotice() {
    notice = null;
    _notify();
  }

  void retry() {
    errorMessage = null;
    settleFailed = false;
    _settling = false;
    _nextRevealTryMs.clear();
    _notify();
  }

  // ── ticker ───────────────────────────────────────────────────────────────
  void _tick() {
    if (_disposed) return;
    final m = match;
    if (m == null || m.status != BattleStatus.live) return;

    final p = phase;
    if (p == BattlePhase.question || p == BattlePhase.reveal) {
      _ensureQuestionLoaded(currentRound);
      _watchOpponentAck(m);
      _checkStartFailure(m);
    }
    if (outcome == null && !_cancelledBeforeStart) {
      _fetchDueReveals(m);
      _updateOpponentLink(m);
      _maybeFinish(m);
    }
    if (outcome != null) _settleOnce();

    final key = '${p.index}:$currentRound:${(msLeftInPhase / 1000).ceil()}:'
        '$countdownNumber:${showBattleFlash ? 1 : 0}:${opponentLink.index}';
    if (key != _lastKey) {
      _lastKey = key;
      _notify();
    }
  }

  // ── questions (rules hide each until its round opens) ───────────────────
  Future<void> _ensureQuestionLoaded(int i) async {
    if (_questions.containsKey(i) || !_loadingQuestions.add(i)) return;
    try {
      for (var attempt = 0; attempt < 6 && !_disposed; attempt++) {
        try {
          final q = await BattleRepository.fetchQuestion(battleId, i);
          if (q != null) {
            _questions[i] = q;
            _notify();
            return;
          }
        } on FirebaseException catch (_) {
          // permission-denied = "not open yet" or a slightly early clock.
        } catch (_) {}
        await Future<void>.delayed(Duration(milliseconds: 350 + attempt * 250));
      }
    } finally {
      _loadingQuestions.remove(i);
    }
  }

  /// Host never wrote the questions ⇒ cancel so nobody is stuck.
  void _checkStartFailure(BattleMatch m) {
    if (_startFailureHandled || _questions.isNotEmpty) return;
    final start = m.startAtMs;
    if (start == null) return;
    if (_nowMs > start + BattleConfig.startFailureMs + 1500) {
      _startFailureHandled = true;
      BattleDuelService.cancelBattle(battleId, 'start_failed').catchError((Object _) {});
    }
  }

  void _watchOpponentAck(BattleMatch m) {
    final opp = m.opponentOf(myUid);
    final r = currentRound;
    if (opp == null || r == _ackRound) return;
    _ackRound = r;
    oppAnsweredCurrent = false;
    _ackSub?.cancel();
    _ackSub = BattleRepository.ackStream(battleId, r, opp).listen((v) {
      oppAnsweredCurrent = v;
      _notify();
    }, onError: (Object _) {});
  }

  // ── reveals: key + both answers, readable only after the reveal time ────
  void _fetchDueReveals(BattleMatch m) {
    final start = m.startAtMs;
    if (start == null) return;
    final opp = m.opponentOf(myUid);
    if (opp == null) return;
    // +300 ms margin so we never ask a hair before the rules open the door.
    final due = BattleEngine.revealedRounds(_nowMs - 300, start, m.settings);
    for (var r = 0; r < due; r++) {
      if (reveals.containsKey(r) || _fetchingReveal.contains(r)) continue;
      if (_nowMs < (_nextRevealTryMs[r] ?? 0)) continue;
      _fetchReveal(r, opp);
    }
  }

  Future<void> _fetchReveal(int r, String opp) async {
    _fetchingReveal.add(r);
    try {
      final key = await BattleRepository.fetchKey(battleId, r);
      if (key == null) throw StateError('key missing');
      final mine = await BattleRepository.fetchAnswer(battleId, r, myUid);
      final theirs = await BattleRepository.fetchAnswer(battleId, r, opp);
      reveals[r] = RoundReveal(index: r, correctIndex: key, mine: mine, theirs: theirs);
      reconnecting = false;
      _notify();
    } catch (_) {
      _nextRevealTryMs[r] = _nowMs + 1200;
    } finally {
      _fetchingReveal.remove(r);
    }
  }

  // ── finishing ────────────────────────────────────────────────────────────
  void _maybeFinish(BattleMatch m) {
    final start = m.startAtMs;
    final end = m.endsAtMs;
    if (start == null || end == null) return;
    final ended = m.forfeit != null || _nowMs >= end;
    if (!ended) return;

    // After a forfeit only rounds that were revealed in time are readable.
    final needed = m.forfeit != null
        ? BattleEngine.revealedRounds(_nowMs - 300, start, m.settings)
        : m.settings.questionCount;
    for (var r = 0; r < needed; r++) {
      if (!reveals.containsKey(r)) return; // still fetching
    }
    final rounds = <RoundData>[];
    final opp = m.opponentOf(myUid);
    if (opp == null) return;
    reveals.forEach((i, rv) {
      rounds.add(RoundData(
        index: i,
        correctIndex: rv.correctIndex,
        answers: {myUid: rv.mine, opp: rv.theirs},
      ));
    });
    outcome = BattleEngine.computeOutcome(
      rounds: rounds,
      uids: m.playerIds,
      settings: m.settings,
      startMs: start,
      forfeit: m.forfeit,
    );
    _heartbeat?.cancel();
    _notify();
  }

  Future<void> _settleOnce() async {
    final o = outcome;
    final m = match;
    if (o == null || m == null || _settled || _settling) return;
    if (!o.countsForStats) {
      _settled = true;
      return;
    }
    // Rules only allow settling once the battle's scheduled end has passed.
    final end = m.endsAtMs;
    if (m.forfeit == null && (end == null || _nowMs < end + 500)) return;
    _settling = true;
    for (var attempt = 0; attempt < 3 && !_disposed; attempt++) {
      try {
        await BattleDuelService.settle(match: m, outcome: o);
        _settled = true;
        settleFailed = false;
        break;
      } on BattleException catch (e) {
        settleFailed = true;
        if (!e.isRetryable && e.code != 'permission-denied') break;
        await Future<void>.delayed(Duration(seconds: 2 + attempt * 2));
      }
    }
    _settling = false;
    _notify();
  }

  // ── opponent connection monitor ──────────────────────────────────────────
  void _updateOpponentLink(BattleMatch m) {
    final start = m.startAtMs;
    if (start == null) return;
    final now = _nowMs;
    if (now < start) {
      opponentLink = OpponentLink.ok;
      return;
    }
    final last = _oppPresence.lastSeenMs ?? start;
    switch (BattleEngine.presenceState(now, last, _oppPresence.state)) {
      case 'ok':
        opponentLink = OpponentLink.ok;
        break;
      case 'reconnecting':
        opponentLink = OpponentLink.reconnecting;
        break;
      case 'away':
        opponentLink = OpponentLink.away;
        break;
      default:
        opponentLink = OpponentLink.disconnected;
    }
    final opp = m.opponentOf(myUid);
    if (opponentLink == OpponentLink.disconnected &&
        opp != null &&
        m.forfeit == null &&
        !_claimInFlight &&
        now >= _nextClaimMs) {
      _claimInFlight = true;
      BattleDuelService.claimDisconnect(battleId, opp).then((_) {}).catchError((Object _) {
        _nextClaimMs = _nowMs + 10000; // rules refused (they are back) — retry later
      }).whenComplete(() {
        _claimInFlight = false;
      });
    }
  }
}
