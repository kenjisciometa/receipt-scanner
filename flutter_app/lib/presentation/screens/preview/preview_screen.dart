import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/formatters.dart';
import '../../widgets/common_widgets.dart';
import '../../../data/models/receipt.dart';
import '../../../data/models/tax_breakdown.dart';
import '../../../services/api/scanner_api_service.dart';
import '../../../services/receipt_validation_service.dart';
import '../../../services/receipt_converter_service.dart';
import '../../../services/invoice_repository.dart';
import '../../../services/receipt_repository.dart';
import '../../../main.dart';

/// Preview screen for captured receipt images with processing results
class PreviewScreen extends ConsumerStatefulWidget {
  const PreviewScreen({
    super.key,
    required this.imagePath,
  });

  final String imagePath;

  @override
  ConsumerState<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends ConsumerState<PreviewScreen> {
  bool _isProcessing = false;
  Receipt? _extractedReceipt;
  String? _errorMessage;
  bool _isEditing = false;

  // Validation warnings
  String? _validationWarning;

  // LLM reasoning (debug only)
  String? _llmReasoning;

  // Step 1 extraction result (debug only)
  String? _step1Result;

  // Simple test result (for web vs app comparison)
  String? _simpleTestResult;

  // Scanner API Service
  late final ScannerApiService _scannerService;

  // Text editing controllers for verified data
  late final TextEditingController _merchantNameController;
  late final TextEditingController _receiptNumberController;
  late final TextEditingController _dateController;
  late final TextEditingController _subtotalController;
  late final TextEditingController _taxController;
  late final TextEditingController _totalController;
  late final TextEditingController _paymentMethodController;

  // Invoice-specific controllers
  late final TextEditingController _vendorAddressController;
  late final TextEditingController _vendorTaxIdController;
  late final TextEditingController _customerNameController;
  late final TextEditingController _invoiceNumberController;
  late final TextEditingController _dueDateController;

  // Document type (can be changed by user)
  String _documentType = 'receipt';

  // Tax Breakdown controllers (rate and amount pairs)
  final List<({TextEditingController rate, TextEditingController amount})> _taxBreakdownControllers = [];

  @override
  void initState() {
    super.initState();
    _scannerService = ScannerApiService();

    // Initialize text controllers
    _merchantNameController = TextEditingController();
    _receiptNumberController = TextEditingController();
    _dateController = TextEditingController();
    _subtotalController = TextEditingController();
    _taxController = TextEditingController();
    _totalController = TextEditingController();
    _paymentMethodController = TextEditingController();

    // Initialize invoice-specific controllers
    _vendorAddressController = TextEditingController();
    _vendorTaxIdController = TextEditingController();
    _customerNameController = TextEditingController();
    _invoiceNumberController = TextEditingController();
    _dueDateController = TextEditingController();

    _startProcessing();
  }

  @override
  void dispose() {
    _merchantNameController.dispose();
    _receiptNumberController.dispose();
    _dateController.dispose();
    _subtotalController.dispose();
    _taxController.dispose();
    _totalController.dispose();
    _paymentMethodController.dispose();
    // Dispose invoice-specific controllers
    _vendorAddressController.dispose();
    _vendorTaxIdController.dispose();
    _customerNameController.dispose();
    _invoiceNumberController.dispose();
    _dueDateController.dispose();
    // Dispose tax breakdown controllers
    for (final controllers in _taxBreakdownControllers) {
      controllers.rate.dispose();
      controllers.amount.dispose();
    }
    _taxBreakdownControllers.clear();
    super.dispose();
  }

  /// Start the receipt processing pipeline using POS API
  Future<void> _startProcessing() async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      logger.i('Starting receipt processing for: ${widget.imagePath}');

      // Verify file exists
      final file = File(widget.imagePath);
      if (!await file.exists()) {
        throw Exception('Image file does not exist: ${widget.imagePath}');
      }
      logger.d('Image file exists: ${await file.length()} bytes');

      // Check if Scanner API is available
      final apiAvailable = await _scannerService.checkServer();
      if (!apiAvailable) {
        throw Exception('Scanner API not available. Please check API server connection.');
      }

      // Process with Scanner API
      print('[PreviewScreen] Processing with Scanner API...');
      final result = await _scannerService.extractFromFile(file);

      print('[PreviewScreen] LLM extraction completed in ${result.processingTimeMs}ms');
      print('[PreviewScreen] result.documentType: ${result.documentType}');
      print('[PreviewScreen] result.vendorAddress: ${result.vendorAddress}');

      // Convert LLM result to Receipt object
      print('[PreviewScreen] Calling ReceiptConverterService.fromLLMResult...');
      final receipt = ReceiptConverterService.fromLLMResult(
        result,
        imagePath: widget.imagePath,
        onDateParseError: (dateStr) => logger.w('Failed to parse date: $dateStr'),
      );

      // Validate totals
      final warning = ReceiptValidationService.validateTotals(
        receipt.taxBreakdown, receipt.totalAmount);

      // Initialize controllers first (before setState)
      _initializeTextControllers(receipt);

      setState(() {
        _extractedReceipt = receipt;
        _documentType = receipt.documentType ?? 'receipt';
        _validationWarning = warning;
        _llmReasoning = result.reasoning;
        _step1Result = result.step1Result;
      });
      print('[PreviewScreen] Receipt created: ${receipt.merchantName}, ${receipt.totalAmount}');
      print('[PreviewScreen] Document type from receipt: ${receipt.documentType}');
      print('[PreviewScreen] _documentType state: $_documentType');
      print('[PreviewScreen] Invoice fields:');
      print('[PreviewScreen]   vendorAddress: ${receipt.vendorAddress}');
      print('[PreviewScreen]   customerName: ${receipt.customerName}');
      print('[PreviewScreen]   invoiceNumber: ${receipt.invoiceNumber}');
      print('[PreviewScreen]   dueDate: ${receipt.dueDate}');
      if (warning != null) {
        logger.w('Validation warning: $warning');
      }

    } catch (e) {
      logger.e('Processing failed: $e');
      setState(() {
        _errorMessage = 'Processing failed: $e';
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Receipt Preview'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        actions: [
          if (_extractedReceipt != null && !_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: _toggleEditMode,
              tooltip: 'Edit data',
            ),
          if (_extractedReceipt != null && _isEditing)
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _saveAsVerified,
              tooltip: 'Save as verified training data',
            ),
          if (_extractedReceipt != null && _isEditing)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: _cancelEdit,
              tooltip: 'Cancel editing',
            ),
          if (_extractedReceipt != null && !_isEditing)
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveReceipt,
              tooltip: 'Save receipt',
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isProcessing) {
      return _buildProcessingView();
    }

    if (_errorMessage != null) {
      return _buildErrorView();
    }

    return Column(
      children: [
        // Image preview section
        Expanded(
          flex: 1,
          child: _buildImagePreview(),
        ),
        
        // Results section
        Expanded(
          flex: 1,
          child: _buildResultsSection(),
        ),
      ],
    );
  }

  Widget _buildProcessingView() {
    return Container(
      color: Colors.black,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Image preview while processing
          Container(
            height: 200,
            margin: const EdgeInsets.all(AppConstants.defaultPadding),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
              child: Image.file(
                File(widget.imagePath),
                fit: BoxFit.contain,
              ),
            ),
          ),
          
          const SizedBox(height: AppConstants.defaultPadding * 2),
          
          // Processing indicator
          const CircularProgressIndicator(
            color: Colors.blue,
            strokeWidth: 3,
          ),
          
          const SizedBox(height: AppConstants.defaultPadding),
          
          const Text(
            'Processing receipt...',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          
          const SizedBox(height: AppConstants.smallPadding),
          
          Text(
            _getProcessingStepText(),
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  String _getProcessingStepText() {
    return 'Processing with LLM...';
  }

  Widget _buildErrorView() {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.all(AppConstants.defaultPadding),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 80,
            color: Colors.red,
          ),
          
          const SizedBox(height: AppConstants.defaultPadding),
          
          const Text(
            'Processing Failed',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          
          const SizedBox(height: AppConstants.smallPadding),
          
          Text(
            _errorMessage!,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: AppConstants.defaultPadding * 2),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                onPressed: _startProcessing,
                child: const Text('Retry'),
              ),
              
              ElevatedButton(
                onPressed: () => context.go('/'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey.shade700,
                ),
                child: const Text('Back'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildImagePreview() {
    final imagePath = widget.imagePath;

    return Container(
      color: Colors.black,
      child: Column(
        children: [
          // Image indicator
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.defaultPadding,
              vertical: AppConstants.smallPadding,
            ),
            color: Colors.black87,
            child: const Row(
              children: [
                Icon(
                  Icons.image,
                  color: Colors.white70,
                  size: 16,
                ),
                SizedBox(width: AppConstants.smallPadding),
                Text(
                  'Scanned Image',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          
          // Image
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppConstants.defaultPadding),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
                child: Image.file(
                  File(imagePath),
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsSection() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(AppConstants.largeBorderRadius),
          topRight: Radius.circular(AppConstants.largeBorderRadius),
        ),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: AppConstants.smallPadding),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Results content
          Expanded(
            child: _extractedReceipt != null 
                ? _buildReceiptDetails()
                : _buildExtractingView(),
          ),
        ],
      ),
    );
  }

  Widget _buildExtractingView() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: AppConstants.defaultPadding),
          Text(
            'Extracting receipt data...',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptDetails() {
    final receipt = _extractedReceipt!;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppConstants.defaultPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Confidence indicator (hide in edit mode)
          if (!_isEditing) ...[
            ConfidenceIndicator(
              confidence: _extractedReceipt?.confidence ?? 0.0,
              padding: const EdgeInsets.all(AppConstants.defaultPadding),
              borderRadius: AppConstants.defaultBorderRadius,
            ),
            const SizedBox(height: AppConstants.defaultPadding),
          ],

          // Validation warning (if totals don't match)
          if (!_isEditing && _validationWarning != null) ...[
            ValidationWarning(
              message: _validationWarning!,
              hint: 'The tax breakdown values may be incorrect. Please verify manually.',
              padding: const EdgeInsets.all(AppConstants.defaultPadding),
              borderRadius: AppConstants.defaultBorderRadius,
            ),
            const SizedBox(height: AppConstants.defaultPadding),
          ],

          // Edit mode notice
          if (_isEditing) ...[
            Container(
              padding: const EdgeInsets.all(AppConstants.defaultPadding),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
                border: Border.all(color: Colors.blue, width: 1),
              ),
              child: Row(
                children: [
                  const Icon(Icons.edit, color: Colors.blue),
                  const SizedBox(width: AppConstants.smallPadding),
                  Expanded(
                    child: Text(
                      'Edit mode: Correct the data and tap the checkmark to save as verified training data.',
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppConstants.defaultPadding),
          ],
          
          // Document Type (always show with selector)
          _buildSectionTitle('Document Type'),
          _buildDataCard([
            DocumentTypeSelector(
              currentType: _documentType,
              onChanged: (newType) {
                setState(() {
                  _documentType = newType;
                });
              },
            ),
          ]),
          const SizedBox(height: AppConstants.defaultPadding),

          // Show different UI based on document type
          if (_documentType == 'invoice') ...[
            // ===== INVOICE UI =====
            // Vendor info
            _buildSectionTitle('Vendor'),
            _buildDataCard([
              _isEditing
                  ? EditableDataRow(label: 'Vendor Name', controller: _merchantNameController)
                  : _buildDataRow('Vendor Name', receipt.merchantName ?? 'N/A'),
              if (_isEditing)
                EditableDataRow(label: 'Address', controller: _vendorAddressController)
              else if (receipt.vendorAddress != null && receipt.vendorAddress!.isNotEmpty)
                _buildDataRow('Address', receipt.vendorAddress!),
              if (_isEditing)
                EditableDataRow(label: 'Tax ID', controller: _vendorTaxIdController)
              else if (receipt.vendorTaxId != null && receipt.vendorTaxId!.isNotEmpty)
                _buildDataRow('Tax ID', receipt.vendorTaxId!),
            ]),

            // Customer info (invoice only)
            _buildSectionTitle('Customer'),
            _buildDataCard([
              _isEditing
                  ? EditableDataRow(label: 'Customer Name', controller: _customerNameController)
                  : _buildDataRow('Customer Name', receipt.customerName ?? 'N/A'),
            ]),

            // Invoice details
            _buildSectionTitle('Invoice Details'),
            _buildDataCard([
              if (_isEditing)
                EditableDataRow(label: 'Invoice #', controller: _invoiceNumberController)
              else if (receipt.invoiceNumber != null && receipt.invoiceNumber!.isNotEmpty)
                _buildDataRow('Invoice #', receipt.invoiceNumber!),
              if (_isEditing)
                EditableDataRow(label: 'Date', controller: _dateController, hint: 'YYYY-MM-DD')
              else if (receipt.purchaseDate != null)
                _buildDataRow('Date', Formatters.formatDate(receipt.purchaseDate!)),
              if (_isEditing)
                EditableDataRow(label: 'Due Date', controller: _dueDateController, hint: 'YYYY-MM-DD')
              else if (receipt.dueDate != null)
                _buildDataRow('Due Date', Formatters.formatDate(receipt.dueDate!)),
            ]),
          ] else ...[
            // ===== RECEIPT UI =====
            // Merchant info
            _buildSectionTitle('Merchant'),
            _buildDataCard([
              _isEditing
                  ? EditableDataRow(label: 'Store Name', controller: _merchantNameController)
                  : _buildDataRow('Store Name', receipt.merchantName ?? 'N/A'),
              if (!_isEditing && receipt.receiptNumber != null)
                _buildDataRow('Receipt #', receipt.receiptNumber!),
              if (_isEditing)
                EditableDataRow(label: 'Receipt #', controller: _receiptNumberController),
            ]),

            // Date and payment info
            _buildSectionTitle('Transaction Details'),
            _buildDataCard([
              if (_isEditing)
                EditableDataRow(label: 'Date', controller: _dateController, hint: 'YYYY-MM-DD')
              else if (receipt.purchaseDate != null)
                _buildDataRow('Date', Formatters.formatDate(receipt.purchaseDate!)),
              if (_isEditing)
                EditableDataRow(label: 'Payment Method', controller: _paymentMethodController)
              else if (receipt.paymentMethod != null)
                _buildDataRow('Payment Method', receipt.paymentMethod!.displayName),
            ]),
          ],
          
          // Currency
          _buildSectionTitle('Currency'),
          _buildDataCard([
            _buildDataRow('Currency', receipt.currency.code),
          ]),
          
          // Amount breakdown
          _buildSectionTitle('Amount Breakdown'),
          _buildDataCard([
            if (_isEditing)
              EditableDataRow(label: 'Subtotal', controller: _subtotalController, hint: '0.00', isAmount: true)
            else if (receipt.subtotalAmount != null)
              _buildDataRow('Subtotal', Formatters.formatAmount(receipt.subtotalAmount!)),
            // TaxBreakdownを表示（詳細版）
            if (!_isEditing && receipt.taxBreakdown.isNotEmpty) ...[
              ...receipt.taxBreakdown.map((tax) => TaxBreakdownCard(
                rate: tax.rate,
                taxAmount: tax.amount,
                taxableAmount: tax.taxableAmount,
                grossAmount: tax.grossAmount,
                formatAmount: Formatters.formatAmount,
              )),
              const Divider(),
              if (receipt.taxTotal != null)
                _buildDataRow('Tax Total', Formatters.formatAmount(receipt.taxTotal!), isHighlighted: true),
            ] else if (_isEditing) ...[
              // Tax Breakdown編集UI
              ..._taxBreakdownControllers.asMap().entries.map((entry) {
                final index = entry.key;
                final controllers = entry.value;
                return _buildTaxBreakdownRow(
                  index: index,
                  rateController: controllers.rate,
                  amountController: controllers.amount,
                );
              }),
              // Add Tax Breakdown button
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppConstants.smallPadding),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          _addTaxBreakdownController();
                          setState(() {});
                        },
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add Tax Rate'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.blue,
                          side: BorderSide(color: Colors.blue.shade300),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Fallback: Single Tax field (if no breakdowns)
              if (_taxBreakdownControllers.isEmpty)
                EditableDataRow(label: 'Tax', controller: _taxController, hint: '0.00', isAmount: true),
            ] else if (receipt.taxTotal != null)
              _buildDataRow('Tax', Formatters.formatAmount(receipt.taxTotal!)),
            if (_isEditing)
              EditableDataRow(label: 'Total', controller: _totalController, hint: '0.00', isAmount: true, isHighlighted: true)
            else if (receipt.totalAmount != null)
              _buildDataRow(
                'Total',
                Formatters.formatAmount(receipt.totalAmount!),
                isHighlighted: true,
              ),
          ]),

          // Debug: LLM Reasoning (開発用)
          if (!_isEditing && _llmReasoning != null) ...[
            const SizedBox(height: AppConstants.defaultPadding * 2),
            DebugSection.grey(
              icon: Icons.psychology,
              title: 'LLM解釈過程（開発用）',
              content: _llmReasoning!,
            ),
          ],

          // Debug: Step 1 Extraction Result (開発用)
          if (!_isEditing && _step1Result != null) ...[
            const SizedBox(height: AppConstants.defaultPadding),
            DebugSection.blue(
              icon: Icons.document_scanner,
              title: 'Step 1: Raw Extraction (DEBUG)',
              content: _step1Result!,
            ),
          ],

          // Debug: Simple Test Result (WEB比較用)
          if (!_isEditing && _simpleTestResult != null) ...[
            const SizedBox(height: AppConstants.defaultPadding),
            DebugSection.green(
              icon: Icons.science,
              title: 'Simple Test (WEB比較用)',
              subtitle: 'Prompt: このレシートからTAXテーブルを読み取り合計金額と各税率いくらか調べてください',
              content: _simpleTestResult!,
            ),
          ],

          const SizedBox(height: AppConstants.defaultPadding * 2),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return SectionTitle(
      title: title,
      padding: const EdgeInsets.only(
        top: AppConstants.defaultPadding,
        bottom: AppConstants.smallPadding,
      ),
    );
  }

  Widget _buildDataCard(List<Widget> children) {
    return DataCard(
      padding: const EdgeInsets.all(AppConstants.defaultPadding),
      children: children,
    );
  }

  Widget _buildDataRow(String label, String value, {bool isHighlighted = false}) {
    return LabelValueRow(
      label: label,
      value: value,
      isHighlighted: isHighlighted,
      padding: const EdgeInsets.symmetric(vertical: AppConstants.smallPadding),
    );
  }

  /// Build editable tax breakdown row with rate and amount
  Widget _buildTaxBreakdownRow({
    required int index,
    required TextEditingController rateController,
    required TextEditingController amountController,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppConstants.smallPadding),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Text(
                  'Tax Rate',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (_taxBreakdownControllers.length > 1)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18),
                    color: Colors.red,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => _removeTaxBreakdownController(index),
                  ),
              ],
            ),
          ),
          Expanded(
            flex: 1,
            child: Padding(
              padding: const EdgeInsets.only(right: AppConstants.smallPadding),
              child: TextField(
                controller: rateController,
                decoration: InputDecoration(
                  hintText: '14.0',
                  suffixText: '%',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: BorderSide(color: Colors.blue, width: 2),
                  ),
                ),
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 14,
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: TextField(
              controller: amountController,
              decoration: InputDecoration(
                hintText: '0.00',
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 8,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide(color: Colors.blue, width: 2),
                ),
              ),
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 14,
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
          ),
        ],
      ),
    );
  }

  /// Initialize text controllers with receipt data
  void _initializeTextControllers(Receipt receipt) {
    // Set document type
    _documentType = receipt.documentType ?? 'receipt';

    // Common fields
    _merchantNameController.text = receipt.merchantName ?? '';
    _receiptNumberController.text = receipt.receiptNumber ?? '';
    _dateController.text = receipt.purchaseDate != null
        ? Formatters.formatDate(receipt.purchaseDate!)
        : '';
    _subtotalController.text = receipt.subtotalAmount != null
        ? receipt.subtotalAmount!.toStringAsFixed(2)
        : '';
    _taxController.text = receipt.taxAmount != null
        ? receipt.taxAmount!.toStringAsFixed(2)
        : '';
    _totalController.text = receipt.totalAmount != null
        ? receipt.totalAmount!.toStringAsFixed(2)
        : '';
    _paymentMethodController.text = receipt.paymentMethod?.displayName ?? '';

    // Invoice-specific fields
    _vendorAddressController.text = receipt.vendorAddress ?? '';
    _vendorTaxIdController.text = receipt.vendorTaxId ?? '';
    _customerNameController.text = receipt.customerName ?? '';
    _invoiceNumberController.text = receipt.invoiceNumber ?? '';
    _dueDateController.text = receipt.dueDate != null
        ? Formatters.formatDate(receipt.dueDate!)
        : '';

    // Initialize tax breakdown controllers
    _clearTaxBreakdownControllers();
    if (receipt.taxBreakdown.isNotEmpty) {
      for (final tax in receipt.taxBreakdown) {
        _addTaxBreakdownController(
          rate: tax.rate.toStringAsFixed(1),
          amount: tax.amount.toStringAsFixed(2),
        );
      }
    }
  }

  /// Clear all tax breakdown controllers
  void _clearTaxBreakdownControllers() {
    for (final controllers in _taxBreakdownControllers) {
      controllers.rate.dispose();
      controllers.amount.dispose();
    }
    _taxBreakdownControllers.clear();
  }
  
  /// Add a new tax breakdown controller
  void _addTaxBreakdownController({String rate = '', String amount = ''}) {
    _taxBreakdownControllers.add((
      rate: TextEditingController(text: rate),
      amount: TextEditingController(text: amount),
    ));
  }
  
  /// Remove a tax breakdown controller at index
  void _removeTaxBreakdownController(int index) {
    if (index >= 0 && index < _taxBreakdownControllers.length) {
      _taxBreakdownControllers[index].rate.dispose();
      _taxBreakdownControllers[index].amount.dispose();
      _taxBreakdownControllers.removeAt(index);
      setState(() {}); // Update UI
    }
  }

  /// Toggle edit mode
  void _toggleEditMode() {
    setState(() {
      _isEditing = true;
    });
  }

  /// Cancel editing and revert to original data
  void _cancelEdit() {
    if (_extractedReceipt != null) {
      _initializeTextControllers(_extractedReceipt!);
    }
    setState(() {
      _isEditing = false;
    });
  }

  /// Save edited data and update the receipt
  Future<void> _saveAsVerified() async {
    if (_extractedReceipt == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No data to save'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      // Parse edited values
      final merchantName = _merchantNameController.text.trim().isEmpty
          ? null
          : _merchantNameController.text.trim();
      final receiptNumber = _receiptNumberController.text.trim().isEmpty
          ? null
          : _receiptNumberController.text.trim();
      final subtotal = _subtotalController.text.trim().isEmpty
          ? null
          : double.tryParse(_subtotalController.text.trim());
      final taxAmount = _taxController.text.trim().isEmpty
          ? null
          : double.tryParse(_taxController.text.trim());
      final total = _totalController.text.trim().isEmpty
          ? null
          : double.tryParse(_totalController.text.trim());
      final paymentMethodStr = _paymentMethodController.text.trim().isEmpty
          ? null
          : _paymentMethodController.text.trim();

      // Invoice-specific fields
      final vendorAddress = _vendorAddressController.text.trim().isEmpty
          ? null
          : _vendorAddressController.text.trim();
      final vendorTaxId = _vendorTaxIdController.text.trim().isEmpty
          ? null
          : _vendorTaxIdController.text.trim();
      final customerName = _customerNameController.text.trim().isEmpty
          ? null
          : _customerNameController.text.trim();
      final invoiceNumber = _invoiceNumberController.text.trim().isEmpty
          ? null
          : _invoiceNumberController.text.trim();

      // Parse date helper function
      DateTime? parseDate(String text) {
        if (text.isEmpty) return null;
        final parts = text.split('/');
        if (parts.length == 3) {
          try {
            return DateTime(
              int.parse(parts[2]),
              int.parse(parts[1]),
              int.parse(parts[0]),
            );
          } catch (e) {
            logger.w('Failed to parse date: $text');
          }
        }
        return null;
      }

      // Parse dates
      final purchaseDate = parseDate(_dateController.text.trim());
      final dueDate = parseDate(_dueDateController.text.trim());

      // Parse tax breakdown
      final taxBreakdown = _taxBreakdownControllers.map((controllers) {
        final rate = double.tryParse(controllers.rate.text.trim());
        final amount = double.tryParse(controllers.amount.text.trim());
        if (rate != null && amount != null) {
          return TaxBreakdown(rate: rate, amount: amount);
        }
        return null;
      }).where((item) => item != null).cast<TaxBreakdown>().toList();

      // Calculate tax total
      final taxTotal = taxBreakdown.isNotEmpty
          ? taxBreakdown.fold(0.0, (sum, tax) => sum + tax.amount)
          : taxAmount;

      // Validate required fields
      if (total == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Total amount is required'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Update the receipt with edited values
      final updatedReceipt = _extractedReceipt!.copyWith(
        documentType: _documentType,
        merchantName: merchantName,
        receiptNumber: receiptNumber,
        purchaseDate: purchaseDate,
        subtotalAmount: subtotal,
        taxAmount: taxTotal,
        totalAmount: total,
        taxBreakdown: taxBreakdown,
        taxTotal: taxTotal,
        paymentMethod: paymentMethodStr != null
            ? PaymentMethod.fromString(paymentMethodStr)
            : null,
        // Invoice-specific fields
        vendorAddress: vendorAddress,
        vendorTaxId: vendorTaxId,
        customerName: customerName,
        invoiceNumber: invoiceNumber,
        dueDate: dueDate,
      );

      setState(() {
        _extractedReceipt = updatedReceipt;
        _isEditing = false;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Changes saved'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );

      logger.i('Receipt updated with edited values');
    } catch (e) {
      logger.e('Failed to save edits: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _saveReceipt() async {
    if (_extractedReceipt == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No data to save'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final receipt = _extractedReceipt!;
      final taxBreakdownMaps = receipt.taxBreakdown.map((tb) => {
        'rate': tb.rate,
        'tax_amount': tb.amount,
        'taxable_amount': tb.taxableAmount,
        'gross_amount': tb.grossAmount,
      }).toList();

      if (_documentType == 'invoice') {
        // Save to invoices table
        final invoiceRepo = InvoiceRepository();
        await invoiceRepo.saveInvoice(
          merchantName: receipt.merchantName,
          vendorAddress: receipt.vendorAddress,
          vendorTaxId: receipt.vendorTaxId,
          customerName: receipt.customerName,
          invoiceNumber: receipt.invoiceNumber,
          invoiceDate: receipt.purchaseDate,
          dueDate: receipt.dueDate,
          subtotalAmount: receipt.subtotalAmount,
          taxAmount: receipt.taxAmount,
          totalAmount: receipt.totalAmount,
          currency: receipt.currency.name,
          taxBreakdown: taxBreakdownMaps,
          paymentMethod: receipt.paymentMethod?.name,
          originalImageUrl: receipt.originalImagePath,
          confidence: receipt.confidence,
          detectedLanguage: receipt.detectedLanguage,
        );
        logger.i('Invoice saved to database');
      } else {
        // Save to receipts table
        final receiptRepo = ReceiptRepository();
        await receiptRepo.saveReceipt(
          merchantName: receipt.merchantName,
          purchaseDate: receipt.purchaseDate,
          subtotalAmount: receipt.subtotalAmount,
          taxAmount: receipt.taxAmount,
          totalAmount: receipt.totalAmount,
          currency: receipt.currency.name,
          paymentMethod: receipt.paymentMethod?.name,
          originalImageUrl: receipt.originalImagePath,
          confidence: receipt.confidence,
          taxBreakdown: taxBreakdownMaps,
        );
        logger.i('Receipt saved to database');
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_documentType == 'invoice'
              ? 'Invoice saved successfully!'
              : 'Receipt saved successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      context.go('/');
    } catch (e) {
      logger.e('Failed to save: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}