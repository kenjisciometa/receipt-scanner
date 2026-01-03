import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

import '../../data/models/processing_result.dart';
import '../../core/utils/text_line_features.dart';
import '../../core/constants/language_keywords.dart';
import '../../main.dart';

/// Service for collecting training data for ML model
/// Saves OCR results and extraction results in JSON format for sequence labeling
class TrainingDataCollector {
  static const String _trainingDataDir = 'training_data';
  static const String _rawDataDir = 'raw';
  static const String _verifiedDataDir = 'verified';
  static const double _minConfidenceThreshold = 0.7; // Only save high-confidence data

  /// Save training data for a receipt
  /// Returns the saved file path, or null if not saved (low confidence)
  Future<String?> saveTrainingData({
    required String receiptId,
    required OCRResult ocrResult,
    required ExtractionResult extractionResult,
    required String imagePath,
    Map<String, dynamic>? additionalMetadata,
  }) async {
    try {
      // Only save high-confidence data
      if (extractionResult.confidence < _minConfidenceThreshold) {
        logger.d('Skipping training data save: confidence too low (${extractionResult.confidence.toStringAsFixed(2)} < $_minConfidenceThreshold)');
        return null;
      }

      // Prepare training data structure
      final trainingData = <String, dynamic>{
        'receipt_id': receiptId,
        'timestamp': DateTime.now().toIso8601String(),
        'text_lines': _prepareTextLines(ocrResult, extractionResult),
        'extraction_result': _prepareExtractionResult(extractionResult),
        'metadata': {
          'image_path': imagePath,
          'language': ocrResult.detectedLanguage ?? 'unknown',
          'ocr_confidence': ocrResult.confidence,
          'extraction_confidence': extractionResult.confidence,
          'extraction_method': extractionResult.metadata['parsing_method'] ?? 'rule_based',
          'consistency_score': extractionResult.metadata['consistency_score'],
          'text_lines_count': ocrResult.textLines.length,
          'text_blocks_count': ocrResult.textBlocks.length,
          if (additionalMetadata != null) ...additionalMetadata,
        },
      };

      // Get training data directory
      final trainingDir = await _getTrainingDataDirectory();
      final rawDir = Directory(path.join(trainingDir.path, _rawDataDir));
      if (!await rawDir.exists()) {
        await rawDir.create(recursive: true);
      }

      // Save as JSON file
      final fileName = 'receipt_${receiptId}_${DateTime.now().millisecondsSinceEpoch}.json';
      final filePath = path.join(rawDir.path, fileName);
      final file = File(filePath);
      
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(trainingData),
        encoding: utf8,
      );

      logger.i('✅ Training data saved: $filePath (confidence: ${extractionResult.confidence.toStringAsFixed(2)})');
      return filePath;
    } catch (e) {
      logger.e('Failed to save training data: $e');
      return null;
    }
  }

  /// Prepare textLines for training data with labels and features
  List<Map<String, dynamic>> _prepareTextLines(
    OCRResult ocrResult,
    ExtractionResult? extractionResult,
  ) {
    final textLines = <Map<String, dynamic>>[];

    // Estimate image size from bounding boxes
    final imageSize = _estimateImageSize(ocrResult);

    // Prefer structured textLines
    if (ocrResult.textLines.isNotEmpty) {
      for (int i = 0; i < ocrResult.textLines.length; i++) {
        final line = ocrResult.textLines[i];
        
        // Extract features if bounding box is available
        TextLineFeatures? features;
        List<double>? featureVector;
        if (line.boundingBox != null && line.boundingBox!.length >= 4) {
          try {
            features = TextLineFeatureExtractor.extractFeatures(
              text: line.text,
              boundingBox: line.boundingBox,
              lineIndex: i,
              totalLines: ocrResult.textLines.length,
              imageWidth: imageSize['width'] ?? 400.0,
              imageHeight: imageSize['height'] ?? 600.0,
            );
            featureVector = _buildFeatureVector(features);
          } catch (e) {
            logger.w('Failed to extract features for line $i: $e');
          }
        }
        
        // Generate pseudo-label
        final labelInfo = _generatePseudoLabel(line, extractionResult, i);
        
        textLines.add({
          'text': line.text,
          'bounding_box': line.boundingBox,
          'confidence': line.confidence,
          'line_index': i,
          'elements': line.elements.map((e) => {
            'text': e.text,
            'confidence': e.confidence,
            'bounding_box': e.boundingBox,
          }).toList(),
          // ML training fields
          'label': labelInfo['label'],
          'label_confidence': labelInfo['confidence'],
          if (features != null) 'features': _featuresToMap(features),
          if (featureVector != null) 'feature_vector': featureVector,
        });
      }
    } else {
      // Fallback to textBlocks
      for (int i = 0; i < ocrResult.textBlocks.length; i++) {
        final block = ocrResult.textBlocks[i];
        final labelInfo = _generatePseudoLabelFromBlock(block, extractionResult, i);
        
        textLines.add({
          'text': block.text,
          'bounding_box': block.boundingBox,
          'confidence': block.confidence,
          'line_index': i,
          'label': labelInfo['label'],
          'label_confidence': labelInfo['confidence'],
        });
      }
    }

    return textLines;
  }

  /// Generate pseudo-label for a TextLine based on extraction result
  /// For verified data, this generates ground truth labels based on corrected data
  Map<String, dynamic> _generatePseudoLabel(
    TextLine line,
    ExtractionResult? extractionResult,
    int lineIndex,
  ) {
    if (extractionResult == null || !extractionResult.success) {
      return {'label': 'OTHER', 'confidence': 0.0};
    }

    final text = line.text.toLowerCase();
    final extractedData = extractionResult.extractedData;
    final isVerified = extractionResult.metadata['is_ground_truth'] == true;
    final confidenceBase = isVerified ? 1.0 : 0.9; // Verified data has maximum confidence
    
    // Check merchant name (improved matching)
    final merchantName = extractedData['merchant_name'] as String?;
    if (merchantName != null) {
      final merchantLower = merchantName.toLowerCase();
      // Check if merchant name appears in the text (partial match is OK)
      if (text.contains(merchantLower) || 
          merchantLower.split(' ').any((word) => word.length > 3 && text.contains(word))) {
        return {'label': 'MERCHANT_NAME', 'confidence': confidenceBase};
      }
    }
    
    // Check date (improved matching for various formats)
    final date = extractedData['date'] as String?;
    if (date != null) {
      // Check if text line contains date-like pattern first
      final hasDatePattern = RegExp(r'\d{1,2}[.\/-]\d{1,2}[.\/-]\d{2,4}|\d{4}[.\/-]\d{1,2}[.\/-]\d{1,2}').hasMatch(line.text);
      
      if (hasDatePattern) {
        // Extract year from both date and text line
        final dateYearMatch = RegExp(r'(\d{4})').firstMatch(date);
        final textYearMatch = RegExp(r'(\d{4})').firstMatch(line.text);
        
        if (dateYearMatch != null && textYearMatch != null) {
          final dateYear = dateYearMatch.group(1)!;
          final textYear = textYearMatch.group(1)!;
          
          // If years match, it's likely a date
          if (dateYear == textYear) {
            return {'label': 'DATE', 'confidence': confidenceBase};
          }
        }
        
        // Also check if date string appears in text (normalized)
        final dateNormalized = date
            .replaceAll(RegExp(r'[T\s].*$'), '') // Remove time part
            .replaceAll('-', '')
            .replaceAll('/', '');
        final textNormalized = line.text
            .replaceAll('-', '')
            .replaceAll('/', '')
            .replaceAll(RegExp(r'[^\d]'), '');
        
        // Check if normalized date appears in normalized text
        if (textNormalized.contains(dateNormalized) || 
            (textNormalized.length >= 4 && dateNormalized.contains(textNormalized.substring(0, textNormalized.length > 8 ? 8 : textNormalized.length)))) {
          return {'label': 'DATE', 'confidence': confidenceBase};
        }
        
        // If text contains "Date:" or similar keywords and has date pattern, it's likely a date
        if (text.contains('date') || text.contains('datum') || text.contains('日付')) {
          return {'label': 'DATE', 'confidence': confidenceBase};
        }
      }
    }
    
    // Check time (improved matching)
    final time = extractedData['time'] as String?;
    if (time != null) {
      final timeNormalized = time.replaceAll(':', '');
      if (text.contains(timeNormalized) || 
          RegExp(r'\d{1,2}:\d{2}(:\d{2})?').hasMatch(line.text)) {
        return {'label': 'TIME', 'confidence': confidenceBase};
      }
    }
    
    // Check receipt number (improved matching)
    final receiptNumber = extractedData['receipt_number'] as String?;
    if (receiptNumber != null) {
      final receiptNormalized = receiptNumber.replaceAll(RegExp(r'[^\d]'), '');
      final textNormalized = line.text.replaceAll(RegExp(r'[^\d]'), '');
      if (textNormalized.contains(receiptNormalized) || 
          text.contains(receiptNumber.toLowerCase())) {
        return {'label': 'RECEIPT_NUMBER', 'confidence': confidenceBase};
      }
    }
    
    // Check amounts (Subtotal, Tax, Total) - improved with value matching
    final subtotalAmount = extractedData['subtotal_amount'] as double?;
    final taxAmount = extractedData['tax_amount'] as double?;
    final totalAmount = extractedData['total_amount'] as double?;
    
    // Extract amount from text line
    final amountMatch = RegExp(r'[\d.,]+').firstMatch(line.text);
    double? lineAmount;
    if (amountMatch != null) {
      final amountStr = amountMatch.group(0)!.replaceAll(',', '.');
      lineAmount = double.tryParse(amountStr);
    }
    
    // Check Subtotal (keyword + amount match for verified data)
    final subtotalKeywords = LanguageKeywords.getAllKeywords('subtotal');
    for (final keyword in subtotalKeywords) {
      if (text.contains(keyword.toLowerCase())) {
        final confidence = isVerified && subtotalAmount != null && lineAmount != null &&
            (lineAmount - subtotalAmount).abs() < 0.01
            ? confidenceBase
            : 0.8;
        return {'label': 'SUBTOTAL', 'confidence': confidence};
      }
    }
    
    // Check Tax (keyword + amount match for verified data)
    final taxKeywords = LanguageKeywords.getAllKeywords('tax');
    for (final keyword in taxKeywords) {
      if (text.contains(keyword.toLowerCase())) {
        final confidence = isVerified && taxAmount != null && lineAmount != null &&
            (lineAmount - taxAmount).abs() < 0.01
            ? confidenceBase
            : 0.8;
        return {'label': 'TAX', 'confidence': confidence};
      }
    }
    
    // Check Total (keyword + amount match for verified data, exclude subtotal)
    final totalKeywords = LanguageKeywords.getAllKeywords('total');
    for (final keyword in totalKeywords) {
      if (text.contains(keyword.toLowerCase()) && !text.contains('subtotal')) {
        final confidence = isVerified && totalAmount != null && lineAmount != null &&
            (lineAmount - totalAmount).abs() < 0.01
            ? confidenceBase
            : 0.8;
        return {'label': 'TOTAL', 'confidence': confidence};
      }
    }
    
    // Check payment method (improved matching)
    final paymentMethod = extractedData['payment_method'] as String?;
    if (paymentMethod != null) {
      final paymentLower = paymentMethod.toLowerCase();
      final paymentKeywords = LanguageKeywords.getAllKeywords('payment_method_cash') +
          LanguageKeywords.getAllKeywords('payment_method_card');
      for (final keyword in paymentKeywords) {
        if (text.contains(keyword.toLowerCase()) || 
            (paymentLower.contains('card') && text.contains('card')) ||
            (paymentLower.contains('cash') && text.contains('cash'))) {
          return {'label': 'PAYMENT_METHOD', 'confidence': confidenceBase};
        }
      }
    }
    
    // Check if it looks like an item (has price-like pattern)
    if (RegExp(r'[\d.,]+\s*[€$£¥kr]|[\d.,]+\s*[€$£¥kr]').hasMatch(line.text)) {
      return {'label': 'ITEM_PRICE', 'confidence': isVerified ? 0.8 : 0.6};
    }
    
    // Check if it looks like an item name (text before price)
    if (lineIndex > 0 && lineIndex < 15) { // Usually items are in middle section
      return {'label': 'ITEM_NAME', 'confidence': isVerified ? 0.7 : 0.5};
    }
    
    return {'label': 'OTHER', 'confidence': isVerified ? 0.5 : 0.3};
  }

  /// Generate pseudo-label for a TextBlock (fallback)
  Map<String, dynamic> _generatePseudoLabelFromBlock(
    TextBlock block,
    ExtractionResult? extractionResult,
    int lineIndex,
  ) {
    // Similar logic but simpler for blocks
    return {'label': 'OTHER', 'confidence': 0.3};
  }

  /// Build feature vector from TextLineFeatures
  List<double> _buildFeatureVector(TextLineFeatures features) {
    return [
      // Position features (4)
      features.xCenter,
      features.yCenter,
      features.width,
      features.height,
      // Position flags (4)
      features.isRightSide ? 1.0 : 0.0,
      features.isBottomArea ? 1.0 : 0.0,
      features.isMiddleSection ? 1.0 : 0.0,
      features.lineIndexNorm,
      // Text features (12)
      features.hasCurrencySymbol ? 1.0 : 0.0,
      features.hasPercent ? 1.0 : 0.0,
      features.hasAmountLike ? 1.0 : 0.0,
      features.hasTotalKeyword ? 1.0 : 0.0,
      features.hasTaxKeyword ? 1.0 : 0.0,
      features.hasSubtotalKeyword ? 1.0 : 0.0,
      features.hasDateLike ? 1.0 : 0.0,
      features.hasQuantityMarker ? 1.0 : 0.0,
      features.hasItemLike ? 1.0 : 0.0,
      features.digitCount / 100.0, // Normalize
      features.alphaCount / 100.0, // Normalize
      features.containsColon ? 1.0 : 0.0,
    ];
  }

  /// Estimate image size from bounding boxes
  Map<String, double> _estimateImageSize(OCRResult ocrResult) {
    double maxX = 0.0;
    double maxY = 0.0;
    
    for (final line in ocrResult.textLines) {
      if (line.boundingBox != null && line.boundingBox!.length >= 4) {
        final x = line.boundingBox![0];
        final y = line.boundingBox![1];
        final w = line.boundingBox![2];
        final h = line.boundingBox![3];
        
        maxX = maxX > (x + w) ? maxX : (x + w);
        maxY = maxY > (y + h) ? maxY : (y + h);
      }
    }
    
    // Add some padding (10%)
    return {
      'width': maxX > 0 ? maxX * 1.1 : 400.0,
      'height': maxY > 0 ? maxY * 1.1 : 600.0,
    };
  }

  /// Convert TextLineFeatures to Map for JSON serialization
  Map<String, dynamic> _featuresToMap(TextLineFeatures features) {
    return {
      'x_center': features.xCenter,
      'y_center': features.yCenter,
      'width': features.width,
      'height': features.height,
      'is_right_side': features.isRightSide,
      'is_bottom_area': features.isBottomArea,
      'is_middle_section': features.isMiddleSection,
      'line_index_norm': features.lineIndexNorm,
      'has_currency_symbol': features.hasCurrencySymbol,
      'has_percent': features.hasPercent,
      'has_amount_like': features.hasAmountLike,
      'has_total_keyword': features.hasTotalKeyword,
      'has_tax_keyword': features.hasTaxKeyword,
      'has_subtotal_keyword': features.hasSubtotalKeyword,
      'has_date_like': features.hasDateLike,
      'has_quantity_marker': features.hasQuantityMarker,
      'has_item_like': features.hasItemLike,
      'digit_count': features.digitCount,
      'alpha_count': features.alphaCount,
      'contains_colon': features.containsColon,
    };
  }

  /// Prepare extraction result for training data
  Map<String, dynamic> _prepareExtractionResult(ExtractionResult extractionResult) {
    return {
      'success': extractionResult.success,
      'confidence': extractionResult.confidence,
      'extracted_data': extractionResult.extractedData,
      'warnings': extractionResult.warnings,
      'applied_patterns': extractionResult.appliedPatterns,
      'metadata': extractionResult.metadata,
    };
  }

  /// Get training data directory
  Future<Directory> _getTrainingDataDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final trainingDir = Directory(path.join(appDir.path, _trainingDataDir));
    if (!await trainingDir.exists()) {
      await trainingDir.create(recursive: true);
    }
    return trainingDir;
  }

  /// Get path to training data directory (for external access)
  Future<String> getTrainingDataPath() async {
    final dir = await _getTrainingDataDirectory();
    return dir.path;
  }

  /// Get list of saved training data files
  Future<List<File>> getSavedTrainingDataFiles() async {
    try {
      final trainingDir = await _getTrainingDataDirectory();
      final rawDir = Directory(path.join(trainingDir.path, _rawDataDir));
      if (!await rawDir.exists()) {
        return [];
      }
      return rawDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.json'))
          .toList()
        ..sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    } catch (e) {
      logger.e('Failed to list training data files: $e');
      return [];
    }
  }

  /// Save verified training data (user-corrected ground truth)
  /// Returns the saved file path, or null if save failed
  Future<String?> saveVerifiedTrainingData({
    required String receiptId,
    required OCRResult ocrResult,
    required Map<String, dynamic> correctedData, // User-corrected extraction data
    required String imagePath,
    Map<String, dynamic>? additionalMetadata,
  }) async {
    try {
      // Create a mock ExtractionResult from corrected data for label generation
      final mockExtractionResult = ExtractionResult(
        success: true,
        processingTime: 0,
        extractedData: correctedData,
        confidence: 1.0,
      );
      
      // Prepare verified training data structure
      final trainingData = <String, dynamic>{
        'receipt_id': receiptId,
        'timestamp': DateTime.now().toIso8601String(),
        'is_verified': true, // Mark as verified ground truth
        'text_lines': _prepareTextLines(ocrResult, mockExtractionResult),
        'extraction_result': {
          'success': true,
          'confidence': 1.0, // Verified data has maximum confidence
          'extracted_data': correctedData,
          'warnings': [],
          'applied_patterns': [],
          'metadata': {
            'parsing_method': 'user_verified',
            'is_ground_truth': true,
          },
        },
        'metadata': {
          'image_path': imagePath,
          'language': ocrResult.detectedLanguage ?? 'unknown',
          'ocr_confidence': ocrResult.confidence,
          'extraction_confidence': 1.0, // Verified data
          'extraction_method': 'user_verified',
          'text_lines_count': ocrResult.textLines.length,
          'text_blocks_count': ocrResult.textBlocks.length,
          'verified_at': DateTime.now().toIso8601String(),
          if (additionalMetadata != null) ...additionalMetadata,
        },
      };

      // Get training data directory
      final trainingDir = await _getTrainingDataDirectory();
      final verifiedDir = Directory(path.join(trainingDir.path, _verifiedDataDir));
      if (!await verifiedDir.exists()) {
        await verifiedDir.create(recursive: true);
      }

      // Save as JSON file
      final fileName = 'verified_receipt_${receiptId}_${DateTime.now().millisecondsSinceEpoch}.json';
      final filePath = path.join(verifiedDir.path, fileName);
      final file = File(filePath);
      
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(trainingData),
        encoding: utf8,
      );

      logger.i('✅ Verified training data saved: $filePath');
      return filePath;
    } catch (e) {
      logger.e('Failed to save verified training data: $e');
      return null;
    }
  }

  /// Get list of saved verified training data files
  Future<List<File>> getVerifiedTrainingDataFiles() async {
    try {
      final trainingDir = await _getTrainingDataDirectory();
      final verifiedDir = Directory(path.join(trainingDir.path, _verifiedDataDir));
      if (!await verifiedDir.exists()) {
        return [];
      }
      return verifiedDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.json'))
          .toList()
        ..sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    } catch (e) {
      logger.e('Failed to list verified training data files: $e');
      return [];
    }
  }

  /// Delete training data file
  Future<bool> deleteTrainingDataFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        logger.d('Deleted training data file: $filePath');
        return true;
      }
      return false;
    } catch (e) {
      logger.e('Failed to delete training data file: $e');
      return false;
    }
  }
}

