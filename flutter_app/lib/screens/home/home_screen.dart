import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:io';
import '../../services/auth_service.dart';
import '../../services/scanner_service.dart';
import '../../services/receipt_repository.dart';
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
        taxBreakdown: _lastScanResult!['tax_breakdown'] != null
            ? List<Map<String, dynamic>>.from(_lastScanResult!['tax_breakdown'])
            : null,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Receipt saved!'),
          backgroundColor: Colors.green,
        ),
      );
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
                                  Text(
                                    _lastScanResult!['merchant_name'] ?? 'Unknown Store',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${_lastScanResult!['date'] ?? ''} ${_lastScanResult!['time'] ?? ''}',
                                    style: TextStyle(color: Colors.grey.shade700),
                                  ),
                                  if (_lastScanResult!['receipt_number'] != null)
                                    Text(
                                      'Receipt #${_lastScanResult!['receipt_number']}',
                                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Items list
                            if (_lastScanResult!['items'] != null && (_lastScanResult!['items'] as List).isNotEmpty) ...[
                              const Text('Items:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              const Divider(),
                              ..._buildItemsList(_lastScanResult!['items']),
                              const Divider(),
                            ],

                            // Tax breakdown
                            if (_lastScanResult!['tax_breakdown'] != null && (_lastScanResult!['tax_breakdown'] as List).isNotEmpty) ...[
                              const SizedBox(height: 8),
                              const Text('Tax Breakdown:', style: TextStyle(fontWeight: FontWeight.bold)),
                              ...(_lastScanResult!['tax_breakdown'] as List).map((tax) => Padding(
                                padding: const EdgeInsets.only(left: 16, top: 4),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('${tax['rate']}%'),
                                    Text('${_lastScanResult!['currency'] ?? '€'} ${tax['tax_amount']?.toStringAsFixed(2) ?? '0.00'}'),
                                  ],
                                ),
                              )),
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
                                    _buildTotalRow('Subtotal', _lastScanResult!['subtotal'], _lastScanResult!['currency']),
                                  if (_lastScanResult!['tax_total'] != null)
                                    _buildTotalRow('Tax Total', _lastScanResult!['tax_total'], _lastScanResult!['currency']),
                                  const Divider(),
                                  _buildTotalRow('Total', _lastScanResult!['total'], _lastScanResult!['currency'], isBold: true),
                                ],
                              ),
                            ),

                            const SizedBox(height: 16),
                            // Footer info
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                if (_lastScanResult!['payment_method'] != null)
                                  Chip(
                                    label: Text(_lastScanResult!['payment_method']),
                                    avatar: const Icon(Icons.payment, size: 16),
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
                                label: Text(_isSaving ? 'Saving...' : 'Save to Account'),
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

  Widget _buildTotalRow(String label, dynamic value, String? currency, {bool isBold = false}) {
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
          Text(
            '$currencySymbol $displayValue',
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: isBold ? 16 : 14,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildItemsList(List<dynamic> items) {
    return items.map((item) {
      final quantity = item['quantity'] ?? 1;
      final price = item['price'];
      final priceStr = price is num ? price.toStringAsFixed(2) : (price?.toString() ?? '0.00');
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['name'] ?? 'Unknown item',
                    style: const TextStyle(fontSize: 14),
                  ),
                  if (quantity > 1)
                    Text(
                      'x$quantity',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    ),
                ],
              ),
            ),
            Text(
              priceStr,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }).toList();
  }
}