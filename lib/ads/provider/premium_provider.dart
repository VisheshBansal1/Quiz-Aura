// ============================================================================
// FILE: lib/ads/provider/premium_provider.dart
//
// Minimal premium-status provider.
//
// Context: this app's full purchase/subscription system — PurchaseService
// (in_app_purchase), and this file's own previous SharedPreferences-backed
// PremiumNotifier — is currently disabled across the ENTIRE codebase (see
// the "ADS DISABLED" comments in purchase_service.dart, premium_screen.dart,
// onboarding_screen.dart, profile_screen.dart, and answer_review_screen.dart).
// With that system off, there is currently no path in this app for a user
// to actually become premium.
//
// The Rewarded Ads integration still needs a real, working answer to "is
// the current user premium?" (premium users must never see ads), so this
// file is kept as the single, canonical home for that answer — exactly
// where every other file in the app already expects to import it from —
// but reduced to a standalone provider with NO dependency on the disabled
// purchase flow, and no new packages (no in_app_purchase, no
// shared_preferences). That keeps the Rewarded Ads feature fully working
// today without silently reactivating a separate, larger subsystem that
// wasn't part of this task.
//
// [isPremiumProvider] currently always resolves to `false`, which matches
// the real state of the app today: with purchases disabled, no user can
// actually be premium yet. When you restore your purchase system (or wire
// up a Firestore/user-profile premium flag), replace ONLY the body below —
// every consumer keeps working unchanged, because they all depend on the
// `isPremiumProvider` symbol itself, never on how it's computed. Current
// consumers: banner_ad_widget.dart (now LIVE — every screen that embeds it,
// see the monetization spec's allow-list), quiz_result_screen.dart (the new
// "View Result" rewarded-ad gate), onboarding_screen.dart, profile_screen.
// dart, answer_review_screen.dart, and the Rewarded Ads gating in
// ai_generate_questions_screen.dart.
// ============================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the current user is Premium. Resolves to `false` until a real
/// premium/purchase source of truth is wired in — see the file header for
/// why, and for exactly what to change when you're ready to wire one up.
final isPremiumProvider = Provider<bool>((ref) => false);
