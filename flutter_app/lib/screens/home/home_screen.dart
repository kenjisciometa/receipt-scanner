import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:io';
import '../../services/auth_service.dart';
import '../../services/scanner_service.dart';
import '../../services/receipt_repository.dart';
import '../../services/image_storage_service.dart';
import '../../config/app_config.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final ImagePicker _picker = ImagePicker();
  final ReceiptRepository _receiptRepository = ReceiptRepository();
  bool _isScanning = false;
  bool _isSaving = false;
  Map<String, dynamic>? _lastScanResult;
  String? _lastImagePath;

  Future<void> _pickAndScanImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    await _scanImage(File(image.path));
  }

  Future<void> _captureAndScanImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.camera);
    if (image == null) return;

    await _scanImage(File(image.path));
  }

  Future<void> _scanImage(File imageFile) async {
    setState(() {
      _isScanning = true;
      _lastScanResult = null;
      _lastImagePath = imageFile.path;
    });

    try {
      // Convert image to base64
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);

      // Call scanner service
      final result = await ScannerService.extractReceipt(base64Image);

      setState(() {
        _lastScanResult = result;
      });

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Receipt scan completed'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception(result['error'] ?? 'Scan error');
      }
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Scan error: $error'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isScanning = false;
      });
    }
  }

  Future<void> _saveReceipt() async {
    if (_lastScanResult == null || _lastScanResult!['success'] != true) return;

    setState(() {
      _isSaving = true;
    });

    try {
      // Upload image to Wasabi if configured
      String? imageUrl;
      if (_lastImagePath != null && ImageStorageService.isConfigured) {
        imageUrl = await ImageStorageService.uploadReceiptImage(_lastImagePath!);
      }

      // Parse date
      DateTime? purchaseDate;
      if (_lastScanResult!['date'] != null) {
        try {
          purchaseDate = DateTime.tryParse(_lastScanResult!['date']);
        } catch (_) {}
      }

      await _receiptRepository.saveReceipt(
        merchantName: _lastScanResult!['merchant_name'],
        purchaseDate: purchaseDate,
        subtotalAmount: (_lastScanResult!['subtotal'] as num?)?.toDouble(),
        taxAmount: (_lastScanResult!['tax_total'] as num?)?.toDouble(),
        totalAmount: (_lastScanResult!['total'] as num?)?.toDouble(),
        currency: _lastScanResult!['currency'],
        paymentMethod: _lastScanResult!['payment_method'],
        confidence: (_lastScanResult!['confidence'] as num?)?.toDouble(),
        originalImageUrl: imageUrl,
        taxBreakdown: _lastScanResult!['tax_breakdown'] != null
            ? List<Map<String, dynamic>>.from(_lastScanResult!['tax_breakdown'])
            : null,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(imageUrl != null ? 'Receipt saved with image!' : 'Receipt saved!'),
          backgroundColor: Colors.green,
        ),
      );

      // Clear after save
      setState(() {
        _lastScanResult = null;
        _lastImagePath = null;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Save error: $error'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  Future<void> _logout() async {
    try {
      await AuthService.signOut();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Logged out successfully'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Logout error: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppConfig.appName),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => context.push('/history'),
            tooltip: 'History',
          ),
          IconButton(
            icon: const Icon(Icons.account_circle),
            onPressed: () => context.push('/account'),
            tooltip: 'Account',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'logout') {
                _logout();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'user',
                enabled: false,
                child: Text(
                  currentUser?.email ?? 'Unknown User',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout),
                    SizedBox(width: 8),
                    Text('Logout'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isScanning ? null : _captureAndScanImage,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Camera'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isScanning ? null : _pickAndScanImage,
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Gallery'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Loading indicator
            if (_isScanning)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(width: 16),
                      Text('Analyzing receipt...'),
                    ],
                  ),
                ),
              ),

            // Results
            if (_lastScanResult != null) ...[
              const Text(
                'Scan Results:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_lastScanResult!['success'] == true) ...[
                            // Header with merchant info
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  GestureDetector(
                                    onTap: _editMerchantName,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Colors.grey.shade300),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Flexible(
                                            child: Text(
                                              _lastScanResult!['merchant_name'] ?? 'Unknown Store',
                                              style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Icon(Icons.edit, size: 16, color: Colors.grey.shade500),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  GestureDetector(
                                    onTap: _editDateTime,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Colors.grey.shade300),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            '${_lastScanResult!['date'] ?? ''} ${_lastScanResult!['time'] ?? ''}',
                                            style: TextStyle(color: Colors.grey.shade700),
                                          ),
                                          const SizedBox(width: 4),
                                          Icon(Icons.edit, size: 14, color: Colors.grey.shade500),
                                        ],
                                      ),
                                    ),
                                  ),
                                  if (_lastScanResult!['receipt_number'] != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        'Receipt #${_lastScanResult!['receipt_number']}',
                                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Tax breakdown
                            if (_lastScanResult!['tax_breakdown'] != null && (_lastScanResult!['tax_breakdown'] as List).isNotEmpty) ...[
                              const SizedBox(height: 8),
                              const Text('Tax Breakdown:', style: TextStyle(fontWeight: FontWeight.bold)),
                              ...(_lastScanResult!['tax_breakdown'] as List).asMap().entries.map((entry) {
                                final index = entry.key;
                                final tax = entry.value;
                                final currency = _lastScanResult!['currency'] ?? '€';
                                final rate = tax['rate'];
                                final taxAmount = (tax['tax_amount'] as num?)?.toDouble();
                                final grossAmount = (tax['gross_amount'] as num?)?.toDouble();
                                return Padding(
                                  padding: const EdgeInsets.only(left: 16, top: 4),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      GestureDetector(
                                        onTap: () => _editTaxBreakdownItem(index, 'rate', rate),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            border: Border.all(color: Colors.grey.shade300),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text('$rate%'),
                                              const SizedBox(width: 4),
                                              Icon(Icons.edit, size: 12, color: Colors.grey.shade500),
                                            ],
                                          ),
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          if (grossAmount != null)
                                            GestureDetector(
                                              onTap: () => _editTaxBreakdownItem(index, 'gross_amount', grossAmount),
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  border: Border.all(color: Colors.grey.shade300),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Text('Gross: $currency ${grossAmount.toStringAsFixed(2)}'),
                                                    const SizedBox(width: 4),
                                                    Icon(Icons.edit, size: 12, color: Colors.grey.shade500),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          const SizedBox(height: 2),
                                          GestureDetector(
                                            onTap: () => _editTaxBreakdownItem(index, 'tax_amount', taxAmount),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                border: Border.all(color: Colors.grey.shade300),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    'Tax: $currency ${taxAmount?.toStringAsFixed(2) ?? '0.00'}',
                                                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Icon(Icons.edit, size: 10, color: Colors.grey.shade500),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              }),
                              const SizedBox(height: 8),
                            ],

                            // Totals
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                children: [
                                  if (_lastScanResult!['subtotal'] != null)
                                    _buildTotalRow('Subtotal', _lastScanResult!['subtotal'], _lastScanResult!['currency'], fieldKey: 'subtotal'),
                                  if (_lastScanResult!['tax_total'] != null)
                                    _buildTotalRow('Tax Total', _lastScanResult!['tax_total'], _lastScanResult!['currency'], fieldKey: 'tax_total'),
                                  const Divider(),
                                  _buildTotalRow('Total', _lastScanResult!['total'], _lastScanResult!['currency'], isBold: true, fieldKey: 'total'),
                                ],
                              ),
                            ),

                            const SizedBox(height: 16),
                            // Footer info
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                GestureDetector(
                                  onTap: _editPaymentMethod,
                                  child: Chip(
                                    label: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(_lastScanResult!['payment_method'] ?? 'Set payment'),
                                        const SizedBox(width: 4),
                                        Icon(Icons.edit, size: 14, color: Colors.grey.shade600),
                                      ],
                                    ),
                                    avatar: const Icon(Icons.payment, size: 16),
                                  ),
                                ),
                                Text(
                                  'Confidence: ${((_lastScanResult!['confidence'] ?? 0) * 100).toInt()}%',
                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                ),
                              ],
                            ),
                            Text(
                              'Processing: ${_lastScanResult!['processing_time_ms']}ms',
                              style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                            ),
                            const SizedBox(height: 16),
                            // Save button
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _isSaving ? null : _saveReceipt,
                                icon: _isSaving
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Icon(Icons.save),
                                label: Text(_isSaving ? 'Saving...' : 'Save'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                          ] else ...[
                            Text(
                              'Error: ${_lastScanResult!['error']}',
                              style: const TextStyle(color: Colors.red),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ] else ...[
              const Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long, size: 80, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'Take a photo or select from gallery to scan receipt',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _editSingleValue(String fieldKey, String label, double? currentValue) async {
    String textValue = currentValue?.toString() ?? '';

    final result = await showDialog<double?>(
      context: context,
      barrierDismissible: true,
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
              onPressed: () {
                Navigator.of(dialogContext).pop(double.tryParse(textValue));
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );

    if (result != null && mounted) {
      setState(() {
        _lastScanResult![fieldKey] = result;
      });
    }
  }

  Future<void> _editMerchantName() async {
    String textValue = _lastScanResult!['merchant_name'] ?? '';

    final result = await showDialog<String?>(
      context: context,
      barrierDismissible: true,
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
              child: const Text('OK'),
            ),
          ],
        );
      },
    );

    if (result != null && result.isNotEmpty && mounted) {
      setState(() {
        _lastScanResult!['merchant_name'] = result;
      });
    }
  }

  Future<void> _editDateTime() async {
    String dateValue = _lastScanResult!['date'] ?? '';
    String timeValue = _lastScanResult!['time'] ?? '';

    final result = await showDialog<Map<String, String>?>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Edit Date & Time'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  initialValue: dateValue,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Date (YYYY-MM-DD)',
                    border: OutlineInputBorder(),
                    hintText: '2025-01-15',
                  ),
                  onChanged: (value) => dateValue = value,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: timeValue,
                  decoration: const InputDecoration(
                    labelText: 'Time (HH:MM)',
                    border: OutlineInputBorder(),
                    hintText: '14:30',
                  ),
                  onChanged: (value) => timeValue = value,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop({
                'date': dateValue,
                'time': timeValue,
              }),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );

    if (result != null && mounted) {
      setState(() {
        _lastScanResult!['date'] = result['date'];
        _lastScanResult!['time'] = result['time'];
      });
    }
  }

  Future<void> _editPaymentMethod() async {
    String textValue = _lastScanResult!['payment_method'] ?? '';
    final commonMethods = ['Card', 'Cash', 'Debit', 'Credit', 'Mobile'];

    final result = await showDialog<String?>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Edit Payment Method'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  initialValue: textValue,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Payment Method',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) => textValue = value,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: commonMethods.map((method) => ActionChip(
                    label: Text(method),
                    onPressed: () => Navigator.of(dialogContext).pop(method),
                  )).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(textValue),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );

    if (result != null && result.isNotEmpty && mounted) {
      setState(() {
        _lastScanResult!['payment_method'] = result;
      });
    }
  }

  Future<void> _editTaxBreakdownItem(int index, String field, dynamic currentValue) async {
    String textValue = currentValue?.toString() ?? '';
    final isPercent = field == 'rate';

    final result = await showDialog<double?>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Edit ${field == 'rate' ? 'Tax Rate' : field == 'gross_amount' ? 'Gross Amount' : 'Tax Amount'}'),
          content: TextFormField(
            initialValue: textValue,
            autofocus: true,
            decoration: InputDecoration(
              labelText: field == 'rate' ? 'Rate' : field == 'gross_amount' ? 'Gross' : 'Tax',
              border: const OutlineInputBorder(),
              prefixText: isPercent ? null : '€ ',
              suffixText: isPercent ? '%' : null,
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
              onPressed: () {
                final value = double.tryParse(textValue);
                Navigator.of(dialogContext).pop(value);
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );

    if (result != null && mounted) {
      setState(() {
        final taxBreakdown = _lastScanResult!['tax_breakdown'] as List;
        taxBreakdown[index][field] = result;
      });
    }
  }

  Widget _buildTotalRow(String label, dynamic value, String? currency, {bool isBold = false, String? fieldKey}) {
    final currencySymbol = currency ?? '€';
    final displayValue = value is num ? value.toStringAsFixed(2) : (value?.toString() ?? '0.00');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: isBold ? 16 : 14,
            ),
          ),
          GestureDetector(
            onTap: fieldKey != null
                ? () => _editSingleValue(fieldKey, label, (value as num?)?.toDouble())
                : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: fieldKey != null
                  ? BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(4),
                    )
                  : null,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$currencySymbol $displayValue',
                    style: TextStyle(
                      fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                      fontSize: isBold ? 16 : 14,
                    ),
                  ),
                  if (fieldKey != null) ...[
                    const SizedBox(width: 4),
                    Icon(Icons.edit, size: 14, color: Colors.grey.shade500),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

}