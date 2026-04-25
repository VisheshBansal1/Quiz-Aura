// ============================================================
// FILE: lib/screens/premium_screen.dart
//
// Shows two plans:
//   • remove_ads_monthly  → ₹28/month (or dynamic price from Play)
//   • remove_ads_lifetime → ₹999 once  (or dynamic price from Play)
//
// Dynamic pricing:
//   ProductDetails.price is fetched from Play Billing and shown
//   on the Buy buttons, falling back to the hardcoded prices if
//   products are still loading.
//
// Error handling:
//   • Network errors during product fetch are shown inline.
//   • Purchase errors surface as SnackBar messages.
//   • Pending purchases show a full-screen loading indicator.
// ============================================================

import 'package:QuizSphere/ads/provider/premium_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../services/purchase_service.dart';

class PremiumScreen extends ConsumerWidget {
  const PremiumScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(premiumProvider);
    final notifier = ref.read(premiumProvider.notifier);

    // Show purchase errors as SnackBars reactively.
    ref.listen<PremiumState>(premiumProvider, (prev, next) {
      if (next.errorMessage != null &&
          next.errorMessage != prev?.errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: Colors.redAccent,
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () => notifier.clearError(),
            ),
          ),
        );
      }
    });

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          _GradientBg(),
          SafeArea(
            child: CustomScrollView(
              slivers: [
                _buildAppBar(context, state),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _buildHeader(),
                      const SizedBox(height: 28),
                      _buildBenefits(),
                      const SizedBox(height: 32),
                      _buildMonthlyCard(context, state, notifier),
                      const SizedBox(height: 16),
                      _buildLifetimeCard(context, state, notifier),
                      const SizedBox(height: 24),
                      _buildRestoreButton(context, notifier, state),
                      const SizedBox(height: 32),
                    ]),
                  ),
                ),
              ],
            ),
          ),
          // Full-screen loading overlay for pending purchase.
          if (state.isLoading)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.tealAccent),
                    SizedBox(height: 16),
                    Text(
                      'Processing purchase…',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── App bar ───────────────────────────────────────────────────────────────

  SliverAppBar _buildAppBar(BuildContext context, PremiumState state) {
    return SliverAppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      pinned: false,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text(
        'Go Premium',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 22,
        ),
      ),
      centerTitle: true,
      actions: [
        if (state.isPremium)
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.amber),
            ),
            child: const Row(
              children: [
                Icon(Icons.star, color: Colors.amber, size: 16),
                SizedBox(width: 4),
                Text('Active', style: TextStyle(color: Colors.amber, fontSize: 12)),
              ],
            ),
          ),
      ],
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFF00BFA5), Color(0xFF1E88E5)],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.tealAccent.withOpacity(0.3),
                blurRadius: 24,
                spreadRadius: 4,
              ),
            ],
          ),
          child: const Icon(Icons.workspace_premium, color: Colors.white, size: 52),
        ),
        const SizedBox(height: 20),
        const Text(
          'Upgrade to Premium',
          style: TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        const Text(
          'Remove all ads and enjoy an uninterrupted\nlearning experience.',
          style: TextStyle(color: Colors.white60, fontSize: 15, height: 1.5),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  // ── Benefits list ─────────────────────────────────────────────────────────

  Widget _buildBenefits() {
    final benefits = [
      (Icons.block, 'No Banner Ads', 'Clean, distraction-free interface'),
      (Icons.video_label_rounded, 'No Rewarded Ads', 'Skip video ads before generating questions'),
      (Icons.bolt, 'Better Experience', 'Faster workflow, zero interruptions'),
      (Icons.devices, 'All Devices', 'Linked to your Google Play account'),
    ];

    return _glassCard(
      child: Column(
        children: benefits.map((b) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.tealAccent.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(b.$1, color: Colors.tealAccent, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(b.$2,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14)),
                      Text(b.$3,
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 12)),
                    ],
                  ),
                ),
                const Icon(Icons.check_circle, color: Colors.tealAccent, size: 18),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Monthly plan card ─────────────────────────────────────────────────────

  Widget _buildMonthlyCard(
      BuildContext context, PremiumState state, PremiumNotifier notifier) {
    final product = PurchaseService.instance.productFor(kMonthlyId);
    final price   = product?.price ?? '₹28';

    return _glassCard(
      highlight: !state.isLifetime && !state.isPremium,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.calendar_month, color: Colors.tealAccent, size: 22),
              const SizedBox(width: 10),
              const Text(
                'Monthly Plan',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.teal.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$price / month',
                  style: const TextStyle(
                      color: Colors.tealAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Remove all ads for 30 days. Auto-renews monthly.',
            style: TextStyle(color: Colors.white60, fontSize: 13),
          ),
          const SizedBox(height: 16),
          _buyButton(
            context: context,
            label: state.isPremium && !state.isLifetime
                ? 'Active ✓'
                : 'Subscribe — $price/mo',
            isActive: state.isPremium && !state.isLifetime,
            isLoading: state.isLoading,
            onPressed: state.isLoading || (state.isPremium && !state.isLifetime)
                ? null
                : notifier.purchaseMonthly,
            color: Colors.teal,
          ),
        ],
      ),
    );
  }

  // ── Lifetime plan card ────────────────────────────────────────────────────

  Widget _buildLifetimeCard(
      BuildContext context, PremiumState state, PremiumNotifier notifier) {
    final product = PurchaseService.instance.productFor(kLifetimeId);
    final price   = product?.price ?? '₹999';

    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.all_inclusive, color: Colors.amberAccent, size: 22),
              const SizedBox(width: 10),
              const Text(
                'Lifetime Plan',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.withOpacity(0.5)),
                ),
                child: Text(
                  price,
                  style: const TextStyle(
                      color: Colors.amberAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('Best Value 🔥',
                style: TextStyle(color: Colors.amberAccent, fontSize: 11)),
          ),
          const SizedBox(height: 8),
          const Text(
            'Pay once, enjoy ad-free forever. No recurring charges.',
            style: TextStyle(color: Colors.white60, fontSize: 13),
          ),
          const SizedBox(height: 16),
          _buyButton(
            context: context,
            label: state.isLifetime ? 'Purchased ✓' : 'Buy Lifetime — $price',
            isActive: state.isLifetime,
            isLoading: state.isLoading,
            onPressed: state.isLoading || state.isLifetime
                ? null
                : notifier.purchaseLifetime,
            color: Colors.amber,
          ),
        ],
      ),
    );
  }

  // ── Restore button ────────────────────────────────────────────────────────

  Widget _buildRestoreButton(
      BuildContext context, PremiumNotifier notifier, PremiumState state) {
    return Column(
      children: [
        TextButton(
          onPressed: state.isLoading ? null : notifier.restorePurchases,
          child: const Text(
            'Restore Purchases',
            style: TextStyle(color: Colors.white54, fontSize: 14),
          ),
        ),
        const Text(
          'Subscriptions are managed by Google Play.\n'
          'Cancellations take effect at the end of the billing period.',
          style: TextStyle(color: Colors.white30, fontSize: 11, height: 1.5),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  // ── Shared UI helpers ─────────────────────────────────────────────────────

  Widget _glassCard({required Widget child, bool highlight = false}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withOpacity(highlight ? 0.13 : 0.08),
        border: Border.all(
          color: highlight
              ? Colors.tealAccent.withOpacity(0.5)
              : Colors.white.withOpacity(0.15),
          width: highlight ? 1.5 : 1,
        ),
        boxShadow: highlight
            ? [
                BoxShadow(
                  color: Colors.tealAccent.withOpacity(0.08),
                  blurRadius: 16,
                  spreadRadius: 2,
                )
              ]
            : null,
      ),
      child: child,
    );
  }

  Widget _buyButton({
    required BuildContext context,
    required String label,
    required bool isActive,
    required bool isLoading,
    required VoidCallback? onPressed,
    required Color color,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isActive ? Colors.white12 : color,
          foregroundColor: isActive ? Colors.white54 : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: isActive ? 0 : 4,
        ),
        child: isLoading && !isActive
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2))
            : Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}

// ── Gradient background (matches app theme) ───────────────────────────────────

class _GradientBg extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
          ),
        ),
      );
}