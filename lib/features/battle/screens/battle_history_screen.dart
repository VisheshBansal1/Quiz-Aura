// ============================================================
// FILE: lib/features/battle/screens/battle_history_screen.dart
// Paginated battle history (15 per page, loaded on scroll).
// ============================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/glass_card.dart';
import '../models/battle_models.dart';
import '../services/battle_repository.dart';
import '../widgets/battle_widgets.dart';

class BattleHistoryScreen extends StatefulWidget {
  const BattleHistoryScreen({super.key});

  @override
  State<BattleHistoryScreen> createState() => _BattleHistoryScreenState();
}

class _BattleHistoryScreenState extends State<BattleHistoryScreen> {
  final ScrollController _scroll = ScrollController();
  final List<BattleHistoryItem> _items = [];
  DocumentSnapshot<Map<String, dynamic>>? _last;
  bool _loading = false;
  bool _hasMore = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 200) _load();
    });
    _load();
  }

  Future<void> _load({bool refresh = false}) async {
    if (_loading || (!_hasMore && !refresh)) return;
    setState(() {
      _loading = true;
      _error = null;
      if (refresh) {
        _items.clear();
        _last = null;
        _hasMore = true;
      }
    });
    try {
      final page = await BattleRepository.historyPage(after: _last);
      if (!mounted) return;
      setState(() {
        _items.addAll(page.items);
        _last = page.lastDoc;
        _hasMore = page.hasMore;
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load your battle history.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BattleScaffold(
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              const Text('Battle history',
                  style: TextStyle(
                      color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            ],
          ),
          Expanded(child: _content()),
        ],
      ),
    );
  }

  Widget _content() {
    if (_items.isEmpty && _loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_items.isEmpty && _error != null) {
      return Center(
        child: EmptyOrError(message: _error!, onRetry: () => _load(refresh: true)),
      );
    }
    if (_items.isEmpty) {
      return const Center(
        child: Text('No battles yet.', style: TextStyle(color: Colors.white60)),
      );
    }
    return RefreshIndicator(
      onRefresh: () => _load(refresh: true),
      child: ListView.builder(
        controller: _scroll,
        padding: const EdgeInsets.all(16),
        itemCount: _items.length + 1,
        itemBuilder: (context, i) {
          if (i == _items.length) {
            if (_loading) {
              return const Padding(
                padding: EdgeInsets.all(12),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              );
            }
            if (_error != null) {
              return EmptyOrError(message: _error!, onRetry: _load);
            }
            return const SizedBox.shrink();
          }
          return _tile(_items[i]);
        },
      ),
    );
  }

  Widget _tile(BattleHistoryItem h) {
    final color = h.result == 'win'
        ? AppColors.accentGreen
        : (h.result == 'draw' ? Colors.amber : AppColors.accentRed);
    final label = h.result == 'win' ? 'WIN' : (h.result == 'draw' ? 'DRAW' : 'LOSS');
    final d = h.completedAt;
    final date = d == null ? '' : '${d.day}/${d.month}/${d.year}';
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(label,
                style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('vs ${h.opponentName}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                Text(
                  '$date · ${h.mode}${h.resultStatus == 'forfeit' ? ' · forfeit' : ''}',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${h.myScore} - ${h.oppScore}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              Text(h.ratingDelta >= 0 ? '+${h.ratingDelta}' : '${h.ratingDelta}',
                  style: TextStyle(color: h.ratingDelta >= 0 ? color : AppColors.accentRed,
                      fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}
