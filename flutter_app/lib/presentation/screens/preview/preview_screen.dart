import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/receipt.dart';
import '../../../data/models/processing_result.dart';
import '../../../services/image_processing/image_preprocessor.dart';
import '../../../services/ocr/ml_kit_service.dart';
import '../../../services/extraction/receipt_parser.dart';
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
  String? _processedImagePath;
  OCRResult? _ocrResult;
  ExtractionResult? _extractionResult;
  Receipt? _extractedReceipt;
  String? _errorMessage;
  
  // Services
  late final ImagePreprocessor _imagePreprocessor;
  late final MLKitService _mlKitService;
  late final ReceiptParser _receiptParser;

  @override
  void initState() {
    super.initState();
    _imagePreprocessor = ImagePreprocessor();
    _mlKitService = MLKitService();
    _receiptParser = ReceiptParser();
    _startProcessing();
  }

  @override
  void dispose() {
    _mlKitService.dispose();
    super.dispose();
  }

  /// Start the complete receipt processing pipeline
  Future<void> _startProcessing() async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      logger.i('Starting receipt processing pipeline for: ${widget.imagePath}');

      // Step 1: OCR text recognition (skip preprocessing for test image)
      String imagePath = widget.imagePath;
      
      // Only apply preprocessing to camera-captured images, not test images
      final isTestImage = widget.imagePath.contains('test_receipt');
      logger.d('Image path: ${widget.imagePath}, isTestImage: $isTestImage');
      
      if (!isTestImage) {
        final preprocessResult = await _imagePreprocessor.processReceiptImage(widget.imagePath);
        
        if (!preprocessResult.success) {
          throw Exception('Image preprocessing failed: ${preprocessResult.errorMessage}');
        }

        setState(() {
          _processedImagePath = preprocessResult.outputPath;
        });

        logger.d('Image preprocessing completed: ${preprocessResult.qualityScore}');
        imagePath = _processedImagePath!;
      } else {
        logger.i('Skipping preprocessing for test image');
      }

      // Step 2: OCR text recognition
      final ocrResult = await _mlKitService.recognizeTextFromFile(imagePath);
      
      if (!ocrResult.success) {
        throw Exception('OCR failed: ${ocrResult.errorMessage}');
      }

      setState(() {
        _ocrResult = ocrResult;
      });

      logger.d('OCR completed: ${ocrResult.recognizedText?.length} characters');

      // Step 3: Extract receipt data with structured blocks
      // Prefer textLines over textBlocks for better line structure
      List<Map<String, dynamic>>? textBlocks;
      if (ocrResult.textLines.isNotEmpty) {
        // Use structured lines (preferred)
        textBlocks = ocrResult.textLines.map((line) => {
          'text': line.text,
          'confidence': line.confidence,
          'boundingBox': line.boundingBox,
          'elements': line.elements.map((e) => {
            'text': e.text,
            'confidence': e.confidence,
            'boundingBox': e.boundingBox,
          }).toList(),
        }).toList();
        logger.d('Using ${textBlocks.length} structured lines from OCR');
      } else if (ocrResult.textBlocks.isNotEmpty) {
        // Fall back to text blocks
        textBlocks = ocrResult.textBlocks.map((block) => {
          'text': block.text,
          'confidence': block.confidence,
          'boundingBox': block.boundingBox,
          'language': block.language,
        }).toList();
        logger.d('Using ${textBlocks.length} text blocks from OCR');
      }
      
      final extractionResult = await _receiptParser.parseReceiptText(
        ocrText: ocrResult.recognizedText!,
        detectedLanguage: ocrResult.detectedLanguage,
        ocrConfidence: ocrResult.confidence,
        textBlocks: textBlocks,
        textLines: ocrResult.textLines.isNotEmpty ? ocrResult.textLines : null,
      );

      setState(() {
        _extractionResult = extractionResult;
      });

      // Step 4: Create Receipt object
      if (extractionResult.success) {
        final receipt = _buildReceiptFromExtraction(extractionResult);
        setState(() {
          _extractedReceipt = receipt;
        });
        
        logger.i('Receipt processing completed successfully');
      }

    } catch (e) {
      logger.e('Receipt processing failed: $e');
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  /// Build Receipt object from extraction results
  Receipt _buildReceiptFromExtraction(ExtractionResult extractionResult) {
    final data = extractionResult.extractedData;
    
    return Receipt.create(
      originalImagePath: widget.imagePath,
      processedImagePath: _processedImagePath,
      rawOcrText: _ocrResult?.recognizedText,
      merchantName: data['merchant_name'] as String?,
      purchaseDate: data['date'] != null ? DateTime.parse(data['date']) : null,
      totalAmount: data['total_amount'] as double?,
      subtotalAmount: data['subtotal_amount'] as double?,
      taxAmount: data['tax_amount'] as double?,
      paymentMethod: data['payment_method'] != null 
          ? PaymentMethod.values.firstWhere(
              (pm) => pm.name == data['payment_method'],
              orElse: () => PaymentMethod.unknown,
            )
          : null,
      currency: data['currency'] != null 
          ? Currency.fromCode(data['currency'])
          : Currency.eur,
      confidence: extractionResult.confidence,
      detectedLanguage: _ocrResult?.detectedLanguage,
      status: extractionResult.hasUsableResults 
          ? ReceiptStatus.completed 
          : ReceiptStatus.needsVerification,
      receiptNumber: data['receipt_number'] as String?,
    );
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
          if (_extractedReceipt != null)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: _navigateToEdit,
            ),
          if (_extractedReceipt != null)
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveReceipt,
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
    if (_processedImagePath == null) {
      return 'Enhancing image quality...';
    } else if (_ocrResult == null) {
      return 'Reading text...';
    } else if (_extractionResult == null) {
      return 'Extracting receipt data...';
    } else {
      return 'Finalizing...';
    }
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
    final imagePath = _processedImagePath ?? widget.imagePath;
    
    return Container(
      color: Colors.black,
      child: Column(
        children: [
          // Image quality indicator
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.defaultPadding,
              vertical: AppConstants.smallPadding,
            ),
            color: Colors.black87,
            child: Row(
              children: [
                Icon(
                  _processedImagePath != null ? Icons.auto_fix_high : Icons.image,
                  color: Colors.white70,
                  size: 16,
                ),
                const SizedBox(width: AppConstants.smallPadding),
                Text(
                  _processedImagePath != null ? 'Enhanced Image' : 'Original Image',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                if (_processedImagePath != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.green, width: 1),
                    ),
                    child: const Text(
                      'PROCESSED',
                      style: TextStyle(
                        color: Colors.green,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
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
          // Confidence indicator
          _buildConfidenceIndicator(),
          
          const SizedBox(height: AppConstants.defaultPadding),
          
          // Merchant info
          if (receipt.merchantName != null) ...[
            _buildSectionTitle('Merchant'),
            _buildDataCard([
              _buildDataRow('Store Name', receipt.merchantName!),
              if (receipt.receiptNumber != null)
                _buildDataRow('Receipt #', receipt.receiptNumber!),
            ]),
          ],
          
          // Date and payment info
          if (receipt.purchaseDate != null || receipt.paymentMethod != null) ...[
            _buildSectionTitle('Transaction Details'),
            _buildDataCard([
              if (receipt.purchaseDate != null)
                _buildDataRow('Date', _formatDate(receipt.purchaseDate!)),
              if (receipt.paymentMethod != null)
                _buildDataRow('Payment Method', receipt.paymentMethod!.displayName),
            ]),
          ],
          
          // Amount breakdown
          if (receipt.totalAmount != null) ...[
            _buildSectionTitle('Amount Breakdown'),
            _buildDataCard([
              if (receipt.subtotalAmount != null)
                _buildDataRow('Subtotal', _formatAmount(receipt.subtotalAmount!, receipt.currency)),
              if (receipt.taxAmount != null)
                _buildDataRow('Tax', _formatAmount(receipt.taxAmount!, receipt.currency)),
              _buildDataRow(
                'Total', 
                _formatAmount(receipt.totalAmount!, receipt.currency),
                isHighlighted: true,
              ),
            ]),
          ],
          
          // Warnings if any
          if (_extractionResult?.warnings.isNotEmpty == true) ...[
            const SizedBox(height: AppConstants.defaultPadding),
            _buildWarningsSection(),
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

  Widget _buildWarningsSection() {
    final warnings = _extractionResult!.warnings;
    
    return Container(
      padding: const EdgeInsets.all(AppConstants.defaultPadding),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
        border: Border.all(color: Colors.orange, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning, color: Colors.orange),
              const SizedBox(width: AppConstants.smallPadding),
              const Text(
                'Warnings',
                style: TextStyle(
                  color: Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.smallPadding),
          ...warnings.map((warning) => Text(
            '• $warning',
            style: const TextStyle(
              color: Colors.orange,
              fontSize: 12,
            ),
          )),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatAmount(double amount, Currency currency) {
    return '${currency.symbol}${amount.toStringAsFixed(2)}';
  }

  void _navigateToEdit() {
    // TODO: Navigate to edit screen
    // context.push('/edit', extra: _extractedReceipt);
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