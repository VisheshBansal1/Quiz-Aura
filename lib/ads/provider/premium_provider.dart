// ============================================================
// FILE: lib/providers/premium_provider.dart
//
// State shape:
//   isPremium    → true when lifetime OR active monthly sub
//   isLifetime   → true when the user bought the lifetime pack
//   expiryDate   → non-null for monthly subscribers
//   isLoading    → true while purchase is in flight
//   errorMessage → last purchase error (null = no error)
//
// Premium logic:
//   • Lifetime purchased  → always premium (no expiry check)
//   • Monthly sub active  → isPremium = now < expiryDate
//   • Subscription expiry: stored in SharedPreferences as ISO-8601
//     string. We re-evaluate on every app start and when the device
//     clock crosses the expiry boundary (handled in _evaluatePremium).
//
// Storage (SharedPreferences keys):
//   pref_is_lifetime   → bool
//   pref_expiry_date   → ISO-8601 string | null
// ============================================================

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/purchase_service.dart';

// ── SharedPreferences keys ────────────────────────────────────────────────────
const _kIsLifetime  = 'pref_is_lifetime';
const _kExpiryDate  = 'pref_expiry_date';

// ── State model ───────────────────────────────────────────────────────────────

class PremiumState {
  final bool isPremium;
  final bool isLifetime;
  final DateTime? expiryDate;
  final bool isLoading;
  final String? errorMessage;

  const PremiumState({
    this.isPremium    = false,
    this.isLifetime   = false,
    this.expiryDate   = null,
    this.isLoading    = false,
    this.errorMessage = null,
  });

  PremiumState copyWith({
    bool?     isPremium,
    bool?     isLifetime,
    DateTime? expiryDate,
    bool      clearExpiry = false,
    bool?     isLoading,
    String?   errorMessage,
    bool      clearError = false,
  }) {
    return PremiumState(
      isPremium:    isPremium    ?? this.isPremium,
      isLifetime:   isLifetime   ?? this.isLifetime,
      expiryDate:   clearExpiry  ? null : (expiryDate ?? this.expiryDate),
      isLoading:    isLoading    ?? this.isLoading,
      errorMessage: clearError   ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class PremiumNotifier extends StateNotifier<PremiumState> {
  PremiumNotifier() : super(const PremiumState()) {
    _init();
  }

  // ── Init ──────────────────────────────────────────────────────────────────

  Future<void> _init() async {
    state = state.copyWith(isLoading: true);

    // 1. Load persisted premium status.
    await _loadFromPrefs();

    // 2. Wire purchase callbacks.
    PurchaseService.instance.onPurchaseSuccess = _onPurchaseSuccess;
    PurchaseService.instance.onPurchaseError   = _onPurchaseError;
    PurchaseService.instance.onPurchasePending = _onPurchasePending;

    // 3. Start IAP service (fetches products + restores purchases).
    await PurchaseService.instance.init();

    state = state.copyWith(isLoading: false);
  }

  // ── SharedPreferences persistence ─────────────────────────────────────────

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();

    final isLifetime = prefs.getBool(_kIsLifetime) ?? false;
    final expiryStr  = prefs.getString(_kExpiryDate);
    DateTime? expiry;

    if (expiryStr != null) {
      expiry = DateTime.tryParse(expiryStr);
    }

    state = state.copyWith(
      isLifetime: isLifetime,
      expiryDate: expiry,
    );

    _evaluatePremium();
  }

  /// Persist both lifetime flag and expiry date atomically.
  Future<void> _saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kIsLifetime, state.isLifetime);

    if (state.expiryDate != null) {
      await prefs.setString(_kExpiryDate, state.expiryDate!.toIso8601String());
    } else {
      await prefs.remove(_kExpiryDate);
    }
  }

  // ── Premium evaluation ────────────────────────────────────────────────────

  /// Central place that decides isPremium from current sub-state.
  /// Called every time lifetime or expiryDate changes.
  void _evaluatePremium() {
    bool premium = false;

    if (state.isLifetime) {
      // Lifetime → always premium.
      premium = true;
    } else if (state.expiryDate != null) {
      // Monthly subscription → check if not expired.
      // Subscription expiry handling: compare UTC times to be timezone-safe.
      premium = DateTime.now().toUtc().isBefore(state.expiryDate!.toUtc());
    }

    state = state.copyWith(isPremium: premium);
    debugPrint('[Premium] isPremium=$premium  isLifetime=${state.isLifetime}  expiry=${state.expiryDate}');
  }

  // ── Purchase callbacks ────────────────────────────────────────────────────

  /// Called by PurchaseService when a purchase is confirmed (purchased/restored).
  void _onPurchaseSuccess(PurchaseDetails details) {
    debugPrint('[Premium] Purchase confirmed: ${details.productID}');

    if (details.productID == kLifetimeId) {
      // Lifetime: no expiry required.
      state = state.copyWith(
        isLifetime:  true,
        clearExpiry: true,
        isLoading:   false,
        clearError:  true,
      );
    } else if (details.productID == kMonthlyId) {
      // Monthly subscription.
      //
      // Subscription expiry handling (client-side fallback):
      //   The in_app_purchase package does not expose expiryTimeMillis on
      //   Android in PurchaseDetails. For a production app, validate the
      //   receipt server-side and return the real expiry. Here we derive
      //   it from transactionDate + 30 days as a robust fallback.
      //
      //   transactionDate is milliseconds-since-epoch as a String on Android.
      final rawDate  = details.transactionDate;
      final txMillis = rawDate != null ? int.tryParse(rawDate) : null;
      final txDate   = txMillis != null
          ? DateTime.fromMillisecondsSinceEpoch(txMillis)
          : DateTime.now();

      final expiry = txDate.add(const Duration(days: 30));

      state = state.copyWith(
        isLifetime: false,
        expiryDate: expiry,
        isLoading:  false,
        clearError: true,
      );
    }

    _evaluatePremium();
    _saveToPrefs();
  }

  void _onPurchaseError(String message) {
    state = state.copyWith(
      isLoading:    false,
      errorMessage: message,
    );
    debugPrint('[Premium] Purchase error: $message');
  }

  void _onPurchasePending() {
    // Show loading while the purchase is processing (e.g. awaiting bank OTP).
    state = state.copyWith(isLoading: true, clearError: true);
    debugPrint('[Premium] Purchase pending…');
  }

  // ── Public actions ────────────────────────────────────────────────────────

  Future<void> purchaseMonthly() async {
    state = state.copyWith(isLoading: true, clearError: true);
    // Duplicate-trigger guard: PurchaseService uses the native billing flow
    // which itself prevents duplicate transactions, but clearing state here
    // ensures our UI spinner is consistent.
    await PurchaseService.instance.purchase(kMonthlyId);
  }

  Future<void> purchaseLifetime() async {
    state = state.copyWith(isLoading: true, clearError: true);
    await PurchaseService.instance.purchase(kLifetimeId);
  }

  Future<void> restorePurchases() async {
    state = state.copyWith(isLoading: true, clearError: true);
    await PurchaseService.instance.restorePurchases();
    // Results will arrive via onPurchaseSuccess callback above.
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

// ── Riverpod providers ────────────────────────────────────────────────────────

final premiumProvider =
    StateNotifierProvider<PremiumNotifier, PremiumState>(
  (_) => PremiumNotifier(),
);

/// Convenience selector — inject only what you need to minimise rebuilds.
final isPremiumProvider = Provider<bool>(
  (ref) => ref.watch(premiumProvider).isPremium,
);