// // ============================================================
// // FILE: lib/ads/widgets/banner_ad_widget.dart
// //
// // BUGS FIXED:
// //   1. CRITICAL: Used fixed AdSize.banner (320×50) which has the
// //      lowest fill rate of all banner formats. Switched to an
// //      anchored adaptive banner sized to the screen width —
// //      adaptive banners get 10-20 % higher eCPM and much better
// //      fill because they fit every device perfectly.
// //
// //   2. AnimatedOpacity had opacity hardcoded to 1.0 — the fade-in
// //      never ran. Fixed with a proper _opacity state variable that
// //      starts at 0.0 and is set to 1.0 after the ad loads.
// //
// //   3. No retry logic: once _adFailed was set the banner was
// //      permanently blank for the session. Added a retry with a
// //      5-second delay so transient network failures self-heal.
// //
// //   4. Height was hardcoded to 52 px regardless of the actual ad
// //      size. After loading, the real height comes from the ad's
// //      size object. Fixed to use _adHeight which defaults to 52
// //      and is updated to the real height on load.
// //
// //   5. AdWidget was wrapped in a SizedBox using _bannerAd!.size
// //      which can be wrong before the ad is confirmed loaded.
// //      Now dimensions are stored in confirmed state variables.
// // ============================================================

// import 'dart:async';

// import 'package:QuizSphere/ads/provider/premium_provider.dart';
// import 'package:flutter/foundation.dart' show kIsWeb;
// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:google_mobile_ads/google_mobile_ads.dart';

// import '../services/admob_service.dart';

// class BannerAdWidget extends ConsumerStatefulWidget {
//   const BannerAdWidget({super.key});

//   @override
//   ConsumerState<BannerAdWidget> createState() => _BannerAdWidgetState();
// }

// class _BannerAdWidgetState extends ConsumerState<BannerAdWidget> {
//   BannerAd? _bannerAd;
//   bool _adLoaded = false;
//   bool _adFailed = false;
//   double _adHeight = 52.0; // default placeholder height
//   double _adWidth = double.infinity;
//   double _opacity = 0.0; // starts at 0, fades in after ad loads

//   Timer? _retryTimer;
//   int _retryCount = 0;
//   static const int _maxRetries = 3;
//   static const Duration _retryDelay = Duration(seconds: 5);

//   @override
//   void initState() {
//     super.initState();
//     WidgetsBinding.instance.addPostFrameCallback((_) => _loadAd());
//   }

//   @override
//   void dispose() {
//     _retryTimer?.cancel();
//     _bannerAd?.dispose();
//     super.dispose();
//   }

//   Future<void> _loadAd() async {
//     if (kIsWeb || !mounted) return;

//     final isPremium = ref.read(isPremiumProvider);
//     if (isPremium) return;

//     // Dispose any existing ad before loading a new one
//     _bannerAd?.dispose();
//     if (mounted) {
//       setState(() {
//         _bannerAd = null;
//         _adLoaded = false;
//         _adFailed = false;
//         _opacity = 0.0;
//       });
//     }

//     // FIX: Use adaptive banner sized to the actual screen width.
//     // This is AdMob's recommended banner type — it achieves much
//     // higher fill rates than the fixed 320x50 banner.
//     final screenWidth = MediaQuery.of(context).size.width.truncate();

//     AdSize adSize = AdSize.banner; // fallback
//     try {
//       final adaptive =
//           await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(
//             screenWidth,
//           );
//       if (adaptive != null) adSize = adaptive;
//     } catch (e) {
//       debugPrint('[AdMob] Adaptive size failed, using standard banner: $e');
//     }

//     if (!mounted) return;

//     final ad = BannerAd(
//       adUnitId: AdmobService.bannerAdUnitId,
//       size: adSize,
//       request: const AdRequest(),
//       listener: BannerAdListener(
//         onAdLoaded: (_) {
//           debugPrint(
//             '[AdMob] BannerAd loaded ✓  ${adSize.width}×${adSize.height}',
//           );
//           if (!mounted) return;
//           setState(() {
//             _adLoaded = true;
//             _adFailed = false;
//             _retryCount = 0;
//             // Store confirmed dimensions once the ad is actually ready
//             _adHeight = adSize.height.toDouble();
//             _adWidth = adSize.width.toDouble();
//           });
//           // Small delay then fade in so the ad isn't jarring
//           Future.delayed(const Duration(milliseconds: 80), () {
//             if (mounted) setState(() => _opacity = 1.0);
//           });
//         },
//         onAdFailedToLoad: (failedAd, error) {
//           debugPrint(
//             '[AdMob] BannerAd failed: ${error.message} (code ${error.code})',
//           );
//           failedAd.dispose();
//           if (!mounted) return;
//           setState(() {
//             _bannerAd = null;
//             _adLoaded = false;
//             _adFailed = true;
//           });
//           // FIX: Retry on transient failures so a brief network hiccup
//           // doesn't permanently hide the banner for the whole session.
//           if (_retryCount < _maxRetries) {
//             _retryCount++;
//             debugPrint(
//               '[AdMob] BannerAd retry $_retryCount/$_maxRetries '
//               'in ${_retryDelay.inSeconds}s',
//             );
//             _retryTimer?.cancel();
//             _retryTimer = Timer(_retryDelay, _loadAd);
//           }
//         },
//         onAdOpened: (_) => debugPrint('[AdMob] BannerAd opened'),
//         onAdClosed: (_) => debugPrint('[AdMob] BannerAd closed'),
//         onAdImpression: (_) => debugPrint('[AdMob] BannerAd impression'),
//       ),
//     );

//     ad.load();
//     if (mounted) setState(() => _bannerAd = ad);
//   }

//   @override
//   Widget build(BuildContext context) {
//     final isPremium = ref.watch(isPremiumProvider);

//     // Premium users or web: collapse completely
//     if (isPremium || kIsWeb) return const SizedBox.shrink();

//     // All retries exhausted and still no ad → collapse completely
//     if (_adFailed && _retryCount >= _maxRetries) {
//       return const SizedBox.shrink();
//     }

//     // Reserve placeholder height while the first load is in progress
//     // so the layout below doesn't jump when the ad appears.
//     return AnimatedContainer(
//       duration: const Duration(milliseconds: 250),
//       width: double.infinity,
//       height: _adLoaded ? _adHeight : (_adFailed ? 0 : 52.0),
//       color: Colors.black,
//       alignment: Alignment.center,
//       child: _adLoaded && _bannerAd != null
//           ? AnimatedOpacity(
//               // FIX: _opacity starts at 0.0 and becomes 1.0 after ad loads,
//               // giving a proper smooth fade-in instead of a hard pop-in.
//               opacity: _opacity,
//               duration: const Duration(milliseconds: 400),
//               child: SizedBox(
//                 width: _adWidth,
//                 height: _adHeight,
//                 child: AdWidget(ad: _bannerAd!),
//               ),
//             )
//           : const SizedBox.shrink(),
//     );
//   }
// }
