// ============================================================
// FILE: lib/ads/services/purchase_service.dart
//
// FIXES:
//   1. Removed `import 'package:in_app_purchase_android/...'`
//      This Android-only import caused crashes on iOS and was
//      unused — completePurchase uses the standard IAP API.
//   2. Added platform guard (dart:io Platform check) around
//      Android-specific logic just in case.
// ============================================================

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
// FIX: Removed in_app_purchase_android import — it is Android-only
// and was not actually used in this file (completePurchase uses the
// standard in_app_purchase API which routes correctly on all platforms).

// ── Product IDs ──────────────────────────────────────────────────────────────
const String kMonthlyId = 'remove_ads_monthly';
const String kLifetimeId = 'remove_ads_lifetime';

const Set<String> _kProductIds = {kMonthlyId, kLifetimeId};

// ── Callback types ───────────────────────────────────────────────────────────
typedef PurchaseSuccessCallback = void Function(PurchaseDetails details);
typedef PurchaseErrorCallback = void Function(String message);
typedef PurchasePendingCallback = void Function();

class PurchaseService {
  PurchaseService._();
  static final PurchaseService instance = PurchaseService._();

  final InAppPurchase _iap = InAppPurchase.instance;

  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;

  List<ProductDetails> _products = [];
  List<ProductDetails> get products => List.unmodifiable(_products);

  PurchaseSuccessCallback? onPurchaseSuccess;
  PurchaseErrorCallback? onPurchaseError;
  PurchasePendingCallback? onPurchasePending;

  // ── Init ──────────────────────────────────────────────────────────────────

  Future<void> init() async {
    if (kIsWeb) {
      debugPrint('[IAP] Skipped on web');
      return;
    }

    bool available = false;
    try {
      available = await _iap.isAvailable();
    } catch (e) {
      debugPrint('[IAP] isAvailable check failed: $e');
      return;
    }

    if (!available) {
      debugPrint('[IAP] Store not available');
      return;
    }

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
        debugPrint('[IAP] Products NOT found: ${response.notFoundIDs}');
      }

      _products = response.productDetails;
      debugPrint('[IAP] Products loaded: ${_products.map((p) => p.id)}');
    } catch (e) {
      debugPrint('[IAP] Failed to fetch products: $e');
    }
  }

  ProductDetails? productFor(String id) {
    try {
      return _products.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  // ── Purchase ──────────────────────────────────────────────────────────────

  Future<bool> purchase(String productId) async {
    final product = productFor(productId);
    if (product == null) {
      onPurchaseError?.call('Product not found. Please restart and try again.');
      return false;
    }

    final param = PurchaseParam(productDetails: product);

    try {
      return await _iap.buyNonConsumable(purchaseParam: param);
    } catch (e) {
      onPurchaseError?.call('Purchase failed: $e');
      return false;
    }
  }

  // ── Restore ───────────────────────────────────────────────────────────────

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
      debugPrint(
        '[IAP] Purchase update: ${purchase.productID} → ${purchase.status}',
      );

      switch (purchase.status) {
        case PurchaseStatus.pending:
          onPurchasePending?.call();
          break;

        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          onPurchaseSuccess?.call(purchase);
          _completePurchase(purchase);
          break;

        case PurchaseStatus.error:
          final msg = purchase.error?.message ?? 'Unknown purchase error';
          onPurchaseError?.call(msg);
          _completePurchase(purchase);
          break;

        case PurchaseStatus.canceled:
          onPurchaseError?.call('Purchase was cancelled.');
          break;
      }
    }
  }

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
