// // ============================================================
// // FILE: lib/ads/provider/premium_provider.dart
// //
// // FIX: Migrated from StateNotifier (deprecated legacy API) to
// //      Notifier (riverpod 2.x / 3.x native API).
// //      Removed `import 'package:flutter_riverpod/legacy.dart'`
// //      which caused crashes on certain riverpod versions.
// // ============================================================

// import 'package:flutter/foundation.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:in_app_purchase/in_app_purchase.dart';
// import 'package:shared_preferences/shared_preferences.dart';

// import '../services/purchase_service.dart';

// // ── SharedPreferences keys ────────────────────────────────────────────────────
// const _kIsLifetime = 'pref_is_lifetime';
// const _kExpiryDate = 'pref_expiry_date';

// // ── State model ───────────────────────────────────────────────────────────────

// class PremiumState {
//   final bool isPremium;
//   final bool isLifetime;
//   final DateTime? expiryDate;
//   final bool isLoading;
//   final String? errorMessage;

//   const PremiumState({
//     this.isPremium = false,
//     this.isLifetime = false,
//     this.expiryDate = null,
//     this.isLoading = false,
//     this.errorMessage = null,
//   });

//   PremiumState copyWith({
//     bool? isPremium,
//     bool? isLifetime,
//     DateTime? expiryDate,
//     bool clearExpiry = false,
//     bool? isLoading,
//     String? errorMessage,
//     bool clearError = false,
//   }) {
//     return PremiumState(
//       isPremium: isPremium ?? this.isPremium,
//       isLifetime: isLifetime ?? this.isLifetime,
//       expiryDate: clearExpiry ? null : (expiryDate ?? this.expiryDate),
//       isLoading: isLoading ?? this.isLoading,
//       errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
//     );
//   }
// }

// // ── Notifier ──────────────────────────────────────────────────────────────────
// // FIX: Uses Notifier<T> instead of deprecated StateNotifier<T>.
// // This removes the dependency on flutter_riverpod/legacy.dart.

// class PremiumNotifier extends Notifier<PremiumState> {
//   @override
//   PremiumState build() {
//     // Kick off async init without blocking the build method.
//     Future.microtask(_init);
//     return const PremiumState();
//   }

//   // ── Init ──────────────────────────────────────────────────────────────────

//   Future<void> _init() async {
//     state = state.copyWith(isLoading: true);

//     // 1. Load persisted premium status.
//     await _loadFromPrefs();

//     // 2. Wire purchase callbacks.
//     PurchaseService.instance.onPurchaseSuccess = _onPurchaseSuccess;
//     PurchaseService.instance.onPurchaseError = _onPurchaseError;
//     PurchaseService.instance.onPurchasePending = _onPurchasePending;

//     // 3. Start IAP service (fetches products + restores purchases).
//     await PurchaseService.instance.init();

//     state = state.copyWith(isLoading: false);
//   }

//   // ── SharedPreferences persistence ─────────────────────────────────────────

//   Future<void> _loadFromPrefs() async {
//     try {
//       final prefs = await SharedPreferences.getInstance();

//       final isLifetime = prefs.getBool(_kIsLifetime) ?? false;
//       final expiryStr = prefs.getString(_kExpiryDate);
//       DateTime? expiry;

//       if (expiryStr != null) {
//         expiry = DateTime.tryParse(expiryStr);
//       }

//       state = state.copyWith(isLifetime: isLifetime, expiryDate: expiry);

//       _evaluatePremium();
//     } catch (e) {
//       debugPrint('[Premium] Failed to load prefs: $e');
//     }
//   }

//   Future<void> _saveToPrefs() async {
//     try {
//       final prefs = await SharedPreferences.getInstance();
//       await prefs.setBool(_kIsLifetime, state.isLifetime);

//       if (state.expiryDate != null) {
//         await prefs.setString(
//           _kExpiryDate,
//           state.expiryDate!.toIso8601String(),
//         );
//       } else {
//         await prefs.remove(_kExpiryDate);
//       }
//     } catch (e) {
//       debugPrint('[Premium] Failed to save prefs: $e');
//     }
//   }

//   // ── Premium evaluation ────────────────────────────────────────────────────

//   void _evaluatePremium() {
//     bool premium = false;

//     if (state.isLifetime) {
//       premium = true;
//     } else if (state.expiryDate != null) {
//       premium = DateTime.now().toUtc().isBefore(state.expiryDate!.toUtc());
//     }

//     state = state.copyWith(isPremium: premium);
//     debugPrint(
//       '[Premium] isPremium=$premium  isLifetime=${state.isLifetime}  expiry=${state.expiryDate}',
//     );
//   }

//   // ── Purchase callbacks ────────────────────────────────────────────────────

//   void _onPurchaseSuccess(PurchaseDetails details) {
//     debugPrint('[Premium] Purchase confirmed: ${details.productID}');

//     if (details.productID == kLifetimeId) {
//       state = state.copyWith(
//         isLifetime: true,
//         clearExpiry: true,
//         isLoading: false,
//         clearError: true,
//       );
//     } else if (details.productID == kMonthlyId) {
//       final rawDate = details.transactionDate;
//       final txMillis = rawDate != null ? int.tryParse(rawDate) : null;
//       final txDate = txMillis != null
//           ? DateTime.fromMillisecondsSinceEpoch(txMillis)
//           : DateTime.now();

//       final expiry = txDate.add(const Duration(days: 30));

//       state = state.copyWith(
//         isLifetime: false,
//         expiryDate: expiry,
//         isLoading: false,
//         clearError: true,
//       );
//     }

//     _evaluatePremium();
//     _saveToPrefs();
//   }

//   void _onPurchaseError(String message) {
//     state = state.copyWith(isLoading: false, errorMessage: message);
//     debugPrint('[Premium] Purchase error: $message');
//   }

//   void _onPurchasePending() {
//     state = state.copyWith(isLoading: true, clearError: true);
//     debugPrint('[Premium] Purchase pending…');
//   }

//   // ── Public actions ────────────────────────────────────────────────────────

//   Future<void> purchaseMonthly() async {
//     state = state.copyWith(isLoading: true, clearError: true);
//     await PurchaseService.instance.purchase(kMonthlyId);
//   }

//   Future<void> purchaseLifetime() async {
//     state = state.copyWith(isLoading: true, clearError: true);
//     await PurchaseService.instance.purchase(kLifetimeId);
//   }

//   Future<void> restorePurchases() async {
//     state = state.copyWith(isLoading: true, clearError: true);
//     await PurchaseService.instance.restorePurchases();
//   }

//   void clearError() {
//     state = state.copyWith(clearError: true);
//   }
// }

// // ── Riverpod providers ────────────s────────────────────────────────────────────
// // FIX: NotifierProvider replaces the deprecated StateNotifierProvider.

// final premiumProvider = NotifierProvider<PremiumNotifier, PremiumState>(
//   PremiumNotifier.new,
// );

// /// Convenience selector — inject only what you need to minimise rebuilds.
// final isPremiumProvider = Provider<bool>(
//   (ref) => ref.watch(premiumProvider).isPremium,
// );
