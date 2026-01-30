import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../services/billing_service.dart';
import '../../config/app_config.dart';

class TrialStartScreen extends ConsumerWidget {
  const TrialStartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final billingState = ref.watch(billingServiceProvider);
    final isLoading = billingState.isLoading;

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
                size: 80,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(height: 24),

              // Welcome Title
              Text(
                'Welcome to ${AppConfig.appName}!',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Trial Info
              Text(
                'Start your free 30-day trial',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Theme.of(context).primaryColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Features List
              _buildFeatureItem(
                context,
                Icons.document_scanner,
                'Scan receipts with AI',
              ),
              const SizedBox(height: 12),
              _buildFeatureItem(
                context,
                Icons.auto_awesome,
                'Automatic data extraction',
              ),
              const SizedBox(height: 12),
              _buildFeatureItem(
                context,
                Icons.cloud_upload,
                'Cloud storage & sync',
              ),
              const SizedBox(height: 12),
              _buildFeatureItem(
                context,
                Icons.download,
                'Export to CSV & JSON',
              ),
              const SizedBox(height: 48),

              // Trial Info Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.credit_card_off, color: Colors.green),
                          const SizedBox(width: 8),
                          Text(
                            'No credit card required',
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Colors.green,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Cancel anytime during trial',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Start Trial Button
              ElevatedButton(
                onPressed: isLoading
                    ? null
                    : () async {
                        final billingService = ref.read(billingServiceProvider.notifier);
                        final success = await billingService.startTrial();

                        if (success && context.mounted) {
                          // Navigate to home after trial started
                          context.go('/');
                        } else if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(billingState.error ?? 'Failed to start trial'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                ),
                child: isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Start Free Trial',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureItem(BuildContext context, IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: Theme.of(context).primaryColor),
        const SizedBox(width: 12),
        Text(
          text,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ],
    );
  }
}
