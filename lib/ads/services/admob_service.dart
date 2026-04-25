// ============================================================
// FILE: lib/services/admob_service.dart
//
// Responsibilities:
//   • Initialize the Mobile Ads SDK once on app start.
//   • Expose test ad-unit IDs (swap for real IDs before release).
//   • Provide a static helper to load & show a RewardedAd on demand.
//
// Ad control logic:
//   Every call site MUST check PremiumProvider.isPremium first.
//   AdmobService itself is agnostic to premium status so it stays
//   focused on ad mechanics and is easy to unit-test independently.
// ============================================================

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdmobService {
  AdmobService._(); // pure-static utility class

  // ──────────────────────────────────────────────────────────────────────────
  // Test Ad Unit IDs
  // Replace these with your real AdMob IDs from the AdMob console before
  // publishing. Real IDs look like "ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX".
  // Using test IDs prevents invalid traffic on your account during development.
  // ──────────────────────────────────────────────────────────────────────────

  /// Banner ad unit — shown on home screen and other list screens.
  static const String bannerAdUnitId = kDebugMode
      ? 'ca-app-pub-3940256099942544/6300978111' // Google test banner
      : 'ca-app-pub-5737850023326024/8945974038'; // ← YOUR real banner ID

  /// Rewarded ad unit — gated before AI generation & answer review.
  static const String rewardedAdUnitId = kDebugMode
      ? 'ca-app-pub-3940256099942544/5224354917' // Google test rewarded
      : 'ca-app-pub-5737850023326024/2834830324'; // ← YOUR real rewarded ID

  // ──────────────────────────────────────────────────────────────────────────
  // Initialisation
  // ──────────────────────────────────────────────────────────────────────────

  static bool _initialised = false;

  /// Call once from main() **after** WidgetsFlutterBinding.ensureInitialized().
  /// Safe to call multiple times — subsequent calls are no-ops.
  /// Automatically skipped on web (google_mobile_ads is mobile-only).
  static Future<void> initialize() async {
    if (_initialised) return;
    if (kIsWeb) {
      debugPrint('[AdMob] Skipped on web');
      return;
    }
    try {
      await MobileAds.instance.initialize();
      _initialised = true;
      debugPrint('[AdMob] SDK initialised');
    } catch (e) {
      debugPrint('[AdMob] SDK init failed (non-fatal): $e');
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Rewarded Ad — load & show
  // ──────────────────────────────────────────────────────────────────────────

  /// Loads a new RewardedAd and shows it immediately once ready.
  ///
  /// [onRewarded]  — called when the user earns the reward (i.e. watched it).
  ///                 Continue the user action inside this callback.
  /// [onAdDismissed] — called after the ad closes regardless of reward status.
  ///                   Use for cleanup / loading indicators.
  /// [onFailed]    — called when the ad fails to load or show.
  ///                 Fall through to the intended action so UX is not blocked.
  ///
  /// IMPORTANT: Always call this ONLY after verifying !isPremium.
  static void loadAndShowRewardedAd({
    required VoidCallback onRewarded,
    VoidCallback? onAdDismissed,
    VoidCallback? onFailed,
  }) {
    RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint('[AdMob] RewardedAd loaded');

          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose(); // ← always dispose to free memory
              debugPrint('[AdMob] RewardedAd dismissed');
              onAdDismissed?.call();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              debugPrint('[AdMob] RewardedAd failed to show: $error');
              onFailed?.call();
            },
          );

          ad.show(
            onUserEarnedReward: (_, reward) {
              debugPrint(
                '[AdMob] Reward earned: ${reward.amount} ${reward.type}',
              );
              onRewarded();
            },
          );
        },
        onAdFailedToLoad: (error) {
          debugPrint('[AdMob] RewardedAd failed to load: $error');
          // Do NOT block the user — fall through gracefully.
          onFailed?.call();
        },
      ),
    );
  }
}
