// ============================================================================
// BannerAdWidget
//
// Live, active Adaptive Banner widget for low-engagement / utility screens
// (Profile, Settings, About, Privacy Policy, Terms & Conditions, History,
// Notifications — see the monetization spec for the full allow-list).
// NEVER place this on gameplay, result, leaderboard, battle, auth, payment,
// or premium screens.
//
// Design:
//   • Premium users (isPremiumProvider) never see this — collapses to zero
//     height instantly and never even makes an ad request.
//   • Uses a current-orientation ANCHORED ADAPTIVE banner sized to the
//     widget's own available width (not a fixed 320x50) — higher fill
//     rate, no clipping, fits both portrait and landscape.
//   • Loads lazily, once, after the first frame — never in initState
//     directly (MediaQuery isn't safe to read before layout exists).
//   • One BannerAd instance per mounted widget; disposed in dispose().
//     Never re-requests while a request is already in flight or a banner
//     is already loaded/cached.
//   • On failure: retries a few times with a fixed delay, then hides
//     completely (SizedBox.shrink, no reserved blank space) rather than
//     leaving a dead grey box on screen forever.
//
// Ad unit configuration mirrors RewardedAdService's pattern exactly: flip
// ONE constant to switch between Google's test unit and the real AdMob
// unit. This is a BRAND NEW placement (unlike the rewarded ad, which is
// already verified end-to-end) — left on TEST ads until you've confirmed
// banners render correctly on every allow-listed screen. Flip
// [_useTestAds] to false only after that check.
// ============================================================================

import 'dart:async';

import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform, debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../provider/premium_provider.dart';
import '../services/ad_analytics_service.dart';

class BannerAdWidget extends ConsumerStatefulWidget {
  /// Identifies which screen this banner is on, for analytics only (e.g.
  /// 'profile', 'settings'). Purely a label — never affects ad behavior.
  final String screenName;

  const BannerAdWidget({super.key, this.screenName = 'unknown'});

  @override
  ConsumerState<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends ConsumerState<BannerAdWidget> {
  // ── Ad unit configuration ─────────────────────────────────────────────
  static const bool _useTestAds = false;

  /// Google's official Android test Adaptive Banner ad unit ID.
  static const String _testAdUnitId = 'ca-app-pub-3940256099942544/6300978111';

  /// Your real production Banner ad unit ID.
  static const String _productionAdUnitId =
      'ca-app-pub-5737850023326024/8945974038';

  static const String _bannerAdUnitId =
      _useTestAds ? _testAdUnitId : _productionAdUnitId;

  static bool get _isSupportedPlatform =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  BannerAd? _bannerAd;
  bool _adLoaded = false;
  bool _requestInFlight = false;
  double _adHeight = 50;
  double _adWidth = double.infinity;
  double _opacity = 0.0;

  Timer? _retryTimer;
  int _retryCount = 0;
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 5);

  @override
  void initState() {
    super.initState();
    // Lazy load: wait for the first real frame/layout before touching
    // MediaQuery or requesting an ad.
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAd());
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    _bannerAd?.dispose();
    super.dispose();
  }

  Future<void> _loadAd() async {
    if (!mounted || !_isSupportedPlatform) return;

    // Premium users never get a banner request in the first place.
    if (ref.read(isPremiumProvider)) return;

    // Prevent duplicate/overlapping requests.
    if (_requestInFlight || _adLoaded) return;
    _requestInFlight = true;

    final screenWidth = MediaQuery.of(context).size.width.truncate();

    AdSize adSize = AdSize.banner;
    try {
      final adaptive = await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(
        screenWidth,
      );
      if (adaptive != null) adSize = adaptive;
    } catch (e) {
      debugPrint('[BannerAdWidget] Adaptive size lookup failed, using standard banner: $e');
    }

    if (!mounted) {
      _requestInFlight = false;
      return;
    }

    AdAnalyticsService.bannerRequested(widget.screenName);

    final ad = BannerAd(
      adUnitId: _bannerAdUnitId,
      size: adSize,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          AdAnalyticsService.bannerLoaded(widget.screenName);
          _requestInFlight = false;
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() {
            _adLoaded = true;
            _retryCount = 0;
            _adHeight = adSize.height.toDouble();
            _adWidth = adSize.width.toDouble();
          });
          // Small fade-in so the banner doesn't just pop into place.
          Future.delayed(const Duration(milliseconds: 80), () {
            if (mounted) setState(() => _opacity = 1.0);
          });
        },
        onAdFailedToLoad: (ad, error) {
          AdAnalyticsService.bannerFailed(
            widget.screenName,
            '${error.code}: ${error.message}',
          );
          _requestInFlight = false;
          ad.dispose();
          if (!mounted) return;
          setState(() {
            _bannerAd = null;
            _adLoaded = false;
          });
          if (_retryCount < _maxRetries) {
            _retryCount++;
            _retryTimer?.cancel();
            _retryTimer = Timer(_retryDelay, () {
              if (mounted) _loadAd();
            });
          }
        },
        onAdClicked: (ad) => AdAnalyticsService.bannerClicked(widget.screenName),
      ),
    );

    _bannerAd = ad;
    ad.load();
  }

  @override
  Widget build(BuildContext context) {
    final isPremium = ref.watch(isPremiumProvider);

    if (isPremium) {
      // Covers the (currently theoretical, but future-proofed) case of a
      // user upgrading to Premium mid-session while a banner is already
      // loaded — release it immediately; Premium must never show ads.
      if (_bannerAd != null) {
        final adToDispose = _bannerAd;
        _bannerAd = null;
        WidgetsBinding.instance.addPostFrameCallback((_) => adToDispose?.dispose());
      }
      return const SizedBox.shrink();
    }

    if (!_isSupportedPlatform) {
      return const SizedBox.shrink();
    }

    if (!_adLoaded || _bannerAd == null) {
      // Nothing to show yet (first load in flight, or a retry is pending
      // after a failure) — collapse completely rather than holding open a
      // blank placeholder box.
      return const SizedBox.shrink();
    }

    // Families Policy: ads must be clearly distinguishable from app content.
    // The banner is wrapped in a labelled, visually distinct container with
    // its own background, a divider line and spacing from the screen above.
    return SafeArea(
      top: false,
      child: AnimatedOpacity(
        opacity: _opacity,
        duration: const Duration(milliseconds: 400),
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
          decoration: const BoxDecoration(
            color: Color(0xFFEFEFEF),
            border: Border(
              top: BorderSide(color: Colors.black26, width: 1),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Advertisement',
                style: TextStyle(
                  color: Colors.black54,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: _adWidth,
                height: _adHeight,
                child: AdWidget(ad: _bannerAd!),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
