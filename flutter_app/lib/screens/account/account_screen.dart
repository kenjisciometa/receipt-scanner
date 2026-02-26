import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/auth_service.dart';
import '../../services/billing_service.dart';
import '../../services/google_play_billing_service.dart';
import '../../services/gmail_service.dart';

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authServiceProvider);
    final billingState = ref.watch(billingServiceProvider);
    final gmailState = ref.watch(gmailServiceProvider);
    final pendingInvoicesCount = ref.watch(pendingExtractedInvoicesCountProvider);
    final user = authState.user;
    final accessStatus = billingState.accessStatus;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Account'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User info card
            Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context).primaryColor,
                  child: Text(
                    user?.email.substring(0, 1).toUpperCase() ?? 'U',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                title: Text(user?.email ?? 'Unknown'),
                subtitle: Text(user?.fullName ?? 'Logged in'),
              ),
            ),
            const SizedBox(height: 16),

            // Gmail integration card
            _buildGmailCard(context, gmailState, pendingInvoicesCount),
            const SizedBox(height: 16),

            // Subscription status card
            if (accessStatus != null)
              _buildSubscriptionCard(context, ref, accessStatus),
            const SizedBox(height: 24),

            // Logout button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Logout'),
                      content: const Text('Are you sure you want to logout?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Logout', style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    final authService = ref.read(authServiceProvider.notifier);
                    await authService.signOut();
                    // Navigate to home (AuthWrapper will show login screen)
                    if (context.mounted) {
                      context.go('/');
                    }
                  }
                },
                icon: const Icon(Icons.logout, color: Colors.red),
                label: const Text('Logout', style: TextStyle(color: Colors.red)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGmailCard(
    BuildContext context,
    GmailConnectionState gmailState,
    int pendingInvoicesCount,
  ) {
    final isConnected = gmailState.isConnected;
    final connection = gmailState.connection;

    return Card(
      child: InkWell(
        onTap: () => context.push('/gmail'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Gmail icon
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isConnected
                      ? Colors.green.shade50
                      : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.email,
                  color: isConnected
                      ? Colors.green.shade700
                      : Colors.red.shade700,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Gmail Integration',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isConnected
                          ? connection!.gmailEmail
                          : 'Not connected',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                    if (isConnected && pendingInvoicesCount > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$pendingInvoicesCount pending',
                            style: TextStyle(
                              color: Colors.orange.shade800,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // Arrow
              Icon(
                Icons.chevron_right,
                color: Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubscriptionCard(
    BuildContext context,
    WidgetRef ref,
    AppAccessStatus accessStatus,
  ) {
    final googlePlayState = ref.watch(googlePlayBillingServiceProvider);
    final productDetails = googlePlayState.productDetails;
    final isPurchasing = googlePlayState.isPurchasing;
    final isVerifying = googlePlayState.isVerifying;

    // Determine status icon and color
    IconData statusIcon;
    Color statusColor;
    String statusText;

    switch (accessStatus.status) {
      case BillingStatus.trial:
        statusIcon = Icons.access_time;
        statusColor = Colors.blue;
        statusText = 'Free trial active';
        break;
      case BillingStatus.subscribed:
        statusIcon = Icons.check_circle;
        statusColor = Colors.green;
        statusText = 'Active subscription';
        break;
      case BillingStatus.canceled:
        statusIcon = Icons.cancel_outlined;
        statusColor = Colors.orange;
        statusText = 'Canceled';
        break;
      case BillingStatus.trialExpired:
        statusIcon = Icons.warning;
        statusColor = Colors.red;
        statusText = 'Trial expired';
        break;
      case BillingStatus.noAccess:
        statusIcon = Icons.lock_outline;
        statusColor = Colors.grey;
        statusText = 'No active subscription';
        break;
      default:
        statusIcon = Icons.help_outline;
        statusColor = Colors.grey;
        statusText = 'Unknown status';
    }

    // Check if purchase is available
    final canPurchase = accessStatus.status == BillingStatus.trial ||
        accessStatus.status == BillingStatus.trialExpired ||
        accessStatus.status == BillingStatus.noAccess ||
        accessStatus.status == BillingStatus.canceled;

    // Get price string from Google Play product
    final priceString = productDetails?.price ?? '€4.99/month';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with status
            Row(
              children: [
                Icon(statusIcon, color: statusColor, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Receipt Scanner Pro',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        statusText,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const Divider(height: 24),

            // Status-specific details
            if (accessStatus.status == BillingStatus.trial) ...[
              if (accessStatus.trialEndsAt != null)
                _buildInfoRow(
                  context,
                  'Trial ends',
                  DateFormat('yyyy-MM-dd').format(accessStatus.trialEndsAt!),
                ),
              _buildInfoRow(
                context,
                'Days remaining',
                '${accessStatus.trialDaysRemaining ?? 0} days',
              ),
            ],

            if (accessStatus.status == BillingStatus.subscribed) ...[
              _buildInfoRow(context, 'Price', priceString),
              if (accessStatus.subscriptionEndsAt != null)
                _buildInfoRow(
                  context,
                  'Next billing',
                  DateFormat('yyyy-MM-dd').format(accessStatus.subscriptionEndsAt!),
                ),
            ],

            if (accessStatus.status == BillingStatus.canceled) ...[
              if (accessStatus.subscriptionEndsAt != null)
                _buildInfoRow(
                  context,
                  'Access until',
                  DateFormat('yyyy-MM-dd').format(accessStatus.subscriptionEndsAt!),
                ),
            ],

            if (accessStatus.status == BillingStatus.trialExpired ||
                accessStatus.status == BillingStatus.noAccess) ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Subscribe to continue using Receipt Scanner Pro features.',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Error display
            if (googlePlayState.error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  googlePlayState.error!,
                  style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                ),
              ),

            // Purchase button (for trial, expired, or no access)
            if (canPurchase && accessStatus.status != BillingStatus.subscribed)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: (isPurchasing || isVerifying)
                      ? null
                      : () => _handlePurchase(ref),
                  icon: (isPurchasing || isVerifying)
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.shopping_cart),
                  label: Text(
                    isPurchasing
                        ? 'Processing...'
                        : isVerifying
                            ? 'Verifying...'
                            : 'Subscribe - $priceString',
                  ),
                ),
              ),

            // Manage subscription button (for active subscribers)
            if (accessStatus.status == BillingStatus.subscribed)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _openSubscriptionManagement,
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Manage subscription'),
                ),
              ),

            const SizedBox(height: 8),

            // Restore purchases button
            Builder(
              builder: (context) {
                debugPrint('🔧 Restore button state - isLoading: ${googlePlayState.isLoading}, isAvailable: ${googlePlayState.isAvailable}');
                return Center(
                  child: TextButton(
                    onPressed: googlePlayState.isLoading
                        ? null
                        : () => _handleRestorePurchases(ref),
                    child: googlePlayState.isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Restore purchases'),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey.shade600,
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handlePurchase(WidgetRef ref) async {
    final googlePlayService = ref.read(googlePlayBillingServiceProvider.notifier);
    await googlePlayService.purchaseSubscription();
  }

  Future<void> _handleRestorePurchases(WidgetRef ref) async {
    debugPrint('👆 Restore purchases button tapped');
    final googlePlayService = ref.read(googlePlayBillingServiceProvider.notifier);
    await googlePlayService.restorePurchases();
    debugPrint('👆 Restore purchases completed');
  }

  Future<void> _openSubscriptionManagement() async {
    final uri = Uri.parse('https://play.google.com/store/account/subscriptions');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
