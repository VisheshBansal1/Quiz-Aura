import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/fcm_service.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../ads/widgets/banner_ad_widget.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

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
                          '🔔 Notifications',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => FcmService.markAllRead(uid),
                        child: const Text(
                          'Mark all read',
                          style: TextStyle(
                            color: Colors.tealAccent,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('notifications')
                        .doc(uid)
                        .collection('items')
                        .orderBy('createdAt', descending: true)
                        .limit(50)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const _NotificationSkeleton();
                      }

                      final docs = snapshot.data?.docs ?? [];

                      if (docs.isEmpty) {
                        return const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('🔔', style: TextStyle(fontSize: 48)),
                              SizedBox(height: 12),
                              Text(
                                'No notifications yet',
                                style: TextStyle(
                                  color: Colors.white60,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: docs.length,
                        itemBuilder: (_, i) {
                          final doc = docs[i];
                          final data = doc.data();
                          final read = (data['read'] ?? false) as bool;
                          final ts = data['createdAt'] as Timestamp?;
                          final time = ts != null
                              ? DateFormat('MMM d, h:mm a').format(ts.toDate())
                              : '';

                          return GlassCard(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            backgroundColor: read
                                ? null
                                : Colors.teal.withOpacity(0.1),
                            borderColor: read
                                ? null
                                : Colors.tealAccent.withOpacity(0.3),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Type icon
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.08),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    _notifEmoji(data['type'] as String? ?? ''),
                                    style: const TextStyle(fontSize: 18),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        data['title'] ?? '',
                                        style: TextStyle(
                                          color: read
                                              ? Colors.white70
                                              : Colors.white,
                                          fontWeight: read
                                              ? FontWeight.normal
                                              : FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      if ((data['body'] ?? '').isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          data['body'],
                                          style: const TextStyle(
                                            color: Colors.white60,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 4),
                                      Text(
                                        time,
                                        style: const TextStyle(
                                          color: Colors.white38,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (!read)
                                  GestureDetector(
                                    onTap: () =>
                                        doc.reference.update({'read': true}),
                                    child: const Icon(
                                      Icons.circle,
                                      color: Colors.tealAccent,
                                      size: 10,
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: const BannerAdWidget(screenName: 'notifications'),
    );
  }

  String _notifEmoji(String type) {
    switch (type) {
      case 'battle_invite':
      case 'battle_start':
        return '⚔️';
      case 'battle_result':
        return '🏆';
      case 'tournament':
        return '🎯';
      case 'badge':
        return '🏅';
      case 'result':
        return '📊';
      default:
        return '🔔';
    }
  }
}

// ── Notification skeleton loading ─────────────────────────────────────────────
class _NotificationSkeleton extends StatefulWidget {
  const _NotificationSkeleton();
  @override
  State<_NotificationSkeleton> createState() => _NotificationSkeletonState();
}

class _NotificationSkeletonState extends State<_NotificationSkeleton>
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
        final shimmer = Color.lerp(
          Colors.white.withOpacity(0.06),
          Colors.white.withOpacity(0.15),
          _anim.value,
        )!;
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: 7,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, __) => Container(
            height: 70,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: shimmer,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.1),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        height: 12,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          color: Colors.white.withOpacity(0.12),
                        ),
                      ),
                      const SizedBox(height: 7),
                      Container(
                        height: 10,
                        width: 90,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(5),
                          color: Colors.white.withOpacity(0.07),
                        ),
                      ),
                    ],
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
