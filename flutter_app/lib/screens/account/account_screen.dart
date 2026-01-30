import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../services/auth_service.dart';
import '../../services/billing_service.dart';

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authServiceProvider);
    final billingState = ref.watch(billingServiceProvider);
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

            // Subscription status card
            if (accessStatus != null)
              Card(
                child: ListTile(
                  leading: Icon(
                    accessStatus.hasAccess ? Icons.check_circle : Icons.warning,
                    color: accessStatus.hasAccess ? Colors.green : Colors.orange,
                  ),
                  title: Text(accessStatus.planName ?? 'Subscription'),
                  subtitle: Text(_getSubscriptionStatusText(accessStatus)),
                  trailing: accessStatus.status == BillingStatus.trial
                      ? Chip(
                          label: Text('${accessStatus.trialDaysRemaining ?? 0} days left'),
                          backgroundColor: Colors.blue.shade100,
                        )
                      : null,
                ),
              ),
            const SizedBox(height: 24),

            // Menu items
            Text(
              'Menu',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),

            // History button (receipts & invoices)
            Card(
              child: ListTile(
                leading: const Icon(Icons.history),
                title: const Text('History'),
                subtitle: const Text('View receipts and invoices'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/history'),
              ),
            ),

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

  String _getSubscriptionStatusText(AppAccessStatus status) {
    switch (status.status) {
      case BillingStatus.trial:
        return 'Free trial active';
      case BillingStatus.subscribed:
        return 'Active subscription - ${status.formattedPrice}';
      case BillingStatus.canceled:
        return 'Canceled - access until period end';
      case BillingStatus.trialExpired:
        return 'Trial expired';
      case BillingStatus.noAccess:
        return 'No active subscription';
      default:
        return 'Unknown status';
    }
  }
}
