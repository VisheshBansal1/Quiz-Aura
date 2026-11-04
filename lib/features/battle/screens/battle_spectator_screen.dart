// ============================================================
// FILE: lib/features/battle/screens/battle_spectator_screen.dart
// Organizer (referee) screen: watches both players, sees the correct
// answer on every question, who answered what and how fast, live scores,
// connection state and the final result. Nothing here can be answered.
// ============================================================

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/glass_card.dart';
import '../controllers/battle_spectator_controller.dart';
import '../engine/battle_engine.dart';
import '../models/battle_models.dart';
import '../widgets/battle_widgets.dart';

class BattleSpectatorScreen extends StatefulWidget {
  final String battleId;

  const BattleSpectatorScreen({super.key, required this.battleId});

  @override
  State<BattleSpectatorScreen> createState() => _BattleSpectatorScreenState();
}

class _BattleSpectatorScreenState extends State<BattleSpectatorScreen> {
  late final BattleSpectatorController _c;
  static const List<Color> _playerColors = [AppColors.battleBlue, AppColors.battleRed];

  @override
  void initState() {
    super.initState();
    _c = BattleSpectatorController(widget.battleId)..start();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  bool get _live {
    switch (_c.phase) {
      case SpectatorPhase.prematch:
      case SpectatorPhase.countdown:
      case SpectatorPhase.question:
      case SpectatorPhase.reveal:
      case SpectatorPhase.finishing:
        return true;
      default:
        return false;
    }
  }

  Future<bool> _onBack() async {
    if (!_live) return true;
    final end = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgMid,
        title: const Text('Leave as organizer?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'The battle keeps running without you. Use "End battle" to stop it for both players.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Stay')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Leave')),
        ],
      ),
    );
    return end == true;
  }

  Future<void> _endBattle() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgMid,
        title: const Text('End this battle?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'It stops for both players. No winner is declared and no ratings change.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep going')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('End battle', style: TextStyle(color: AppColors.accentRed)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final err = await _c.endBattle();
    if (err != null && mounted) showBattleSnack(context, err);
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      // ignore: deprecated_member_use
      onWillPop: _onBack,
      child: BattleScaffold(
        child: AnimatedBuilder(animation: _c, builder: (context, _) => _body()),
      ),
    );
  }

  Widget _body() {
    switch (_c.phase) {
      case SpectatorPhase.loading:
      case SpectatorPhase.waiting:
        return _spinner('Getting the battle ready…');
      case SpectatorPhase.prematch:
      case SpectatorPhase.countdown:
        return _prematch();
      case SpectatorPhase.question:
      case SpectatorPhase.reveal:
        return _liveView();
      case SpectatorPhase.finishing:
        return _spinner('Calculating results…');
      case SpectatorPhase.result:
        return _result();
      case SpectatorPhase.cancelled:
        return _message(_c.match?.cancelReason == 'organizer_ended'
            ? 'You ended this battle. No result was recorded.'
            : 'This battle was cancelled. No result was recorded.');
    }
  }

  Widget _spinner(String t) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 14),
          Text(t, style: const TextStyle(color: Colors.white70)),
        ]),
      );

  Widget _message(String t) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.event_busy, size: 56, color: Colors.white54),
            const SizedBox(height: 12),
            Text(t, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 16)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
              child: const Text('Back to home'),
            ),
          ]),
        ),
      );

  Widget _prematch() {
    final ps = _c.players;
    final n = _c.countdownNumber;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const SizedBox(height: 8),
          const _RefereeBadge(),
          const SizedBox(height: 20),
          Row(children: [
            for (var i = 0; i < ps.length; i++) ...[
              if (i == 1)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Text('VS',
                      style: TextStyle(
                          color: AppColors.battleGold, fontSize: 28, fontWeight: FontWeight.w900)),
                ),
              Expanded(child: BattlePlayerCard(player: ps[i], color: _playerColors[i % 2])),
            ],
          ]),
          const Spacer(),
          Text(_c.phase == SpectatorPhase.countdown && n > 0 ? '$n' : 'Starting soon…',
              style: const TextStyle(color: Colors.white, fontSize: 72, fontWeight: FontWeight.bold)),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _liveView() {
    final m = _c.match!;
    final ps = _c.players;
    final r = _c.currentRound;
    final data = _c.roundData(r);
    final q = data.question;
    final isReveal = _c.phase == SpectatorPhase.reveal;
    final secs = (_c.msLeftInPhase / 1000).ceil();

    return LayoutBuilder(
      builder: (context, box) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: box.maxHeight - 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                const _RefereeBadge(),
                const Spacer(),
                TextButton.icon(
                  onPressed: _endBattle,
                  icon: const Icon(Icons.stop_circle_outlined, color: AppColors.accentRed, size: 18),
                  label: const Text('End battle', style: TextStyle(color: AppColors.accentRed)),
                ),
              ]),
              Row(children: [
                for (var i = 0; i < ps.length; i++) ...[
                  if (i == 1) const SizedBox(width: 8),
                  Expanded(child: _playerPanel(ps[i], _playerColors[i % 2], data, r)),
                ],
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Text('Question ${r + 1}/${_c.totalRounds}',
                    style: const TextStyle(color: Colors.white70)),
                const Spacer(),
                Icon(isReveal ? Icons.hourglass_bottom : Icons.timer, size: 16, color: Colors.white70),
                const SizedBox(width: 4),
                Text(isReveal ? 'Next in ${secs}s' : '${secs}s',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ]),
              const SizedBox(height: 6),
              if (!isReveal)
                TweenAnimationBuilder<double>(
                  key: ValueKey('sbar$r'),
                  tween: Tween(begin: _c.questionFractionLeft, end: 0),
                  duration: Duration(milliseconds: _c.msLeftInPhase),
                  builder: (context, v, _) => ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: v,
                      minHeight: 8,
                      backgroundColor: Colors.white12,
                      valueColor: const AlwaysStoppedAnimation(AppColors.accentTeal),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
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
                for (var i = 0; i < q.options.length; i++) _option(q, i, data, ps),
                const SizedBox(height: 4),
                _legend(ps),
              ],
              const SizedBox(height: 6),
              Center(
                child: Text('${m.settings.questionCount} questions · you are watching only',
                    style: const TextStyle(color: Colors.white38, fontSize: 11)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _playerPanel(BattlePlayer p, Color color, SpectatorRound d, int round) {
    final a = d.answers[p.uid];
    final ms = _c.responseMs(round, p.uid);
    final link = _c.linkText(p.uid);
    String status;
    Color statusColor = Colors.white60;
    if (a == null) {
      status = 'thinking…';
    } else {
      final correct = d.correctIndex != null ? (a.choice == d.correctIndex) : null;
      status = 'answered ${((ms ?? 0) / 1000).toStringAsFixed(1)}s';
      if (correct == true) statusColor = AppColors.accentGreen;
      if (correct == false) statusColor = AppColors.accentRed;
    }
    return GlassCard(
      padding: const EdgeInsets.all(10),
      borderColor: color.withOpacity(0.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            BattleAvatar(name: p.name, photoUrl: p.photoUrl, radius: 14),
            const SizedBox(width: 6),
            Expanded(
              child: Text(p.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 12)),
            ),
          ]),
          const SizedBox(height: 4),
          Text('${_c.scoreOf(p.uid)}',
              style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.bold)),
          Text(link.isEmpty ? status : '$status · $link',
              style: TextStyle(color: link.isEmpty ? statusColor : Colors.amber, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _option(BattleQuestion q, int i, SpectatorRound d, List<BattlePlayer> ps) {
    final isCorrect = d.correctIndex == i;
    final picked = <int>[];
    for (var k = 0; k < ps.length; k++) {
      if (d.answers[ps[k].uid]?.choice == i) picked.add(k);
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: isCorrect ? AppColors.accentGreen.withOpacity(0.22) : Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isCorrect ? AppColors.accentGreen : Colors.white24, width: 1.5),
      ),
      child: Row(children: [
        CircleAvatar(
          radius: 13,
          backgroundColor: Colors.white12,
          child: Text(String.fromCharCode(65 + i),
              style: const TextStyle(color: Colors.white, fontSize: 12)),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(q.options[i], style: const TextStyle(color: Colors.white, fontSize: 15))),
        for (final k in picked)
          Container(
            margin: const EdgeInsets.only(left: 4),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _playerColors[k % 2].withOpacity(0.3),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _playerColors[k % 2]),
            ),
            child: Text(ps[k].name.isEmpty ? 'P${k + 1}' : ps[k].name.split(' ').first,
                style: const TextStyle(color: Colors.white, fontSize: 11)),
          ),
        if (isCorrect)
          const Padding(
            padding: EdgeInsets.only(left: 8),
            child: Icon(Icons.check_circle, color: AppColors.accentGreen),
          ),
      ]),
    );
  }

  Widget _legend(List<BattlePlayer> ps) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var k = 0; k < ps.length; k++) ...[
          Container(width: 10, height: 10, decoration: BoxDecoration(color: _playerColors[k % 2], shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text(ps[k].name, style: const TextStyle(color: Colors.white60, fontSize: 11)),
          const SizedBox(width: 12),
        ],
        const Icon(Icons.check_circle, size: 12, color: AppColors.accentGreen),
        const SizedBox(width: 4),
        const Text('correct answer', style: TextStyle(color: Colors.white60, fontSize: 11)),
      ],
    );
  }

  Widget _result() {
    final o = _c.outcome!;
    final ps = _c.players;
    final a = ps.isNotEmpty ? ps[0] : null;
    final b = ps.length > 1 ? ps[1] : null;
    String title;
    Color color;
    if (o.resultStatus == 'abandoned') {
      title = 'NO RESULT';
      color = Colors.white70;
    } else if (o.winnerId == null) {
      title = "IT'S A DRAW";
      color = Colors.amber;
    } else {
      final w = ps.where((p) => p.uid == o.winnerId).toList();
      title = '${w.isEmpty ? 'Player' : w.first.name} WINS';
      color = AppColors.accentGreen;
    }
    final m = _c.match;
    String? sub;
    if (o.resultStatus == 'forfeit') {
      final left = ps.where((p) => p.uid == m?.forfeit?.by).toList();
      sub = '${left.isEmpty ? 'A player' : left.first.name} ${m?.forfeit?.reason == 'disconnect' ? 'disconnected' : 'left the battle'}.';
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Center(child: _RefereeBadge()),
        const SizedBox(height: 14),
        Center(
          child: Text(title,
              textAlign: TextAlign.center,
              style: TextStyle(color: color, fontSize: 28, fontWeight: FontWeight.w900)),
        ),
        if (sub != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Center(child: Text(sub, style: const TextStyle(color: Colors.white70))),
          ),
        const SizedBox(height: 16),
        if (a != null && b != null)
          Row(children: [
            Expanded(child: BattlePlayerCard(player: a, color: AppColors.battleBlue)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text('${o.tally[a.uid]?.score ?? 0} : ${o.tally[b.uid]?.score ?? 0}',
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            ),
            Expanded(child: BattlePlayerCard(player: b, color: AppColors.battleRed)),
          ]),
        const SizedBox(height: 14),
        if (a != null && b != null && o.tally[a.uid] != null && o.tally[b.uid] != null)
          GlassCard(
            padding: const EdgeInsets.all(14),
            child: Column(children: [
              _row('Correct', '${o.tally[a.uid]!.correct}', '${o.tally[b.uid]!.correct}'),
              _row('Incorrect', '${o.tally[a.uid]!.incorrect}', '${o.tally[b.uid]!.incorrect}'),
              _row('Unanswered', '${o.tally[a.uid]!.unanswered}', '${o.tally[b.uid]!.unanswered}'),
              _row('Accuracy', '${o.tally[a.uid]!.accuracy.toStringAsFixed(0)}%',
                  '${o.tally[b.uid]!.accuracy.toStringAsFixed(0)}%'),
              _row('Total time', '${(o.tally[a.uid]!.answerMs / 1000).toStringAsFixed(1)}s',
                  '${(o.tally[b.uid]!.answerMs / 1000).toStringAsFixed(1)}s'),
            ]),
          ),
        const SizedBox(height: 18),
        ElevatedButton(
          onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
          child: const Text('Done'),
        ),
      ],
    );
  }

  Widget _row(String label, String a, String b) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Expanded(child: Text(a, style: const TextStyle(color: AppColors.battleBlue, fontWeight: FontWeight.bold))),
          Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12)),
          Expanded(
            child: Text(b,
                textAlign: TextAlign.end,
                style: const TextStyle(color: AppColors.battleRed, fontWeight: FontWeight.bold)),
          ),
        ]),
      );
}

class _RefereeBadge extends StatelessWidget {
  const _RefereeBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.battleGold.withOpacity(0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.battleGold),
      ),
      child: const Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.visibility, size: 14, color: AppColors.battleGold),
        SizedBox(width: 6),
        Text('ORGANIZER · watching',
            style: TextStyle(color: AppColors.battleGold, fontSize: 11, fontWeight: FontWeight.bold)),
      ]),
    );
  }
}
