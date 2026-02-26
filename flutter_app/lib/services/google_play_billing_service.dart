import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

import '../config/app_config.dart';
import 'auth_service.dart';
import 'billing_service.dart';

/// Google Play Billing state
class GooglePlayBillingState {
  final bool isAvailable;
  final bool isLoading;
  final String? error;
  final ProductDetails? productDetails;
  final PurchaseDetails? pendingPurchase;
  final bool isPurchasing;
  final bool isVerifying;

  const GooglePlayBillingState({
    this.isAvailable = false,
    this.isLoading = false,
    this.error,
    this.productDetails,
    this.pendingPurchase,
    this.isPurchasing = false,
    this.isVerifying = false,
  });

  GooglePlayBillingState copyWith({
    bool? isAvailable,
    bool? isLoading,
    String? error,
    ProductDetails? productDetails,
    PurchaseDetails? pendingPurchase,
    bool? isPurchasing,
    bool? isVerifying,
    bool clearError = false,
    bool clearPendingPurchase = false,
  }) {
    return GooglePlayBillingState(
      isAvailable: isAvailable ?? this.isAvailable,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      productDetails: productDetails ?? this.productDetails,
      pendingPurchase: clearPendingPurchase ? null : (pendingPurchase ?? this.pendingPurchase),
      isPurchasing: isPurchasing ?? this.isPurchasing,
      isVerifying: isVerifying ?? this.isVerifying,
    );
  }
}

/// Google Play Billing Service
class GooglePlayBillingService extends StateNotifier<GooglePlayBillingState> {
  final Ref _ref;
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  /// Google Play subscription product ID
  static const String kSubscriptionId = 'receipt_pro_monthly';

  /// Product IDs for querying
  static const Set<String> _productIds = {kSubscriptionId};

  GooglePlayBillingService(this._ref) : super(const GooglePlayBillingState());

  /// Initialize the billing service
  Future<void> initialize() async {
    if (!Platform.isAndroid) {
      debugPrint('ℹ️ Google Play Billing: Not on Android, skipping initialization');
      return;
    }

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      // Check if billing is available
      final available = await _inAppPurchase.isAvailable();
      if (!available) {
        debugPrint('❌ Google Play Billing: Store not available');
        state = state.copyWith(
          isAvailable: false,
          isLoading: false,
          error: 'Google Play Store is not available',
        );
        return;
      }

      debugPrint('✅ Google Play Billing: Store is available');
      state = state.copyWith(isAvailable: true);

      // Listen to purchase updates
      _subscription = _inAppPurchase.purchaseStream.listen(
        _onPurchaseUpdate,
        onDone: _onPurchaseDone,
        onError: _onPurchaseError,
      );

      // Load product details
      await _loadProductDetails();

      state = state.copyWith(isLoading: false);
    } catch (e) {
      debugPrint('❌ Google Play Billing: Initialization error: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to initialize billing: $e',
      );
    }
  }

  /// Load product details from Google Play
  Future<void> _loadProductDetails() async {
    try {
      final response = await _inAppPurchase.queryProductDetails(_productIds);

      if (response.notFoundIDs.isNotEmpty) {
        debugPrint('⚠️ Products not found: ${response.notFoundIDs}');
      }

      if (response.error != null) {
        debugPrint('❌ Product query error: ${response.error}');
        state = state.copyWith(error: response.error?.message);
        return;
      }

      if (response.productDetails.isEmpty) {
        debugPrint('⚠️ No products found');
        state = state.copyWith(error: 'Subscription product not found');
        return;
      }

      // Find our subscription product
      // Note: Avoid using orElse with firstWhere due to type variance issues
      // with GooglePlayProductDetails on Android
      ProductDetails? subscriptionProduct;
      for (final p in response.productDetails) {
        if (p.id == kSubscriptionId) {
          subscriptionProduct = p;
          break;
        }
      }
      // Fallback to first product if not found
      subscriptionProduct ??= response.productDetails.isNotEmpty
          ? response.productDetails.first
          : null;

      if (subscriptionProduct == null) {
        state = state.copyWith(error: 'Subscription product not found');
        return;
      }

      debugPrint('✅ Product loaded: ${subscriptionProduct.id} - ${subscriptionProduct.price}');
      state = state.copyWith(productDetails: subscriptionProduct);
    } catch (e) {
      debugPrint('❌ Error loading product details: $e');
      state = state.copyWith(error: 'Failed to load product details: $e');
    }
  }

  /// Handle purchase updates from the stream
  void _onPurchaseUpdate(List<PurchaseDetails> purchaseDetailsList) {
    for (final purchaseDetails in purchaseDetailsList) {
      debugPrint('📦 Purchase update: ${purchaseDetails.productID} - ${purchaseDetails.status}');

      switch (purchaseDetails.status) {
        case PurchaseStatus.pending:
          state = state.copyWith(
            pendingPurchase: purchaseDetails,
            isPurchasing: true,
          );
          break;

        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          _handleSuccessfulPurchase(purchaseDetails);
          break;

        case PurchaseStatus.error:
          state = state.copyWith(
            isPurchasing: false,
            error: purchaseDetails.error?.message ?? 'Purchase failed',
            clearPendingPurchase: true,
          );
          // Complete the transaction to acknowledge the error
          if (purchaseDetails.pendingCompletePurchase) {
            _inAppPurchase.completePurchase(purchaseDetails);
          }
          break;

        case PurchaseStatus.canceled:
          state = state.copyWith(
            isPurchasing: false,
            clearPendingPurchase: true,
          );
          if (purchaseDetails.pendingCompletePurchase) {
            _inAppPurchase.completePurchase(purchaseDetails);
          }
          break;
      }
    }
  }

  /// Handle successful purchase - verify with backend
  Future<void> _handleSuccessfulPurchase(PurchaseDetails purchaseDetails) async {
    state = state.copyWith(
      isPurchasing: false,
      isVerifying: true,
      pendingPurchase: purchaseDetails,
    );

    try {
      // IMPORTANT: Always acknowledge the purchase first to prevent automatic refund
      // Google Play will refund the purchase if not acknowledged within 3 days
      if (purchaseDetails.pendingCompletePurchase) {
        debugPrint('📦 Acknowledging purchase...');
        await _inAppPurchase.completePurchase(purchaseDetails);
        debugPrint('✅ Purchase acknowledged');
      }

      // Verify purchase with backend
      final verified = await verifyPurchase(purchaseDetails);

      if (verified) {
        debugPrint('✅ Purchase verified with backend successfully');

        // Refresh billing status to update app access
        final billingService = _ref.read(billingServiceProvider.notifier);
        await billingService.getAppAccess();

        state = state.copyWith(
          isVerifying: false,
          clearPendingPurchase: true,
        );
      } else {
        debugPrint('⚠️ Purchase acknowledged but backend verification failed');
        // Purchase is acknowledged, but backend verification failed
        // User should contact support or try refreshing
        state = state.copyWith(
          isVerifying: false,
          error: 'Purchase completed but verification pending. Please restart the app or contact support.',
          clearPendingPurchase: true,
        );

        // Try to refresh billing status anyway
        final billingService = _ref.read(billingServiceProvider.notifier);
        await billingService.getAppAccess();
      }
    } catch (e) {
      debugPrint('❌ Error in purchase handling: $e');

      // Still try to acknowledge if not done yet
      if (purchaseDetails.pendingCompletePurchase) {
        try {
          await _inAppPurchase.completePurchase(purchaseDetails);
          debugPrint('✅ Purchase acknowledged after error');
        } catch (ackError) {
          debugPrint('❌ Failed to acknowledge purchase: $ackError');
        }
      }

      state = state.copyWith(
        isVerifying: false,
        error: 'Purchase processing error: $e',
        clearPendingPurchase: true,
      );
    }
  }

  void _onPurchaseDone() {
    debugPrint('📦 Purchase stream done');
  }

  void _onPurchaseError(Object error) {
    debugPrint('❌ Purchase stream error: $error');
    state = state.copyWith(
      isPurchasing: false,
      error: 'Purchase error: $error',
    );
  }

  /// Start a subscription purchase
  Future<bool> purchaseSubscription() async {
    if (!state.isAvailable) {
      state = state.copyWith(error: 'Google Play Store is not available');
      return false;
    }

    if (state.productDetails == null) {
      state = state.copyWith(error: 'Product not loaded. Please try again.');
      return false;
    }

    state = state.copyWith(isPurchasing: true, clearError: true);

    try {
      // For subscriptions on Android, we need to use GooglePlayPurchaseParam
      final purchaseParam = GooglePlayPurchaseParam(
        productDetails: state.productDetails!,
        changeSubscriptionParam: null,
      );

      final success = await _inAppPurchase.buyNonConsumable(
        purchaseParam: purchaseParam,
      );

      if (!success) {
        state = state.copyWith(
          isPurchasing: false,
          error: 'Failed to initiate purchase',
        );
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('❌ Error starting purchase: $e');
      state = state.copyWith(
        isPurchasing: false,
        error: 'Failed to start purchase: $e',
      );
      return false;
    }
  }

  /// Restore previous purchases
  Future<void> restorePurchases() async {
    debugPrint('🔄 restorePurchases called');
    debugPrint('   - isAvailable: ${state.isAvailable}');
    debugPrint('   - isLoading: ${state.isLoading}');

    if (!state.isAvailable) {
      debugPrint('❌ Google Play Store is not available');
      state = state.copyWith(error: 'Google Play Store is not available');
      return;
    }

    state = state.copyWith(isLoading: true, clearError: true);
    debugPrint('🔄 Starting restore...');

    try {
      await _inAppPurchase.restorePurchases();
      debugPrint('✅ restorePurchases completed');
      state = state.copyWith(isLoading: false);
    } catch (e) {
      debugPrint('❌ Error restoring purchases: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to restore purchases: $e',
      );
    }
  }

  /// Verify purchase with backend
  Future<bool> verifyPurchase(PurchaseDetails purchase) async {
    try {
      final authService = _ref.read(authServiceProvider.notifier);
      final headers = await authService.getAuthHeaders();

      // Get Android-specific verification data
      String? purchaseToken;
      if (purchase is GooglePlayPurchaseDetails) {
        purchaseToken = purchase.verificationData.serverVerificationData;
      } else {
        purchaseToken = purchase.verificationData.serverVerificationData;
      }

      if (purchaseToken.isEmpty) {
        debugPrint('❌ No purchase token available');
        return false;
      }

      final response = await http.post(
        Uri.parse(AppConfig.billingVerifyGooglePlayUrl),
        headers: headers,
        body: jsonEncode({
          'package_name': 'com.sciometa.eds',
          'product_id': purchase.productID,
          'purchase_token': purchaseToken,
          'app_slug': AppConfig.appId,
        }),
      );

      debugPrint('📊 Verify response status: ${response.statusCode}');
      debugPrint('📊 Verify response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final success = data['success'] as bool? ?? false;
        final valid = (data['data'] as Map<String, dynamic>?)?['valid'] as bool? ?? false;
        return success && valid;
      }

      return false;
    } catch (e) {
      debugPrint('❌ Error verifying purchase with backend: $e');
      return false;
    }
  }

  /// Dispose of the subscription
  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  /// Reset state
  void reset() {
    state = const GooglePlayBillingState();
  }
}

// Riverpod providers
final googlePlayBillingServiceProvider =
    StateNotifierProvider<GooglePlayBillingService, GooglePlayBillingState>((ref) {
  final service = GooglePlayBillingService(ref);
  // Auto-initialize on Android
  if (Platform.isAndroid) {
    service.initialize();
  }
  return service;
});

final isGooglePlayAvailableProvider = Provider<bool>((ref) {
  return ref.watch(googlePlayBillingServiceProvider).isAvailable;
});

final googlePlayProductProvider = Provider<ProductDetails?>((ref) {
  return ref.watch(googlePlayBillingServiceProvider).productDetails;
});
