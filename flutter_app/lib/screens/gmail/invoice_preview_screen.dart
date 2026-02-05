import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/models/gmail_extracted_invoice.dart';
import '../../services/gmail_service.dart';
import '../../services/auth_service.dart';

/// Screen for previewing and editing an extracted invoice before approval
class InvoicePreviewScreen extends ConsumerStatefulWidget {
  final GmailExtractedInvoice invoice;

  const InvoicePreviewScreen({
    super.key,
    required this.invoice,
  });

  @override
  ConsumerState<InvoicePreviewScreen> createState() =>
      _InvoicePreviewScreenState();
}

class _InvoicePreviewScreenState extends ConsumerState<InvoicePreviewScreen> {
  late TextEditingController _merchantNameController;
  late TextEditingController _invoiceNumberController;
  late TextEditingController _totalAmountController;
  late TextEditingController _subtotalController;
  late TextEditingController _taxTotalController;
  late TextEditingController _vendorAddressController;
  late TextEditingController _vendorTaxIdController;
  late TextEditingController _customerNameController;

  DateTime? _invoiceDate;
  DateTime? _dueDate;
  String _currency = 'EUR';

  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  void _initControllers() {
    _merchantNameController =
        TextEditingController(text: widget.invoice.merchantName ?? '');
    _invoiceNumberController =
        TextEditingController(text: widget.invoice.invoiceNumber ?? '');
    _totalAmountController = TextEditingController(
        text: widget.invoice.totalAmount?.toStringAsFixed(2) ?? '');
    _subtotalController = TextEditingController(
        text: widget.invoice.subtotal?.toStringAsFixed(2) ?? '');
    _taxTotalController = TextEditingController(
        text: widget.invoice.taxTotal?.toStringAsFixed(2) ?? '');
    _vendorAddressController =
        TextEditingController(text: widget.invoice.vendorAddress ?? '');
    _vendorTaxIdController =
        TextEditingController(text: widget.invoice.vendorTaxId ?? '');
    _customerNameController =
        TextEditingController(text: widget.invoice.customerName ?? '');

    _invoiceDate = widget.invoice.invoiceDate;
    _dueDate = widget.invoice.dueDate;
    _currency = widget.invoice.currency;

    // Add listeners to track changes
    for (final controller in [
      _merchantNameController,
      _invoiceNumberController,
      _totalAmountController,
      _subtotalController,
      _taxTotalController,
      _vendorAddressController,
      _vendorTaxIdController,
      _customerNameController,
    ]) {
      controller.addListener(_markChanged);
    }
  }

  void _markChanged() {
    if (!_hasChanges) {
      setState(() => _hasChanges = true);
    }
  }

  @override
  void dispose() {
    _merchantNameController.dispose();
    _invoiceNumberController.dispose();
    _totalAmountController.dispose();
    _subtotalController.dispose();
    _taxTotalController.dispose();
    _vendorAddressController.dispose();
    _vendorTaxIdController.dispose();
    _customerNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(extractedInvoicesServiceProvider);
    final canEdit = widget.invoice.canEdit;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Invoice Details'),
        actions: [
          if (canEdit && _hasChanges)
            TextButton(
              onPressed: _resetChanges,
              child: const Text('Reset'),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Email source info
            _buildSourceCard(),
            const SizedBox(height: 16),

            // Original document preview
            if (widget.invoice.originalFileUrl != null)
              _buildDocumentCard(),
            if (widget.invoice.originalFileUrl != null)
              const SizedBox(height: 16),

            // Confidence indicator
            if (widget.invoice.confidence != null) _buildConfidenceCard(),
            const SizedBox(height: 16),

            // Invoice fields
            _buildInvoiceFieldsCard(canEdit),
            const SizedBox(height: 16),

            // Amounts
            _buildAmountsCard(canEdit),
            const SizedBox(height: 16),

            // Vendor info
            _buildVendorCard(canEdit),
            const SizedBox(height: 24),

            // Error display
            if (state.error != null)
              Card(
                color: Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red.shade700),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          state.error!,
                          style: TextStyle(color: Colors.red.shade700),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Action buttons
            if (canEdit) _buildActionButtons(state),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Email Source',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            if (widget.invoice.emailSubject != null)
              _buildInfoRow('Subject', widget.invoice.emailSubject!),
            if (widget.invoice.emailFrom != null)
              _buildInfoRow('From', widget.invoice.emailFrom!),
            if (widget.invoice.emailDate != null)
              _buildInfoRow(
                'Date',
                DateFormat('yyyy-MM-dd HH:mm')
                    .format(widget.invoice.emailDate!),
              ),
            _buildInfoRow('Source', widget.invoice.sourceTypeDisplay),
            if (widget.invoice.attachmentFilename != null)
              _buildInfoRow('Attachment', widget.invoice.attachmentFilename!),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentCard() {
    final url = widget.invoice.originalFileUrl!;
    final filename = widget.invoice.attachmentFilename ?? 'document';
    final isPdf = filename.toLowerCase().endsWith('.pdf');

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  isPdf ? Icons.picture_as_pdf : Icons.image,
                  color: isPdf ? Colors.red : Colors.blue,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Original Document',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      Text(
                        filename,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.open_in_new),
                  onPressed: () => _openDocument(url),
                  tooltip: 'Open in browser',
                ),
              ],
            ),
          ),
          // Image preview (for non-PDF files)
          if (!isPdf)
            ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
              child: Image.network(
                url,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
                headers: _getAuthHeaders(),
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return SizedBox(
                    height: 200,
                    child: Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                            : null,
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 100,
                    color: Colors.grey.shade100,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.broken_image, color: Colors.grey.shade400),
                          const SizedBox(height: 4),
                          Text(
                            'Preview unavailable',
                            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          // PDF placeholder
          if (isPdf)
            Container(
              padding: const EdgeInsets.all(16),
              child: OutlinedButton.icon(
                onPressed: () => _openDocument(url),
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('View PDF'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Map<String, String> _getAuthHeaders() {
    try {
      final authState = ref.read(authServiceProvider);
      final token = authState.session?.accessToken;
      if (token != null) {
        return {'Authorization': 'Bearer $token'};
      }
    } catch (_) {}
    return {};
  }

  Future<void> _openDocument(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open document'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildConfidenceCard() {
    final confidence = widget.invoice.confidence!;
    final isHigh = confidence >= 0.7;

    return Card(
      color: isHigh ? Colors.green.shade50 : Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(
              isHigh ? Icons.verified : Icons.warning_amber,
              color: isHigh ? Colors.green.shade700 : Colors.orange.shade700,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Extraction Confidence: ${(confidence * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color:
                          isHigh ? Colors.green.shade700 : Colors.orange.shade700,
                    ),
                  ),
                  Text(
                    isHigh
                        ? 'High confidence extraction. Please verify the details.'
                        : 'Lower confidence. Please review carefully and correct any errors.',
                    style: TextStyle(
                      fontSize: 12,
                      color:
                          isHigh ? Colors.green.shade600 : Colors.orange.shade600,
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

  Widget _buildInvoiceFieldsCard(bool canEdit) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Invoice Information',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _merchantNameController,
              decoration: const InputDecoration(
                labelText: 'Merchant Name *',
                hintText: 'Enter merchant name',
              ),
              enabled: canEdit,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _invoiceNumberController,
              decoration: const InputDecoration(
                labelText: 'Invoice Number',
                hintText: 'Enter invoice number',
              ),
              enabled: canEdit,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildDateField(
                    label: 'Invoice Date',
                    value: _invoiceDate,
                    enabled: canEdit,
                    onChanged: (date) {
                      setState(() {
                        _invoiceDate = date;
                        _hasChanges = true;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDateField(
                    label: 'Due Date',
                    value: _dueDate,
                    enabled: canEdit,
                    onChanged: (date) {
                      setState(() {
                        _dueDate = date;
                        _hasChanges = true;
                      });
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountsCard(bool canEdit) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Amounts',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                // Currency selector
                DropdownButton<String>(
                  value: _currency,
                  underline: const SizedBox(),
                  items: ['EUR', 'USD', 'GBP', 'SEK', 'NOK', 'DKK']
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: canEdit
                      ? (value) {
                          if (value != null) {
                            setState(() {
                              _currency = value;
                              _hasChanges = true;
                            });
                          }
                        }
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _subtotalController,
                    decoration: const InputDecoration(
                      labelText: 'Subtotal',
                      hintText: '0.00',
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    enabled: canEdit,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _taxTotalController,
                    decoration: const InputDecoration(
                      labelText: 'Tax Total',
                      hintText: '0.00',
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    enabled: canEdit,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _totalAmountController,
              decoration: const InputDecoration(
                labelText: 'Total Amount *',
                hintText: '0.00',
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              enabled: canEdit,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVendorCard(bool canEdit) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Vendor Details',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _vendorAddressController,
              decoration: const InputDecoration(
                labelText: 'Vendor Address',
                hintText: 'Enter address',
              ),
              maxLines: 2,
              enabled: canEdit,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _vendorTaxIdController,
              decoration: const InputDecoration(
                labelText: 'Vendor Tax ID',
                hintText: 'e.g., FI12345678',
              ),
              enabled: canEdit,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _customerNameController,
              decoration: const InputDecoration(
                labelText: 'Customer Name',
                hintText: 'Your company/name',
              ),
              enabled: canEdit,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateField({
    required String label,
    required DateTime? value,
    required bool enabled,
    required ValueChanged<DateTime?> onChanged,
  }) {
    return InkWell(
      onTap: enabled
          ? () async {
              final date = await showDatePicker(
                context: context,
                initialDate: value ?? DateTime.now(),
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              onChanged(date);
            }
          : null,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.calendar_today, size: 18),
        ),
        child: Text(
          value != null
              ? DateFormat('yyyy-MM-dd').format(value)
              : 'Select date',
          style: TextStyle(
            color: value != null ? null : Colors.grey.shade500,
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(ExtractedInvoicesState state) {
    return Row(
      children: [
        // Re-extract button
        Expanded(
          child: OutlinedButton(
            onPressed: state.isProcessing
                ? null
                : () => _reextractInvoice(context),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.blue),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.refresh, color: Colors.blue, size: 20),
                SizedBox(height: 4),
                Text('Re-extract', style: TextStyle(color: Colors.blue, fontSize: 12)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Reject button
        Expanded(
          child: OutlinedButton(
            onPressed: state.isProcessing
                ? null
                : () => _rejectInvoice(context),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.red),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.close, color: Colors.red, size: 20),
                SizedBox(height: 4),
                Text('Reject', style: TextStyle(color: Colors.red, fontSize: 12)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Approve button
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: state.isProcessing
                ? null
                : () => _approveInvoice(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: state.isProcessing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check, size: 20),
                      SizedBox(height: 4),
                      Text('Approve', style: TextStyle(fontSize: 12)),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  void _resetChanges() {
    setState(() {
      _merchantNameController.text = widget.invoice.merchantName ?? '';
      _invoiceNumberController.text = widget.invoice.invoiceNumber ?? '';
      _totalAmountController.text =
          widget.invoice.totalAmount?.toStringAsFixed(2) ?? '';
      _subtotalController.text =
          widget.invoice.subtotal?.toStringAsFixed(2) ?? '';
      _taxTotalController.text =
          widget.invoice.taxTotal?.toStringAsFixed(2) ?? '';
      _vendorAddressController.text = widget.invoice.vendorAddress ?? '';
      _vendorTaxIdController.text = widget.invoice.vendorTaxId ?? '';
      _customerNameController.text = widget.invoice.customerName ?? '';
      _invoiceDate = widget.invoice.invoiceDate;
      _dueDate = widget.invoice.dueDate;
      _currency = widget.invoice.currency;
      _hasChanges = false;
    });
  }

  Map<String, dynamic> _getEdits() {
    return {
      'merchant_name': _merchantNameController.text.trim(),
      'invoice_number': _invoiceNumberController.text.trim().isEmpty
          ? null
          : _invoiceNumberController.text.trim(),
      'total_amount': double.tryParse(_totalAmountController.text),
      'subtotal': double.tryParse(_subtotalController.text),
      'tax_total': double.tryParse(_taxTotalController.text),
      'vendor_address': _vendorAddressController.text.trim().isEmpty
          ? null
          : _vendorAddressController.text.trim(),
      'vendor_tax_id': _vendorTaxIdController.text.trim().isEmpty
          ? null
          : _vendorTaxIdController.text.trim(),
      'customer_name': _customerNameController.text.trim().isEmpty
          ? null
          : _customerNameController.text.trim(),
      'invoice_date': _invoiceDate?.toIso8601String(),
      'due_date': _dueDate?.toIso8601String(),
      'currency': _currency,
    };
  }

  Future<void> _approveInvoice(BuildContext context) async {
    // Validate required fields
    if (_merchantNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Merchant name is required'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_totalAmountController.text.trim().isEmpty ||
        double.tryParse(_totalAmountController.text) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Valid total amount is required'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final success = await ref
        .read(extractedInvoicesServiceProvider.notifier)
        .approveInvoice(widget.invoice.id, edits: _hasChanges ? _getEdits() : null);

    if (context.mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invoice approved and saved!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    }
  }

  Future<void> _reextractInvoice(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Re-extract Invoice?'),
        content: const Text(
          'This will re-analyze the original document and update the extracted data. '
          'Any manual edits will be lost.',
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
          .reextractInvoice(widget.invoice.id);

      if (context.mounted) {
        if (result != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Invoice re-extracted successfully'),
              backgroundColor: Colors.green,
            ),
          );
          // Return the updated invoice to refresh the list
          Navigator.pop(context, true);
        }
      }
    }
  }

  Future<void> _rejectInvoice(BuildContext context) async {
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
          .rejectInvoice(widget.invoice.id);

      if (context.mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Invoice rejected'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        }
      }
    }
  }
}
