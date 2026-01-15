import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../services/receipt_repository.dart';
import '../../services/image_storage_service.dart';

final receiptRepositoryProvider = Provider((ref) => ReceiptRepository());

final receiptsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repository = ref.watch(receiptRepositoryProvider);
  return repository.getReceipts();
});

final statisticsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final repository = ref.watch(receiptRepositoryProvider);
  return repository.getStatistics();
});

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  String _selectedFilter = 'All';
  DateTimeRange? _customDateRange;

  @override
  void initState() {
    super.initState();
    // Refresh data when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(receiptsProvider);
      ref.invalidate(statisticsProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final receiptsAsync = ref.watch(receiptsProvider);
    final statsAsync = ref.watch(statisticsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(receiptsProvider);
          ref.invalidate(statisticsProvider);
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
                      child: _StatCard(
                        title: 'Total Spent',
                        value: '€${stats['total_spent']?.toStringAsFixed(2) ?? '0.00'}',
                        icon: Icons.shopping_cart,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        title: 'Total Tax',
                        value: '€${stats['total_tax']?.toStringAsFixed(2) ?? '0.00'}',
                        icon: Icons.receipt_long,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        title: 'Receipts',
                        value: '${stats['receipt_count'] ?? 0}',
                        icon: Icons.format_list_numbered,
                      ),
                    ),
                  ],
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Error: $e'),
              ),
              const SizedBox(height: 24),

              // Receipt history
              Text(
                'Receipt History',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),

              // Filter chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ...['All', 'Today', 'Yesterday', 'Last 7 days', 'This month'].map((filter) {
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
                            lastDate: DateTime.now(),
                            initialDateRange: _customDateRange,
                            helpText: 'Select date range',
                            cancelText: 'Cancel',
                            confirmText: 'OK',
                            saveText: 'OK',
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

              receiptsAsync.when(
                data: (receipts) {
                  if (receipts.isEmpty) {
                    return const Card(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(
                          child: Text('No receipts yet. Scan your first receipt!'),
                        ),
                      ),
                    );
                  }
                  // Filter receipts by added date
                  final filtered = _filterReceiptsByAddedDate(receipts, _selectedFilter);
                  if (filtered.isEmpty) {
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Center(
                          child: Text('No receipts added $_selectedFilter'.toLowerCase()),
                        ),
                      ),
                    );
                  }
                  return Column(
                    children: filtered.map((receipt) => _ReceiptCard(receipt: receipt)).toList(),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Error loading receipts: $e'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _filterReceiptsByAddedDate(List<Map<String, dynamic>> receipts, String filter) {
    if (filter == 'All') return receipts;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final last7Days = today.subtract(const Duration(days: 7));
    final thisMonthStart = DateTime(now.year, now.month, 1);

    return receipts.where((receipt) {
      // Use created_at (added date)
      final createdAt = receipt['created_at'] != null
          ? DateTime.tryParse(receipt['created_at'])
          : null;

      if (createdAt == null) return false;

      final addedDay = DateTime(createdAt.year, createdAt.month, createdAt.day);

      switch (filter) {
        case 'Today':
          return addedDay == today;
        case 'Yesterday':
          return addedDay == yesterday;
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

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, size: 28, color: Theme.of(context).primaryColor),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ReceiptCard extends ConsumerStatefulWidget {
  final Map<String, dynamic> receipt;

  const _ReceiptCard({required this.receipt});

  @override
  ConsumerState<_ReceiptCard> createState() => _ReceiptCardState();
}

class _ReceiptCardState extends ConsumerState<_ReceiptCard> {
  bool _isEditMode = false;

  Map<String, dynamic> get receipt => widget.receipt;

  @override
  Widget build(BuildContext context) {
    final merchantName = receipt['merchant_name'] ?? 'Unknown';
    final total = receipt['total_amount'] as num?;
    final subtotal = receipt['subtotal_amount'] as num?;
    final tax = receipt['tax_amount'] as num?;
    final currency = receipt['currency'] ?? 'EUR';
    final taxBreakdown = receipt['tax_breakdown'] as List<dynamic>?;
    final purchaseDate = receipt['purchase_date'] != null
        ? DateTime.tryParse(receipt['purchase_date'])
        : null;
    final createdAt = receipt['created_at'] != null
        ? DateTime.parse(receipt['created_at'])
        : null;

    String currencySymbol = currency == 'EUR' ? '€' : currency;

    String formatDate(DateTime? date) {
      if (date == null) return 'Unknown date';
      return '${date.day}.${date.month}.${date.year}';
    }

    String formatTime(DateTime? date) {
      if (date == null) return '';
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        leading: const CircleAvatar(
          child: Icon(Icons.receipt),
        ),
        title: Text(merchantName),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(formatDate(purchaseDate ?? createdAt)),
            if (createdAt != null)
              Text(
                'Added: ${formatDate(createdAt)} ${formatTime(createdAt)}',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
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
                      const Text('Edit Receipt', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      TextButton.icon(
                        onPressed: () => setState(() => _isEditMode = false),
                        icon: const Icon(Icons.close, size: 18),
                        label: const Text('Done'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Merchant name
                  _EditableField(
                    label: 'Merchant',
                    value: merchantName,
                    icon: Icons.store,
                    onTap: () => _editMerchantName(context, ref, merchantName),
                  ),
                  const SizedBox(height: 8),

                  // Date
                  _EditableField(
                    label: 'Date',
                    value: formatDate(purchaseDate ?? createdAt),
                    icon: Icons.calendar_today,
                    onTap: () => _editDate(context, ref, purchaseDate),
                  ),
                  const SizedBox(height: 8),

                  // Subtotal
                  _EditableField(
                    label: 'Subtotal',
                    value: '$currencySymbol${subtotal?.toStringAsFixed(2) ?? '0.00'}',
                    icon: Icons.receipt_long,
                    onTap: () => _editAmount(context, ref, 'subtotal_amount', 'Subtotal', subtotal?.toDouble()),
                  ),
                  const SizedBox(height: 8),

                  // Tax
                  _EditableField(
                    label: 'Tax',
                    value: '$currencySymbol${tax?.toStringAsFixed(2) ?? '0.00'}',
                    icon: Icons.percent,
                    onTap: () => _editAmount(context, ref, 'tax_amount', 'Tax', tax?.toDouble()),
                  ),
                  const SizedBox(height: 8),

                  // Total
                  _EditableField(
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
                    _EditableField(
                      label: 'Tax Breakdown',
                      value: '${taxBreakdown.length} tax rate(s)',
                      icon: Icons.list_alt,
                      onTap: () => _editTaxBreakdown(context, ref, taxBreakdown),
                    ),
                  ],
                ] else ...[
                  // Normal view - read-only display
                  // Amounts
                  if (subtotal != null)
                    _DetailRow(label: 'Subtotal', value: '$currencySymbol${subtotal.toStringAsFixed(2)}'),
                  _DetailRow(label: 'Tax', value: '$currencySymbol${tax?.toStringAsFixed(2) ?? '0.00'}'),
                  _DetailRow(label: 'Total', value: '$currencySymbol${total?.toStringAsFixed(2) ?? '0.00'}', isBold: true),

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

                      // Validate: tax_amount should equal gross_amount * rate / (100 + rate)
                      bool isItemValid = true;
                      if (grossAmount != null && taxAmount != null && rate > 0) {
                        final expectedTax = grossAmount * rate / (100 + rate);
                        isItemValid = (taxAmount - expectedTax).abs() < 0.02; // 2 cent tolerance
                      }

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Text('$rate%', style: const TextStyle(fontSize: 13)),
                                if (!isItemValid) ...[
                                  const SizedBox(width: 4),
                                  const Icon(Icons.warning, size: 14, color: Colors.orange),
                                ],
                              ],
                            ),
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
                    // Validation summary
                    Builder(
                      builder: (context) {
                        final validation = _validateTaxBreakdown(taxBreakdown, total?.toDouble(), tax?.toDouble());
                        if (validation.isNotEmpty) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.orange.shade200),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: validation.map((msg) => Row(
                                  children: [
                                    const Icon(Icons.warning, size: 14, color: Colors.orange),
                                    const SizedBox(width: 4),
                                    Expanded(child: Text(msg, style: const TextStyle(fontSize: 12, color: Colors.orange))),
                                  ],
                                )).toList(),
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
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
                    // View image button (only if image exists)
                    if (receipt['original_image_url'] != null) ...[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _showImageDialog(context, receipt['original_image_url']),
                          icon: const Icon(Icons.image, size: 18),
                          label: const Text('View Image'),
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

  /// Validate tax breakdown against totals
  /// Returns list of validation error messages (empty if valid)
  List<String> _validateTaxBreakdown(List<dynamic> taxBreakdown, double? total, double? taxTotal) {
    final errors = <String>[];

    double grossSum = 0;
    double taxSum = 0;

    for (final item in taxBreakdown) {
      final rate = (item['rate'] as num?)?.toDouble() ?? 0;
      final taxAmount = (item['tax_amount'] as num?)?.toDouble() ?? 0;
      final grossAmount = (item['gross_amount'] as num?)?.toDouble() ?? 0;

      grossSum += grossAmount;
      taxSum += taxAmount;

      // Validate individual item: tax = gross * rate / (100 + rate)
      if (grossAmount > 0 && rate > 0) {
        final expectedTax = grossAmount * rate / (100 + rate);
        if ((taxAmount - expectedTax).abs() > 0.02) {
          errors.add('${rate}%: tax ${taxAmount.toStringAsFixed(2)} != expected ${expectedTax.toStringAsFixed(2)}');
        }
      }
    }

    // Validate gross sum equals total
    if (total != null && grossSum > 0) {
      if ((grossSum - total).abs() > 0.02) {
        errors.add('Gross sum ${grossSum.toStringAsFixed(2)} != Total ${total.toStringAsFixed(2)}');
      }
    }

    // Validate tax sum equals tax total
    if (taxTotal != null && taxSum > 0) {
      if ((taxSum - taxTotal).abs() > 0.02) {
        errors.add('Tax sum ${taxSum.toStringAsFixed(2)} != Tax ${taxTotal.toStringAsFixed(2)}');
      }
    }

    return errors;
  }

  Future<void> _editMerchantName(BuildContext context, WidgetRef ref, String currentValue) async {
    String textValue = currentValue;

    final result = await showDialog<String?>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Edit Merchant Name'),
          content: TextFormField(
            initialValue: textValue,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Merchant Name',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) => textValue = value,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(textValue),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (result != null && result.isNotEmpty && context.mounted) {
      await _updateReceipt(context, ref, merchantName: result);
    }
  }

  Future<void> _editDate(BuildContext context, WidgetRef ref, DateTime? currentDate) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: currentDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (pickedDate != null && context.mounted) {
      await _updateReceipt(context, ref, purchaseDate: pickedDate);
    }
  }

  Future<void> _editAmount(BuildContext context, WidgetRef ref, String field, String label, double? currentValue) async {
    String textValue = currentValue?.toString() ?? '';

    final result = await showDialog<double?>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Edit $label'),
          content: TextFormField(
            initialValue: textValue,
            autofocus: true,
            decoration: InputDecoration(
              labelText: label,
              border: const OutlineInputBorder(),
              prefixText: '€ ',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (value) => textValue = value,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(double.tryParse(textValue)),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (result != null && context.mounted) {
      switch (field) {
        case 'subtotal_amount':
          await _updateReceipt(context, ref, subtotalAmount: result);
          break;
        case 'tax_amount':
          await _updateReceipt(context, ref, taxAmount: result);
          break;
        case 'total_amount':
          await _updateReceipt(context, ref, totalAmount: result);
          break;
      }
    }
  }

  Future<void> _editTaxBreakdown(BuildContext context, WidgetRef ref, List<dynamic> currentBreakdown) async {
    final List<Map<String, dynamic>> editableBreakdown =
        currentBreakdown.map((e) => Map<String, dynamic>.from(e)).toList();

    final result = await showDialog<List<Map<String, dynamic>>?>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Edit Tax Breakdown'),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: editableBreakdown.length,
                  itemBuilder: (context, index) {
                    final item = editableBreakdown[index];
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    initialValue: item['rate']?.toString() ?? '',
                                    decoration: const InputDecoration(
                                      labelText: 'Rate %',
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                    ),
                                    keyboardType: TextInputType.number,
                                    onChanged: (v) => item['rate'] = double.tryParse(v),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextFormField(
                                    initialValue: item['tax_amount']?.toString() ?? '',
                                    decoration: const InputDecoration(
                                      labelText: 'Tax €',
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                    ),
                                    keyboardType: TextInputType.number,
                                    onChanged: (v) => item['tax_amount'] = double.tryParse(v),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              initialValue: item['gross_amount']?.toString() ?? '',
                              decoration: const InputDecoration(
                                labelText: 'Gross €',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (v) => item['gross_amount'] = double.tryParse(v),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(dialogContext).pop(editableBreakdown),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null && context.mounted) {
      await _updateReceipt(context, ref, taxBreakdown: result);
    }
  }

  Future<void> _updateReceipt(
    BuildContext context,
    WidgetRef ref, {
    String? merchantName,
    DateTime? purchaseDate,
    double? subtotalAmount,
    double? taxAmount,
    double? totalAmount,
    List<Map<String, dynamic>>? taxBreakdown,
  }) async {
    try {
      final repository = ref.read(receiptRepositoryProvider);
      await repository.updateReceipt(
        id: receipt['id'],
        merchantName: merchantName,
        purchaseDate: purchaseDate,
        subtotalAmount: subtotalAmount,
        taxAmount: taxAmount,
        totalAmount: totalAmount,
        taxBreakdown: taxBreakdown,
      );
      ref.invalidate(receiptsProvider);
      ref.invalidate(statisticsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Receipt updated'), backgroundColor: Colors.green),
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

  void _showImageDialog(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: const Text('Receipt Image'),
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
                future: ImageStorageService.getImage(imageUrl),
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
                          Text('Failed to load image:\n${snapshot.error ?? "Unknown error"}', textAlign: TextAlign.center),
                        ],
                      ),
                    );
                  }
                  return InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: Image.memory(
                      snapshot.data!,
                      fit: BoxFit.contain,
                    ),
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
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Downloading image...'), duration: Duration(seconds: 1)),
      );

      final imageBytes = await ImageStorageService.getImage(imageUrl);
      if (imageBytes == null) {
        throw Exception('Failed to download image');
      }

      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath = '${directory.path}/receipt_$timestamp.jpg';

      final file = File(filePath);
      await file.writeAsBytes(imageBytes);

      if (!context.mounted) return;

      await Share.shareXFiles(
        [XFile(filePath)],
        text: 'Receipt image',
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Receipt?'),
        content: const Text('Are you sure you want to delete this receipt? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final repository = ref.read(receiptRepositoryProvider);
        await repository.deleteReceipt(receipt['id']);
        ref.invalidate(receiptsProvider);
        ref.invalidate(statisticsProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Receipt deleted'), backgroundColor: Colors.orange),
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

class _EditableField extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;
  final bool isBold;

  const _EditableField({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: Colors.grey.shade600),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.edit, size: 20, color: Theme.of(context).primaryColor),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;

  const _DetailRow({
    required this.label,
    required this.value,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: isBold ? const TextStyle(fontWeight: FontWeight.bold) : null,
          ),
        ],
      ),
    );
  }
}
