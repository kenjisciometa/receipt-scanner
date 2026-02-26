import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../services/gmail_service.dart';

/// Gmail status button with badge for AppBar
///
/// Displays a mail icon that indicates Gmail connection status:
/// - Filled icon: Connected
/// - Outlined icon: Not connected
///
/// Shows an orange badge with pending invoice count when > 0.
/// Tapping navigates to:
/// - Connected: /gmail/extracted (extracted invoices list)
/// - Not connected: /gmail (Gmail settings screen)
class GmailStatusButton extends ConsumerStatefulWidget {
  const GmailStatusButton({super.key});

  @override
  ConsumerState<GmailStatusButton> createState() => _GmailStatusButtonState();
}

class _GmailStatusButtonState extends ConsumerState<GmailStatusButton> {
  bool _hasLoadedInvoices = false;

  @override
  void initState() {
    super.initState();
    // Load invoices on first build if connected
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInvoicesIfNeeded();
    });
  }

  void _loadInvoicesIfNeeded() {
    if (_hasLoadedInvoices) return;

    final isConnected = ref.read(isGmailConnectedProvider);
    if (isConnected) {
      _hasLoadedInvoices = true;
      ref.read(extractedInvoicesServiceProvider.notifier).loadInvoices(status: 'pending');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = ref.watch(isGmailConnectedProvider);
    final pendingCount = ref.watch(pendingExtractedInvoicesCountProvider);

    // Load invoices when connection status changes to connected
    ref.listen<bool>(isGmailConnectedProvider, (previous, next) {
      if (next && !_hasLoadedInvoices) {
        _hasLoadedInvoices = true;
        ref.read(extractedInvoicesServiceProvider.notifier).loadInvoices(status: 'pending');
      }
    });

    return IconButton(
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(isConnected ? Icons.mail : Icons.mail_outline),
          if (isConnected && pendingCount > 0)
            Positioned(
              right: -6,
              top: -4,
              child: Container(
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(
                  minWidth: 16,
                  minHeight: 16,
                ),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).appBarTheme.backgroundColor ??
                        Theme.of(context).colorScheme.surface,
                    width: 1.5,
                  ),
                ),
                child: Text(
                  pendingCount > 99 ? '99+' : '$pendingCount',
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
      onPressed: () {
        if (isConnected) {
          context.push('/gmail/extracted');
        } else {
          context.push('/gmail');
        }
      },
      tooltip: _getTooltipText(isConnected, pendingCount),
    );
  }

  String _getTooltipText(bool isConnected, int pendingCount) {
    if (!isConnected) {
      return 'Connect Gmail';
    }
    if (pendingCount > 0) {
      return '$pendingCount pending invoice${pendingCount > 1 ? 's' : ''}';
    }
    return 'Gmail Invoices';
  }
}
