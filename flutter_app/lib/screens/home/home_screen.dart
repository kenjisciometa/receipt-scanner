import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../../services/auth_service.dart';
import '../../services/api/scanner_api_service.dart';
import '../../services/receipt_repository.dart';
import '../../services/invoice_repository.dart';
import '../../services/image_storage_service.dart';
import '../../services/scanner/document_scanner_service.dart';
import '../../config/app_config.dart';
import '../../presentation/widgets/receipt_edit_dialogs.dart';
import '../../presentation/widgets/account_status_button.dart';
import '../../presentation/widgets/gmail_status_button.dart';
import '../../services/receipt_validation_service.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final ImagePicker _picker = ImagePicker();
  final DocumentScannerService _documentScanner = DocumentScannerService();
  ScannerApiService? _scannerApi;
  bool _isScanning = false;
  bool _isSaving = false;
  Map<String, dynamic>? _lastScanResult;
  String? _lastImagePath;

  /// Get or create the scanner API service with auth headers
  ScannerApiService _getScannerApi() {
    _scannerApi ??= ScannerApiService(
      getAuthHeaders: () => ref.read(authServiceProvider.notifier).getAuthHeaders(),
    );
    return _scannerApi!;
  }

  /// Create a receipt repository with current auth info
  ReceiptRepository _getReceiptRepository() {
    final authState = ref.read(authServiceProvider);
    final user = authState.user;
    if (user == null) {
      throw Exception('User not authenticated');
    }
    return ReceiptRepository(
      userId: user.id,
      organizationId: user.organizationId,
    );
  }

  /// Create an invoice repository with current auth info
  InvoiceRepository _getInvoiceRepository() {
    final authState = ref.read(authServiceProvider);
    final user = authState.user;
    if (user == null) {
      throw Exception('User not authenticated');
    }
    return InvoiceRepository(
      userId: user.id,
      organizationId: user.organizationId,
    );
  }

  @override
  void dispose() {
    _documentScanner.dispose();
    super.dispose();
  }

  Future<void> _pickAndScanImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
    );
    if (result == null || result.files.single.path == null) return;

    await _scanImage(File(result.files.single.path!));
  }

  Future<void> _captureAndScanImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.camera);
    if (image == null) return;

    await _scanImage(File(image.path));
  }

  Future<void> _documentScanAndProcess() async {
    try {
      final result = await _documentScanner.scanReceipt();
      if (result != null && result.isSuccess && result.firstImagePath != null) {
        await _scanImage(File(result.firstImagePath!));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Document scanner error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Add receipt or invoice manually without image
  void _addManually() {
    final now = DateTime.now();
    final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    setState(() {
      _lastScanResult = {
        'success': true,
        'document_type': 'receipt',
        'merchant_name': null,
        'date': dateStr,
        'time': timeStr,
        'subtotal': null,
        'tax_total': null,
        'total': 0.0,
        'currency': 'EUR',
        'payment_method': null,
        'tax_breakdown': <Map<String, dynamic>>[],
        'confidence': 1.0,
        'processing_time_ms': 0,
      };
      _lastImagePath = null;
    });
  }

  Future<void> _scanImage(File imageFile) async {
    setState(() {
      _isScanning = true;
      _lastScanResult = null;
      _lastImagePath = imageFile.path;
    });

    try {
      // Call scanner API service
      final extractionResult = await _getScannerApi().extractFromFile(imageFile);

      // Convert to Map for compatibility with existing UI code
      final result = <String, dynamic>{
        'success': true,
        ...extractionResult.toJson(),
      };

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

    // Check for validation errors
    final taxBreakdown = _lastScanResult!['tax_breakdown'] as List?;
    if (taxBreakdown != null && taxBreakdown.isNotEmpty) {
      final total = (_lastScanResult!['total'] as num?)?.toDouble();
      final taxTotal = (_lastScanResult!['tax_total'] as num?)?.toDouble();
      final subtotal = (_lastScanResult!['subtotal'] as num?)?.toDouble();
      final errors = ReceiptValidationService.validateTaxBreakdown(taxBreakdown, total, taxTotal, subtotal: subtotal);

      if (errors.isNotEmpty) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.warning_amber, color: Colors.orange),
                SizedBox(width: 8),
                Text('Validation Warning'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Tax calculations do not match:'),
                const SizedBox(height: 8),
                ...errors.map((e) => Padding(
                  padding: const EdgeInsets.only(left: 8, bottom: 4),
                  child: Text('• $e', style: const TextStyle(fontSize: 13)),
                )),
                const SizedBox(height: 12),
                const Text('Save anyway?'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                child: const Text('Save Anyway'),
              ),
            ],
          ),
        );

        if (confirmed != true) return;
      }
    }

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

      final documentType = _lastScanResult!['document_type'] as String? ?? 'receipt';

      // Upload image to NAS via ReactPOS API (use correct endpoint based on document type)
      String? imageUrl;
      if (_lastImagePath != null && ImageStorageService.isConfigured) {
        final authService = ref.read(authServiceProvider.notifier);
        final authHeaders = await authService.getAuthHeaders();
        if (documentType == 'invoice') {
          imageUrl = await ImageStorageService.uploadInvoiceImage(
            _lastImagePath!,
            authHeaders: authHeaders,
          );
        } else {
          imageUrl = await ImageStorageService.uploadReceiptImage(
            _lastImagePath!,
            authHeaders: authHeaders,
          );
        }
      }
      final taxBreakdownList = _lastScanResult!['tax_breakdown'] != null
          ? List<Map<String, dynamic>>.from(_lastScanResult!['tax_breakdown'])
          : null;

      if (kDebugMode) {
        print('[HomeScreen] Saving as $documentType...');
      }

      if (documentType == 'invoice') {
        // Parse due date for invoices
        DateTime? dueDate;
        if (_lastScanResult!['due_date'] != null) {
          try {
            dueDate = DateTime.tryParse(_lastScanResult!['due_date']);
          } catch (_) {}
        }

        final invoiceRepo = _getInvoiceRepository();
        await invoiceRepo.saveInvoice(
          merchantName: _lastScanResult!['merchant_name'],
          vendorAddress: _lastScanResult!['vendor_address'],
          vendorTaxId: _lastScanResult!['vendor_tax_id'],
          customerName: _lastScanResult!['customer_name'],
          invoiceNumber: _lastScanResult!['invoice_number'],
          invoiceDate: purchaseDate,
          dueDate: dueDate,
          subtotalAmount: (_lastScanResult!['subtotal'] as num?)?.toDouble(),
          taxAmount: (_lastScanResult!['tax_total'] as num?)?.toDouble(),
          totalAmount: (_lastScanResult!['total'] as num?)?.toDouble(),
          currency: _lastScanResult!['currency'],
          taxBreakdown: taxBreakdownList,
          paymentMethod: _lastScanResult!['payment_method'],
          originalImageUrl: imageUrl,
          confidence: (_lastScanResult!['confidence'] as num?)?.toDouble(),
        );
      } else {
        final receiptRepo = _getReceiptRepository();
        await receiptRepo.saveReceipt(
          merchantName: _lastScanResult!['merchant_name'],
          purchaseDate: purchaseDate,
          subtotalAmount: (_lastScanResult!['subtotal'] as num?)?.toDouble(),
          taxAmount: (_lastScanResult!['tax_total'] as num?)?.toDouble(),
          totalAmount: (_lastScanResult!['total'] as num?)?.toDouble(),
          currency: _lastScanResult!['currency'],
          paymentMethod: _lastScanResult!['payment_method'],
          confidence: (_lastScanResult!['confidence'] as num?)?.toDouble(),
          originalImageUrl: imageUrl,
          taxBreakdown: taxBreakdownList,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(documentType == 'invoice'
              ? (imageUrl != null ? 'Invoice saved with image!' : 'Invoice saved!')
              : (imageUrl != null ? 'Receipt saved with image!' : 'Receipt saved!')),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppConfig.appName),
        actions: [
          const GmailStatusButton(),
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => context.push('/history'),
            tooltip: 'History',
          ),
          const AccountStatusButton(),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Action Buttons - responsive layout
            LayoutBuilder(
              builder: (context, constraints) {
                // Use vertical layout on narrow screens (< 360px)
                if (constraints.maxWidth < 360) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _isScanning ? null : _documentScanAndProcess,
                        icon: const Icon(Icons.document_scanner),
                        label: const Text('Scan'),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: _isScanning ? null : _captureAndScanImage,
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('Camera'),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: _isScanning ? null : _pickAndScanImage,
                        icon: const Icon(Icons.photo_library),
                        label: const Text('Gallery'),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _isScanning ? null : _addManually,
                        icon: const Icon(Icons.edit_note),
                        label: const Text('Add manually'),
                      ),
                    ],
                  );
                }
                // Horizontal layout for wider screens
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isScanning ? null : _documentScanAndProcess,
                            icon: const Icon(Icons.document_scanner, size: 20),
                            label: const Text('Scan', maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isScanning ? null : _captureAndScanImage,
                            icon: const Icon(Icons.camera_alt, size: 20),
                            label: const Text('Camera', maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isScanning ? null : _pickAndScanImage,
                            icon: const Icon(Icons.photo_library, size: 20),
                            label: const Text('Gallery', maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _isScanning ? null : _addManually,
                        icon: const Icon(Icons.edit_note, size: 20),
                        label: const Text('Add manually'),
                      ),
                    ),
                  ],
                );
              },
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
                                  // Document Type Toggle
                                  Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: GestureDetector(
                                            onTap: () {
                                              setState(() {
                                                _lastScanResult!['document_type'] = 'receipt';
                                              });
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(vertical: 8),
                                              decoration: BoxDecoration(
                                                color: _lastScanResult!['document_type'] != 'invoice'
                                                    ? Colors.green.shade100
                                                    : Colors.grey.shade100,
                                                borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                                                border: Border.all(
                                                  color: _lastScanResult!['document_type'] != 'invoice'
                                                      ? Colors.green.shade400
                                                      : Colors.grey.shade300,
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                    Icons.receipt_long,
                                                    size: 16,
                                                    color: _lastScanResult!['document_type'] != 'invoice'
                                                        ? Colors.green.shade700
                                                        : Colors.grey.shade500,
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    'Receipt',
                                                    style: TextStyle(
                                                      fontWeight: _lastScanResult!['document_type'] != 'invoice'
                                                          ? FontWeight.bold
                                                          : FontWeight.normal,
                                                      color: _lastScanResult!['document_type'] != 'invoice'
                                                          ? Colors.green.shade700
                                                          : Colors.grey.shade600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: GestureDetector(
                                            onTap: () {
                                              setState(() {
                                                _lastScanResult!['document_type'] = 'invoice';
                                              });
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(vertical: 8),
                                              decoration: BoxDecoration(
                                                color: _lastScanResult!['document_type'] == 'invoice'
                                                    ? Colors.blue.shade100
                                                    : Colors.grey.shade100,
                                                borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
                                                border: Border.all(
                                                  color: _lastScanResult!['document_type'] == 'invoice'
                                                      ? Colors.blue.shade400
                                                      : Colors.grey.shade300,
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                    Icons.description,
                                                    size: 16,
                                                    color: _lastScanResult!['document_type'] == 'invoice'
                                                        ? Colors.blue.shade700
                                                        : Colors.grey.shade500,
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    'Invoice',
                                                    style: TextStyle(
                                                      fontWeight: _lastScanResult!['document_type'] == 'invoice'
                                                          ? FontWeight.bold
                                                          : FontWeight.normal,
                                                      color: _lastScanResult!['document_type'] == 'invoice'
                                                          ? Colors.blue.shade700
                                                          : Colors.grey.shade600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Merchant/Vendor Name
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
                                  // Show receipt number for receipts
                                  if (_lastScanResult!['document_type'] != 'invoice' && _lastScanResult!['receipt_number'] != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        'Receipt #${_lastScanResult!['receipt_number']}',
                                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                      ),
                                    ),
                                  // Show invoice number for invoices (editable)
                                  if (_lastScanResult!['document_type'] == 'invoice')
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: GestureDetector(
                                        onTap: () => _editInvoiceTextField('invoice_number', 'Edit Invoice Number', 'Invoice Number'),
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
                                                _lastScanResult!['invoice_number'] != null
                                                    ? 'Invoice #${_lastScanResult!['invoice_number']}'
                                                    : 'Set invoice #',
                                                style: TextStyle(
                                                  color: _lastScanResult!['invoice_number'] != null
                                                      ? Colors.grey.shade600
                                                      : Colors.grey,
                                                  fontSize: 12,
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              Icon(Icons.edit, size: 12, color: Colors.grey.shade500),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),

                            // Invoice-specific fields
                            if (_lastScanResult!['document_type'] == 'invoice') ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.blue.shade200),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.description, size: 16, color: Colors.blue.shade700),
                                        const SizedBox(width: 6),
                                        Text(
                                          'INVOICE',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blue.shade700,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                    // Vendor Address
                                    const SizedBox(height: 8),
                                    Text(
                                      'Vendor Address:',
                                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                    ),
                                    GestureDetector(
                                      onTap: () => _editInvoiceTextField('vendor_address', 'Edit Vendor Address', 'Vendor Address'),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                        decoration: BoxDecoration(
                                          border: Border.all(color: Colors.grey.shade300),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                _lastScanResult!['vendor_address'] ?? 'Set address',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: _lastScanResult!['vendor_address'] != null ? Colors.black87 : Colors.grey,
                                                ),
                                              ),
                                            ),
                                            Icon(Icons.edit, size: 14, color: Colors.grey.shade500),
                                          ],
                                        ),
                                      ),
                                    ),
                                    // Vendor Tax ID
                                    const SizedBox(height: 8),
                                    Text(
                                      'Vendor Tax ID:',
                                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                    ),
                                    GestureDetector(
                                      onTap: () => _editInvoiceTextField('vendor_tax_id', 'Edit Vendor Tax ID', 'Tax ID'),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                        decoration: BoxDecoration(
                                          border: Border.all(color: Colors.grey.shade300),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                _lastScanResult!['vendor_tax_id'] ?? 'Set tax ID',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: _lastScanResult!['vendor_tax_id'] != null ? Colors.black87 : Colors.grey,
                                                ),
                                              ),
                                            ),
                                            Icon(Icons.edit, size: 14, color: Colors.grey.shade500),
                                          ],
                                        ),
                                      ),
                                    ),
                                    // Customer Name
                                    const SizedBox(height: 8),
                                    Text(
                                      'Customer:',
                                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                    ),
                                    GestureDetector(
                                      onTap: () => _editInvoiceTextField('customer_name', 'Edit Customer Name', 'Customer Name'),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                        decoration: BoxDecoration(
                                          border: Border.all(color: Colors.grey.shade300),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                _lastScanResult!['customer_name'] ?? 'Set customer',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w500,
                                                  color: _lastScanResult!['customer_name'] != null ? Colors.black87 : Colors.grey,
                                                ),
                                              ),
                                            ),
                                            Icon(Icons.edit, size: 14, color: Colors.grey.shade500),
                                          ],
                                        ),
                                      ),
                                    ),
                                    // Due Date
                                    const SizedBox(height: 8),
                                    Text(
                                      'Due Date:',
                                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                    ),
                                    GestureDetector(
                                      onTap: _editDueDate,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                        decoration: BoxDecoration(
                                          border: Border.all(color: Colors.grey.shade300),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                _lastScanResult!['due_date'] ?? 'Set due date',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: _lastScanResult!['due_date'] != null ? Colors.black87 : Colors.grey,
                                                ),
                                              ),
                                            ),
                                            Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade500),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            const SizedBox(height: 16),

                            // Tax breakdown
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Tax Breakdown:', style: TextStyle(fontWeight: FontWeight.bold)),
                                TextButton.icon(
                                  onPressed: _addTaxBreakdownItem,
                                  icon: const Icon(Icons.add, size: 16),
                                  label: const Text('Add tax'),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ),
                              ],
                            ),
                            if (_lastScanResult!['tax_breakdown'] != null && (_lastScanResult!['tax_breakdown'] as List).isNotEmpty) ...[
                              ...(_lastScanResult!['tax_breakdown'] as List).asMap().entries.map((entry) {
                                final index = entry.key;
                                final tax = entry.value;
                                final currency = _lastScanResult!['currency'] ?? '€';
                                final rate = tax['rate'];
                                final taxAmount = (tax['tax_amount'] as num?)?.toDouble();
                                final grossAmount = (tax['gross_amount'] as num?)?.toDouble();
                                return Padding(
                                  padding: const EdgeInsets.only(left: 8, top: 4),
                                  child: Row(
                                    children: [
                                      // Delete button
                                      GestureDetector(
                                        onTap: () => _removeTaxBreakdownItem(index),
                                        child: Icon(Icons.remove_circle, size: 18, color: Colors.red.shade300),
                                      ),
                                      const SizedBox(width: 8),
                                      // Rate
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
                                              Text('${rate ?? 0}%'),
                                              const SizedBox(width: 4),
                                              Icon(Icons.edit, size: 12, color: Colors.grey.shade500),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const Spacer(),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
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
                                                  Text('Gross: $currency ${grossAmount?.toStringAsFixed(2) ?? '0.00'}'),
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
                              // Tax validation
                              Builder(
                                builder: (context) {
                                  final taxBreakdown = _lastScanResult!['tax_breakdown'] as List;
                                  final total = (_lastScanResult!['total'] as num?)?.toDouble();
                                  final taxTotal = (_lastScanResult!['tax_total'] as num?)?.toDouble();
                                  final subtotal = (_lastScanResult!['subtotal'] as num?)?.toDouble();
                                  final errors = ReceiptValidationService.validateTaxBreakdown(taxBreakdown, total, taxTotal, subtotal: subtotal);
                                  if (errors.isEmpty) return const SizedBox.shrink();
                                  return Container(
                                    padding: const EdgeInsets.all(8),
                                    margin: const EdgeInsets.only(bottom: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.orange.shade200),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(Icons.warning_amber, color: Colors.orange.shade700, size: 16),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Tax calculation warnings:',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.orange.shade700,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        ...errors.map((e) => Padding(
                                          padding: const EdgeInsets.only(left: 20),
                                          child: Text(
                                            '• $e',
                                            style: TextStyle(color: Colors.orange.shade800, fontSize: 11),
                                          ),
                                        )),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ] else ...[
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Text(
                                  'No tax entries. Tap "Add tax" to add.',
                                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                                ),
                              ),
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
                                  _buildTotalRow('Subtotal', _lastScanResult!['subtotal'], _lastScanResult!['currency'], fieldKey: 'subtotal'),
                                  _buildTotalRow('Tax Total', _lastScanResult!['tax_total'], _lastScanResult!['currency'], fieldKey: 'tax_total'),
                                  const Divider(),
                                  _buildTotalRow('Total', _lastScanResult!['total'], _lastScanResult!['currency'], isBold: true, fieldKey: 'total'),
                                ],
                              ),
                            ),

                            // Subtotal + Tax Total validation
                            Builder(
                              builder: (context) {
                                final subtotal = (_lastScanResult!['subtotal'] as num?)?.toDouble();
                                final taxTotal = (_lastScanResult!['tax_total'] as num?)?.toDouble();
                                final total = (_lastScanResult!['total'] as num?)?.toDouble();
                                final error = ReceiptValidationService.validateTotalSum(subtotal, taxTotal, total);
                                if (error == null) return const SizedBox.shrink();
                                return Container(
                                  padding: const EdgeInsets.all(8),
                                  margin: const EdgeInsets.only(top: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.orange.shade200),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.warning_amber, size: 16, color: Colors.orange.shade700),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          error,
                                          style: TextStyle(color: Colors.orange.shade800, fontSize: 12),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),

                            const SizedBox(height: 16),
                            // Footer info
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
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
                                    const SizedBox(width: 8),
                                    GestureDetector(
                                      onTap: _editCurrency,
                                      child: Chip(
                                        label: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(_lastScanResult!['currency'] ?? 'EUR'),
                                            const SizedBox(width: 4),
                                            Icon(Icons.arrow_drop_down, size: 18, color: Colors.grey.shade600),
                                          ],
                                        ),
                                        avatar: const Icon(Icons.currency_exchange, size: 16),
                                      ),
                                    ),
                                  ],
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
    final result = await ReceiptEditDialogs.editAmount(
      context: context,
      title: 'Edit $label',
      label: label,
      currentValue: currentValue,
    );

    if (result != null && mounted) {
      setState(() {
        _lastScanResult![fieldKey] = result;
      });
    }
  }

  Future<void> _editMerchantName() async {
    final result = await ReceiptEditDialogs.editText(
      context: context,
      title: 'Edit Merchant Name',
      label: 'Merchant Name',
      currentValue: _lastScanResult!['merchant_name'] ?? '',
    );

    if (result != null && result.isNotEmpty && mounted) {
      setState(() {
        _lastScanResult!['merchant_name'] = result;
      });
    }
  }

  Future<void> _editDateTime() async {
    final result = await ReceiptEditDialogs.editDateTime(
      context: context,
      currentDate: _lastScanResult!['date'],
      currentTime: _lastScanResult!['time'],
    );

    if (result != null && mounted) {
      setState(() {
        _lastScanResult!['date'] = result['date'];
        _lastScanResult!['time'] = result['time'];
      });
    }
  }

  Future<void> _editPaymentMethod() async {
    final result = await ReceiptEditDialogs.editPaymentMethod(
      context: context,
      currentValue: _lastScanResult!['payment_method'],
    );

    if (result != null && result.isNotEmpty && mounted) {
      setState(() {
        _lastScanResult!['payment_method'] = result;
      });
    }
  }

  // Invoice-specific edit methods
  Future<void> _editInvoiceTextField(String fieldKey, String title, String label) async {
    final result = await ReceiptEditDialogs.editText(
      context: context,
      title: title,
      label: label,
      currentValue: _lastScanResult![fieldKey] ?? '',
    );

    if (result != null && mounted) {
      setState(() {
        _lastScanResult![fieldKey] = result.isEmpty ? null : result;
      });
    }
  }

  Future<void> _editDueDate() async {
    final currentDueDate = _lastScanResult!['due_date'] as String?;
    DateTime? initialDate;
    if (currentDueDate != null) {
      initialDate = DateTime.tryParse(currentDueDate);
    }

    final result = await showDatePicker(
      context: context,
      initialDate: initialDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (result != null && mounted) {
      setState(() {
        _lastScanResult!['due_date'] = '${result.year}-${result.month.toString().padLeft(2, '0')}-${result.day.toString().padLeft(2, '0')}';
      });
    }
  }

  Future<void> _editCurrency() async {
    final currencies = ['EUR', 'USD', 'SEK', 'NOK', 'DKK', 'GBP', 'JPY', 'CHF'];
    final currentCurrency = _lastScanResult!['currency'] ?? 'EUR';

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Currency'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: currencies.length,
            itemBuilder: (context, index) {
              final currency = currencies[index];
              final isSelected = currency == currentCurrency;
              return ListTile(
                title: Text(
                  currency,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? Colors.blue : null,
                  ),
                ),
                trailing: isSelected ? const Icon(Icons.check, color: Colors.blue) : null,
                onTap: () => Navigator.of(context).pop(currency),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _lastScanResult!['currency'] = result;
      });
    }
  }

  Future<void> _editTaxBreakdownItem(int index, String field, dynamic currentValue) async {
    final isPercent = field == 'rate';
    final title = field == 'rate' ? 'Tax Rate' : field == 'gross_amount' ? 'Gross Amount' : 'Tax Amount';
    final label = field == 'rate' ? 'Rate' : field == 'gross_amount' ? 'Gross' : 'Tax';

    final result = await ReceiptEditDialogs.editAmount(
      context: context,
      title: 'Edit $title',
      label: label,
      currentValue: currentValue is num ? currentValue.toDouble() : double.tryParse(currentValue?.toString() ?? ''),
      isPercent: isPercent,
    );

    if (result != null && mounted) {
      setState(() {
        final taxBreakdown = _lastScanResult!['tax_breakdown'] as List;
        taxBreakdown[index][field] = result;
      });
    }
  }

  void _addTaxBreakdownItem() {
    setState(() {
      final taxBreakdown = _lastScanResult!['tax_breakdown'] as List;
      taxBreakdown.add({
        'rate': 24.0,
        'gross_amount': 0.0,
        'tax_amount': 0.0,
      });
    });
  }

  void _removeTaxBreakdownItem(int index) {
    setState(() {
      final taxBreakdown = _lastScanResult!['tax_breakdown'] as List;
      taxBreakdown.removeAt(index);
    });
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