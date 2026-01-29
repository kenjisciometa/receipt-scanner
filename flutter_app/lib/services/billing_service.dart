import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import 'auth_service.dart';
import 'google_play_billing_service.dart';

/// Billing access status from Sciometa Auth
enum BillingStatus {
  noAccess,      // User has no access and no trial
  trial,         // User is in trial period
  trialExpired,  // Trial has expired
  subscribed,    // User has active subscription
  canceled,      // Subscription canceled but still active until period end
  unknown,       // Unknown status
}

/// App access data from /api/billing/app-access
class AppAccessStatus {
  final BillingStatus status;
  final bool canStartTrial;
  final DateTime? trialEndsAt;
  final int? trialDaysRemaining;
  final DateTime? subscriptionEndsAt;
  final String? planName;
  final int? priceCents;
  final String? currency;

  AppAccessStatus({
    required this.status,
    required this.canStartTrial,
    this.trialEndsAt,
    this.trialDaysRemaining,
    this.subscriptionEndsAt,
    this.planName,
    this.priceCents,
    this.currency,
  });

  factory AppAccessStatus.fromJson(Map<String, dynamic> json) {
    final statusStr = json['status'] as String? ?? 'unknown';
    final status = _parseStatus(statusStr);

    return AppAccessStatus(
      status: status,
      canStartTrial: json['can_start_trial'] as bool? ?? false,
      trialEndsAt: json['trial_ends_at'] != null
          ? DateTime.parse(json['trial_ends_at'] as String)
          : null,
      trialDaysRemaining: json['trial_days_remaining'] as int?,
      subscriptionEndsAt: json['subscription_ends_at'] != null
          ? DateTime.parse(json['subscription_ends_at'] as String)
          : null,
      planName: json['plan_name'] as String?,
      priceCents: json['price_cents'] as int?,
      currency: json['currency'] as String?,
    );
  }

  static BillingStatus _parseStatus(String status) {
    switch (status.toLowerCase()) {
      case 'no_access':
        return BillingStatus.noAccess;
      case 'trial':
        return BillingStatus.trial;
      case 'trial_expired':
        return BillingStatus.trialExpired;
      case 'subscribed':
      case 'active':
        return BillingStatus.subscribed;
      case 'canceled':
        return BillingStatus.canceled;
      default:
        return BillingStatus.unknown;
    }
  }

  /// Whether the user has access to the app (trial or subscribed)
  bool get hasAccess =>
      status == BillingStatus.trial || status == BillingStatus.subscribed;

  /// Formatted price string (e.g., "€4.99/month")
  String get formattedPrice {
    if (priceCents == null || currency == null) return '';
    final price = priceCents! / 100;
    final currencySymbol = currency == 'eur' ? '€' : currency!.toUpperCase();
    return '$currencySymbol${price.toStringAsFixed(2)}/month';
  }
}

/// Billing state
class BillingState {
  final AppAccessStatus? accessStatus;
  final bool isLoading;
  final String? error;

  const BillingState({
    this.accessStatus,
    this.isLoading = false,
    this.error,
  });

  BillingState copyWith({
    AppAccessStatus? accessStatus,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return BillingState(
      accessStatus: accessStatus ?? this.accessStatus,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Billing service for Sciometa Auth integration
class BillingService extends StateNotifier<BillingState> {
  final Ref _ref;

  BillingService(this._ref) : super(const BillingState());

  /// Get auth headers from AuthService
  Future<Map<String, String>> _getAuthHeaders() async {
    final authService = _ref.read(authServiceProvider.notifier);
    return authService.getAuthHeaders();
  }

  /// Fetch app access status from Sciometa Auth
  Future<AppAccessStatus?> getAppAccess() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final headers = await _getAuthHeaders();
      final uri = Uri.parse('${AppConfig.billingAppAccessUrl}?app_slug=${AppConfig.appId}');

      final response = await http.get(uri, headers: headers);
      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        final accessData = data['data'] as Map<String, dynamic>?;
        if (accessData != null) {
          debugPrint('📊 Raw billing data: $accessData');
          final accessStatus = AppAccessStatus.fromJson(accessData);
          state = BillingState(accessStatus: accessStatus);
          debugPrint('✅ App access status: ${accessStatus.status}');
          debugPrint('   - canStartTrial: ${accessStatus.canStartTrial}');
          debugPrint('   - trialEndsAt: ${accessStatus.trialEndsAt}');
          debugPrint('   - trialDaysRemaining: ${accessStatus.trialDaysRemaining}');
          debugPrint('   - hasAccess: ${accessStatus.hasAccess}');
          return accessStatus;
        }
      }

      final error = data['error'] as String? ?? 'Failed to get access status';
      state = state.copyWith(isLoading: false, error: error);
      debugPrint('❌ Get app access failed: $error');
      return null;
    } catch (e) {
      debugPrint('❌ Get app access error: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
      return null;
    }
  }

  /// Start trial for this app
  Future<bool> startTrial() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final headers = await _getAuthHeaders();
      final response = await http.post(
        Uri.parse(AppConfig.billingStartTrialUrl),
        headers: headers,
        body: jsonEncode({'app_slug': AppConfig.appId}),
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('✅ Trial started successfully');
        // Refresh access status
        await getAppAccess();
        return true;
      }

      final error = data['error'] as String? ?? 'Failed to start trial';
      state = state.copyWith(isLoading: false, error: error);
      debugPrint('❌ Start trial failed: $error');
      return false;
    } catch (e) {
      debugPrint('❌ Start trial error: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// Create Stripe checkout session and return checkout URL
  Future<String?> createCheckoutSession({
    required String successUrl,
    required String cancelUrl,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final headers = await _getAuthHeaders();
      final response = await http.post(
        Uri.parse(AppConfig.billingCreateCheckoutUrl),
        headers: headers,
        body: jsonEncode({
          'app_slug': AppConfig.appId,
          'success_url': successUrl,
          'cancel_url': cancelUrl,
        }),
      );

      debugPrint('📊 Create checkout response status: ${response.statusCode}');
      debugPrint('📊 Create checkout response body: ${response.body}');

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        final checkoutData = data['data'] as Map<String, dynamic>?;
        final checkoutUrl = checkoutData?['checkout_url'] as String?;

        if (checkoutUrl != null) {
          state = state.copyWith(isLoading: false);
          debugPrint('✅ Checkout session created: $checkoutUrl');
          return checkoutUrl;
        }
      }

      final error = data['error'] as String? ?? 'Failed to create checkout session';
      final code = data['code'] as String?;
      state = state.copyWith(isLoading: false, error: error);
      debugPrint('❌ Create checkout failed: $error (code: $code)');
      return null;
    } catch (e) {
      debugPrint('❌ Create checkout error: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
      return null;
    }
  }

  /// Reset billing state (e.g., on logout)
  void reset() {
    state = const BillingState();
  }

  /// Check if Google Play Billing should be used
  bool get shouldUseGooglePlay => Platform.isAndroid;

  /// Initialize Google Play Billing (call after successful auth)
  Future<void> initializeGooglePlayBilling() async {
    if (shouldUseGooglePlay) {
      final googlePlayService = _ref.read(googlePlayBillingServiceProvider.notifier);
      await googlePlayService.initialize();
    }
  }
}

// Riverpod providers
final billingServiceProvider = StateNotifierProvider<BillingService, BillingState>((ref) {
  return BillingService(ref);
});

final appAccessStatusProvider = Provider<AppAccessStatus?>((ref) {
  return ref.watch(billingServiceProvider).accessStatus;
});

final hasAppAccessProvider = Provider<bool>((ref) {
  final accessStatus = ref.watch(appAccessStatusProvider);
  return accessStatus?.hasAccess ?? false;
});
