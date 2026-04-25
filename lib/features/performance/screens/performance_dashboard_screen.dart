import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/performance_service.dart';
import '../../../core/widgets/glass_card.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PerformanceDashboardScreen extends StatelessWidget {
  const PerformanceDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Container(
              decoration:
                  const BoxDecoration(gradient: AppColors.mainGradient)),
          SafeArea(
            child: Column(
              children: [
                // ── AppBar ───────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 12, 16, 0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios,
                            color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Expanded(
                        child: Text(
                          '📊 Performance Dashboard',
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

                // ── Body ─────────────────────────────────────────────────
                Expanded(
                  child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    stream: PerformanceService.statsStream(uid),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                              color: Colors.white),
                        );
                      }

                      final data = snapshot.data?.data() ?? {};

                      if (data.isEmpty) {
                        return const _EmptyState();
                      }

                      final byTopic =
                          Map<String, dynamic>.from(data['byTopic'] ?? {});
                      final weakTopics =
                          List<String>.from(data['weakTopics'] ?? []);
                      final history =
                          List<dynamic>.from(data['progressHistory'] ?? []);

                      // Compute overall accuracy
                      int totalQ = 0, totalC = 0;
                      for (final v in byTopic.values) {
                        totalQ += (v['total'] ?? 0) as int;
                        totalC += (v['correct'] ?? 0) as int;
                      }
                      final overallAcc =
                          totalQ == 0 ? 0.0 : totalC / totalQ * 100;

                      return ListView(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        children: [
                          // ── Overall accuracy card ────────────────────
                          GlassCard(
                            borderRadius: 24,
                            elevation: 6,
                            padding: const EdgeInsets.symmetric(
                                vertical: 24, horizontal: 20),
                            child: Column(
                              children: [
                                const Text(
                                  'Overall Accuracy',
                                  style: TextStyle(
                                      color: Colors.white70, fontSize: 13),
                                ),
                                const SizedBox(height: 16), 
                                _CircularAccuracy(value: overallAcc),
                                const SizedBox(height: 16), 
                                Text(
                                  '$totalQ questions answered  •  $totalC correct',
                                  style: const TextStyle(
                                      color: Colors.white54, fontSize: 12),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // ── Weak topics alert ────────────────────────
                          if (weakTopics.isNotEmpty) ...[
                            GlassCard(
                              borderColor: Colors.orange.withOpacity(0.4),
                              backgroundColor:
                                  Colors.orange.withOpacity(0.08),
                              padding: const EdgeInsets.all(16), 
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(Icons.warning_amber_rounded,
                                          color: Colors.orange, size: 18),
                                      SizedBox(width: 8),
                                      Text(
                                        'Weak Topics',
                                        style: TextStyle(
                                          color: Colors.orange,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'You scored below 60% in these topics. Focus here!',
                                    style: TextStyle(
                                        color: Colors.white60,
                                        fontSize: 12),
                                  ),
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: weakTopics.map((t) {
                                      final topic = byTopic[t];
                                      final label =
                                          topic?['title'] ?? t;
                                      final acc = (topic?['accuracy'] ??
                                          0.0) as double;
                                      return Container(
                                        padding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 6),
                                        decoration: BoxDecoration(
                                          color: Colors.orange
                                              .withOpacity(0.15),
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          border: Border.all(
                                              color: Colors.orange
                                                  .withOpacity(0.3)),
                                        ),
                                        child: Text(
                                          '$label (${acc.toStringAsFixed(0)}%)',
                                          style: const TextStyle(
                                              color: Colors.orange,
                                              fontSize: 12),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // ── Topic breakdown ──────────────────────────
                          if (byTopic.isNotEmpty) ...[
                            Row(
                              children: const [
                                Icon(Icons.bar_chart_rounded,
                                    color: Colors.white70, size: 18),
                                SizedBox(width: 8),
                                Text(
                                  'Topic Accuracy Breakdown',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            ...byTopic.entries.map((entry) {
                              final topic =
                                  entry.value as Map<String, dynamic>;
                              final title = topic['title'] ?? entry.key;
                              final acc =
                                  (topic['accuracy'] ?? 0.0) as double;
                              final total = (topic['total'] ?? 0) as int;
                              final correct =
                                  (topic['correct'] ?? 0) as int;

                              final barColor = acc >= 80
                                  ? Colors.greenAccent
                                  : acc >= 60
                                      ? Colors.amber
                                      : Colors.redAccent;

                              return GlassCard(
                                margin:
                                    const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            title,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          '$correct/$total',
                                          style: const TextStyle(
                                              color: Colors.white54,
                                              fontSize: 12),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '${acc.toStringAsFixed(1)}%',
                                          style: TextStyle(
                                            color: barColor,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    ClipRRect(
                                      borderRadius:
                                          BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: acc / 100,
                                        minHeight: 6,
                                        backgroundColor: Colors.white12,
                                        color: barColor,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(), 

                            const SizedBox(height: 16),
                          ],

                          // ── Recent activity ──────────────────────────
                          if (history.isNotEmpty) ...[
                            // consistent section header style
                            Row(
                              children: const [
                                Icon(Icons.history_rounded,
                                    color: Colors.white70, size: 18),
                                SizedBox(width: 8),
                                Text(
                                  'Recent Activity',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            ...history.reversed.take(10).map((h) {
                              final map = h as Map<String, dynamic>;
                              final pct =
                                  (map['percentage'] ?? 0.0) as double;
                              final topicTitle =
                                  map['topicTitle'] ?? 'Quiz';

                              // show date if available
                              final dateRaw = map['date'];
                              String dateStr = '';
                              if (dateRaw != null) {
                                try {
                                  final dt =
                                      DateTime.parse(dateRaw.toString());
                                  dateStr =
                                      '${dt.day}/${dt.month}/${dt.year}';
                                } catch (_) {}
                              }

                              final actColor = pct >= 80
                                  ? Colors.greenAccent
                                  : pct >= 60
                                      ? Colors.amber
                                      : Colors.redAccent;

                              return Container(
                                margin:
                                    const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 12), 
                                decoration: BoxDecoration(
                                  color:
                                      Colors.white.withOpacity(0.06),
                                  borderRadius:
                                      BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.quiz_outlined,
                                      color: actColor,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column( 
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            topicTitle,
                                            style: const TextStyle(
                                                color: Colors.white70,
                                                fontSize: 13),
                                          ),
                                          if (dateStr.isNotEmpty) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              dateStr,
                                              style: const TextStyle(
                                                  color: Colors.white38,
                                                  fontSize: 11),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    Text(
                                      '${pct.toStringAsFixed(0)}%',
                                      style: TextStyle(
                                        color: actColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(), 
                          ],

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

// ── Circular accuracy widget ────────────────────────────────────────────────

class _CircularAccuracy extends StatelessWidget {
  final double value;
  const _CircularAccuracy({required this.value});

  @override
  Widget build(BuildContext context) {
    final color = value >= 80
        ? Colors.greenAccent
        : value >= 60
            ? Colors.amber
            : Colors.redAccent;

    return SizedBox(
      width: 120,
      height: 120,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            value: value / 100,
            strokeWidth: 10,
            backgroundColor: Colors.white12,
            color: color,
          ),
          // SizedBox(
          //   height: 30,
          // ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: 10,),
              Text(
                '${value.toStringAsFixed(1)}%',
                style: TextStyle(
                  color: color,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              // SizedBox(height: 0,),
              const Text(
                'accuracy',
                style: TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Empty state ─────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('📊', style: TextStyle(fontSize: 60)),
          SizedBox(height: 16),
          Text(
            'No data yet',
            style: TextStyle(
              color: Colors.white60,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 40), 
            child: Text(
              'Complete some quizzes to see your performance stats.',
              style: TextStyle(color: Colors.white38, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}