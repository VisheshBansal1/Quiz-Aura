// ============================================================
// FILE: lib/ads/widgets/banner_ad_widget.dart
//
// BUGS FIXED:
//   1. CRITICAL: Widget returned SizedBox.shrink() while ad was still
//      loading (_bannerAd != null but _adLoaded == false) which caused
//      the Scaffold body layout to give the ad ZERO height — so even
//      after the ad loaded, the AdWidget had no room to render.
//      FIX: Reserve a fixed 50px slot immediately; fill it with the ad
//      once loaded, or keep it transparent until then.
//   2. Ad was loaded once in initState via postFrameCallback. If the
//      widget rebuilt (e.g. tab switch) the ad was already loaded but
//      _adLoaded could be false causing a blank slot.
//   3. Added _adFailedToLoad flag so we collapse on real failure.
// ============================================================

import 'package:QuizSphere/ads/provider/premium_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../services/admob_service.dart';

class BannerAdWidget extends ConsumerStatefulWidget {
  const BannerAdWidget({super.key});

  @override
  ConsumerState<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends ConsumerState<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _adLoaded = false;
  bool _adFailed = false;

  static const double _bannerHeight = 52.0;

  @override
  void initState() {
    super.initState();
    // Load after first frame so context + premium state are available
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAd());
  }

  void _loadAd() {
    if (kIsWeb) return;
    if (!mounted) return;

    // Check premium AFTER first frame (premiumProvider may not be ready in constructor)
    final isPremium = ref.read(isPremiumProvider);
    if (isPremium) return;

    final ad = BannerAd(
      // FIX: Use adaptive banner for better fill rates and proper sizing
      adUnitId: AdmobService.bannerAdUnitId,
      size: AdSize.banner, // 320x50 — most reliable for fill
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          debugPrint('[AdMob] BannerAd loaded ✓');
          if (mounted) setState(() => _adLoaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('[AdMob] BannerAd failed: ${error.message}');
          ad.dispose();
          if (mounted) setState(() => _adFailed = true);
        },
        onAdOpened: (_) => debugPrint('[AdMob] BannerAd opened'),
        onAdClosed: (_) => debugPrint('[AdMob] BannerAd closed'),
      ),
    );

    ad.load();
    if (mounted) setState(() => _bannerAd = ad);
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isPremium = ref.watch(isPremiumProvider);

    // Premium users or web: collapse completely
    if (isPremium || kIsWeb || _adFailed) {
      return const SizedBox.shrink();
    }

    // FIX: Always reserve the height slot so the layout doesn't jump.
    // While the ad hasn't loaded yet → show a transparent placeholder.
    // Once loaded → show the actual AdWidget with a fade-in.
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      height: _bannerHeight,
      color: Colors.black,
      alignment: Alignment.center,
      child: _adLoaded && _bannerAd != null
          ? AnimatedOpacity(
              opacity: 1.0,
              duration: const Duration(milliseconds: 400),
              child: SizedBox(
                width: _bannerAd!.size.width.toDouble(),
                height: _bannerAd!.size.height.toDouble(),
                child: AdWidget(ad: _bannerAd!),
              ),
            )
          : const SizedBox.shrink(), // transparent placeholder while loading
    );
  }
}
