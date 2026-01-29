import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/billing_service.dart';
import '../../services/auth_service.dart';
import '../../services/google_play_billing_service.dart';
import '../../config/app_config.dart';

class PaywallScreen extends ConsumerWidget {
  const PaywallScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final billingState = ref.watch(billingServiceProvider);
    final accessStatus = billingState.accessStatus;
    final isLoading = billingState.isLoading;

    // Watch Google Play state on Android
    final googlePlayState = Platform.isAndroid
        ? ref.watch(googlePlayBillingServiceProvider)
        : null;

    final isPurchasing = googlePlayState?.isPurchasing ?? false;
    final isVerifying = googlePlayState?.isVerifying ?? false;
    final googlePlayProduct = googlePlayState?.productDetails;
    final googlePlayError = googlePlayState?.error;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // App Icon
              Icon(
                Icons.receipt_long,
                size: 64,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(height: 24),

              // Title
              Text(
                'Your trial has ended',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Subtitle
              Text(
                'Subscribe to continue using ${AppConfig.appName}',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Plan Card
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: Theme.of(context).primaryColor,
                    width: 2,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      // Plan Name
                      Text(
                        accessStatus?.planName ?? 'Receipt Pro',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Price - use Google Play price on Android if available
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            _getDisplayPrice(accessStatus, googlePlayProduct),
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                          Text(
                            '/month',
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Features
                      _buildFeatureRow(context, 'Unlimited receipt scans'),
                      const SizedBox(height: 8),
                      _buildFeatureRow(context, 'AI-powered data extraction'),
                      const SizedBox(height: 8),
                      _buildFeatureRow(context, 'Cloud storage & sync'),
                      const SizedBox(height: 8),
                      _buildFeatureRow(context, 'Export to CSV & JSON'),
                      const SizedBox(height: 8),
                      _buildFeatureRow(context, 'Priority support'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Error message
              if (googlePlayError != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    googlePlayError,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Subscribe Button
              ElevatedButton(
                onPressed: (isLoading || isPurchasing || isVerifying)
                    ? null
                    : () => _handleSubscribe(context, ref),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                ),
                child: _buildSubscribeButtonContent(
                  isLoading: isLoading,
                  isPurchasing: isPurchasing,
                  isVerifying: isVerifying,
                ),
              ),
              const SizedBox(height: 12),

              // Restore Purchases button (Android only)
              if (Platform.isAndroid) ...[
                TextButton(
                  onPressed: (isLoading || isPurchasing || isVerifying)
                      ? null
                      : () => _handleRestorePurchases(context, ref),
                  child: const Text('Restore Purchases'),
                ),
                const SizedBox(height: 4),
              ],

              // Logout link
              TextButton(
                onPressed: () async {
                  final authService = ref.read(authServiceProvider.notifier);
                  await authService.signOut();
                },
                child: Text(
                  'Sign out',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getDisplayPrice(AppAccessStatus? accessStatus, dynamic googlePlayProduct) {
    // On Android, prefer Google Play price if available
    if (Platform.isAndroid && googlePlayProduct != null) {
      // Extract price without "/month" suffix if present in rawPrice
      final rawPrice = googlePlayProduct.price as String;
      return rawPrice.replaceAll('/month', '');
    }
    // Fallback to server-provided price
    return accessStatus?.formattedPrice.replaceAll('/month', '') ?? '\$4.99';
  }

  Widget _buildSubscribeButtonContent({
    required bool isLoading,
    required bool isPurchasing,
    required bool isVerifying,
  }) {
    if (isVerifying) {
      return const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          ),
          SizedBox(width: 12),
          Text('Verifying purchase...'),
        ],
      );
    }

    if (isPurchasing) {
      return const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          ),
          SizedBox(width: 12),
          Text('Processing...'),
        ],
      );
    }

    if (isLoading) {
      return const SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Colors.white,
        ),
      );
    }

    return const Text(
      'Subscribe Now',
      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildFeatureRow(BuildContext context, String text) {
    return Row(
      children: [
        Icon(
          Icons.check_circle,
          color: Theme.of(context).primaryColor,
          size: 20,
        ),
        const SizedBox(width: 8),
        Text(text),
      ],
    );
  }

  Future<void> _handleSubscribe(BuildContext context, WidgetRef ref) async {
    // On Android, use Google Play Billing
    if (Platform.isAndroid) {
      await _handleGooglePlaySubscribe(context, ref);
    } else {
      // On other platforms, use Stripe checkout
      await _handleStripeSubscribe(context, ref);
    }
  }

  Future<void> _handleGooglePlaySubscribe(BuildContext context, WidgetRef ref) async {
    final googlePlayService = ref.read(googlePlayBillingServiceProvider.notifier);
    final googlePlayState = ref.read(googlePlayBillingServiceProvider);

    // Check if Google Play is available
    if (!googlePlayState.isAvailable) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Google Play Store is not available'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Check if product is loaded
    if (googlePlayState.productDetails == null) {
      // Try to reload product
      await googlePlayService.initialize();
      final updatedState = ref.read(googlePlayBillingServiceProvider);
      if (updatedState.productDetails == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Subscription product not available. Please try again later.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
    }

    // Start purchase
    final success = await googlePlayService.purchaseSubscription();
    if (!success && context.mounted) {
      final state = ref.read(googlePlayBillingServiceProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(state.error ?? 'Failed to start purchase'),
          backgroundColor: Colors.red,
        ),
      );
    }
    // Purchase flow continues via stream listener in GooglePlayBillingService
  }

  Future<void> _handleRestorePurchases(BuildContext context, WidgetRef ref) async {
    final googlePlayService = ref.read(googlePlayBillingServiceProvider.notifier);
    await googlePlayService.restorePurchases();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Checking for previous purchases...'),
        ),
      );
    }
  }

  Future<void> _handleStripeSubscribe(BuildContext context, WidgetRef ref) async {
    final billingService = ref.read(billingServiceProvider.notifier);

    // Create checkout session
    final checkoutUrl = await billingService.createCheckoutSession(
      successUrl: 'receiptscanner://billing/success',
      cancelUrl: 'receiptscanner://billing/cancel',
    );

    if (checkoutUrl != null) {
      // Open Stripe checkout in browser
      final uri = Uri.parse(checkoutUrl);
      debugPrint('🌐 Attempting to launch URL: $checkoutUrl');
      final canLaunch = await canLaunchUrl(uri);
      debugPrint('🌐 canLaunchUrl: $canLaunch');
      if (canLaunch) {
        final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
        debugPrint('🌐 launchUrl result: $launched');
        if (!launched && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to open browser'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else if (context.mounted) {
        debugPrint('❌ Cannot launch URL');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open checkout page'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else if (context.mounted) {
      final billingState = ref.read(billingServiceProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(billingState.error ?? 'Failed to create checkout session'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
