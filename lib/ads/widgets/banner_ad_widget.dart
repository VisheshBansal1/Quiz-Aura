// ============================================================
// FILE: lib/widgets/banner_ad_widget.dart
//
// Ad control logic:
//   • Reads isPremiumProvider from Riverpod.
//   • If isPremium == true  → returns SizedBox.shrink() (zero height).
//   • If isPremium == false → loads and renders a BannerAd.
//
// Memory management:
//   • BannerAd is disposed in _BannerAdWidgetState.dispose()
//     to prevent the ad from holding native resources after the
//     widget is removed from the tree.
//   • Ad is only loaded once per widget instance. Navigating away
//     and back creates a fresh widget & fresh ad load.
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

  @override
  void initState() {
    super.initState();
    // Defer until after the first frame so Riverpod is fully mounted.
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAdIfNeeded());
  }

  void _loadAdIfNeeded() {
    // Ad control logic: check premium status before loading.
    if (kIsWeb) return; // google_mobile_ads is mobile-only
    final isPremium = ref.read(isPremiumProvider);
    if (isPremium) return; // premium users never see ads

    final ad = BannerAd(
      adUnitId: AdmobService.bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _adLoaded = true);
          debugPrint('[AdMob] BannerAd loaded');
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          debugPrint('[AdMob] BannerAd failed to load: $error');
        },
      ),
    );

    ad.load();
    _bannerAd = ad;
  }

  @override
  void dispose() {
    // Always dispose to release native ad resources.
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Reactively hide the banner the moment user goes premium mid-session.
    final isPremium = ref.watch(isPremiumProvider);

    if (isPremium || !_adLoaded || _bannerAd == null) {
      return const SizedBox.shrink(); // zero-height placeholder
    }

    return SafeArea(
      top: false,
      child: SizedBox(
        width: _bannerAd!.size.width.toDouble(),
        height: _bannerAd!.size.height.toDouble(),
        child: AdWidget(ad: _bannerAd!),
      ),
    );
  }
}
