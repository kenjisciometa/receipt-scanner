import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../services/gmail_service.dart';

/// Screen for managing Gmail connection and settings
class GmailConnectionScreen extends ConsumerWidget {
  const GmailConnectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gmailState = ref.watch(gmailServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gmail Integration'),
        actions: [
          if (gmailState.isConnected)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: gmailState.isLoading
                  ? null
                  : () => ref.read(gmailServiceProvider.notifier).refresh(),
              tooltip: 'Refresh',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header description
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.email,
                        color: Colors.red.shade700,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Gmail Invoice Extraction',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Automatically extract invoices from your Gmail attachments',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.grey.shade600,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Error display
            if (gmailState.error != null)
              _buildErrorCard(context, gmailState.error!),

            // Connection status
            if (gmailState.isConnected)
              _buildConnectedView(context, ref, gmailState)
            else
              _buildDisconnectedView(context, ref, gmailState),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard(BuildContext context, String error) {
    return Card(
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade700),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                error,
                style: TextStyle(color: Colors.red.shade700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDisconnectedView(
    BuildContext context,
    WidgetRef ref,
    GmailConnectionState state,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Benefits list
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'What you can do:',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 12),
                _buildBenefitItem(
                  context,
                  Icons.search,
                  'Automatic scanning',
                  'We scan your inbox for invoices automatically',
                ),
                _buildBenefitItem(
                  context,
                  Icons.document_scanner,
                  'PDF & image support',
                  'Extract data from PDF and image attachments',
                ),
                _buildBenefitItem(
                  context,
                  Icons.schedule,
                  'Background sync',
                  'New invoices are processed every 6 hours',
                ),
                _buildBenefitItem(
                  context,
                  Icons.verified_user,
                  'Review before saving',
                  'You approve each invoice before it\'s saved',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Privacy note
        Card(
          color: Colors.blue.shade50,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.privacy_tip, color: Colors.blue.shade700),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Privacy & Security',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'We only read emails with attachments that match invoice keywords. '
                        'Your tokens are encrypted and you can disconnect anytime.',
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Connect button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: state.isConnecting
                ? null
                : () async {
                    final success =
                        await ref.read(gmailServiceProvider.notifier).connectGmail();
                    if (success && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Gmail connected successfully!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  },
            icon: state.isConnecting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.login),
            label: Text(state.isConnecting ? 'Connecting...' : 'Connect Gmail'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBenefitItem(
    BuildContext context,
    IconData icon,
    String title,
    String description,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 20,
              color: Theme.of(context).primaryColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectedView(
    BuildContext context,
    WidgetRef ref,
    GmailConnectionState state,
  ) {
    final connection = state.connection!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Connection status card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: connection.isHealthy
                            ? Colors.green.shade50
                            : Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        connection.isHealthy
                            ? Icons.check_circle
                            : Icons.warning,
                        color: connection.isHealthy
                            ? Colors.green.shade700
                            : Colors.orange.shade700,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            connection.gmailEmail,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            connection.syncStatus,
                            style: TextStyle(
                              color: connection.isHealthy
                                  ? Colors.green.shade700
                                  : Colors.orange.shade700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),

                // Last sync info
                _buildInfoRow(
                  context,
                  'Last sync',
                  connection.lastSyncAt != null
                      ? DateFormat('yyyy-MM-dd HH:mm').format(connection.lastSyncAt!)
                      : 'Never',
                ),
                _buildInfoRow(
                  context,
                  'Auto-sync',
                  connection.syncEnabled ? 'Every 6 hours' : 'Disabled',
                ),

                // Last sync error
                if (connection.lastSyncError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline,
                              color: Colors.red.shade700, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              connection.lastSyncError!,
                              style: TextStyle(
                                color: Colors.red.shade700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Sync date filter card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Sync From Date',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_calendar, size: 20),
                      onPressed: () => _showDatePickerDialog(context, ref, connection.syncFromDate),
                      tooltip: 'Change date',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.date_range, size: 18, color: Colors.grey.shade600),
                    const SizedBox(width: 8),
                    Text(
                      connection.syncFromDate != null
                          ? DateFormat('yyyy-MM-dd').format(connection.syncFromDate!)
                          : 'No date filter (recent emails only)',
                      style: TextStyle(
                        color: connection.syncFromDate != null
                            ? Colors.black87
                            : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Only emails after this date will be synced',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Sync keywords card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Search Keywords',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit, size: 20),
                      onPressed: () => _showKeywordsDialog(context, ref, connection.syncKeywords),
                      tooltip: 'Edit keywords',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: connection.syncKeywords.map((keyword) {
                    return Chip(
                      label: Text(keyword),
                      backgroundColor: Colors.grey.shade100,
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Actions
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: state.isSyncing
                    ? null
                    : () async {
                        final success = await ref
                            .read(gmailServiceProvider.notifier)
                            .triggerSync();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(success
                                  ? 'Sync started! Check extracted invoices in a few minutes.'
                                  : 'Sync failed. Please try again.'),
                              backgroundColor:
                                  success ? Colors.green : Colors.red,
                            ),
                          );
                        }
                      },
                icon: state.isSyncing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync),
                label: Text(state.isSyncing ? 'Syncing...' : 'Sync Now'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => context.push('/gmail/extracted'),
                icon: const Icon(Icons.receipt_long),
                label: const Text('View Invoices'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Disconnect button
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: state.isLoading
                ? null
                : () => _confirmDisconnect(context, ref),
            icon: const Icon(Icons.link_off, color: Colors.red),
            label: const Text('Disconnect Gmail',
                style: TextStyle(color: Colors.red)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.red),
            ),
          ),
        ),
      ],
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
            style: TextStyle(color: Colors.grey.shade600),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  // Default keywords matching server-side register-token defaults
  static const _defaultKeywords = [
    'invoice', 'receipt', 'Rechnung', 'Quittung', 'facture', 'reçu',
    'fattura', 'ricevuta', 'lasku', 'kuitti', 'faktura', 'kvitto'
  ];

  Future<void> _showKeywordsDialog(
    BuildContext context,
    WidgetRef ref,
    List<String> currentKeywords,
  ) async {
    final controller = TextEditingController(text: currentKeywords.join(', '));

    final result = await showDialog<List<String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Edit Search Keywords'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Enter keywords separated by commas. Only files with matching keywords in their filename will be processed.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    labelText: 'Keywords',
                    hintText: 'invoice, receipt, lasku, kuitti...',
                    helperText: 'Tip: Include words in multiple languages',
                    helperMaxLines: 2,
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: () {
                    controller.text = _defaultKeywords.join(', ');
                  },
                  icon: const Icon(Icons.restore, size: 18),
                  label: const Text('Reset to defaults'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.blue,
                    padding: EdgeInsets.zero,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Defaults: ${_defaultKeywords.take(6).join(", ")}...',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final keywords = controller.text
                    .split(',')
                    .map((k) => k.trim())
                    .where((k) => k.isNotEmpty)
                    .toList();
                Navigator.pop(context, keywords);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (result != null && result.isNotEmpty) {
      await ref
          .read(gmailServiceProvider.notifier)
          .updateSyncSettings(syncKeywords: result);
    }
  }

  Future<void> _showDatePickerDialog(
    BuildContext context,
    WidgetRef ref,
    DateTime? currentDate,
  ) async {
    final now = DateTime.now();
    final initialDate = currentDate ?? DateTime(now.year - 1, 4, 1); // Default: April last year

    final result = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: now,
      helpText: 'Select start date for email sync',
      confirmText: 'Set Date',
      cancelText: 'Cancel',
    );

    if (result != null) {
      final success = await ref
          .read(gmailServiceProvider.notifier)
          .updateSyncSettings(syncFromDate: result);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success
                ? 'Sync from date updated to ${DateFormat('yyyy-MM-dd').format(result)}'
                : 'Failed to update date'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _confirmDisconnect(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disconnect Gmail?'),
        content: const Text(
          'This will remove the Gmail connection and stop automatic invoice extraction. '
          'Existing extracted invoices will not be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Disconnect', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success =
          await ref.read(gmailServiceProvider.notifier).disconnectGmail();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success
                ? 'Gmail disconnected'
                : 'Failed to disconnect. Please try again.'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    }
  }
}
