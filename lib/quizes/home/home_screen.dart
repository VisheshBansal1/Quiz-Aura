// ============================================================
// FILE: lib/quizes/home/home_screen.dart
// CHANGES:
//   1. Shimmer skeleton while Firestore loads
//   2. Staggered animation on grid items
//   3. AutomaticKeepAliveClientMixin — no reload on tab switch
//   4. Each topic card shows live active-quiz count badge
// ============================================================

import 'package:QuizSphere/quizes/home/quiz_list_screen.dart';
import 'package:QuizSphere/features/battle/widgets/battle_banner.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'topic_icon_mapper.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
        ),
      ),
      child: Column(
        children: [
          const BattleBanner(),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('topics')
                .where('isActive', isEqualTo: true)
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const _ShimmerGrid();
              }
    
              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.wifi_off, color: Colors.white38, size: 48),
                      const SizedBox(height: 12),
                      const Text(
                        'Failed to load categories',
                        style: TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () => setState(() {}),
                        child: const Text(
                          'Retry',
                          style: TextStyle(color: Colors.tealAccent),
                        ),
                      ),
                    ],
                  ),
                );
              }
    
              final docs = snapshot.data?.docs ?? [];
    
              if (docs.isEmpty) {
                return const Center(
                  child: Text(
                    'No quiz categories yet',
                    style: TextStyle(fontSize: 16, color: Colors.white70),
                  ),
                );
              }
    
              return GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                itemCount: docs.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 0.78,
                ),
                itemBuilder: (context, i) {
                  final doc = docs[i];
                  final data = doc.data();
    
                  return _AnimatedTopicCard(
                    key: ValueKey(doc.id),
                    index: i,
                    topicId: doc.id,
                    title: data['title'] ?? 'Quiz',
                    subtitle: data['subtitle'] ?? '',
                    iconName: data['icon'] ?? 'quiz',
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

// ── Animated topic card ───────────────────────────────────────────────────────
class _AnimatedTopicCard extends StatefulWidget {
  final int index;
  final String topicId;
  final String title;
  final String subtitle;
  final String iconName;

  const _AnimatedTopicCard({
    super.key,
    required this.index,
    required this.topicId,
    required this.title,
    required this.subtitle,
    required this.iconName,
  });

  @override
  State<_AnimatedTopicCard> createState() => _AnimatedTopicCardState();
}

class _AnimatedTopicCardState extends State<_AnimatedTopicCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

    Future.delayed(Duration(milliseconds: 40 * widget.index), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final icon = TopicIconMapper.fromString(widget.iconName);

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => QuizListScreen(
                topicId: widget.topicId,
                topicTitle: widget.title,
              ),
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: Colors.white.withOpacity(0.12),
              border: Border.all(color: Colors.white.withOpacity(0.25)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.18),
                  ),
                  child: Icon(icon, size: 30, color: Colors.white),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                if (widget.subtitle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    widget.subtitle,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: Colors.white70),
                  ),
                ],
                const SizedBox(height: 8),
                // ── Active quiz count badge ─────────────────────────────
                _ActiveQuizBadge(topicId: widget.topicId),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Active quiz count badge ───────────────────────────────────────────────────
// Streams the count of active quizzes for this topic from Firestore.
class _ActiveQuizBadge extends StatelessWidget {
  final String topicId;
  const _ActiveQuizBadge({required this.topicId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('quizzes')
          .where('topicId', isEqualTo: topicId)
          .where('isActive', isEqualTo: true)
          .snapshots(),
      builder: (context, snap) {
        // While loading — tiny shimmer pill
        if (snap.connectionState == ConnectionState.waiting) {
          return Container(
            height: 20,
            width: 70,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: Colors.white.withOpacity(0.1),
            ),
          );
        }

        final count = snap.data?.docs.length ?? 0;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: count > 0
                ? Colors.tealAccent.withOpacity(0.18)
                : Colors.white.withOpacity(0.08),
            border: Border.all(
              color: count > 0
                  ? Colors.tealAccent.withOpacity(0.5)
                  : Colors.white.withOpacity(0.15),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.quiz_outlined,
                size: 11,
                color: count > 0 ? Colors.tealAccent : Colors.white38,
              ),
              const SizedBox(width: 4),
              Text(
                count > 0 ? '$count active' : 'No quizzes',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: count > 0 ? Colors.tealAccent : Colors.white38,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Shimmer skeleton grid ─────────────────────────────────────────────────────
class _ShimmerGrid extends StatefulWidget {
  const _ShimmerGrid();

  @override
  State<_ShimmerGrid> createState() => _ShimmerGridState();
}

class _ShimmerGridState extends State<_ShimmerGrid>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        final shimmerColor = Color.lerp(
          Colors.white.withOpacity(0.06),
          Colors.white.withOpacity(0.14),
          _anim.value,
        )!;

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: 6,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 0.95,
          ),
          itemBuilder: (_, __) => Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: shimmerColor,
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.1),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: 80,
                  height: 13,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    color: Colors.white.withOpacity(0.1),
                  ),
                ),
                const SizedBox(height: 7),
                Container(
                  width: 50,
                  height: 10,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(5),
                    color: Colors.white.withOpacity(0.07),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  width: 70,
                  height: 20,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: Colors.white.withOpacity(0.07),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
