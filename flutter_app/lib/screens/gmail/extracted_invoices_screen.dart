import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../data/models/gmail_extracted_invoice.dart';
import '../../services/gmail_service.dart';

/// Screen showing list of extracted invoices from Gmail
class ExtractedInvoicesScreen extends ConsumerStatefulWidget {
  const ExtractedInvoicesScreen({super.key});

  @override
  ConsumerState<ExtractedInvoicesScreen> createState() =>
      _ExtractedInvoicesScreenState();
}

class _ExtractedInvoicesScreenState
    extends ConsumerState<ExtractedInvoicesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _currentFilter;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);

    // Load invoices on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(extractedInvoicesServiceProvider.notifier).loadInvoices();
    });
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      String? filter;
      switch (_tabController.index) {
        case 0:
          filter = null; // All
          break;
        case 1:
          filter = 'pending';
          break;
        case 2:
          filter = 'approved';
          break;
      }
      if (filter != _currentFilter) {
        _currentFilter = filter;
        ref
            .read(extractedInvoicesServiceProvider.notifier)
            .loadInvoices(status: filter);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(extractedInvoicesServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Extracted Invoices'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: state.isLoading
                ? null
                : () => ref
                    .read(extractedInvoicesServiceProvider.notifier)
                    .refresh(status: _currentFilter),
            tooltip: 'Refresh',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'All (${state.invoices.length})'),
            Tab(text: 'Pending (${state.pendingCount})'),
            const Tab(text: 'Approved'),
          ],
        ),
      ),
      body: _buildBody(context, state),
    );
  }

  Widget _buildBody(BuildContext context, ExtractedInvoicesState state) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text(
              state.error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.red.shade700),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => ref
                  .read(extractedInvoicesServiceProvider.notifier)
                  .refresh(status: _currentFilter),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final filteredInvoices = _getFilteredInvoices(state.invoices);

    if (filteredInvoices.isEmpty) {
      return _buildEmptyState(context);
    }

    return RefreshIndicator(
      onRefresh: () => ref
          .read(extractedInvoicesServiceProvider.notifier)
          .refresh(status: _currentFilter),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: filteredInvoices.length,
        itemBuilder: (context, index) {
          return _buildInvoiceCard(context, filteredInvoices[index]);
        },
      ),
    );
  }

  List<GmailExtractedInvoice> _getFilteredInvoices(
      List<GmailExtractedInvoice> invoices) {
    switch (_tabController.index) {
      case 1:
        return invoices
            .where((i) => i.status == ExtractedInvoiceStatus.pending)
            .toList();
      case 2:
        return invoices
            .where((i) => i.status == ExtractedInvoiceStatus.approved)
            .toList();
      default:
        return invoices;
    }
  }

  Widget _buildEmptyState(BuildContext context) {
    String message;
    IconData icon;

    switch (_tabController.index) {
      case 1:
        message = 'No pending invoices';
        icon = Icons.check_circle_outline;
        break;
      case 2:
        message = 'No approved invoices';
        icon = Icons.receipt_long;
        break;
      default:
        message = 'No invoices extracted yet';
        icon = Icons.inbox;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            message,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.grey.shade600,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            _tabController.index == 0
                ? 'Connect Gmail and sync to start extracting invoices'
                : '',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade500,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceCard(BuildContext context, GmailExtractedInvoice invoice) {
    final currencyFormat = NumberFormat.currency(
      symbol: _getCurrencySymbol(invoice.currency),
      decimalDigits: 2,
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => context.push('/gmail/extracted/${invoice.id}', extra: invoice),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with merchant and status
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Source type icon
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _getSourceTypeColor(invoice.sourceType).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getSourceTypeIcon(invoice.sourceType),
                      color: _getSourceTypeColor(invoice.sourceType),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          invoice.merchantName ?? 'Unknown Merchant',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (invoice.invoiceNumber != null)
                          Text(
                            'Invoice #${invoice.invoiceNumber}',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                  _buildStatusChip(invoice.status),
                ],
              ),
              const SizedBox(height: 12),

              // Email info
              if (invoice.emailSubject != null)
                Row(
                  children: [
                    Icon(Icons.email, size: 16, color: Colors.grey.shade500),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        invoice.emailSubject!,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 8),

              // Amount and date row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Amount
                  Text(
                    invoice.totalAmount != null
                        ? currencyFormat.format(invoice.totalAmount)
                        : 'N/A',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),

                  // Date
                  if (invoice.invoiceDate != null)
                    Text(
                      DateFormat('yyyy-MM-dd').format(invoice.invoiceDate!),
                      style: TextStyle(
                        color: Colors.grey.shade600,
                      ),
                    ),
                ],
              ),


              // Action buttons for pending invoices
              if (invoice.status == ExtractedInvoiceStatus.pending) ...[
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () => _reextractInvoice(context, invoice),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Re-extract'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 4),
                    TextButton.icon(
                      onPressed: () => _rejectInvoice(context, invoice),
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Reject'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                    ),
                    const SizedBox(width: 4),
                    ElevatedButton.icon(
                      onPressed: () => _approveInvoice(context, invoice),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Approve'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(ExtractedInvoiceStatus status) {
    Color bgColor;
    Color textColor;
    String label;

    switch (status) {
      case ExtractedInvoiceStatus.pending:
        bgColor = Colors.orange.shade100;
        textColor = Colors.orange.shade800;
        label = 'Pending';
        break;
      case ExtractedInvoiceStatus.approved:
        bgColor = Colors.green.shade100;
        textColor = Colors.green.shade800;
        label = 'Approved';
        break;
      case ExtractedInvoiceStatus.rejected:
        bgColor = Colors.red.shade100;
        textColor = Colors.red.shade800;
        label = 'Rejected';
        break;
      case ExtractedInvoiceStatus.skipped:
        bgColor = Colors.grey.shade100;
        textColor = Colors.grey.shade800;
        label = 'Skipped';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  IconData _getSourceTypeIcon(InvoiceSourceType sourceType) {
    switch (sourceType) {
      case InvoiceSourceType.attachment:
        return Icons.attach_file;
      case InvoiceSourceType.emailBody:
        return Icons.email;
    }
  }

  Color _getSourceTypeColor(InvoiceSourceType sourceType) {
    switch (sourceType) {
      case InvoiceSourceType.attachment:
        return Colors.blue;
      case InvoiceSourceType.emailBody:
        return Colors.purple;
    }
  }

  String _getCurrencySymbol(String currency) {
    switch (currency.toUpperCase()) {
      case 'EUR':
        return '\u20AC';
      case 'USD':
        return '\$';
      case 'GBP':
        return '\u00A3';
      case 'SEK':
      case 'NOK':
      case 'DKK':
        return 'kr';
      default:
        return currency;
    }
  }

  Future<void> _approveInvoice(
      BuildContext context, GmailExtractedInvoice invoice) async {
    final state = ref.read(extractedInvoicesServiceProvider);
    if (state.isProcessing) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve Invoice?'),
        content: Text(
          'This will save the invoice from ${invoice.merchantName ?? 'Unknown'} '
          'for ${invoice.totalAmount != null ? NumberFormat.currency(symbol: _getCurrencySymbol(invoice.currency)).format(invoice.totalAmount) : 'N/A'} '
          'to your invoices list.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Approve'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Server requires edits with total_amount
      final edits = {
        'merchant_name': invoice.merchantName ?? '',
        'invoice_number': invoice.invoiceNumber,
        'total_amount': invoice.totalAmount ?? 0,
        'subtotal': invoice.subtotal,
        'tax_total': invoice.taxTotal,
        'vendor_address': invoice.vendorAddress,
        'vendor_tax_id': invoice.vendorTaxId,
        'customer_name': invoice.customerName,
        'invoice_date': invoice.invoiceDate?.toIso8601String(),
        'due_date': invoice.dueDate?.toIso8601String(),
        'currency': invoice.currency,
      };

      final success = await ref
          .read(extractedInvoicesServiceProvider.notifier)
          .approveInvoice(invoice.id, edits: edits);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success
                ? 'Invoice approved and saved!'
                : 'Failed to approve invoice'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _reextractInvoice(
      BuildContext context, GmailExtractedInvoice invoice) async {
    final state = ref.read(extractedInvoicesServiceProvider);
    if (state.isProcessing) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Re-extract Invoice?'),
        content: const Text(
          'This will re-analyze the original document and update the extracted data.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.blue),
            child: const Text('Re-extract'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final result = await ref
          .read(extractedInvoicesServiceProvider.notifier)
          .reextractInvoice(invoice.id);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result != null
                ? 'Invoice re-extracted successfully'
                : 'Failed to re-extract invoice'),
            backgroundColor: result != null ? Colors.green : Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _rejectInvoice(
      BuildContext context, GmailExtractedInvoice invoice) async {
    final state = ref.read(extractedInvoicesServiceProvider);
    if (state.isProcessing) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Invoice?'),
        content: const Text(
          'This invoice will be marked as rejected and won\'t appear in your pending list.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await ref
          .read(extractedInvoicesServiceProvider.notifier)
          .rejectInvoice(invoice.id);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(success ? 'Invoice rejected' : 'Failed to reject invoice'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    }
  }
}
