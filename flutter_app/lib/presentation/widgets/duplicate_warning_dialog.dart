import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/models/invoice_summary.dart';

/// Dialog shown when potential duplicate invoices are detected.
///
/// Displays the matching invoice(s) and allows the user to:
/// - Cancel the save operation
/// - View the existing invoice (returns viewId)
/// - Save anyway (returns true)
class DuplicateWarningDialog extends StatelessWidget {
  final List<DuplicateMatch> duplicates;

  const DuplicateWarningDialog({
    super.key,
    required this.duplicates,
  });

  /// Show the dialog and return the result.
  ///
  /// Returns:
  /// - null: User cancelled
  /// - true: User chose to save anyway
  /// - String: ID of invoice to view
  static Future<dynamic> show(
    BuildContext context, {
    required List<DuplicateMatch> duplicates,
  }) {
    return showDialog<dynamic>(
      context: context,
      barrierDismissible: false,
      builder: (context) => DuplicateWarningDialog(
        duplicates: duplicates,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: Colors.orange.shade700,
            size: 28,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Possible Duplicate Found',
              style: TextStyle(fontSize: 18),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              duplicates.length == 1
                  ? 'This invoice may already exist:'
                  : 'This invoice may match ${duplicates.length} existing invoices:',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            // Show up to 3 duplicates
            ...duplicates.take(3).map((match) => _buildMatchCard(context, match)),
            if (duplicates.length > 3)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '...and ${duplicates.length - 3} more',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        // Cancel button
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('Cancel'),
        ),
        // View Existing button (for first duplicate only)
        if (duplicates.isNotEmpty)
          OutlinedButton(
            onPressed: () => Navigator.pop(context, duplicates.first.invoice.id),
            child: const Text('View Existing'),
          ),
        // Save Anyway button
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange.shade700,
            foregroundColor: Colors.white,
          ),
          child: const Text('Save Anyway'),
        ),
      ],
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    );
  }

  Widget _buildMatchCard(BuildContext context, DuplicateMatch match) {
    final invoice = match.invoice;
    final dateFormat = DateFormat('yyyy-MM-dd');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Vendor name
            Row(
              children: [
                const Icon(Icons.description, size: 18, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    invoice.merchantName ?? 'Unknown Vendor',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Invoice details
            if (invoice.invoiceNumber != null)
              _buildDetailRow('Invoice #', invoice.invoiceNumber!),
            if (invoice.invoiceDate != null)
              _buildDetailRow('Date', dateFormat.format(invoice.invoiceDate!)),
            if (invoice.totalAmount != null)
              _buildDetailRow(
                'Total',
                '${invoice.currency} ${invoice.totalAmount!.toStringAsFixed(2)}',
              ),
            _buildDetailRow('Source', invoice.source.displayName),
            const SizedBox(height: 8),
            // Matched fields indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.link,
                    size: 14,
                    color: Colors.orange.shade800,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Matched: ${match.matchDescription}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange.shade800,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

/// Helper function to check for duplicates and show warning dialog if needed.
///
/// Returns true if the save should proceed (no duplicates or user chose to save anyway).
/// Returns false if the save should be cancelled.
/// Returns the invoice ID if user wants to view an existing invoice.
Future<dynamic> checkDuplicatesAndWarn(
  BuildContext context, {
  required List<DuplicateMatch> duplicates,
}) async {
  if (duplicates.isEmpty) {
    return true; // No duplicates, proceed with save
  }

  return DuplicateWarningDialog.show(
    context,
    duplicates: duplicates,
  );
}
