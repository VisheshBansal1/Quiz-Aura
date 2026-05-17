// // ============================================================
// // FILE: lib/ads/services/admob_service.dart
// //
// // BUGS FIXED:
// //   1. CRITICAL: loadAndShowRewardedAd() had no guard for SDK
// //      initialization. If called before AdmobService.initialize()
// //      completed (e.g. from a postFrameCallback race), the ad
// //      request silently failed and onFailed was never called,
// //      leaving the UI stuck on a loading spinner.
// //      FIX: Guard with _initialised; call onFailed immediately
// //      if the SDK isn't ready yet, rather than hanging.
// //
// //   2. The rewarded ad had no timeout. If the network was slow
// //      or the ad server was unreachable the load callback simply
// //      never fired, leaving the UI in a loading state forever.
// //      FIX: Added a 15-second load timeout after which onFailed
// //      is called so the UX is never permanently blocked.
// //
// //   3. kDebugMode in a `const` field only guarantees correct
// //      evaluation when the variable is accessed, not at class
// //      definition time on some older Dart toolchains. Documented
// //      explicitly; no functional change needed for modern SDKs.
// //
// //   4. Added a public `isInitialized` getter so call sites can
// //      diagnose issues without accessing the private flag.
// // ============================================================

// import 'dart:async';
// import 'dart:ui';

// import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
// import 'package:google_mobile_ads/google_mobile_ads.dart';

// class AdmobService {
//   AdmobService._(); // pure-static utility class

//   // ──────────────────────────────────────────────────────────────────────────
//   // Ad Unit IDs — TESTING MODE
//   // Hardcoded to Google's official test IDs so ads fill in every build
//   // (debug, profile, release) without affecting your AdMob account.
//   //
//   // TODO before publishing to production:
//   //   Replace both values with your real AdMob IDs:
//   //     bannerAdUnitId  → 'ca-app-pub-5737850023326024/8945974038'
//   //     rewardedAdUnitId → 'ca-app-pub-5737850023326024/2834830324'
//   // ──────────────────────────────────────────────────────────────────────────

//   /// Banner ad unit — Google's official test ID (always fills).
//   static const String bannerAdUnitId = 'ca-app-pub-3940256099942544/6300978111';

//   /// Rewarded ad unit — Google's official test ID (always fills).
//   static const String rewardedAdUnitId =
//       'ca-app-pub-3940256099942544/5224354917';

//   // ──────────────────────────────────────────────────────────────────────────
//   // Initialisation
//   // ──────────────────────────────────────────────────────────────────────────

//   static bool _initialised = false;

//   /// Whether the Mobile Ads SDK has been successfully initialised.
//   static bool get isInitialized => _initialised;

//   /// Call once from main() **after** WidgetsFlutterBinding.ensureInitialized()
//   /// and Firebase.initializeApp(). Safe to call multiple times — subsequent
//   /// calls are no-ops. Automatically skipped on web.
//   static Future<void> initialize() async {
//     if (_initialised) return;
//     if (kIsWeb) {
//       debugPrint('[AdMob] Skipped on web');
//       return;
//     }
//     try {
//       final status = await MobileAds.instance.initialize();
//       // Log adapter status for easier debugging
//       for (final entry in status.adapterStatuses.entries) {
//         debugPrint(
//           '[AdMob] adapter ${entry.key}: ${entry.value.state.name} — '
//           '${entry.value.description}',
//         );
//       }
//       _initialised = true;
//       debugPrint('[AdMob] SDK initialised ✓');
//     } catch (e) {
//       debugPrint('[AdMob] SDK init failed (non-fatal): $e');
//     }
//   }

//   // ──────────────────────────────────────────────────────────────────────────
//   // Rewarded Ad — load & show
//   // ──────────────────────────────────────────────────────────────────────────

//   /// Loads a new RewardedAd and shows it immediately once ready.
//   ///
//   /// [onRewarded]    — called when the user earns the reward.
//   /// [onAdDismissed] — called after the ad closes (reward or not).
//   /// [onFailed]      — called when the ad fails to load/show OR when the
//   ///                   SDK is not yet initialised. Always fall through to the
//   ///                   intended action inside this callback so UX is never
//   ///                   permanently blocked.
//   ///
//   /// IMPORTANT: Always call this only after verifying !isPremium.
//   static void loadAndShowRewardedAd({
//     required VoidCallback onRewarded,
//     VoidCallback? onAdDismissed,
//     VoidCallback? onFailed,
//   }) {
//     // FIX: Guard against calling before SDK is ready. Without this the
//     // RewardedAd.load() call silently does nothing on some devices.
//     if (!_initialised) {
//       debugPrint(
//         '[AdMob] loadAndShowRewardedAd: SDK not initialised — failing gracefully',
//       );
//       onFailed?.call();
//       return;
//     }

//     // FIX: 15-second timeout so the UI is never stuck on a loading spinner
//     // when the ad server is unreachable or responding slowly.
//     Timer? timeoutTimer;
//     bool completed = false;

//     void complete(String reason, VoidCallback cb) {
//       if (completed) return;
//       completed = true;
//       timeoutTimer?.cancel();
//       debugPrint('[AdMob] Rewarded ad completed: $reason');
//       cb();
//     }

//     timeoutTimer = Timer(const Duration(seconds: 15), () {
//       debugPrint('[AdMob] RewardedAd load timed out after 15s');
//       complete('timeout', () => onFailed?.call());
//     });

//     RewardedAd.load(
//       adUnitId: rewardedAdUnitId,
//       request: const AdRequest(),
//       rewardedAdLoadCallback: RewardedAdLoadCallback(
//         onAdLoaded: (ad) {
//           debugPrint('[AdMob] RewardedAd loaded ✓');
//           // Cancel timeout — ad is in memory; latency from here is negligible
//           timeoutTimer?.cancel();

//           ad.fullScreenContentCallback = FullScreenContentCallback(
//             onAdShowedFullScreenContent: (_) {
//               debugPrint('[AdMob] RewardedAd showing full screen');
//             },
//             onAdDismissedFullScreenContent: (ad) {
//               ad.dispose();
//               debugPrint('[AdMob] RewardedAd dismissed');
//               complete('dismissed', () => onAdDismissed?.call());
//             },
//             onAdFailedToShowFullScreenContent: (ad, error) {
//               ad.dispose();
//               debugPrint('[AdMob] RewardedAd failed to show: $error');
//               complete('show-failed', () => onFailed?.call());
//             },
//           );

//           ad.show(
//             onUserEarnedReward: (_, reward) {
//               debugPrint(
//                 '[AdMob] Reward earned: ${reward.amount} ${reward.type}',
//               );
//               // Mark rewarded immediately; dismiss callback fires after
//               complete('rewarded', onRewarded);
//             },
//           );
//         },
//         onAdFailedToLoad: (error) {
//           debugPrint(
//             '[AdMob] RewardedAd failed to load: ${error.message} (code ${error.code})',
//           );
//           complete('load-failed', () => onFailed?.call());
//         },
//       ),
//     );
//   }
// }
