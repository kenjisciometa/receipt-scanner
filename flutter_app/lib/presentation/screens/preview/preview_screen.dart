import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../data/models/receipt.dart';
import '../../../data/models/receipt_item.dart';
import '../../../data/models/tax_breakdown.dart';
import '../../../services/llm/llama_cpp_service.dart';
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

  // LLM Service
  late final LlamaCppService _llmService;

  // Text editing controllers for verified data
  late final TextEditingController _merchantNameController;
  late final TextEditingController _receiptNumberController;
  late final TextEditingController _dateController;
  late final TextEditingController _subtotalController;
  late final TextEditingController _taxController;
  late final TextEditingController _totalController;
  late final TextEditingController _paymentMethodController;

  // Tax Breakdown controllers (rate and amount pairs)
  final List<({TextEditingController rate, TextEditingController amount})> _taxBreakdownControllers = [];

  @override
  void initState() {
    super.initState();
    _llmService = LlamaCppService();

    // Initialize text controllers
    _merchantNameController = TextEditingController();
    _receiptNumberController = TextEditingController();
    _dateController = TextEditingController();
    _subtotalController = TextEditingController();
    _taxController = TextEditingController();
    _totalController = TextEditingController();
    _paymentMethodController = TextEditingController();

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
    // Dispose tax breakdown controllers
    for (final controllers in _taxBreakdownControllers) {
      controllers.rate.dispose();
      controllers.amount.dispose();
    }
    _taxBreakdownControllers.clear();
    super.dispose();
  }

  /// Start the receipt processing pipeline using LLM
  Future<void> _startProcessing() async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      logger.i('Starting LLM processing for: ${widget.imagePath}');

      // Verify file exists
      final file = File(widget.imagePath);
      if (!await file.exists()) {
        throw Exception('Image file does not exist: ${widget.imagePath}');
      }
      logger.d('Image file exists: ${await file.length()} bytes');

      // Check if LLM server is available
      final llmAvailable = await _llmService.checkServer();
      if (!llmAvailable) {
        throw Exception('LLM server not available. Please start llama-server and run: adb reverse tcp:8080 tcp:8080');
      }

      // Process with LLM
      logger.i('Processing with LLM (Qwen2.5-VL)...');
      final result = await _llmService.extractFromFile(file);

      logger.i('LLM extraction completed in ${result.processingTimeMs}ms, confidence: ${result.confidence}');

      // Convert LLM result to Receipt object
      final receipt = _buildReceiptFromLLM(result);

      // Validate totals
      final warning = _validateTotals(receipt);

      setState(() {
        _extractedReceipt = receipt;
        _validationWarning = warning;
        _llmReasoning = result.reasoning;
      });

      _initializeTextControllers(receipt);
      logger.i('Receipt created: ${receipt.merchantName}, ${receipt.totalAmount}');
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

  /// Build Receipt from LLM extraction result
  Receipt _buildReceiptFromLLM(LLMExtractionResult llmResult) {
    // Parse date
    DateTime? purchaseDate;
    if (llmResult.date != null) {
      try {
        purchaseDate = DateTime.parse(llmResult.date!);
      } catch (e) {
        logger.w('Failed to parse date: ${llmResult.date}');
      }
    }

    // Convert tax breakdown with full details
    final taxBreakdownList = llmResult.taxBreakdown.map((item) => TaxBreakdown(
      rate: item.rate,
      amount: item.taxAmount,
      taxableAmount: item.taxableAmount,
      grossAmount: item.grossAmount,
    )).toList();

    // Detect currency
    Currency currency = Currency.eur;
    if (llmResult.currency != null) {
      currency = Currency.fromCode(llmResult.currency!);
    }

    // Convert items
    final items = llmResult.items.asMap().entries.map((entry) {
      final item = entry.value;
      return ReceiptItem(
        id: 'item_${entry.key}',
        name: item.name,
        quantity: item.quantity,
        unitPrice: item.price / item.quantity,
        totalPrice: item.price,
        taxRate: item.taxRate,
      );
    }).toList();

    return Receipt.create(
      originalImagePath: widget.imagePath,
      merchantName: llmResult.merchantName,
      purchaseDate: purchaseDate,
      totalAmount: llmResult.total,
      subtotalAmount: llmResult.subtotal,
      taxAmount: llmResult.taxTotal,
      taxBreakdown: taxBreakdownList,
      taxTotal: llmResult.taxTotal,
      paymentMethod: llmResult.paymentMethod != null
          ? PaymentMethod.fromString(llmResult.paymentMethod)
          : null,
      currency: currency,
      items: items,
      confidence: llmResult.confidence,
      receiptNumber: llmResult.receiptNumber,
      rawOcrText: llmResult.rawResponse,
      status: ReceiptStatus.completed,
    );
  }

  /// Validate that total matches sum of gross amounts from tax breakdown
  String? _validateTotals(Receipt receipt) {
    if (receipt.taxBreakdown.isEmpty || receipt.totalAmount == null) {
      return null;
    }

    // Calculate sum of gross amounts
    double sumGross = 0;
    bool hasGrossAmounts = false;

    for (final tax in receipt.taxBreakdown) {
      if (tax.grossAmount != null) {
        sumGross += tax.grossAmount!;
        hasGrossAmounts = true;
      }
    }

    if (!hasGrossAmounts) {
      return null; // No gross amounts to validate
    }

    final total = receipt.totalAmount!;
    final difference = (sumGross - total).abs();

    // Allow small rounding differences (0.02 or less)
    if (difference > 0.02) {
      return 'Total mismatch: Sum of tax categories (${sumGross.toStringAsFixed(2)}) ≠ Total (${total.toStringAsFixed(2)}). Difference: ${difference.toStringAsFixed(2)}';
    }

    return null;
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
          onPressed: () => context.pop(),
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
                onPressed: () => context.pop(),
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
            _buildConfidenceIndicator(),
            const SizedBox(height: AppConstants.defaultPadding),
          ],

          // Validation warning (if totals don't match)
          if (!_isEditing && _validationWarning != null) ...[
            _buildValidationWarning(),
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
          
          // Document Type
          if (receipt.documentType != null) ...[
            _buildSectionTitle('Document Type'),
            _buildDataCard([
              _buildDocumentTypeRow(receipt.documentType!),
            ]),
            const SizedBox(height: AppConstants.defaultPadding),
          ],
          
          // Merchant info
          _buildSectionTitle('Merchant'),
          _buildDataCard([
            _isEditing
                ? _buildEditableDataRow('Store Name', _merchantNameController)
                : _buildDataRow('Store Name', receipt.merchantName ?? 'N/A'),
            if (!_isEditing && receipt.receiptNumber != null)
              _buildDataRow('Receipt #', receipt.receiptNumber!),
            if (_isEditing)
              _buildEditableDataRow('Receipt #', _receiptNumberController),
          ]),
          
          // Date and payment info
          _buildSectionTitle('Transaction Details'),
          _buildDataCard([
            if (_isEditing)
              _buildEditableDataRow('Date', _dateController, hint: 'YYYY-MM-DD')
            else if (receipt.purchaseDate != null)
              _buildDataRow('Date', _formatDate(receipt.purchaseDate!)),
            if (_isEditing)
              _buildEditableDataRow('Payment Method', _paymentMethodController)
            else if (receipt.paymentMethod != null)
              _buildDataRow('Payment Method', receipt.paymentMethod!.displayName),
          ]),
          
          // Currency
          if (receipt.currency != null) ...[
            _buildSectionTitle('Currency'),
            _buildDataCard([
              _buildDataRow('Currency', receipt.currency.code),
            ]),
          ],
          
          // Amount breakdown
          _buildSectionTitle('Amount Breakdown'),
          _buildDataCard([
            if (_isEditing)
              _buildEditableDataRow('Subtotal', _subtotalController, hint: '0.00', isAmount: true)
            else if (receipt.subtotalAmount != null)
              _buildDataRow('Subtotal', _formatAmount(receipt.subtotalAmount!)),
            // TaxBreakdownを表示（詳細版）
            if (!_isEditing && receipt.taxBreakdown.isNotEmpty) ...[
              ...receipt.taxBreakdown.map((tax) => _buildTaxBreakdownDisplay(tax)),
              const Divider(),
              if (receipt.taxTotal != null)
                _buildDataRow('Tax Total', _formatAmount(receipt.taxTotal!), isHighlighted: true),
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
                _buildEditableDataRow('Tax', _taxController, hint: '0.00', isAmount: true),
            ] else if (receipt.taxTotal != null)
              _buildDataRow('Tax', _formatAmount(receipt.taxTotal!)),
            if (_isEditing)
              _buildEditableDataRow('Total', _totalController, hint: '0.00', isAmount: true, isHighlighted: true)
            else if (receipt.totalAmount != null)
              _buildDataRow(
                'Total',
                _formatAmount(receipt.totalAmount!),
                isHighlighted: true,
              ),
          ]),

          // Debug: LLM Reasoning (開発用 - デバッグモードのみ)
          if (!_isEditing && _llmReasoning != null) ...[
            const SizedBox(height: AppConstants.defaultPadding * 2),
            _buildReasoningSection(),
          ],

          const SizedBox(height: AppConstants.defaultPadding * 2),
        ],
      ),
    );
  }

  Widget _buildConfidenceIndicator() {
    final confidence = _extractedReceipt?.confidence ?? 0.0;
    final color = confidence >= 0.8 
        ? Colors.green 
        : confidence >= 0.6 
            ? Colors.orange 
            : Colors.red;
    
    return Container(
      padding: const EdgeInsets.all(AppConstants.defaultPadding),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
        border: Border.all(color: color, width: 1),
      ),
      child: Row(
        children: [
          Icon(
            confidence >= 0.8 
                ? Icons.check_circle 
                : confidence >= 0.6 
                    ? Icons.warning 
                    : Icons.error,
            color: color,
          ),
          const SizedBox(width: AppConstants.smallPadding),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Detection Confidence: ${(confidence * 100).toInt()}%',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  confidence >= 0.8 
                      ? 'High confidence - data looks accurate'
                      : confidence >= 0.6 
                          ? 'Medium confidence - please verify'
                          : 'Low confidence - manual review recommended',
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build validation warning indicator when totals don't match
  Widget _buildValidationWarning() {
    return Container(
      padding: const EdgeInsets.all(AppConstants.defaultPadding),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
        border: Border.all(color: Colors.red, width: 2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error,
            color: Colors.red,
            size: 24,
          ),
          const SizedBox(width: AppConstants.smallPadding),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Calculation Error',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _validationWarning!,
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'The tax breakdown values may be incorrect. Please verify manually.',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build reasoning section (開発用 - LLMの解釈過程)
  Widget _buildReasoningSection() {
    return Container(
      padding: const EdgeInsets.all(AppConstants.defaultPadding),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
        border: Border.all(color: Colors.grey.shade300, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.psychology, size: 18, color: Colors.grey.shade600),
              const SizedBox(width: 6),
              Text(
                'LLM解釈過程（開発用）',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
          const Divider(),
          Text(
            _llmReasoning ?? '',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade800,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(
        top: AppConstants.defaultPadding,
        bottom: AppConstants.smallPadding,
      ),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildDataCard(List<Widget> children) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          children: children,
        ),
      ),
    );
  }

  Widget _buildDataRow(String label, String value, {bool isHighlighted = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppConstants.smallPadding),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                color: isHighlighted ? Colors.black : Colors.black87,
                fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
                fontSize: isHighlighted ? 16 : 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build a detailed tax breakdown display for a single tax rate
  Widget _buildTaxBreakdownDisplay(TaxBreakdown tax) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: AppConstants.smallPadding),
      padding: const EdgeInsets.all(AppConstants.smallPadding),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(AppConstants.smallBorderRadius),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tax rate header
          Row(
            children: [
              Icon(Icons.percent, size: 16, color: Colors.blue.shade700),
              const SizedBox(width: 4),
              Text(
                'VAT ${tax.rate}%',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade700,
                ),
              ),
              const Spacer(),
              if (tax.grossAmount != null)
                Text(
                  _formatAmount(tax.grossAmount!),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          // Details row
          Row(
            children: [
              if (tax.taxableAmount != null) ...[
                Expanded(
                  child: Text(
                    'Net: ${_formatAmount(tax.taxableAmount!)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
              ],
              Expanded(
                child: Text(
                  'Tax: ${_formatAmount(tax.amount)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentTypeRow(String documentType) {
    // Determine icon and color based on document type
    IconData icon;
    Color color;
    String displayText;

    switch (documentType.toLowerCase()) {
      case 'receipt':
        icon = Icons.receipt;
        color = Colors.green;
        displayText = 'Receipt';
        break;
      case 'invoice':
        icon = Icons.description;
        color = Colors.blue;
        displayText = 'Invoice';
        break;
      default:
        icon = Icons.help_outline;
        color = Colors.grey;
        displayText = 'Unknown';
    }
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppConstants.smallPadding),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              'Type',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: AppConstants.smallPadding),
                Text(
                  displayText,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableDataRow(
    String label,
    TextEditingController controller, {
    String? hint,
    bool isAmount = false,
    bool isHighlighted = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppConstants.smallPadding),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: hint,
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
              style: TextStyle(
                color: isHighlighted ? Colors.black : Colors.black87,
                fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
                fontSize: isHighlighted ? 16 : 14,
              ),
              keyboardType: isAmount ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
            ),
          ),
        ],
      ),
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

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatAmount(double amount) {
    return amount.toStringAsFixed(2);
  }
  

  /// Initialize text controllers with receipt data
  void _initializeTextControllers(Receipt receipt) {
    _merchantNameController.text = receipt.merchantName ?? '';
    _receiptNumberController.text = receipt.receiptNumber ?? '';
    _dateController.text = receipt.purchaseDate != null 
        ? _formatDate(receipt.purchaseDate!) 
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

      // Parse date
      DateTime? purchaseDate;
      if (_dateController.text.trim().isNotEmpty) {
        final parts = _dateController.text.trim().split('/');
        if (parts.length == 3) {
          try {
            purchaseDate = DateTime(
              int.parse(parts[2]),
              int.parse(parts[1]),
              int.parse(parts[0]),
            );
          } catch (e) {
            logger.w('Failed to parse date: ${_dateController.text}');
          }
        }
      }

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

  void _saveReceipt() {
    // TODO: Save receipt to database
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Receipt saved successfully!'),
        backgroundColor: Colors.green,
      ),
    );
    context.pop();
  }
}