// ============================================================================
// AdAnalyticsService
//
// Lightweight, dependency-free analytics logger for the ad/monetization
// flow. No new pub package is added here — every event is written as a
// single structured debugPrint line, visible immediately in `flutter run` /
// Logcat / Xcode console with zero setup.
//
// Wiring in a real analytics backend later (Firebase Analytics, Mixpanel,
// Amplitude, …) is a ONE-PLACE change: replace the body of [_send] with
// that SDK's logEvent(...) call. Every event below already funnels through
// [_send], so nothing else in the app needs to change when you do.
//
// Event names match the monetization spec exactly:
//   rewarded_requested, rewarded_loaded, rewarded_failed, rewarded_shown,
//   reward_earned, rewarded_closed, banner_requested, banner_loaded,
//   banner_failed, banner_clicked, view_result_clicked, premium_bypass,
//   ad_retry_clicked, go_premium_clicked
// ============================================================================

import 'package:flutter/foundation.dart';

class AdAnalyticsService {
  AdAnalyticsService._();

  /// Every event funnels through here — swap this one body for a real
  /// analytics SDK call when you're ready; no call site below needs to
  /// change.
  static void _send(String name, [Map<String, Object?> params = const {}]) {
    if (params.isEmpty) {
      debugPrint('[Analytics] $name');
    } else {
      debugPrint('[Analytics] $name $params');
    }
  }

  // ── Rewarded ad lifecycle ────────────────────────────────────────────
  // Fired from inside RewardedAdService itself, so every screen that uses
  // it — the existing quiz-generation gate AND the new quiz-result gate —
  // is covered automatically, with no changes needed at either call site.
  static void rewardedRequested() => _send('rewarded_requested');
  static void rewardedLoaded() => _send('rewarded_loaded');
  static void rewardedFailed(String reason) =>
      _send('rewarded_failed', {'reason': reason});
  static void rewardedShown() => _send('rewarded_shown');
  static void rewardEarned() => _send('reward_earned');
  static void rewardedClosed({required bool rewarded}) =>
      _send('rewarded_closed', {'rewarded': rewarded});

  // ── Banner ad lifecycle ──────────────────────────────────────────────
  // Tagged by screen name so you can see fill rate / clicks per placement.
  static void bannerRequested(String screen) =>
      _send('banner_requested', {'screen': screen});
  static void bannerLoaded(String screen) =>
      _send('banner_loaded', {'screen': screen});
  static void bannerFailed(String screen, String reason) =>
      _send('banner_failed', {'screen': screen, 'reason': reason});
  static void bannerClicked(String screen) =>
      _send('banner_clicked', {'screen': screen});

  // ── Quiz-result gate + dialog actions ────────────────────────────────
  static void viewResultClicked(String screen) =>
      _send('view_result_clicked', {'screen': screen});
  static void premiumBypass(String screen) =>
      _send('premium_bypass', {'screen': screen});
  static void adRetryClicked(String screen) =>
      _send('ad_retry_clicked', {'screen': screen});
  static void goPremiumClicked(String screen) =>
      _send('go_premium_clicked', {'screen': screen});
}
