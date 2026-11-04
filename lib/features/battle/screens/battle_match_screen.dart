// ============================================================
// FILE: lib/features/battle/screens/battle_match_screen.dart
// One screen for the whole match: pre-match (profiles + VS) →
// synchronized 3-2-1 → live questions with reveal → result.
// All timing comes from BattleMatchController (server schedule);
// this file is presentation only.
// ============================================================

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/glass_card.dart';
import '../controllers/battle_match_controller.dart';
import '../engine/battle_engine.dart';
import '../models/battle_models.dart';
import '../services/battle_duel_service.dart';
import '../widgets/battle_widgets.dart';
import 'battle_matchmaking_screen.dart';
import 'battle_room_screen.dart';

class BattleMatchScreen extends StatefulWidget {
  final String battleId;

  const BattleMatchScreen({super.key, required this.battleId});

  @override
  State<BattleMatchScreen> createState() => _BattleMatchScreenState();
}

class _BattleMatchScreenState extends State<BattleMatchScreen> {
  late final BattleMatchController _c;

  @override
  void initState() {
    super.initState();
    _c = BattleMatchController(widget.battleId)..start();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  bool get _inProgress {
    switch (_c.phase) {
      case BattlePhase.prematch:
      case BattlePhase.countdown:
      case BattlePhase.question:
      case BattlePhase.reveal:
      case BattlePhase.finishing:
        return true;
      default:
        return false;
    }
  }

  Future<bool> _onBack() async {
    if (!_inProgress) return true;
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgMid,
        title: const Text('Leave battle?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Leaving counts as a forfeit and your opponent wins.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Stay')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Leave', style: TextStyle(color: AppColors.accentRed)),
          ),
        ],
      ),
    );
    if (leave != true) return false;
    final err = await _c.forfeit();
    if (err != null && mounted) showBattleSnack(context, err);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      // ignore: deprecated_member_use
      onWillPop: _onBack,
      child: BattleScaffold(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => _body(),
        ),
      ),
    );
  }

  Widget _body() {
    switch (_c.phase) {
      case BattlePhase.loading:
        return _spinner('Loading battle…');
      case BattlePhase.preparing:
        return _spinner('Preparing the battle…');
      case BattlePhase.prematch:
        return _prematch(false);
      case BattlePhase.countdown:
        return _prematch(true);
      case BattlePhase.question:
      case BattlePhase.reveal:
        return _live();
      case BattlePhase.finishing:
        return _finishing();
      case BattlePhase.result:
        return _result();
      case BattlePhase.cancelled:
        return _message(
          _c.match?.cancelReason == 'start_failed'
              ? 'The battle could not start. No result was recorded.'
              : 'This battle was cancelled. No result was recorded.',
          Icons.event_busy,
        );
      case BattlePhase.error:
        return _message(_c.errorMessage ?? 'Something went wrong.', Icons.error_outline);
    }
  }

  Widget _spinner(String text) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(text, style: const TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }

  Widget _message(String text, IconData icon) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 60, color: Colors.white54),
            const SizedBox(height: 14),
            Text(text,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 16)),
            const SizedBox(height: 22),
            ElevatedButton(
              onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
              child: const Text('Back to home'),
            ),
          ],
        ),
      ),
    );
  }

  // ── pre-match + countdown ────────────────────────────────────────────────
  Widget _prematch(bool countdown) {
    final me = _c.me;
    final opp = _c.opponent;
    if (me == null || opp == null) return _spinner('Preparing the battle…');
    final n = _c.countdownNumber;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const SizedBox(height: 12),
          const Text('MATCH FOUND',
              style: TextStyle(
                  color: AppColors.battleGold,
                  fontSize: 20,
                  letterSpacing: 3,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                  child: BattlePlayerCard(
                      player: me, color: AppColors.battleBlue, isMe: true)),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Text('VS',
                    style: TextStyle(
                        color: AppColors.battleGold,
                        fontSize: 30,
                        fontWeight: FontWeight.w900)),
              ),
              Expanded(child: BattlePlayerCard(player: opp, color: AppColors.battleRed)),
            ],
          ),
          const Spacer(),
          if (countdown && n > 0)
            TweenAnimationBuilder<double>(
              key: ValueKey(n),
              tween: Tween(begin: 1.6, end: 1.0),
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOutBack,
              builder: (context, s, _) => Transform.scale(
                scale: s,
                child: Text('$n',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 96, fontWeight: FontWeight.bold)),
              ),
            )
          else
            Column(
              children: [
                const Text('Get ready…',
                    style: TextStyle(color: Colors.white70, fontSize: 18)),
                const SizedBox(height: 6),
                Text('Starting in ${_c.secondsUntilStart}s',
                    style: const TextStyle(color: Colors.white54)),
              ],
            ),
          const Spacer(),
          Text('${_c.totalRounds} questions · ${_c.match?.settings.questionSeconds ?? 15}s each',
              style: const TextStyle(color: Colors.white54, fontSize: 12)),
        ],
      ),
    );
  }

  // ── live ─────────────────────────────────────────────────────────────────
  Widget _live() {
    final m = _c.match;
    final me = _c.me;
    final opp = _c.opponent;
    if (m == null || me == null || opp == null) return _spinner('Loading…');
    final isReveal = _c.phase == BattlePhase.reveal;
    final q = _c.currentQuestion;
    final round = _c.currentRound;
    final secs = (_c.msLeftInPhase / 1000).ceil();
    final oppUid = opp.uid;

    var myDone = _c.answeredCount(_c.myUid);
    var oppDone = _c.answeredCount(oppUid);
    if (_c.currentReveal == null) {
      if (_c.hasAnsweredCurrent) myDone++;
      if (_c.oppAnsweredCurrent) oppDone++;
    }

    return LayoutBuilder(
      builder: (context, box) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: box.maxHeight - 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _scoreChip(me, _c.liveScore(_c.myUid), myDone, AppColors.battleBlue,
                        crossEnd: false),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _scoreChip(opp, _c.liveScore(oppUid), oppDone, AppColors.battleRed,
                        crossEnd: true),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text('Question ${round + 1}/${_c.totalRounds}',
                      style: const TextStyle(color: Colors.white70)),
                  const Spacer(),
                  Icon(isReveal ? Icons.hourglass_bottom : Icons.timer,
                      size: 16,
                      color: secs <= 5 && !isReveal ? AppColors.accentRed : Colors.white70),
                  const SizedBox(width: 4),
                  Text(isReveal ? 'Next in ${secs}s' : '${secs}s',
                      style: TextStyle(
                          color: secs <= 5 && !isReveal
                              ? AppColors.accentRed
                              : Colors.white,
                          fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 6),
              if (!isReveal)
                TweenAnimationBuilder<double>(
                  key: ValueKey('bar$round'),
                  tween: Tween(begin: _c.questionFractionLeft, end: 0),
                  duration: Duration(milliseconds: _c.msLeftInPhase),
                  builder: (context, v, _) => ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: v,
                      minHeight: 8,
                      backgroundColor: Colors.white12,
                      valueColor: AlwaysStoppedAnimation(
                          v < 0.33 ? AppColors.accentRed : AppColors.accentTeal),
                    ),
                  ),
                )
              else
                const SizedBox(height: 8),
              _banners(),
              const SizedBox(height: 12),
              if (_c.showBattleFlash)
                const Center(
                  child: Text('BATTLE!',
                      style: TextStyle(
                          color: AppColors.battleGold,
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 4)),
                ),
              if (q == null)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                GlassCard(
                  padding: const EdgeInsets.all(18),
                  child: Text(q.text,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(height: 12),
                for (var i = 0; i < q.options.length; i++) _option(q, i, isReveal),
                const SizedBox(height: 8),
                _footer(isReveal),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _scoreChip(BattlePlayer p, int score, int answered, Color color,
      {required bool crossEnd}) {
    return GlassCard(
      padding: const EdgeInsets.all(10),
      borderColor: color.withOpacity(0.5),
      child: Column(
        crossAxisAlignment: crossEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: crossEnd ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (!crossEnd) BattleAvatar(name: p.name, photoUrl: p.photoUrl, radius: 14),
              if (!crossEnd) const SizedBox(width: 6),
              Flexible(
                child: Text(p.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 12)),
              ),
              if (crossEnd) const SizedBox(width: 6),
              if (crossEnd) BattleAvatar(name: p.name, photoUrl: p.photoUrl, radius: 14),
            ],
          ),
          const SizedBox(height: 4),
          Text('$score',
              style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: _c.totalRounds == 0 ? 0 : answered / _c.totalRounds,
            minHeight: 4,
            backgroundColor: Colors.white12,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ],
      ),
    );
  }

  Widget _banners() {
    final widgets = <Widget>[];
    String? link;
    switch (_c.opponentLink) {
      case OpponentLink.reconnecting:
        link = 'Opponent is reconnecting…';
        break;
      case OpponentLink.away:
        link = 'Opponent left the app for a moment';
        break;
      case OpponentLink.disconnected:
        link = 'Opponent disconnected — ending the battle…';
        break;
      case OpponentLink.ok:
        break;
    }
    if (link != null) widgets.add(_bannerRow(Icons.wifi_off, link, Colors.amber));
    if (_c.reconnecting) {
      widgets.add(_bannerRow(Icons.sync_problem, 'Reconnecting…', Colors.orangeAccent));
    }
    if (_c.notice != null) {
      widgets.add(GestureDetector(
        onTap: _c.clearNotice,
        child: _bannerRow(Icons.info_outline, _c.notice!, AppColors.accentRed),
      ));
    }
    if (widgets.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(children: widgets),
    );
  }

  Widget _bannerRow(IconData icon, String text, Color color) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(color: color, fontSize: 12))),
        ],
      ),
    );
  }

  Widget _option(BattleQuestion q, int i, bool isReveal) {
    final reveal = _c.currentReveal;
    final mine = _c.myChoice;
    final letter = String.fromCharCode(65 + i);

    Color border = Colors.white24;
    Color fill = Colors.white.withOpacity(0.06);
    IconData? trailing;
    Color? trailingColor;

    if (!isReveal || reveal == null) {
      if (mine == i) {
        border = AppColors.battleBlue;
        fill = AppColors.battleBlue.withOpacity(0.25);
        trailing = Icons.lock;
        trailingColor = AppColors.battleBlue;
      }
    } else {
      if (i == reveal.correctIndex) {
        border = AppColors.accentGreen;
        fill = AppColors.accentGreen.withOpacity(0.25);
        trailing = Icons.check_circle;
        trailingColor = AppColors.accentGreen;
      } else if (reveal.mine?.choice == i) {
        border = AppColors.accentRed;
        fill = AppColors.accentRed.withOpacity(0.25);
        trailing = Icons.cancel;
        trailingColor = AppColors.accentRed;
      }
    }
    final oppPicked = reveal != null && isReveal && reveal.theirs?.choice == i;
    final canTap = !isReveal && mine == null;

    return GestureDetector(
      onTap: canTap ? () => _c.selectAnswer(i) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border, width: 1.5),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 13,
              backgroundColor: Colors.white12,
              child: Text(letter,
                  style: const TextStyle(color: Colors.white, fontSize: 12)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(q.options[i],
                  style: const TextStyle(color: Colors.white, fontSize: 15)),
            ),
            if (oppPicked)
              const Padding(
                padding: EdgeInsets.only(right: 6),
                child: Icon(Icons.person, size: 18, color: AppColors.battleRed),
              ),
            if (trailing != null) Icon(trailing, color: trailingColor),
          ],
        ),
      ),
    );
  }

  Widget _footer(bool isReveal) {
    final reveal = _c.currentReveal;
    String text;
    Color color = Colors.white70;
    if (!isReveal) {
      if (_c.hasAnsweredCurrent) {
        text = _c.oppAnsweredCurrent
            ? 'Locked in ✓  Opponent has answered too'
            : 'Locked in ✓  Waiting for the timer…';
      } else {
        text = 'Pick an answer — you cannot change it';
      }
    } else if (reveal == null) {
      text = 'Checking answers…';
    } else {
      final mine = reveal.mine;
      if (mine == null) {
        text = 'No answer — 0 points';
        color = AppColors.accentRed;
      } else if (mine.choice == reveal.correctIndex) {
        text = 'Correct! +${BattleConfig.basePoints}';
        color = AppColors.accentGreen;
      } else {
        text = 'Wrong — 0 points';
        color = AppColors.accentRed;
      }
    }
    return Center(
      child: Text(text,
          style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 14)),
    );
  }

  // ── finishing ────────────────────────────────────────────────────────────
  Widget _finishing() {
    if (_c.errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_c.errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white)),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _c.retry, child: const Text('Retry')),
              TextButton(
                onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
                child: const Text('Back to home'),
              ),
            ],
          ),
        ),
      );
    }
    return _spinner('Calculating results…');
  }

  // ── result ───────────────────────────────────────────────────────────────
  Widget _result() {
    final m = _c.match;
    final o = _c.outcome;
    final me = _c.me;
    final opp = _c.opponent;
    if (m == null || o == null || me == null || opp == null) return _finishing();

    final iWon = o.winnerId == _c.myUid;
    final draw = o.winnerId == null && o.resultStatus == 'draw';
    final abandoned = o.resultStatus == 'abandoned';

    String title;
    Color color;
    if (abandoned) {
      title = 'NO RESULT';
      color = Colors.white70;
    } else if (draw) {
      title = "IT'S A DRAW";
      color = Colors.amber;
    } else if (iWon) {
      title = 'VICTORY!';
      color = AppColors.accentGreen;
    } else {
      title = 'DEFEAT';
      color = AppColors.accentRed;
    }
    String? sub;
    if (abandoned) sub = 'Nobody answered — this battle was not counted.';
    if (o.resultStatus == 'forfeit') {
      sub = m.forfeit?.by == _c.myUid
          ? 'You left the battle.'
          : (m.forfeit?.reason == 'disconnect'
              ? 'Your opponent disconnected.'
              : 'Your opponent left the battle.');
    }
    final mine = o.tally[_c.myUid];
    final theirs = o.tally[opp.uid];
    final delta = _c.myRatingDelta;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 8),
        Center(
          child: Text(title,
              style: TextStyle(
                  color: color, fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: 3)),
        ),
        if (sub != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Center(
                child: Text(sub, style: const TextStyle(color: Colors.white70, fontSize: 13))),
          ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
                child: BattlePlayerCard(player: me, color: AppColors.battleBlue, isMe: true)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text('${mine?.score ?? 0} : ${theirs?.score ?? 0}',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            ),
            Expanded(child: BattlePlayerCard(player: opp, color: AppColors.battleRed)),
          ],
        ),
        const SizedBox(height: 16),
        if (mine != null && theirs != null)
          GlassCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                _statRow('Correct', '${mine.correct}', '${theirs.correct}'),
                _statRow('Incorrect', '${mine.incorrect}', '${theirs.incorrect}'),
                _statRow('Unanswered', '${mine.unanswered}', '${theirs.unanswered}'),
                _statRow('Accuracy', '${mine.accuracy.toStringAsFixed(0)}%',
                    '${theirs.accuracy.toStringAsFixed(0)}%'),
                _statRow('Total time', '${(mine.answerMs / 1000).toStringAsFixed(1)}s',
                    '${(theirs.answerMs / 1000).toStringAsFixed(1)}s'),
              ],
            ),
          ),
        if (delta != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Center(
              child: Text(
                'Rating ${delta >= 0 ? '+' : ''}$delta',
                style: TextStyle(
                    color: delta >= 0 ? AppColors.accentGreen : AppColors.accentRed,
                    fontSize: 16,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ),
        if (_c.settleFailed)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Center(
              child: Text('Could not save this result to your stats yet.',
                  style: TextStyle(color: Colors.amber, fontSize: 12)),
            ),
          ),
        const SizedBox(height: 20),
        if (!m.isOrganized) ElevatedButton.icon(
          onPressed: () => _playAgain(m),
          icon: const Icon(Icons.replay),
          label: const Text('Play again'),
          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
        ),
        const SizedBox(height: 8),
        if (!m.isOrganized) OutlinedButton.icon(
          onPressed: () => _challengeAgain(opp.uid),
          icon: const Icon(Icons.person_add_alt_1),
          label: Text('Challenge ${opp.name} again'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
          child: const Text('Back to home', style: TextStyle(color: Colors.white70)),
        ),
      ],
    );
  }

  Widget _statRow(String label, String a, String b) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
              child: Text(a,
                  style: const TextStyle(
                      color: AppColors.battleBlue, fontWeight: FontWeight.bold))),
          Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12)),
          Expanded(
              child: Text(b,
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                      color: AppColors.battleRed, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  void _playAgain(BattleMatch m) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => BattleMatchmakingScreen(category: m.category)),
    );
  }

  Future<void> _challengeAgain(String oppUid) async {
    try {
      final r = await BattleDuelService.createRoom(
        mode: 'friend',
        targetUid: oppUid,
        category: _c.match?.category ?? '',
      );
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => BattleRoomScreen(battleId: r['battleId']!)),
      );
    } on BattleException catch (e) {
      showBattleSnack(context, e.message);
    }
  }
}
