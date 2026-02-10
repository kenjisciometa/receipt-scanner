import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../services/invoice_repository.dart';
import '../../services/image_storage_service.dart';
import '../../services/auth_service.dart';
import '../../presentation/widgets/receipt_edit_dialogs.dart';
import '../../presentation/widgets/common_widgets.dart';
import '../../presentation/widgets/file_viewer_widget.dart';

final invoiceRepositoryProvider = Provider((ref) {
  final authState = ref.watch(authServiceProvider);
  final user = authState.user;
  if (user == null) {
    throw Exception('User not authenticated');
  }
  return InvoiceRepository(
    userId: user.id,
    organizationId: user.organizationId,
  );
});

final invoicesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final authState = ref.watch(authServiceProvider);
  if (authState.user == null) return [];
  final repository = ref.watch(invoiceRepositoryProvider);
  return repository.getInvoices();
});

final invoiceStatisticsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final repository = ref.watch(invoiceRepositoryProvider);
  return repository.getStatistics();
});

class InvoiceHistoryScreen extends ConsumerStatefulWidget {
  const InvoiceHistoryScreen({super.key});

  @override
  ConsumerState<InvoiceHistoryScreen> createState() => _InvoiceHistoryScreenState();
}

class _InvoiceHistoryScreenState extends ConsumerState<InvoiceHistoryScreen> {
  String _selectedFilter = 'All';
  DateTimeRange? _customDateRange;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(invoicesProvider);
      ref.invalidate(invoiceStatisticsProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final invoicesAsync = ref.watch(invoicesProvider);
    final statsAsync = ref.watch(invoiceStatisticsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Invoice History'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(invoicesProvider);
          ref.invalidate(invoiceStatisticsProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Statistics
              Text(
                'Statistics',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              statsAsync.when(
                data: (stats) => Row(
                  children: [
                    Expanded(
                      child: StatCard(
                        title: 'Total',
                        value: '€${stats['total_amount']?.toStringAsFixed(2) ?? '0.00'}',
                        icon: Icons.euro,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: StatCard(
                        title: 'Tax',
                        value: '€${stats['total_tax']?.toStringAsFixed(2) ?? '0.00'}',
                        icon: Icons.receipt_long,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: StatCard(
                        title: 'Invoices',
                        value: '${stats['invoice_count'] ?? 0}',
                        icon: Icons.description,
                      ),
                    ),
                  ],
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Error: $e'),
              ),
              const SizedBox(height: 24),

              // Invoice history
              Text(
                'Invoice History',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),

              // Date filter chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ...['All', 'Today', 'Last 7 days', 'This month'].map((filter) {
                      final isSelected = _selectedFilter == filter;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(filter),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              _selectedFilter = filter;
                              _customDateRange = null;
                            });
                          },
                          selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
                          checkmarkColor: Theme.of(context).primaryColor,
                        ),
                      );
                    }),
                    // Custom date range chip
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(_customDateRange != null
                            ? '${_customDateRange!.start.day}.${_customDateRange!.start.month} - ${_customDateRange!.end.day}.${_customDateRange!.end.month}'
                            : 'Custom'),
                        selected: _selectedFilter == 'Custom',
                        onSelected: (selected) async {
                          final range = await showDateRangePicker(
                            context: context,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                            initialDateRange: _customDateRange,
                          );
                          if (range != null) {
                            setState(() {
                              _selectedFilter = 'Custom';
                              _customDateRange = range;
                            });
                          }
                        },
                        selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
                        checkmarkColor: Theme.of(context).primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              invoicesAsync.when(
                data: (invoices) {
                  if (invoices.isEmpty) {
                    return const Card(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(
                          child: Text('No invoices yet. Scan your first invoice!'),
                        ),
                      ),
                    );
                  }
                  // Filter invoices
                  final filtered = _filterInvoicesByDate(invoices, _selectedFilter);

                  if (filtered.isEmpty) {
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Center(
                          child: Text('No invoices match the selected filters'),
                        ),
                      ),
                    );
                  }
                  return Column(
                    children: filtered.map((invoice) => InvoiceCard(invoice: invoice)).toList(),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Error loading invoices: $e'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _filterInvoicesByDate(List<Map<String, dynamic>> invoices, String filter) {
    if (filter == 'All') return invoices;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final last7Days = today.subtract(const Duration(days: 7));
    final thisMonthStart = DateTime(now.year, now.month, 1);

    return invoices.where((invoice) {
      final createdAt = invoice['created_at'] != null
          ? DateTime.tryParse(invoice['created_at'])
          : null;

      if (createdAt == null) return false;

      final addedDay = DateTime(createdAt.year, createdAt.month, createdAt.day);

      switch (filter) {
        case 'Today':
          return addedDay == today;
        case 'Last 7 days':
          return addedDay.isAfter(last7Days) || addedDay == last7Days;
        case 'This month':
          return addedDay.isAfter(thisMonthStart) || addedDay == thisMonthStart;
        case 'Custom':
          if (_customDateRange == null) return true;
          final rangeStart = DateTime(_customDateRange!.start.year, _customDateRange!.start.month, _customDateRange!.start.day);
          final rangeEnd = DateTime(_customDateRange!.end.year, _customDateRange!.end.month, _customDateRange!.end.day);
          return (addedDay.isAfter(rangeStart) || addedDay == rangeStart) &&
                 (addedDay.isBefore(rangeEnd) || addedDay == rangeEnd);
        default:
          return true;
      }
    }).toList();
  }
}

class InvoiceCard extends ConsumerStatefulWidget {
  final Map<String, dynamic> invoice;
  final bool initiallyExpanded;
  final bool isHighlighted;

  const InvoiceCard({
    super.key,
    required this.invoice,
    this.initiallyExpanded = false,
    this.isHighlighted = false,
  });

  @override
  ConsumerState<InvoiceCard> createState() => _InvoiceCardState();
}

class _InvoiceCardState extends ConsumerState<InvoiceCard> {
  bool _isEditMode = false;

  Map<String, dynamic> get invoice => widget.invoice;

  @override
  Widget build(BuildContext context) {
    final merchantName = invoice['merchant_name'] ?? 'Unknown Vendor';
    final customerName = invoice['customer_name'];
    final invoiceNumber = invoice['invoice_number'];
    final total = invoice['total_amount'] as num?;
    final tax = invoice['tax_amount'] as num?;
    final currency = invoice['currency'] ?? 'EUR';
    final taxBreakdown = invoice['tax_breakdown'] as List<dynamic>?;
    final invoiceDate = invoice['invoice_date'] != null
        ? DateTime.tryParse(invoice['invoice_date'])
        : null;
    final dueDate = invoice['due_date'] != null
        ? DateTime.tryParse(invoice['due_date'])
        : null;
    final createdAt = invoice['created_at'] != null
        ? DateTime.parse(invoice['created_at'])
        : null;

    String currencySymbol = currency == 'EUR' ? '€' : currency;

    String formatDate(DateTime? date) {
      if (date == null) return 'Unknown date';
      return '${date.day}.${date.month}.${date.year}';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      // Highlight with orange border when this is the duplicate match
      shape: widget.isHighlighted
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.orange.shade600, width: 2),
            )
          : null,
      color: widget.isHighlighted ? Colors.orange.shade50 : null,
      child: ExpansionTile(
        initiallyExpanded: widget.initiallyExpanded,
        leading: CircleAvatar(
          backgroundColor: widget.isHighlighted ? Colors.orange.shade200 : null,
          child: Icon(
            Icons.description,
            color: widget.isHighlighted ? Colors.orange.shade800 : null,
          ),
        ),
        title: Text(
          merchantName,
          maxLines: 2,
          softWrap: true,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (invoiceNumber != null)
              Text('Invoice #$invoiceNumber', style: const TextStyle(fontSize: 12)),
            Text(formatDate(invoiceDate ?? createdAt)),
          ],
        ),
        trailing: Text(
          '$currencySymbol${total?.toStringAsFixed(2) ?? '0.00'}',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_isEditMode) ...[
                  // Edit mode - editable fields
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Edit Invoice', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      TextButton.icon(
                        onPressed: () => setState(() => _isEditMode = false),
                        icon: const Icon(Icons.close, size: 18),
                        label: const Text('Done'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Merchant name
                  EditableField(
                    label: 'Vendor',
                    value: merchantName,
                    icon: Icons.store,
                    onTap: () => _editMerchantName(context, ref, merchantName),
                  ),
                  const SizedBox(height: 8),

                  // Vendor Address
                  EditableField(
                    label: 'Address',
                    value: invoice['vendor_address'] ?? 'Not set',
                    icon: Icons.location_on,
                    onTap: () => _editVendorAddress(context, ref, invoice['vendor_address']),
                  ),
                  const SizedBox(height: 8),

                  // Invoice Number
                  EditableField(
                    label: 'Invoice #',
                    value: invoiceNumber ?? 'Not set',
                    icon: Icons.numbers,
                    onTap: () => _editInvoiceNumber(context, ref, invoiceNumber),
                  ),
                  const SizedBox(height: 8),

                  // Invoice Date
                  EditableField(
                    label: 'Invoice Date',
                    value: formatDate(invoiceDate),
                    icon: Icons.calendar_today,
                    onTap: () => _editInvoiceDate(context, ref, invoiceDate),
                  ),
                  const SizedBox(height: 8),

                  // Due Date
                  EditableField(
                    label: 'Due Date',
                    value: formatDate(dueDate),
                    icon: Icons.event,
                    onTap: () => _editDueDate(context, ref, dueDate),
                  ),
                  const SizedBox(height: 8),

                  // Tax
                  EditableField(
                    label: 'Tax',
                    value: '$currencySymbol${tax?.toStringAsFixed(2) ?? '0.00'}',
                    icon: Icons.percent,
                    onTap: () => _editAmount(context, ref, 'tax_amount', 'Tax', tax?.toDouble()),
                  ),
                  const SizedBox(height: 8),

                  // Total
                  EditableField(
                    label: 'Total',
                    value: '$currencySymbol${total?.toStringAsFixed(2) ?? '0.00'}',
                    icon: Icons.payments,
                    onTap: () => _editAmount(context, ref, 'total_amount', 'Total', total?.toDouble()),
                    isBold: true,
                  ),

                  // Tax breakdown
                  if (taxBreakdown != null && taxBreakdown.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    EditableField(
                      label: 'Tax Breakdown',
                      value: '${taxBreakdown.length} tax rate(s)',
                      icon: Icons.list_alt,
                      onTap: () => _editTaxBreakdown(context, ref, taxBreakdown),
                    ),
                  ],
                ] else ...[
                  // Normal view - read-only display
                  // Vendor info
                  if (invoice['vendor_address'] != null || invoice['vendor_tax_id'] != null) ...[
                    const Text('Vendor', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 4),
                    if (invoice['vendor_address'] != null)
                      DetailRow(
                        label: 'Address',
                        value: (invoice['vendor_address'] as String).split(',').map((s) => s.trim()).join('\n'),
                      ),
                    if (invoice['vendor_tax_id'] != null)
                      DetailRow(label: 'Tax ID', value: invoice['vendor_tax_id']),
                    const SizedBox(height: 12),
                  ],

                  // Customer info
                  if (customerName != null) ...[
                    const Text('Customer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 4),
                    DetailRow(label: 'Name', value: customerName),
                    const SizedBox(height: 12),
                  ],

                  // Dates
                  const Text('Dates', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 4),
                  if (invoiceDate != null)
                    DetailRow(label: 'Invoice Date', value: formatDate(invoiceDate)),
                  if (dueDate != null)
                    DetailRow(
                      label: 'Due Date',
                      value: formatDate(dueDate),
                    ),
                  const SizedBox(height: 12),

                  // Amounts
                  const Text('Amounts', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 4),
                  DetailRow(label: 'Tax', value: '$currencySymbol${tax?.toStringAsFixed(2) ?? '0.00'}'),
                  DetailRow(label: 'Total', value: '$currencySymbol${total?.toStringAsFixed(2) ?? '0.00'}', isBold: true),

                  // Tax breakdown
                  if (taxBreakdown != null && taxBreakdown.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Divider(),
                    const Text('Tax Breakdown:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 4),
                    ...taxBreakdown.map((taxItem) {
                      final rate = (taxItem['rate'] as num?)?.toDouble() ?? 0;
                      final taxAmount = (taxItem['tax_amount'] as num?)?.toDouble();
                      final grossAmount = (taxItem['gross_amount'] as num?)?.toDouble();

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('$rate%', style: const TextStyle(fontSize: 13)),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                if (grossAmount != null)
                                  Text('Gross: $currencySymbol${grossAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 13)),
                                Text(
                                  'Tax: $currencySymbol${taxAmount?.toStringAsFixed(2) ?? '0.00'}',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ],

                // Action buttons
                const SizedBox(height: 20),
                Row(
                  children: [
                    // Edit button
                    if (!_isEditMode) ...[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => setState(() => _isEditMode = true),
                          icon: Icon(Icons.edit, size: 18, color: Theme.of(context).primaryColor),
                          label: Text('Edit', style: TextStyle(color: Theme.of(context).primaryColor)),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Theme.of(context).primaryColor),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    // View image button
                    if (invoice['original_image_url'] != null) ...[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _showImageDialog(context, invoice['original_image_url']),
                          icon: const Icon(Icons.image, size: 18),
                          label: const Text('Image'),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    // Delete button
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _confirmDelete(context, ref),
                        icon: const Icon(Icons.delete, color: Colors.red, size: 18),
                        label: const Text('Delete', style: TextStyle(color: Colors.red)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.red),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editMerchantName(BuildContext context, WidgetRef ref, String currentValue) async {
    final result = await ReceiptEditDialogs.editText(
      context: context,
      title: 'Edit Vendor Name',
      label: 'Vendor Name',
      currentValue: currentValue,
    );

    if (result != null && result.isNotEmpty && context.mounted) {
      await _updateInvoice(context, ref, merchantName: result);
    }
  }

  Future<void> _editVendorAddress(BuildContext context, WidgetRef ref, String? currentValue) async {
    final result = await ReceiptEditDialogs.editText(
      context: context,
      title: 'Edit Vendor Address',
      label: 'Address',
      currentValue: currentValue ?? '',
    );

    if (result != null && context.mounted) {
      await _updateInvoice(context, ref, vendorAddress: result.isEmpty ? null : result);
    }
  }

  Future<void> _editInvoiceNumber(BuildContext context, WidgetRef ref, String? currentValue) async {
    final result = await ReceiptEditDialogs.editText(
      context: context,
      title: 'Edit Invoice Number',
      label: 'Invoice Number',
      currentValue: currentValue ?? '',
    );

    if (result != null && context.mounted) {
      await _updateInvoice(context, ref, invoiceNumber: result.isEmpty ? null : result);
    }
  }

  Future<void> _editInvoiceDate(BuildContext context, WidgetRef ref, DateTime? currentDate) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: currentDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (pickedDate != null && context.mounted) {
      await _updateInvoice(context, ref, invoiceDate: pickedDate);
    }
  }

  Future<void> _editDueDate(BuildContext context, WidgetRef ref, DateTime? currentDate) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: currentDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );

    if (pickedDate != null && context.mounted) {
      await _updateInvoice(context, ref, dueDate: pickedDate);
    }
  }

  Future<void> _editAmount(BuildContext context, WidgetRef ref, String field, String label, double? currentValue) async {
    final result = await ReceiptEditDialogs.editAmount(
      context: context,
      title: 'Edit $label',
      label: label,
      currentValue: currentValue,
    );

    if (result != null && context.mounted) {
      switch (field) {
        case 'tax_amount':
          await _updateInvoice(context, ref, taxAmount: result);
          break;
        case 'total_amount':
          await _updateInvoice(context, ref, totalAmount: result);
          break;
      }
    }
  }

  Future<void> _editTaxBreakdown(BuildContext context, WidgetRef ref, List<dynamic> currentBreakdown) async {
    final result = await ReceiptEditDialogs.editTaxBreakdown(
      context: context,
      currentBreakdown: currentBreakdown,
    );

    if (result != null && context.mounted) {
      await _updateInvoice(context, ref, taxBreakdown: result);
    }
  }

  Future<void> _updateInvoice(
    BuildContext context,
    WidgetRef ref, {
    String? merchantName,
    String? vendorAddress,
    String? invoiceNumber,
    DateTime? invoiceDate,
    DateTime? dueDate,
    double? taxAmount,
    double? totalAmount,
    List<Map<String, dynamic>>? taxBreakdown,
  }) async {
    try {
      final repository = ref.read(invoiceRepositoryProvider);
      await repository.updateInvoice(
        id: invoice['id'],
        merchantName: merchantName,
        vendorAddress: vendorAddress,
        invoiceNumber: invoiceNumber,
        invoiceDate: invoiceDate,
        dueDate: dueDate,
        taxAmount: taxAmount,
        totalAmount: totalAmount,
        taxBreakdown: taxBreakdown,
      );
      ref.invalidate(invoicesProvider);
      ref.invalidate(invoiceStatisticsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invoice updated'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<Uint8List?> _getImageWithAuth(String imageUrl) async {
    final authService = ref.read(authServiceProvider.notifier);
    final authHeaders = await authService.getAuthHeaders();
    return ImageStorageService.getImage(imageUrl, authHeaders: authHeaders);
  }

  void _showImageDialog(BuildContext context, String imageUrl) {
    final isPdf = isPdfUrl(imageUrl);
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: Text(isPdf ? 'Invoice PDF' : 'Invoice Image'),
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.save_alt),
                  tooltip: 'Save to device',
                  onPressed: () => _saveImageToDevice(context, imageUrl),
                ),
              ],
            ),
            Flexible(
              child: FutureBuilder<Uint8List?>(
                future: _getImageWithAuth(imageUrl),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }
                  if (snapshot.hasError || snapshot.data == null) {
                    return Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error, size: 48, color: Colors.red),
                          const SizedBox(height: 8),
                          Text('Failed to load file:\n${snapshot.error ?? "Unknown error"}', textAlign: TextAlign.center),
                        ],
                      ),
                    );
                  }
                  return FileViewerWidget(
                    data: snapshot.data!,
                    fit: BoxFit.contain,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveImageToDevice(BuildContext context, String imageUrl) async {
    final isPdf = isPdfUrl(imageUrl);
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Downloading ${isPdf ? 'PDF' : 'image'}...'), duration: const Duration(seconds: 1)),
      );

      final fileBytes = await _getImageWithAuth(imageUrl);
      if (fileBytes == null) {
        throw Exception('Failed to download file');
      }

      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = isPdf ? 'pdf' : 'jpg';
      final filePath = '${directory.path}/invoice_$timestamp.$extension';

      final file = File(filePath);
      await file.writeAsBytes(fileBytes);

      if (!context.mounted) return;

      await Share.shareXFiles(
        [XFile(filePath)],
        text: isPdf ? 'Invoice PDF' : 'Invoice image',
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await ReceiptEditDialogs.confirmAction(
      context: context,
      title: 'Delete Invoice?',
      message: 'Are you sure you want to delete this invoice? This action cannot be undone.',
      confirmText: 'Delete',
      confirmColor: Colors.red,
    );

    if (confirmed) {
      try {
        final repository = ref.read(invoiceRepositoryProvider);
        await repository.deleteInvoice(invoice['id']);
        ref.invalidate(invoicesProvider);
        ref.invalidate(invoiceStatisticsProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invoice deleted'), backgroundColor: Colors.orange),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }
}
