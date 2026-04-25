import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/badge_model.dart';
import '../../../core/services/pdf_certificate_service.dart';
import '../../../core/widgets/glass_card.dart';

class BadgesScreen extends StatelessWidget {
  const BadgesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Container(decoration: const BoxDecoration(gradient: AppColors.mainGradient)),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 12, 16, 0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Expanded(
                        child: Text('🏅 Badges & Rewards',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),

                Expanded(
                  child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(uid)
                        .snapshots(),
                    builder: (context, snapshot) {
                      final data     = snapshot.data?.data() ?? {};
                      final earned   = List<String>.from(data['badges'] ?? []);
                      final coins    = (data['coins'] ?? 0) as int;
                      final name     = data['name'] ?? 'User';

                      return ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          // ── Coins card ──────────────────────────────────
                          GlassCard(
                            borderRadius: 24,
                            elevation: 6,
                            child: Row(
                              children: [
                                const Text('🪙', style: TextStyle(fontSize: 36)),
                                const SizedBox(width: 16),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '$coins',
                                      style: const TextStyle(
                                        color: Colors.amber,
                                        fontSize: 32,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const Text('Total Coins',
                                        style: TextStyle(
                                            color: Colors.white60, fontSize: 13)),
                                  ],
                                ),
                                const Spacer(),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${earned.length}/${BadgeModel.all.length}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const Text('Badges Earned',
                                        style: TextStyle(
                                            color: Colors.white60, fontSize: 13)),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // ── Certificate button ──────────────────────────
                          if (earned.isNotEmpty) ...[
                            GlassCard(
                              child: Column(
                                children: [
                                  const Row(
                                    children: [
                                      Text('📜', style: TextStyle(fontSize: 24)),
                                      SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text('Your Certificate',
                                                style: TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 15)),
                                            Text(
                                                'Download a certificate of your progress',
                                                style: TextStyle(
                                                    color: Colors.white60,
                                                    fontSize: 12)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 44,
                                    child: ElevatedButton.icon(
                                      onPressed: () async {
                                        await PdfCertificateService
                                            .generateAndShare(
                                          userName:    name,
                                          achievement: 'QuizAura Achievement',
                                          quizTitle:   'College Competitive Platform',
                                          date:        DateTime.now(),
                                          score:       earned.length /
                                              BadgeModel.all.length * 100,
                                        );
                                      },
                                      icon: const Icon(Icons.download),
                                      label: const Text('Download Certificate'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.teal,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12)),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],

                          // ── Badges grid ─────────────────────────────────
                          const Text('All Badges',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),

                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                              childAspectRatio: 0.8,
                            ),
                            itemCount: BadgeModel.all.length,
                            itemBuilder: (_, i) {
                              final badge    = BadgeModel.all[i];
                              final hasEarned = earned.contains(badge.id);
                              return _BadgeTile(
                                  badge: badge, earned: hasEarned);
                            },
                          ),

                          const SizedBox(height: 80),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BadgeTile extends StatelessWidget {
  final BadgeModel badge;
  final bool earned;

  const _BadgeTile({required this.badge, required this.earned});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: const Color(0xFF203A43),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text('${badge.emoji} ${badge.name}',
                style: const TextStyle(color: Colors.white)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(badge.description,
                    style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'How to earn: ${badge.condition}',
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 12),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close',
                    style: TextStyle(color: Colors.tealAccent)),
              ),
            ],
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: earned
              ? Colors.white.withOpacity(0.12)
              : Colors.white.withOpacity(0.04),
          border: Border.all(
            color: earned
                ? Colors.amber.withOpacity(0.5)
                : Colors.white.withOpacity(0.1),
            width: earned ? 1.5 : 1,
          ),
        ),
        child: Stack(
          children: [
            // Content
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ColorFiltered(
                    colorFilter: earned
                        ? const ColorFilter.mode(
                            Colors.transparent, BlendMode.multiply)
                        : const ColorFilter.matrix([
                            0.2126, 0.7152, 0.0722, 0, 0,
                            0.2126, 0.7152, 0.0722, 0, 0,
                            0.2126, 0.7152, 0.0722, 0, 0,
                            0,      0,      0,      1, 0,
                          ]),
                    child: Text(badge.emoji,
                        style: const TextStyle(fontSize: 32)),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    badge.name,
                    style: TextStyle(
                      color: earned ? Colors.white : Colors.white38,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Earned checkmark
            if (earned)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Colors.amber,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check,
                      color: Colors.black, size: 10),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
