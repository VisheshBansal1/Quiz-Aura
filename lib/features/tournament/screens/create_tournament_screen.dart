// ============================================================
// FILE: lib/quizes/admin/screens/create_tournament_screen.dart
// IMPROVEMENTS: Per-round scheduling, tournament-specific quiz creation,
//               qualifier count UI, full validation, real-world UX
// ============================================================

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/glass_card.dart';
import '../services/tournament_service.dart';
import 'tournament_round_quiz_creator.dart';

class CreateTournamentScreen extends StatefulWidget {
  const CreateTournamentScreen({super.key});
  @override
  State<CreateTournamentScreen> createState() => _CreateTournamentScreenState();
}

class _CreateTournamentScreenState extends State<CreateTournamentScreen> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _prizeCtrl = TextEditingController();
  final _maxPlayersCtrl = TextEditingController(text: '100');
  final _entryCoinsCtrl = TextEditingController(text: '0');

  int _totalRounds = 3;
  DateTime _startAt = DateTime.now().add(const Duration(days: 1));
  bool _loading = false;
  String? _createdId;

  final Map<int, String> _roundQuizIds = {};
  final Map<int, String> _roundQuizTitles = {};
  final Map<int, int> _roundQualifiers = {};
  final Map<int, DateTime> _roundStartTimes = {};
  final Map<int, DateTime> _roundEndTimes = {};

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _prizeCtrl.dispose();
    _maxPlayersCtrl.dispose();
    _entryCoinsCtrl.dispose();
    super.dispose();
  }

  String? _validate() {
    if (_titleCtrl.text.trim().isEmpty) return 'Enter tournament title';
    for (int r = 1; r <= _totalRounds; r++) {
      final start = _roundStartTimes[r];
      final end = _roundEndTimes[r];
      if (start == null) return 'Set start time for Round $r';
      if (end == null) return 'Set end time for Round $r';
      if (!end.isAfter(start)) return 'Round $r: end must be after start';
      if (r > 1) {
        final prevEnd = _roundEndTimes[r - 1];
        if (prevEnd != null && start.isBefore(prevEnd)) {
          return 'Round $r must start after Round ${r - 1} ends';
        }
      }
    }
    return null;
  }

  Future<void> _create() async {
    final error = _validate();
    if (error != null) {
      _snack(error);
      return;
    }
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final maxPlayers = int.tryParse(_maxPlayersCtrl.text.trim()) ?? 100;
      final id = await TournamentService.createTournament(
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        startAt: _startAt,
        maxParticipants: maxPlayers,
        totalRounds: _totalRounds,
        prizeDescription: _prizeCtrl.text.trim(),
        entryCoins: int.tryParse(_entryCoinsCtrl.text.trim()) ?? 0,
      );
      for (int r = 1; r <= _totalRounds; r++) {
        final quizId = _roundQuizIds[r] ?? '';
        if (quizId.isNotEmpty) {
          await TournamentService.addRound(
            tournamentId: id,
            roundNumber: r,
            quizId: quizId,
            startAt: _roundStartTimes[r]!,
            endAt: _roundEndTimes[r]!,
            qualifyCount: _roundQualifiers[r] ?? maxPlayers ~/ 2,
          );
        }
      }

      // ── Auto-set tournament endAt = last round's endAt + 30 min ──────────
      // This lets the list & detail screens detect the tournament as "Finished"
      // automatically once all rounds have closed, without requiring an admin
      // to manually press "End Tournament Now".
      DateTime? lastRoundEnd;
      for (int r = 1; r <= _totalRounds; r++) {
        final end = _roundEndTimes[r];
        if (end != null) {
          if (lastRoundEnd == null || end.isAfter(lastRoundEnd)) {
            lastRoundEnd = end;
          }
        }
      }
      if (lastRoundEnd != null) {
        await TournamentService.updateEndAt(
          tournamentId: id,
          endAt: lastRoundEnd.add(const Duration(minutes: 30)),
        );
      }

      if (!mounted) return;
      setState(() {
        _createdId = id;
        _loading = false;
      });
      _snack('Tournament created! 🏆', success: true);
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
      setState(() => _loading = false);
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

  Future<void> _pickTournamentDate() async {
    final p = await showDatePicker(
      context: context,
      initialDate: _startAt,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (c, ch) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(primary: Colors.teal),
        ),
        child: ch!,
      ),
    );
    if (p == null || !mounted) return;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startAt),
      builder: (c, ch) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(primary: Colors.teal),
        ),
        child: ch!,
      ),
    );
    if (!mounted) return;
    setState(() {
      _startAt = DateTime(
        p.year,
        p.month,
        p.day,
        t?.hour ?? _startAt.hour,
        t?.minute ?? _startAt.minute,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Container(
            decoration:
                const BoxDecoration(gradient: AppColors.mainGradient),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 12, 16, 0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back_ios,
                          color: Colors.white,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Expanded(
                        child: Text(
                          'Create Tournament',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('Tournament Details'),
                        const SizedBox(height: 8),
                        _field(
                          _titleCtrl,
                          'Title *',
                          'e.g. National DSA Championship',
                        ),
                        const SizedBox(height: 10),
                        _field(
                          _descCtrl,
                          'Description',
                          'What is this tournament about?',
                          maxLines: 2,
                        ),
                        const SizedBox(height: 10),
                        _field(
                          _prizeCtrl,
                          'Prize / Reward',
                          'e.g. Certificate, Gift Card',
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _field(
                                _maxPlayersCtrl,
                                'Max Players',
                                '100',
                                kb: TextInputType.number,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _field(
                                _entryCoinsCtrl,
                                'Entry Coins',
                                '0',
                                kb: TextInputType.number,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _label('Registration Deadline'),
                        const SizedBox(height: 8),
                        GlassCard(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.teal.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.how_to_reg,
                                  color: Colors.tealAccent,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Players register until tournament starts',
                                      style: TextStyle(
                                        color: Colors.white54,
                                        fontSize: 11,
                                      ),
                                    ),
                                    Text(
                                      DateFormat(
                                        'MMM dd, yyyy • h:mm a',
                                      ).format(_startAt),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              TextButton(
                                onPressed: _pickTournamentDate,
                                child: const Text(
                                  'Change',
                                  style:
                                      TextStyle(color: Colors.tealAccent),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            _label('Round Schedule'),
                            Row(
                              children: [1, 2, 3, 4, 5].map((n) {
                                final sel = n == _totalRounds;
                                return GestureDetector(
                                  onTap: () =>
                                      setState(() => _totalRounds = n),
                                  child: Container(
                                    width: 36,
                                    height: 36,
                                    margin:
                                        const EdgeInsets.only(left: 6),
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: sel
                                          ? Colors.teal
                                          : Colors.white.withOpacity(0.1),
                                      borderRadius:
                                          BorderRadius.circular(8),
                                      border: Border.all(
                                        color: sel
                                            ? Colors.teal
                                            : Colors.white24,
                                      ),
                                    ),
                                    child: Text(
                                      '$n',
                                      style: TextStyle(
                                        color: sel
                                            ? Colors.white
                                            : Colors.white70,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Set schedule and quiz for each round.',
                          style: TextStyle(
                              color: Colors.white38, fontSize: 11),
                        ),
                        const SizedBox(height: 12),
                        ...List.generate(_totalRounds, (i) {
                          final r = i + 1;
                          return _RoundConfigCard(
                            key: ValueKey('r$r'),
                            round: r,
                            totalRounds: _totalRounds,
                            tournamentId: _createdId ?? 'draft',
                            selectedQuizId: _roundQuizIds[r],
                            selectedQuizTitle: _roundQuizTitles[r],
                            startTime: _roundStartTimes[r],
                            endTime: _roundEndTimes[r],
                            qualifiers: _roundQualifiers[r] ??
                                ((int.tryParse(_maxPlayersCtrl.text) ??
                                        100) ~/
                                    2),
                            onQuizSelected: (id, title) => setState(() {
                              _roundQuizIds[r] = id;
                              _roundQuizTitles[r] = title;
                            }),
                            onStartTimeChanged: (dt) => setState(
                                () => _roundStartTimes[r] = dt),
                            onEndTimeChanged: (dt) =>
                                setState(() => _roundEndTimes[r] = dt),
                            onQualifiersChanged: (n) =>
                                setState(() => _roundQualifiers[r] = n),
                          );
                        }),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton.icon(
                            onPressed: (_loading || _createdId != null)
                                ? null
                                : _create,
                            icon: _loading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.emoji_events),
                            label: Text(
                              _createdId != null
                                  ? '✅ Tournament Created!'
                                  : 'Create Tournament',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _createdId != null
                                  ? Colors.green
                                  : Colors.teal,
                              foregroundColor: Colors.white,
                              // FIX: prevent theme infinite-width minimumSize
                              minimumSize: Size.zero,
                              tapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                        if (_createdId != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: Colors.green.withOpacity(0.4)),
                            ),
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  color: Colors.greenAccent,
                                ),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Tournament is live! Players can now register.',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_loading)
            Container(
              color: Colors.black45,
              child: const Center(
                child:
                    CircularProgressIndicator(color: Colors.tealAccent),
              ),
            ),
        ],
      ),
    );
  }

  Widget _label(String t) => Text(
        t,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.bold,
        ),
      );

  Widget _field(
    TextEditingController ctrl,
    String label,
    String hint, {
    int maxLines = 1,
    TextInputType kb = TextInputType.text,
  }) {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: ctrl,
            maxLines: maxLines,
            keyboardType: kb,
            style: const TextStyle(color: Colors.white, fontSize: 15),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: Colors.white30),
              border: InputBorder.none,
              isDense: true,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ROUND CONFIG CARD — expandable per-round configuration
// ─────────────────────────────────────────────────────────────────────────────
class _RoundConfigCard extends StatefulWidget {
  final int round, totalRounds;
  final String tournamentId;
  final String? selectedQuizId, selectedQuizTitle;
  final DateTime? startTime, endTime;
  final int qualifiers;
  final void Function(String, String) onQuizSelected;
  final void Function(DateTime) onStartTimeChanged, onEndTimeChanged;
  final void Function(int) onQualifiersChanged;

  const _RoundConfigCard({
    super.key,
    required this.round,
    required this.totalRounds,
    required this.tournamentId,
    required this.selectedQuizId,
    required this.selectedQuizTitle,
    required this.startTime,
    required this.endTime,
    required this.qualifiers,
    required this.onQuizSelected,
    required this.onStartTimeChanged,
    required this.onEndTimeChanged,
    required this.onQualifiersChanged,
  });

  @override
  State<_RoundConfigCard> createState() => _RoundConfigCardState();
}

class _RoundConfigCardState extends State<_RoundConfigCard> {
  bool _expanded = false;

  bool get _isComplete =>
      widget.startTime != null &&
      widget.endTime != null &&
      widget.selectedQuizId != null;

  @override
  void initState() {
    super.initState();
    _expanded = widget.round == 1;
  }

  Future<DateTime?> _pickDT(BuildContext ctx, DateTime initial) async {
    final d = await showDatePicker(
      context: ctx,
      initialDate: initial,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (c, ch) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(primary: Colors.teal),
        ),
        child: ch!,
      ),
    );
    if (d == null || !ctx.mounted) return null;
    final t = await showTimePicker(
      context: ctx,
      initialTime: TimeOfDay.fromDateTime(initial),
      builder: (c, ch) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(primary: Colors.teal),
        ),
        child: ch!,
      ),
    );
    if (!ctx.mounted) return null;
    return DateTime(
      d.year,
      d.month,
      d.day,
      t?.hour ?? initial.hour,
      t?.minute ?? initial.minute,
    );
  }

  void _openQuizPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF203A43),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _QuizPickerSheet(
        round: widget.round,
        tournamentId: widget.tournamentId,
        onQuizSelected: widget.onQuizSelected,
        onCreateNew: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TournamentRoundQuizCreator(
                tournamentId: widget.tournamentId,
                roundNumber: widget.round,
                onQuizCreated: widget.onQuizSelected,
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('MMM d • h:mm a');
    final roundLabel = widget.round == 1
        ? 'Qualification'
        : widget.round == widget.totalRounds
            ? 'Grand Final'
            : 'Semi-Final';

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.zero,
      borderColor: _isComplete
          ? Colors.teal.withOpacity(0.45)
          : Colors.white.withOpacity(0.12),
      child: Column(
        children: [
          // ── Header ────────────────────────────────────────────────
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isComplete
                          ? Colors.teal.withOpacity(0.25)
                          : Colors.white.withOpacity(0.06),
                      border: Border.all(
                        color: _isComplete
                            ? Colors.teal.withOpacity(0.6)
                            : Colors.white24,
                      ),
                    ),
                    child: Center(
                      child: _isComplete
                          ? const Icon(
                              Icons.check,
                              color: Colors.tealAccent,
                              size: 18,
                            )
                          : Text(
                              'R${widget.round}',
                              style: const TextStyle(
                                color: Colors.white60,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
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
                            Text(
                              'Round ${widget.round}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.amber.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.amber.withOpacity(0.3),
                                ),
                              ),
                              child: Text(
                                roundLabel,
                                style: const TextStyle(
                                  color: Colors.amber,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        if (widget.startTime != null &&
                            widget.endTime != null)
                          Text(
                            '${fmt.format(widget.startTime!)} → ${fmt.format(widget.endTime!)}',
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 11,
                            ),
                          )
                        else
                          const Text(
                            '⚠ Schedule not set',
                            style: TextStyle(
                              color: Colors.orange,
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.white54,
                  ),
                ],
              ),
            ),
          ),

          if (_expanded) ...[
            Divider(
                height: 1,
                color: Colors.white.withOpacity(0.08)),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Schedule ───────────────────────────────────────
                  const Text(
                    'SCHEDULE',
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 10,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _TimeTile(
                          label: 'Opens',
                          icon: Icons.lock_open_rounded,
                          value: widget.startTime,
                          color: Colors.green,
                          onTap: () async {
                            final dt = await _pickDT(
                              context,
                              widget.startTime ??
                                  DateTime.now().add(
                                    Duration(days: widget.round),
                                  ),
                            );
                            if (dt != null)
                              widget.onStartTimeChanged(dt);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _TimeTile(
                          label: 'Closes',
                          icon: Icons.lock_outline,
                          value: widget.endTime,
                          color: Colors.redAccent,
                          onTap: () async {
                            final dt = await _pickDT(
                              context,
                              widget.endTime ??
                                  (widget.startTime?.add(
                                        const Duration(hours: 2),
                                      ) ??
                                      DateTime.now().add(
                                        Duration(
                                          days: widget.round,
                                          hours: 2,
                                        ),
                                      )),
                            );
                            if (dt != null) widget.onEndTimeChanged(dt);
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // ── Qualifiers ─────────────────────────────────────
                  const Text(
                    'TOP QUALIFIERS',
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 10,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [2, 5, 10, 20, 50, 100].map((n) {
                      final sel = n == widget.qualifiers;
                      return GestureDetector(
                        onTap: () => widget.onQualifiersChanged(n),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: sel
                                ? Colors.amber.withOpacity(0.2)
                                : Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: sel
                                  ? Colors.amber.withOpacity(0.5)
                                  : Colors.white24,
                            ),
                          ),
                          child: Text(
                            'Top $n',
                            style: TextStyle(
                              color: sel
                                  ? Colors.amber
                                  : Colors.white54,
                              fontWeight: sel
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 14),

                  // ── Round Quiz ─────────────────────────────────────
                  const Text(
                    'ROUND QUIZ',
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 10,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (widget.selectedQuizId != null) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.teal.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.teal.withOpacity(0.35),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.quiz,
                            color: Colors.tealAccent,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              widget.selectedQuizTitle ?? 'Quiz assigned',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          TextButton(
                            onPressed: _openQuizPicker,
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8),
                            ),
                            child: const Text(
                              'Change',
                              style: TextStyle(
                                color: Colors.tealAccent,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _openQuizPicker,
                        icon: const Icon(Icons.add_circle_outline,
                            size: 16),
                        label: const Text('Assign Quiz to this Round'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.tealAccent,
                          side: BorderSide(
                              color: Colors.teal.withOpacity(0.4)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding:
                              const EdgeInsets.symmetric(vertical: 10),
                          // FIX: prevent theme minimumSize crash
                          minimumSize: Size.zero,
                          tapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TimeTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final DateTime? value;
  final Color color;
  final VoidCallback onTap;

  const _TimeTile({
    required this.label,
    required this.icon,
    required this.value,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('MMM d\nh:mm a');
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: value != null
              ? color.withOpacity(0.1)
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: value != null
                ? color.withOpacity(0.4)
                : Colors.white.withOpacity(0.12),
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 16,
                color: value != null ? color : Colors.white38),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: value != null ? color : Colors.white38,
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value != null ? fmt.format(value!) : 'Tap to set',
                    style: TextStyle(
                      color:
                          value != null ? Colors.white : Colors.white38,
                      fontWeight: value != null
                          ? FontWeight.bold
                          : FontWeight.normal,
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// QUIZ PICKER BOTTOM SHEET
// FIX: "or pick existing" now only shows tournament quizzes
//      (isTournamentQuiz == true), never regular app quizzes.
// ─────────────────────────────────────────────────────────────────────────────
class _QuizPickerSheet extends StatelessWidget {
  final int round;
  final String tournamentId;
  final void Function(String, String) onQuizSelected;
  final VoidCallback onCreateNew;

  const _QuizPickerSheet({
    required this.round,
    required this.tournamentId,
    required this.onQuizSelected,
    required this.onCreateNew,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      expand: false,
      builder: (_, ctrl) => Column(
        children: [
          // ── Handle ──────────────────────────────────────────────────
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // ── Title ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Round $round — Assign Quiz',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Create new button ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onCreateNew,
                icon: const Icon(Icons.add_circle_outline),
                label: const Text(
                  'Create New Quiz for this Round',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  // FIX: prevent theme minimumSize crash
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Divider ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                    child: Divider(
                        color: Colors.white.withOpacity(0.15))),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'or pick existing tournament quiz',
                    style:
                        TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ),
                Expanded(
                    child: Divider(
                        color: Colors.white.withOpacity(0.15))),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // ── Existing tournament quizzes list ─────────────────────────
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('quizzes')
                  // FIX: filter to tournament-only quizzes —
                  // regular quizzes (isTournamentQuiz == false or absent)
                  // are never shown here.
                  .where('isTournamentQuiz', isEqualTo: true)
                  .where('isActive', isEqualTo: true)
                  .orderBy('createdAt', descending: true)
                  .limit(50)
                  .snapshots(),
              builder: (ctx, snap) {
                if (!snap.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(
                        color: Colors.white),
                  );
                }

                final docs = snap.data!.docs;

                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.emoji_events_outlined,
                            color: Colors.white24, size: 40),
                        const SizedBox(height: 12),
                        const Text(
                          'No tournament quizzes yet.',
                          style: TextStyle(
                              color: Colors.white54, fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Use "Create New" above to make one.',
                          style: TextStyle(
                              color: Colors.white38, fontSize: 12),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  controller: ctrl,
                  padding:
                      const EdgeInsets.fromLTRB(16, 4, 16, 20),
                  itemCount: docs.length,
                  itemBuilder: (_, i) {
                    final d = docs[i].data();
                    final id = docs[i].id;
                    final title =
                        (d['title'] as String?) ?? 'Untitled Quiz';
                    final roundNum = d['roundNumber'] as int?;
                    final qCount = d['questionCount'] as int?;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              Colors.teal.withOpacity(0.3),
                          child: const Icon(
                            Icons.emoji_events_outlined,
                            color: Colors.tealAccent,
                            size: 16,
                          ),
                        ),
                        title: Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        // FIX: show round number + question count
                        // as subtitle instead of the removed isTQ badge.
                        subtitle: Text(
                          [
                            if (roundNum != null)
                              'Round $roundNum quiz',
                            if (qCount != null) '$qCount questions',
                          ].join(' • '),
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                          ),
                        ),
                        trailing: const Icon(
                          Icons.arrow_forward_ios,
                          size: 12,
                          color: Colors.white38,
                        ),
                        onTap: () {
                          onQuizSelected(id, title);
                          Navigator.pop(context);
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}