import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_analytics_service.dart';

class RewardedAdService {
  RewardedAdService._internal();

  /// App-wide singleton — one instance, one preloaded ad slot, for the
  /// lifetime of the app. main.dart calls [loadAd] on this instance once at
  /// startup; AiGenerateQuestionsScreen calls [isAdReady] / [showAd] on the
  /// same instance later. There is deliberately no per-screen instance —
  /// preloading only pays off if the ad is requested well before it's shown.
  ///
  /// Analytics: every load/show lifecycle event below is reported through
  /// [AdAnalyticsService] (rewarded_requested / rewarded_loaded /
  /// rewarded_failed / rewarded_shown / reward_earned / rewarded_closed).
  /// Because this is the ONE shared instance, every screen that gates
  /// content behind this service — quiz generation AND the quiz result
  /// screen — is covered automatically, with no changes needed at those
  /// call sites.
  static final RewardedAdService instance = RewardedAdService._internal();

  // ── Ad unit configuration ─────────────────────────────────────────────
  // Flip this ONE constant to switch every rewarded ad request between
  // Google's official test unit and your real AdMob unit. Leave it `true`
  // for all of development/testing so debug, profile, AND release builds
  // reliably fill with test ads and never risk your AdMob account on
  // invalid traffic. Set it to `false` only once you've verified the whole
  // flow end-to-end and are ready to serve real ads.
  static const bool _useTestAds = false;

  /// Google's official Android test Rewarded ad unit ID (always fills;
  /// never earns real revenue). Given directly in the task spec.
  static const String _testAdUnitId = 'ca-app-pub-3940256099942544/5224354917';

  /// TODO: replace with your real AdMob Rewarded ad unit ID before release,
  /// then flip [_useTestAds] to false. Do NOT flip it until this is set.
  static const String _productionAdUnitId =
      'ca-app-pub-5737850023326024/2834830324';

  /// The ID actually used for every ad request. This is the only symbol the
  /// rest of the service (or any caller) ever reads.
  static const String rewardedAdUnitId = _useTestAds
      ? _testAdUnitId
      : _productionAdUnitId;

  // ── State ────────────────────────────────────────────────────────────
  RewardedAd? _rewardedAd;
  bool _isLoading = false;

  /// True once a rewarded ad has finished loading and is cached, ready to
  /// show immediately. False before the first load, while a load is in
  /// flight, after a load failure, or on an unsupported platform.
  bool get isAdReady => _rewardedAd != null;

  /// The only platform this service currently serves ads on. Web and any
  /// platform other than Android (iOS, desktop, …) are treated as
  /// "unsupported" per the app's platform requirements: [loadAd] and
  /// [showAd] both no-op there instead of touching the Google Mobile Ads
  /// SDK, so callers never need to guard against platform themselves.
  static bool get _isSupportedPlatform =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  // ── Load ─────────────────────────────────────────────────────────────

  /// Preloads a rewarded ad so it's ready by the time the user taps
  /// "Generate". Fire-and-forget by design — never await this; the ad
  /// arrives via [onAdLoaded] into [_rewardedAd], checked later through
  /// [isAdReady]. Safe to call repeatedly (e.g. once from main() at
  /// startup, then again after every dismissal) — no-ops if unsupported,
  /// already loading, or an ad is already cached.
  void loadAd() {
    debugPrint("========== ENTERED loadAd() ==========");
    if (!_isSupportedPlatform) {
      debugPrint('[RewardedAdService] loadAd skipped — unsupported platform.');
      return;
    }
    if (_isLoading) {
      debugPrint('[RewardedAdService] loadAd skipped — already loading.');
      return;
    }
    if (_rewardedAd != null) {
      debugPrint('[RewardedAdService] loadAd skipped — ad already cached.');
      return;
    }

    debugPrint("Supported Platform = $_isSupportedPlatform");
    debugPrint("Ad Unit = $rewardedAdUnitId");

    _isLoading = true;
    AdAnalyticsService.rewardedRequested();
    RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (RewardedAd ad) {
          debugPrint('[RewardedAdService] Ad loaded ✓ — ready to show.');
          AdAnalyticsService.rewardedLoaded();
          _isLoading = false;
          _rewardedAd = ad;
        },
        onAdFailedToLoad: (LoadAdError error) {
          debugPrint(
            '[RewardedAdService] Failed to load: ${error.message} '
            '(code ${error.code})',
          );
          AdAnalyticsService.rewardedFailed('load-failed: ${error.code}');
          _isLoading = false;
          _rewardedAd = null;
          // Deliberately NOT auto-retried here — that would risk hammering
          // the ad server in a loop if the network is down. The next
          // natural trigger (screen reopened, user taps Generate again, or
          // the next successful show-and-dismiss cycle) calls loadAd()
          // again on its own.
        },
      ),
    );
  }

  // ── Show ─────────────────────────────────────────────────────────────

  /// Shows the cached rewarded ad. Callers should check [isAdReady] first;
  /// if there is no cached ad (or the platform is unsupported) this fails
  /// open by calling [onAdFailedToShow] immediately and returning — it
  /// never throws.
  ///
  /// Exactly one of the three callbacks fires per call:
  ///   • [onReward]          — the user watched to completion and earned
  ///                           the reward. This is the ONLY signal that
  ///                           should trigger quiz generation.
  ///   • [onAdDismissed]     — the ad closed WITHOUT the reward being
  ///                           earned (the user backed out early). Do NOT
  ///                           generate a quiz from this path.
  ///   • [onAdFailedToShow]  — the ad was cached but the SDK could not
  ///                           display it (rare — e.g. no foreground
  ///                           Activity). Treat the same as "ad not ready"
  ///                           and fail open.
  ///
  /// The next ad is automatically preloaded once this one closes, so the
  /// service is ready again for the next free-user generation.
  void showAd({
    required VoidCallback onReward,
    VoidCallback? onAdDismissed,
    VoidCallback? onAdFailedToShow,
  }) {
    final RewardedAd? ad = _rewardedAd;

    if (!_isSupportedPlatform || ad == null) {
      debugPrint('[RewardedAdService] showAd: nothing to show — failing open.');
      onAdFailedToShow?.call();
      return;
    }
  
    // Consume the cached ad immediately. A RewardedAd instance can only
    // ever be shown once (a second show() call fails), and clearing the
    // cache here also protects against a rapid double-tap trying to show
    // the same instance twice.
    _rewardedAd = null;

    // The SDK calls onAdDismissedFullScreenContent after EVERY show —
    // including when the reward was already granted, since the ad still
    // has to visually close. This guard makes sure exactly one of the
    // three outward-facing callbacks below ever fires for this call, and
    // that exactly one rewarded_closed/rewarded_failed analytics event is
    // ever reported per show() cycle.
    bool outcomeReported = false;
    void reportOutcome(String reason, VoidCallback? callback) {
      if (outcomeReported) return;
      outcomeReported = true;
      debugPrint('[RewardedAdService] showAd outcome: $reason');
      switch (reason) {
        case 'reward-earned':
          AdAnalyticsService.rewardEarned();
          AdAnalyticsService.rewardedClosed(rewarded: true);
          break;
        case 'dismissed-without-reward':
          AdAnalyticsService.rewardedClosed(rewarded: false);
          break;
        case 'failed-to-show':
          AdAnalyticsService.rewardedFailed('show-failed');
          break;
      }
      callback?.call();
    }

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        debugPrint('[RewardedAdService] Ad showing full screen.');
        AdAnalyticsService.rewardedShown();
      },
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        reportOutcome('dismissed-without-reward', onAdDismissed);
        loadAd(); // Preload the next one for next time.
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        debugPrint('[RewardedAdService] Failed to show: $error');
        reportOutcome('failed-to-show', onAdFailedToShow);
        loadAd(); // Preload the next one for next time.
      },
    );

    ad.show(
      onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
        debugPrint(
          '[RewardedAdService] Reward earned: '
          '${reward.amount} ${reward.type}',
        );
        reportOutcome('reward-earned', onReward);
      },
    );
  }

  // ── Dispose ──────────────────────────────────────────────────────────

  /// Releases any cached, unshown ad. Safe to call multiple times. Not
  /// generally needed for the app-wide [instance] (there's nothing that
  /// meaningfully "ends" its lifetime before the process exits), but kept
  /// as part of the public API for correctness, testability, and in case
  /// a future caller ever scopes a RewardedAdService more narrowly.
  void dispose() {
    _rewardedAd?.dispose();
    _rewardedAd = null;
    _isLoading = false;
  }
}
