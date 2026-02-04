import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../services/billing_service.dart';

/// Account button with status badge for AppBar
///
/// Displays an account icon with a colored badge indicating subscription status:
/// - Blue: trial
/// - Green: subscribed
/// - Orange: canceled (still has access until period end)
/// - Red: noAccess or trialExpired
class AccountStatusButton extends ConsumerWidget {
  const AccountStatusButton({super.key});



  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final billingState = ref.watch(billingServiceProvider);
    final accessStatus = billingState.accessStatus;

    return IconButton(
      icon: Stack(
        children: [
          const Icon(Icons.account_circle),
          if (accessStatus != null)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: _getStatusColor(accessStatus.status),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).appBarTheme.backgroundColor ??
                           Theme.of(context).colorScheme.surface,
                    width: 1.5,
                  ),
                ),
              ),
            ),
        ],
      ),
      onPressed: () => context.push('/account'),
      tooltip: _getTooltipText(accessStatus),
    );
  }

  Color _getStatusColor(BillingStatus status) {
    switch (status) {
      case BillingStatus.trial:
        return Colors.blue;
      case BillingStatus.subscribed:
        return Colors.green;
      case BillingStatus.canceled:
        return Colors.orange;
      case BillingStatus.noAccess:
      case BillingStatus.trialExpired:
        return Colors.red;
      case BillingStatus.unknown:
        return Colors.grey;
    }
  }

  String _getTooltipText(AppAccessStatus? accessStatus) {
    if (accessStatus == null) return 'Account';

    switch (accessStatus.status) {
      case BillingStatus.trial:
        final days = accessStatus.trialDaysRemaining ?? 0;
        return 'Trial ($days days left)';
      case BillingStatus.subscribed:
        return 'Subscribed';
      case BillingStatus.canceled:
        return 'Subscription ending';
      case BillingStatus.noAccess:
        return 'No subscription';
      case BillingStatus.trialExpired:
        return 'Trial expired';
      case BillingStatus.unknown:
        return 'Account';
    }
  }
}
