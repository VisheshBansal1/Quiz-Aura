// ============================================================================
// GoPremiumScreen
//
// A NEW, self-contained "Go Premium" info screen — deliberately separate
// from the dormant `PremiumScreen` in this same folder, which is wired to
// the disabled `PurchaseService` / `in_app_purchase` subsystem (see that
// file's own header comments). Reactivating real purchases is a bigger job
// than "improve the ad flow," so this screen stays informational: it
// explains what Premium removes and shows the two planned price points,
// but the CTA buttons are honest about purchases not being live yet
// instead of silently doing nothing when tapped.
//
// TODO (when you restore your purchase system): wire the two plan buttons
// below to PurchaseService.instance.purchase(kMonthlyId) /
// purchase(kLifetimeId) — see lib/ads/services/purchase_service.dart and
// lib/ads/provider/premium_provider.dart for the rest of that flow.
// ============================================================================

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_bg.dart';

class GoPremiumScreen extends StatelessWidget {
  const GoPremiumScreen({super.key});

  static const List<_Benefit> _benefits = [
    _Benefit('No banner ads — every screen, clean', Icons.block_rounded),
    _Benefit(
      'No rewarded ads — instant quiz generation & results',
      Icons.flash_on_rounded,
    ),
    _Benefit("Support QuizAura's development", Icons.favorite_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        title: const Text('Go Premium'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: const GradientBg(),
      ),
      body: Stack(
        children: [
          const GradientBg(),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 12),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.amberAccent.withOpacity(0.15),
                      ),
                      child: const Icon(
                        Icons.workspace_premium_rounded,
                        size: 56,
                        color: Colors.amberAccent,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'QuizAura Premium',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'One-time or monthly — remove ads for good.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white.withOpacity(0.6)),
                  ),
                  const SizedBox(height: 28),
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final b in _benefits)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(b.icon, color: Colors.tealAccent, size: 20),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    b.text,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _PlanCard(
                          title: 'Monthly',
                          price: '₹28',
                          period: '/ month',
                          onTap: () => _showComingSoon(context),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _PlanCard(
                          title: 'Lifetime',
                          price: '₹999',
                          period: 'one-time',
                          highlighted: true,
                          onTap: () => _showComingSoon(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Prices shown are planned pricing and may change at launch.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
            "Premium purchases aren't available yet — check back soon!",
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }
}

class _Benefit {
  final String text;
  final IconData icon;
  const _Benefit(this.text, this.icon);
}

class _PlanCard extends StatelessWidget {
  final String title;
  final String price;
  final String period;
  final bool highlighted;
  final VoidCallback onTap;

  const _PlanCard({
    required this.title,
    required this.price,
    required this.period,
    required this.onTap,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderColor: highlighted ? Colors.amberAccent.withOpacity(0.6) : null,
      child: Column(
        children: [
          if (highlighted)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.amberAccent.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'BEST VALUE',
                style: TextStyle(
                  color: Colors.amberAccent,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            price,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            period,
            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 38,
            child: OutlinedButton(
              onPressed: onTap,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.white.withOpacity(0.3)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Coming Soon',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
