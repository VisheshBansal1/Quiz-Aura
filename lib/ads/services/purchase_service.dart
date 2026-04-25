// ============================================================
// FILE: lib/services/purchase_service.dart
//
// Responsibilities:
//   • Fetch product details from Play Billing / App Store.
//   • Initiate purchase flows (subscription + one-time).
//   • Broadcast purchase updates via a stream.
//   • Restore previous purchases on app start.
//
// Purchase validation:
//   Google Play sends purchase updates via purchaseStream. We
//   treat PurchaseStatus.purchased / restored as valid and mark
//   the purchase complete with completePurchase(). The receipt /
//   transaction info is surfaced to PremiumProvider for storage.
//
// Subscription expiry:
//   The Play Billing library does NOT expose the expiry date
//   directly in the PurchaseDetails object on Android. The
//   canonical way is to verify the purchase server-side using
//   the Google Play Developer API and read expiryTimeMillis from
//   the SubscriptionPurchase resource. For a simpler client-only
//   approach we derive an expiry +30 days from purchaseTime and
//   store it in SharedPreferences — see PremiumProvider.
// ============================================================

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
// Android-specific details needed to mark a purchase complete.
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

// ── Product IDs — must match exactly what you create in Play Console ────────
const String kMonthlyId  = 'remove_ads_monthly';   // Subscription  ₹28/mo
const String kLifetimeId = 'remove_ads_lifetime';  // Non-consumable ₹999

const Set<String> _kProductIds = {kMonthlyId, kLifetimeId};

// ── Callback types ───────────────────────────────────────────────────────────
typedef PurchaseSuccessCallback = void Function(PurchaseDetails details);
typedef PurchaseErrorCallback   = void Function(String message);
typedef PurchasePendingCallback = void Function();

class PurchaseService {
  PurchaseService._();
  static final PurchaseService instance = PurchaseService._();

  final InAppPurchase _iap = InAppPurchase.instance;

  // Stream subscription kept alive for the app lifetime.
  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;

  // Cached product list after first fetch.
  List<ProductDetails> _products = [];
  List<ProductDetails> get products => List.unmodifiable(_products);

  // External callbacks wired up by PremiumProvider.
  PurchaseSuccessCallback? onPurchaseSuccess;
  PurchaseErrorCallback?   onPurchaseError;
  PurchasePendingCallback? onPurchasePending;

  // ── Init ──────────────────────────────────────────────────────────────────

  /// Call once during app startup (from PremiumProvider.init).
  Future<void> init() async {
    // IAP is not available on web
    if (kIsWeb) {
      debugPrint("[IAP] Skipped on web");
      return;
    }
    final available = await _iap.isAvailable();
    if (!available) {
      debugPrint('[IAP] Store not available');
      return;
    }

    // Start listening to the purchase stream before any purchase is triggered
    // to avoid missing events that fire between app launches (pending txns).
    _purchaseSub = _iap.purchaseStream.listen(
      _onPurchaseUpdate,
      onError: (e) => debugPrint('[IAP] Stream error: $e'),
    );

    await _fetchProducts();
    await restorePurchases();
  }

  // ── Fetch products ─────────────────────────────────────────────────────────

  Future<void> _fetchProducts() async {
    try {
      final response = await _iap.queryProductDetails(_kProductIds);

      if (response.error != null) {
        debugPrint('[IAP] Product query error: ${response.error}');
        return;
      }

      if (response.notFoundIDs.isNotEmpty) {
        // This usually means the product IDs don't match Play Console.
        debugPrint('[IAP] Products NOT found: ${response.notFoundIDs}');
      }

      _products = response.productDetails;
      debugPrint('[IAP] Products loaded: ${_products.map((p) => p.id)}');
    } catch (e) {
      debugPrint('[IAP] Failed to fetch products: $e');
    }
  }

  /// Returns details for a given product ID, or null if not yet loaded.
  ProductDetails? productFor(String id) {
    try {
      return _products.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  // ── Purchase ──────────────────────────────────────────────────────────────

  /// Initiates the purchase UI for [productId].
  ///
  /// Returns false if the product was not found (e.g. store unavailable).
  Future<bool> purchase(String productId) async {
    final product = productFor(productId);
    if (product == null) {
      onPurchaseError?.call('Product not found. Please restart and try again.');
      return false;
    }

    final param = PurchaseParam(productDetails: product);

    try {
      if (productId == kLifetimeId) {
        // Non-consumable → buyNonConsumable
        return await _iap.buyNonConsumable(purchaseParam: param);
      } else {
        // Subscription → buyConsumable is wrong; use buyNonConsumable
        // for subscriptions too. in_app_purchase routes correctly on Android.
        return await _iap.buyNonConsumable(purchaseParam: param);
      }
    } catch (e) {
      onPurchaseError?.call('Purchase failed: $e');
      return false;
    }
  }

  // ── Restore ───────────────────────────────────────────────────────────────

  /// Restores previously purchased products.
  /// Must be called on app start to cover reinstall / device-switch scenarios.
  Future<void> restorePurchases() async {
    try {
      await _iap.restorePurchases();
      debugPrint('[IAP] Restore triggered');
    } catch (e) {
      debugPrint('[IAP] Restore failed: $e');
    }
  }

  // ── Stream handler ────────────────────────────────────────────────────────

  void _onPurchaseUpdate(List<PurchaseDetails> purchases) {
    for (final purchase in purchases) {
      debugPrint('[IAP] Purchase update: ${purchase.productID} → ${purchase.status}');

      switch (purchase.status) {
        case PurchaseStatus.pending:
          onPurchasePending?.call();
          break;

        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          // Deliver the product BEFORE calling completePurchase,
          // per Google Play Billing best-practice documentation.
          onPurchaseSuccess?.call(purchase);
          _completePurchase(purchase);
          break;

        case PurchaseStatus.error:
          final msg = purchase.error?.message ?? 'Unknown purchase error';
          onPurchaseError?.call(msg);
          _completePurchase(purchase); // still complete to clear the queue
          break;

        case PurchaseStatus.canceled:
          onPurchaseError?.call('Purchase was cancelled.');
          break;
      }
    }
  }

  /// Acknowledges the purchase with the platform so it is not refunded.
  void _completePurchase(PurchaseDetails purchase) {
    if (purchase.pendingCompletePurchase) {
      _iap.completePurchase(purchase);
    }
  }

  // ── Dispose ───────────────────────────────────────────────────────────────

  void dispose() {
    _purchaseSub?.cancel();
  }
}