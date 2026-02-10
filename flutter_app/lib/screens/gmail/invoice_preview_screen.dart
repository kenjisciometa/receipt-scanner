import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:internet_file/internet_file.dart';
import 'package:pdfx/pdfx.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/models/gmail_extracted_invoice.dart';
import '../../data/models/invoice_summary.dart';
import '../../services/gmail_service.dart';
import '../../services/auth_service.dart';
import '../../services/invoice_cache_service.dart';
import '../../presentation/widgets/duplicate_warning_dialog.dart';

/// Screen for previewing and editing an extracted invoice before approval.
/// Uses a PageView to allow swiping between image/PDF view and details form.
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
  // Current page index (0 = image, 1 = details)
  int _currentPage = 1;

  // Form controllers
  late TextEditingController _merchantNameController;
  late TextEditingController _invoiceNumberController;
  late TextEditingController _totalAmountController;
  late TextEditingController _subtotalController;
  late TextEditingController _taxRateController;
  late TextEditingController _taxTotalController;
  late TextEditingController _vendorAddressController;
  late TextEditingController _vendorTaxIdController;
  late TextEditingController _customerNameController;

  DateTime? _invoiceDate;
  DateTime? _dueDate;
  String _currency = 'EUR';

  bool _hasChanges = false;

  // PDF loading state
  PdfControllerPinch? _pdfController;
  bool _isPdfLoading = false;
  String? _pdfError;

  @override
  void initState() {
    super.initState();
    _initControllers();
    _preloadPdfIfNeeded();
  }

  void _initControllers() {
    _merchantNameController =
        TextEditingController(text: widget.invoice.merchantName ?? '');
    _invoiceNumberController =
        TextEditingController(text: widget.invoice.invoiceNumber ?? '');
    final totalAmountText = widget.invoice.totalAmount?.toStringAsFixed(2) ?? '';
    debugPrint('Init totalAmount: ${widget.invoice.totalAmount}, text: "$totalAmountText"');
    _totalAmountController = TextEditingController(text: totalAmountText);
    _subtotalController = TextEditingController(
        text: widget.invoice.subtotal?.toStringAsFixed(2) ?? '');
    // Get tax rate from tax_breakdown if available
    final taxBreakdown = widget.invoice.rawExtractedData?['tax_breakdown'];
    String taxRateText = '';
    if (taxBreakdown is List && taxBreakdown.isNotEmpty) {
      final firstRate = taxBreakdown[0]['rate'];
      if (firstRate != null) {
        taxRateText = firstRate is num
            ? (firstRate == firstRate.truncate() ? firstRate.toInt().toString() : firstRate.toString())
            : firstRate.toString();
      }
    }
    _taxRateController = TextEditingController(text: taxRateText);
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
      _taxRateController,
      _taxTotalController,
      _vendorAddressController,
      _vendorTaxIdController,
      _customerNameController,
    ]) {
      controller.addListener(_markChanged);
    }
  }

  void _preloadPdfIfNeeded() {
    final url = widget.invoice.originalFileUrl;
    final filename = widget.invoice.attachmentFilename ?? '';
    final isPdf = filename.toLowerCase().endsWith('.pdf');

    if (url != null && isPdf) {
      _loadPdfDocument(url);
    }
  }

  Future<void> _loadPdfDocument(String url) async {
    if (_isPdfLoading) return;

    setState(() {
      _isPdfLoading = true;
      _pdfError = null;
    });

    try {
      final token = ref.read(authServiceProvider).session?.accessToken;
      final headers = token != null ? {'Authorization': 'Bearer $token'} : <String, String>{};

      final pdfBytes = await InternetFile.get(url, headers: headers);
      final document = await PdfDocument.openData(pdfBytes);

      if (mounted) {
        setState(() {
          _pdfController = PdfControllerPinch(
            document: Future.value(document),
          );
          _isPdfLoading = false;
        });
      } else {
        document.close();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _pdfError = 'Failed to load PDF: $e';
          _isPdfLoading = false;
        });
      }
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
    _taxRateController.dispose();
    _taxTotalController.dispose();
    _vendorAddressController.dispose();
    _vendorTaxIdController.dispose();
    _customerNameController.dispose();
    _pdfController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasDocument = widget.invoice.originalFileUrl != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Invoice Details'),
        actions: [
          if (widget.invoice.canEdit && _hasChanges)
            TextButton(
              onPressed: _resetChanges,
              child: const Text('Reset'),
            ),
        ],
      ),
      body: hasDocument
          ? Column(
              children: [
                // Page indicator at top for better visibility
                _buildPageIndicator(),
                // Swipeable content with IndexedStack to preserve state
                Expanded(
                  child: GestureDetector(
                    onHorizontalDragEnd: (details) {
                      if (details.primaryVelocity == null) return;
                      // Swipe left (next page)
                      if (details.primaryVelocity! < -200 && _currentPage < 1) {
                        setState(() => _currentPage = 1);
                      }
                      // Swipe right (previous page)
                      if (details.primaryVelocity! > 200 && _currentPage > 0) {
                        setState(() => _currentPage = 0);
                      }
                    },
                    child: IndexedStack(
                      index: _currentPage,
                      children: [
                        _buildImagePage(),
                        _buildDetailsPage(),
                      ],
                    ),
                  ),
                ),
              ],
            )
          : _buildDetailsPage(), // No document, just show details
    );
  }

  Widget _buildImagePage() {
    final url = widget.invoice.originalFileUrl;
    if (url == null) return _buildNoImagePlaceholder();

    final filename = widget.invoice.attachmentFilename ?? 'document';
    final isPdf = filename.toLowerCase().endsWith('.pdf');

    return Column(
      children: [
        // Document header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Row(
            children: [
              Icon(
                isPdf ? Icons.picture_as_pdf : Icons.image,
                color: isPdf ? Colors.red : Colors.blue,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  filename,
                  style: const TextStyle(fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.open_in_new, size: 20),
                onPressed: () => _openDocument(url),
                tooltip: 'Open in browser',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
        // Document view
        Expanded(
          child: isPdf ? _buildPdfView() : _buildImageView(url),
        ),
      ],
    );
  }

  Widget _buildPdfView() {
    if (_isPdfLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading PDF...'),
          ],
        ),
      );
    }

    if (_pdfError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
              const SizedBox(height: 16),
              Text(
                'Could not load PDF',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _pdfError!,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () {
                  _pdfController?.dispose();
                  _pdfController = null;
                  final url = widget.invoice.originalFileUrl;
                  if (url != null) _loadPdfDocument(url);
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_pdfController == null) {
      return const Center(child: Text('No PDF loaded'));
    }

    return PdfViewPinch(
      controller: _pdfController!,
      builders: PdfViewPinchBuilders<DefaultBuilderOptions>(
        options: const DefaultBuilderOptions(),
        documentLoaderBuilder: (_) =>
            const Center(child: CircularProgressIndicator()),
        pageLoaderBuilder: (_) =>
            const Center(child: CircularProgressIndicator()),
        errorBuilder: (_, error) => Center(
          child: Text(
            'Error: $error',
            style: TextStyle(color: Colors.red.shade700),
          ),
        ),
      ),
    );
  }

  Widget _buildImageView(String url) {
    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 4.0,
      child: Center(
        child: Image.network(
          url,
          headers: _getAuthHeaders(),
          fit: BoxFit.contain,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null,
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.broken_image,
                      size: 48, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'Could not load image',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildNoImagePlaceholder() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.image_not_supported, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'No document available',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsPage() {
    final state = ref.watch(extractedInvoicesServiceProvider);
    final canEdit = widget.invoice.canEdit;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Email source info
          _buildSourceCard(),
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
          if (state.error != null) const SizedBox(height: 16),

          // Action buttons
          if (canEdit) _buildActionButtons(state),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildPageIndicator() {
    final hasDocument = widget.invoice.originalFileUrl != null;
    if (!hasDocument) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300, width: 1),
        ),
      ),
      child: Row(
        children: [
          // Left arrow - tap to go to Document
          GestureDetector(
            onTap: _currentPage == 1 ? () => setState(() => _currentPage = 0) : null,
            child: AnimatedOpacity(
              opacity: _currentPage == 1 ? 1.0 : 0.3,
              duration: const Duration(milliseconds: 200),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(
                  Icons.chevron_left,
                  color: _currentPage == 1 ? Theme.of(context).colorScheme.primary : Colors.grey,
                  size: 28,
                ),
              ),
            ),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildTabButton(0, Icons.description, 'Document'),
                const SizedBox(width: 8),
                Icon(Icons.swap_horiz, color: Colors.grey.shade400, size: 20),
                const SizedBox(width: 8),
                _buildTabButton(1, Icons.edit_note, 'Details'),
              ],
            ),
          ),
          // Right arrow - tap to go to Details
          GestureDetector(
            onTap: _currentPage == 0 ? () => setState(() => _currentPage = 1) : null,
            child: AnimatedOpacity(
              opacity: _currentPage == 0 ? 1.0 : 0.3,
              duration: const Duration(milliseconds: 200),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(
                  Icons.chevron_right,
                  color: _currentPage == 0 ? Theme.of(context).colorScheme.primary : Colors.grey,
                  size: 28,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(int index, IconData icon, String label) {
    final isActive = _currentPage == index;
    return GestureDetector(
      onTap: () {
        if (_currentPage != index) {
          setState(() => _currentPage = index);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? Theme.of(context).colorScheme.primary
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive
                ? Theme.of(context).colorScheme.primary
                : Colors.grey.shade400,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isActive ? Colors.white : Colors.grey.shade600,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                color: isActive ? Colors.white : Colors.grey.shade600,
              ),
            ),
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
    // Extract tax_breakdown from rawExtractedData
    final taxBreakdown = _getTaxBreakdown();

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
            // Subtotal
            TextField(
              controller: _subtotalController,
              decoration: const InputDecoration(
                labelText: 'Subtotal (Net)',
                hintText: '0.00',
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              enabled: canEdit,
            ),
            const SizedBox(height: 12),
            // VAT Rate and Tax Total in a row
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _taxRateController,
                    decoration: const InputDecoration(
                      labelText: 'VAT Rate (%)',
                      hintText: '24',
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
            // Tax breakdown display (if available from extraction)
            if (taxBreakdown.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Extracted VAT Breakdown',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...taxBreakdown.map((item) => _buildTaxBreakdownRow(item)),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            // Total Amount
            TextField(
              controller: _totalAmountController,
              decoration: const InputDecoration(
                labelText: 'Total Amount (Gross) *',
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

  /// Get tax breakdown from rawExtractedData
  List<Map<String, dynamic>> _getTaxBreakdown() {
    final rawData = widget.invoice.rawExtractedData;
    debugPrint('[InvoicePreview] rawExtractedData: $rawData');
    if (rawData == null) {
      debugPrint('[InvoicePreview] rawExtractedData is null');
      return [];
    }

    final breakdown = rawData['tax_breakdown'];
    debugPrint('[InvoicePreview] tax_breakdown: $breakdown');
    if (breakdown is List) {
      final result = breakdown
          .whereType<Map<String, dynamic>>()
          .where((item) => item['rate'] != null)
          .toList();
      debugPrint('[InvoicePreview] parsed tax_breakdown: $result');
      return result;
    }
    return [];
  }

  /// Build a row for tax breakdown display
  Widget _buildTaxBreakdownRow(Map<String, dynamic> item) {
    final rate = item['rate'];
    final taxAmount = item['tax_amount'];
    final taxableAmount = item['taxable_amount'];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'VAT ${rate is num ? rate.toStringAsFixed(rate.truncateToDouble() == rate ? 0 : 1) : rate}%',
            style: const TextStyle(fontSize: 14),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${_formatAmount(taxAmount)} $_currency',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (taxableAmount != null)
                Text(
                  'on ${_formatAmount(taxableAmount)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// Format amount for display
  String _formatAmount(dynamic amount) {
    if (amount == null) return '0.00';
    if (amount is num) return amount.toStringAsFixed(2);
    return amount.toString();
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

  void _resetChanges() {
    setState(() {
      _merchantNameController.text = widget.invoice.merchantName ?? '';
      _invoiceNumberController.text = widget.invoice.invoiceNumber ?? '';
      _totalAmountController.text =
          widget.invoice.totalAmount?.toStringAsFixed(2) ?? '';
      _subtotalController.text =
          widget.invoice.subtotal?.toStringAsFixed(2) ?? '';
      // Reset tax rate from tax_breakdown if available
      final taxBreakdown = widget.invoice.rawExtractedData?['tax_breakdown'];
      String taxRateText = '';
      if (taxBreakdown is List && taxBreakdown.isNotEmpty) {
        final firstRate = taxBreakdown[0]['rate'];
        if (firstRate != null) {
          taxRateText = firstRate is num
              ? (firstRate == firstRate.truncate() ? firstRate.toInt().toString() : firstRate.toString())
              : firstRate.toString();
        }
      }
      _taxRateController.text = taxRateText;
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
      'tax_rate': double.tryParse(_taxRateController.text),
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

    // Require total amount (0 is allowed, but empty is not)
    final totalText = _totalAmountController.text.trim();
    debugPrint('Total amount text: "$totalText", parsed: ${double.tryParse(totalText)}');
    if (totalText.isEmpty || double.tryParse(totalText) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Total amount is required (got: "$totalText")'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Check for duplicates before saving
    final cacheService = ref.read(invoiceCacheServiceProvider.notifier);
    final duplicates = cacheService.findDuplicates(
      totalAmount: double.tryParse(totalText),
      invoiceDate: _invoiceDate,
      invoiceNumber: _invoiceNumberController.text.trim().isEmpty
          ? null
          : _invoiceNumberController.text.trim(),
    );

    if (duplicates.isNotEmpty && context.mounted) {
      final result = await DuplicateWarningDialog.show(
        context,
        duplicates: duplicates,
      );

      if (result == null) {
        // User cancelled
        return;
      } else if (result is String) {
        // User wants to view existing invoice - navigate to history
        if (context.mounted) {
          context.push('/history', extra: result);
        }
        return;
      }
      // result == true means user chose "Save Anyway"
    }

    // Always send current values (server requires total_amount)
    final success = await ref
        .read(extractedInvoicesServiceProvider.notifier)
        .approveInvoice(widget.invoice.id, edits: _getEdits());

    if (context.mounted) {
      if (success) {
        // Add to cache after successful save
        cacheService.addToCache(InvoiceSummary(
          id: widget.invoice.id,
          merchantName: _merchantNameController.text.trim(),
          invoiceNumber: _invoiceNumberController.text.trim().isEmpty
              ? null
              : _invoiceNumberController.text.trim(),
          invoiceDate: _invoiceDate,
          totalAmount: double.tryParse(totalText),
          currency: _currency,
          source: InvoiceSource.gmail,
        ));

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
