import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;

import '../../core/errors/exceptions.dart';
import '../../data/models/processing_result.dart' as models;
import '../../main.dart';

/// Service for Google ML Kit text recognition
class MLKitService {
  late final TextRecognizer _textRecognizer;
  
  MLKitService() {
    _textRecognizer = TextRecognizer(
      script: TextRecognitionScript.latin,
    );
  }

  /// Recognize text from image file
  Future<models.OCRResult> recognizeTextFromFile(String imagePath) async {
    final stopwatch = Stopwatch()..start();
    
    try {
      logger.d('Starting OCR recognition for: $imagePath');
      
      // Validate file exists
      final file = File(imagePath);
      if (!await file.exists()) {
        throw FileNotFoundStorageException(imagePath);
      }

      // Create InputImage from file
      final inputImage = InputImage.fromFilePath(imagePath);
      
      // Perform text recognition
      final recognizedText = await _textRecognizer.processImage(inputImage);
      
      stopwatch.stop();
      final processingTime = stopwatch.elapsedMilliseconds;
      
      // Process results
      return _processRecognitionResult(recognizedText, processingTime);
      
    } catch (e) {
      stopwatch.stop();
      logger.e('OCR recognition failed: $e');
      
      if (e is ReceiptScannerException) {
        rethrow;
      }
      
      return models.OCRResult.failure(
        errorMessage: 'OCR recognition failed: $e',
        processingTime: stopwatch.elapsedMilliseconds,
      );
    }
  }

  /// Recognize text from image bytes
  Future<models.OCRResult> recognizeTextFromBytes(Uint8List imageBytes) async {
    final stopwatch = Stopwatch()..start();
    
    try {
      logger.d('Starting OCR recognition from bytes');
      
      // Create InputImage from bytes
      final inputImage = InputImage.fromBytes(
        bytes: imageBytes,
        metadata: InputImageMetadata(
          size: _getImageSize(imageBytes),
          rotation: InputImageRotation.rotation0deg,
          format: InputImageFormat.nv21,
          bytesPerRow: 0, // Auto-calculated
        ),
      );
      
      // Perform text recognition
      final recognizedText = await _textRecognizer.processImage(inputImage);
      
      stopwatch.stop();
      final processingTime = stopwatch.elapsedMilliseconds;
      
      // Process results
      return _processRecognitionResult(recognizedText, processingTime);
      
    } catch (e) {
      stopwatch.stop();
      logger.e('OCR recognition from bytes failed: $e');
      
      return models.OCRResult.failure(
        errorMessage: 'OCR recognition failed: $e',
        processingTime: stopwatch.elapsedMilliseconds,
      );
    }
  }

  /// Process ML Kit recognition result
  models.OCRResult _processRecognitionResult(
    RecognizedText recognizedText, 
    int processingTime,
  ) {
    final fullText = recognizedText.text;
    
    // Check if any text was found
    if (fullText.isEmpty) {
      logger.w('No text recognized in image');
      return models.OCRResult.failure(
        errorMessage: 'No text found in image',
        processingTime: processingTime,
      );
    }

    // Extract text blocks and lines with confidence and position
    final textBlocks = <models.TextBlock>[];
    final rawTextLines = <models.TextLine>[]; // Temporary list before combining
    double totalConfidence = 0.0;
    int elementCount = 0;

    // Step 1: Extract all lines from ML Kit
    for (final block in recognizedText.blocks) {
      for (final line in block.lines) {
        // Extract line-level information
        final lineElements = <models.TextBlock>[];
        final lineTextParts = <String>[];
        
        // Calculate line bounding box (union of all elements)
        double? minX, minY, maxX, maxY;
        
        for (final element in line.elements) {
          // Calculate bounding box for element
          final boundingBox = element.boundingBox;
          final boxCoords = [
            boundingBox.left.toDouble(),
            boundingBox.top.toDouble(),
            boundingBox.width.toDouble(),
            boundingBox.height.toDouble(),
          ];

          // Update line bounding box
          if (minX == null || boundingBox.left < minX) minX = boundingBox.left.toDouble();
          if (minY == null || boundingBox.top < minY) minY = boundingBox.top.toDouble();
          if (maxX == null || (boundingBox.left + boundingBox.width) > maxX) {
            maxX = (boundingBox.left + boundingBox.width).toDouble();
          }
          if (maxY == null || (boundingBox.top + boundingBox.height) > maxY) {
            maxY = (boundingBox.top + boundingBox.height).toDouble();
          }

          final textBlock = models.TextBlock(
            text: element.text,
            confidence: 1.0, // ML Kit doesn't provide element-level confidence
            boundingBox: boxCoords,
            language: null, // Will be detected separately
          );
          
          textBlocks.add(textBlock);
          lineElements.add(textBlock);
          lineTextParts.add(element.text);

          totalConfidence += 1.0;
          elementCount++;
        }
        
        // Create line from elements
        if (lineElements.isNotEmpty && minX != null && minY != null && maxX != null && maxY != null) {
          final lineText = lineTextParts.join(' ');
          final lineBoundingBox = [
            minX,
            minY,
            maxX - minX,
            maxY - minY,
          ];
          
          rawTextLines.add(models.TextLine(
            text: lineText,
            confidence: 1.0,
            boundingBox: lineBoundingBox,
            elements: lineElements,
          ));
          
          logger.d('📄 Raw line extracted: "$lineText" (y: ${minY.toStringAsFixed(1)})');
        }
      }
    }

    // Step 2: Combine lines with same Y coordinate (within tolerance)
    logger.d('🔄 Combining lines with same Y coordinate (tolerance: 10px)...');
    final textLines = <models.TextLine>[];
    const yTolerance = 10.0; // Pixels tolerance for same line
    
    // Group lines by Y coordinate
    final yGroups = <double, List<models.TextLine>>{};
    for (final line in rawTextLines) {
      final y = line.boundingBox?[1] ?? 0.0;
      
      // Find existing group with similar Y coordinate
      double? matchedY;
      for (final groupY in yGroups.keys) {
        if ((y - groupY).abs() <= yTolerance) {
          matchedY = groupY;
          break;
        }
      }
      
      if (matchedY != null) {
        yGroups[matchedY]!.add(line);
      } else {
        yGroups[y] = [line];
      }
    }
    
    // Combine lines in each group
    for (final entry in yGroups.entries) {
      final groupY = entry.key;
      final linesInGroup = entry.value;
      
      if (linesInGroup.length == 1) {
        // Single line, no need to combine
        textLines.add(linesInGroup[0]);
        logger.d('  ✓ Single line: "${linesInGroup[0].text}" (y: ${groupY.toStringAsFixed(1)})');
      } else {
        // Multiple lines with same Y, combine them
        final combinedElements = <models.TextBlock>[];
        final combinedTextParts = <String>[];
        double? combinedMinX, combinedMinY, combinedMaxX, combinedMaxY;
        
        // Sort by X coordinate (left to right)
        linesInGroup.sort((a, b) {
          final aX = a.boundingBox?[0] ?? 0.0;
          final bX = b.boundingBox?[0] ?? 0.0;
          return aX.compareTo(bX);
        });
        
        for (final line in linesInGroup) {
          combinedTextParts.add(line.text);
          combinedElements.addAll(line.elements);
          
          final bbox = line.boundingBox;
          if (bbox != null && bbox.length >= 4) {
            final x = bbox[0];
            final y = bbox[1];
            final w = bbox[2];
            final h = bbox[3];
            
            if (combinedMinX == null || x < combinedMinX) combinedMinX = x;
            if (combinedMinY == null || y < combinedMinY) combinedMinY = y;
            if (combinedMaxX == null || (x + w) > combinedMaxX) combinedMaxX = x + w;
            if (combinedMaxY == null || (y + h) > combinedMaxY) combinedMaxY = y + h;
          }
        }
        
        if (combinedMinX != null && combinedMinY != null && combinedMaxX != null && combinedMaxY != null) {
          final combinedText = combinedTextParts.join(' ');
          final combinedBbox = [
            combinedMinX,
            combinedMinY,
            combinedMaxX - combinedMinX,
            combinedMaxY - combinedMinY,
          ];
          
          final combinedLine = models.TextLine(
            text: combinedText,
            confidence: 1.0,
            boundingBox: combinedBbox,
            elements: combinedElements,
          );
          
          textLines.add(combinedLine);
          logger.d('  🔗 Combined ${linesInGroup.length} lines (y: ${groupY.toStringAsFixed(1)}): "${combinedText}"');
          for (int i = 0; i < linesInGroup.length; i++) {
            logger.d('    - Line $i: "${linesInGroup[i].text}"');
          }
        }
      }
    }
    
    // Sort final lines by Y coordinate (top to bottom)
    textLines.sort((a, b) {
      final aY = a.boundingBox?[1] ?? 0.0;
      final bY = b.boundingBox?[1] ?? 0.0;
      return aY.compareTo(bY);
    });
    
    logger.d('✅ Line combining completed: ${rawTextLines.length} raw lines → ${textLines.length} combined lines');

    // Calculate overall confidence
    final confidence = elementCount > 0 ? totalConfidence / elementCount : 0.0;
    
    // Detect language
    final detectedLanguage = _detectLanguage(fullText);
    
    logger.i('OCR completed: ${fullText.length} characters, ${textLines.length} lines, $elementCount elements, confidence: ${confidence.toStringAsFixed(2)}');

    return models.OCRResult.success(
      recognizedText: fullText,
      processingTime: processingTime,
      detectedLanguage: detectedLanguage,
      confidence: confidence,
      textBlocks: textBlocks,
      textLines: textLines,
      metadata: {
        'blocks_count': recognizedText.blocks.length,
        'lines_count': textLines.length,
        'elements_count': elementCount,
      },
    );
  }

  /// Simple language detection based on common words
  String? _detectLanguage(String text) {
    final lowerText = text.toLowerCase();
    
    // Language-specific keywords
    final languageKeywords = <String, List<String>>{
      'fi': ['yhteensä', 'alv', 'käteinen', 'kortti', 'kuitti', 'kauppa', 'summa'],
      'sv': ['totalt', 'moms', 'kontanter', 'kort', 'kvitto', 'affär', 'summa'],
      'fr': ['total', 'tva', 'espèces', 'carte', 'reçu', 'magasin', 'montant'],
      'de': ['gesamt', 'mwst', 'bar', 'karte', 'rechnung', 'geschäft', 'betrag'],
      'it': ['totale', 'iva', 'contanti', 'carta', 'ricevuta', 'negozio', 'importo'],
      'es': ['total', 'iva', 'efectivo', 'tarjeta', 'recibo', 'tienda', 'importe'],
    };

    int maxMatches = 0;
    String? bestLanguage;

    for (final entry in languageKeywords.entries) {
      final language = entry.key;
      final keywords = entry.value;
      
      int matches = 0;
      for (final keyword in keywords) {
        if (lowerText.contains(keyword)) {
          matches++;
        }
      }

      if (matches > maxMatches) {
        maxMatches = matches;
        bestLanguage = language;
      }
    }

    // Default to English if no specific language detected
    return bestLanguage ?? 'en';
  }

  /// Get image size from bytes
  Size _getImageSize(Uint8List imageBytes) {
    try {
      final image = img.decodeImage(imageBytes);
      if (image != null) {
        return Size(image.width.toDouble(), image.height.toDouble());
      }
    } catch (e) {
      logger.w('Failed to decode image size: $e');
    }
    
    // Return default size if decoding fails
    return const Size(1000, 1000);
  }

  /// Dispose of resources
  void dispose() {
    _textRecognizer.close();
    logger.d('MLKitService disposed');
  }
}