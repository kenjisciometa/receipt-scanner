import 'dart:math' as math;

import '../../core/constants/language_keywords.dart';
import '../../core/constants/pattern_generator.dart';
import '../../core/constants/regex_patterns.dart';
import '../../core/errors/exceptions.dart';
import '../../data/models/receipt.dart';
import '../../data/models/receipt_item.dart';
import '../../data/models/processing_result.dart';
import '../../main.dart';

/// 金額候補を表すクラス
class AmountCandidate {
  final double amount;
  int score; // mutable for score adjustments
  final int lineIndex;
  final String source;
  final String? label;
  final double? confidence;
  final List<double>? boundingBox;
  final String fieldName; // 'total_amount', 'subtotal_amount', 'tax_amount'

  AmountCandidate({
    required this.amount,
    required this.score,
    required this.lineIndex,
    required this.source,
    required this.fieldName,
    this.label,
    this.confidence,
    this.boundingBox,
  });

  @override
  String toString() => 'AmountCandidate($fieldName: $amount, score: $score, line: $lineIndex)';
}

/// フィールドごとの候補リスト
class FieldCandidates {
  final String fieldName;
  final List<AmountCandidate> candidates;

  FieldCandidates({
    required this.fieldName,
    required this.candidates,
  });

  /// 上位N個の候補を取得
  List<AmountCandidate> getTopN(int n) {
    final sorted = List<AmountCandidate>.from(candidates);
    sorted.sort((a, b) => b.score.compareTo(a.score));
    return sorted.take(n).toList();
  }

  /// 最良候補を取得
  AmountCandidate? get best => candidates.isNotEmpty ? getTopN(1).first : null;
}

/// 整合性チェック結果
class ConsistencyResult {
  final Map<String, AmountCandidate> selectedCandidates;
  final double consistencyScore;
  final List<String> warnings;
  final bool needsVerification;
  final Map<String, double>? correctedValues;

  ConsistencyResult({
    required this.selectedCandidates,
    required this.consistencyScore,
    this.warnings = const [],
    this.needsVerification = false,
    this.correctedValues,
  });
}

/// Main service for parsing receipt data from OCR text
class ReceiptParser {
  /// Parse receipt data from OCR text and (optional) structured OCR blocks
  Future<ExtractionResult> parseReceiptText({
    required String ocrText,
    required String? detectedLanguage,
    required double ocrConfidence,
    List<Map<String, dynamic>>? textBlocks,
    List<TextLine>? textLines,
  }) async {
    final stopwatch = Stopwatch()..start();
    final appliedPatterns = <String>[];
    final warnings = <String>[];

    try {
      // Normalize OCR text (reduce common OCR noise)
      final normalizedText = _normalizeOcrText(ocrText);

      logger.d('Starting receipt data extraction for language: $detectedLanguage');
      logger.d('OCR text length: ${normalizedText.length} characters');
      logger.d('OCR text content:\n$normalizedText');

      // Log textLines if available
      if (textLines != null && textLines.isNotEmpty) {
        logger.d('📋 Structured textLines (${textLines.length} lines):');
        for (int i = 0; i < textLines.length; i++) {
          final line = textLines[i];
          final bbox = line.boundingBox;
          final bboxStr = bbox != null && bbox.length >= 4
              ? '[x:${bbox[0].toStringAsFixed(1)}, y:${bbox[1].toStringAsFixed(1)}, w:${bbox[2].toStringAsFixed(1)}, h:${bbox[3].toStringAsFixed(1)}]'
              : 'no bbox';
          logger.d('  Line $i: "${line.text}" (confidence: ${line.confidence.toStringAsFixed(2)}, bbox: $bboxStr, elements: ${line.elements.length})');
        }
      }

      if (normalizedText.trim().isEmpty) {
        throw InsufficientDataException(['raw_text']);
      }

      // Prefer structured parsing with textLines (best for receipts)
      if (textLines != null && textLines.isNotEmpty) {
        logger.d('Using structured parsing with ${textLines.length} textLines');
        final result = await _parseWithStructuredData(
          normalizedText,
          textBlocks ?? <Map<String, dynamic>>[],
          detectedLanguage,
          ocrConfidence,
          appliedPatterns,
          warnings,
          stopwatch,
          textLines: textLines,
        );
        return result;
      }

      // Fallback: use textBlocks if available
      if (textBlocks != null && textBlocks.isNotEmpty) {
        logger.d('Using structured parsing with ${textBlocks.length} blocks');
        final result = await _parseWithStructuredData(
          normalizedText,
          textBlocks!,
          detectedLanguage,
          ocrConfidence,
          appliedPatterns,
          warnings,
          stopwatch,
        );
        return result;
      }

      // Fallback: text-only parsing with line structure
      logger.d('Using text-only parsing (line-by-line) approach');
      
      // Use structured line information if available, otherwise fall back to text splitting
      List<String> lines;
      if (textBlocks != null && textBlocks.isNotEmpty) {
        // Extract lines from structured text blocks (preferred method)
        logger.d('Using structured line information from OCR');
        lines = _extractLinesFromTextBlocks(textBlocks);
      } else {
        // Fall back to simple text splitting
        logger.d('Using text splitting approach (no structured blocks available)');
        lines = normalizedText
            .split('\n')
            .map(_normalizeLine)
            .where((line) => line.trim().isNotEmpty)
            .toList();
      }

      logger.d('Processing ${lines.length} lines of text');
      for (int i = 0; i < lines.length; i++) {
        logger.d('Line $i: "${lines[i]}"');
      }

      // Combine consecutive lines that belong together (e.g., "TOTAL:" and "€15.60")
      lines = _combineRelatedLines(lines);
      logger.d('After combining related lines: ${lines.length} lines');
      for (int i = 0; i < lines.length; i++) {
        logger.d('Combined line $i: "${lines[i]}"');
      }

      final extractedData = <String, dynamic>{};

      // Merchant
      final merchantName = _extractMerchantName(normalizedText, appliedPatterns);
      if (merchantName != null) {
        extractedData['merchant_name'] = merchantName;
      } else {
        warnings.add('Merchant name not found');
      }

      // Date
      final date = _extractDate(normalizedText, appliedPatterns);
      if (date != null) {
        extractedData['date'] = date.toIso8601String();
      } else {
        warnings.add('Purchase date not found');
      }

      // Time (optional)
      final time = _extractTime(normalizedText, appliedPatterns);
      if (time != null) {
        extractedData['time'] = time; // "HH:mm:ss" or "HH:mm"
      }

      // Amounts (total/subtotal/tax)
      final amounts = _extractAmountsLineByLine(lines, detectedLanguage, appliedPatterns);
      logger.d('Extracted amounts: $amounts');
      extractedData.addAll(amounts);

      // Payment method
      final paymentMethod = _extractPaymentMethod(normalizedText, appliedPatterns);
      if (paymentMethod != null) {
        extractedData['payment_method'] = paymentMethod.name;
      }

      // Currency
      final currency = _extractCurrency(normalizedText, appliedPatterns);
      if (currency != null) {
        extractedData['currency'] = currency.code;
      }

      // Receipt number
      final receiptNumber = _extractReceiptNumber(normalizedText, appliedPatterns);
      if (receiptNumber != null) {
        extractedData['receipt_number'] = receiptNumber;
      }

      // Items (optional)
      final items = _extractItems(normalizedText, appliedPatterns);
      if (items.isNotEmpty) {
        extractedData['items'] = items
            .map((item) => {
                  'name': item.name,
                  'quantity': item.quantity,
                  'unit_price': item.unitPrice,
                  'total_price': item.totalPrice,
                  'category': item.category,
                })
            .toList();
      }

      // Confidence
      final confidence = _calculateExtractionConfidence(
        extractedData,
        ocrConfidence,
        warnings.length,
      );

      stopwatch.stop();
      final processingTime = stopwatch.elapsedMilliseconds;

      logger.d('Final extracted data: $extractedData');

      _validateExtractedData(extractedData, warnings);
      logger.d('Validation warnings: $warnings');

      logger.i('Receipt extraction completed: ${extractedData.length} fields, '
          'confidence: ${confidence.toStringAsFixed(2)}, '
          'warnings: ${warnings.length}');

      return ExtractionResult.success(
        extractedData: extractedData,
        processingTime: processingTime,
        confidence: confidence,
        warnings: warnings,
        appliedPatterns: appliedPatterns,
        metadata: {
          'detected_language': detectedLanguage,
          'ocr_confidence': ocrConfidence,
          'text_length': normalizedText.length,
          'patterns_applied': appliedPatterns.length,
          'parsing_method': 'text_line_by_line',
        },
      );
    } catch (e) {
      stopwatch.stop();
      logger.e('Receipt extraction failed: $e');

      if (e is ReceiptScannerException) {
        rethrow;
      }

      return ExtractionResult.failure(
        errorMessage: 'Receipt extraction failed: $e',
        processingTime: stopwatch.elapsedMilliseconds,
        warnings: warnings,
        metadata: {
          'detected_language': detectedLanguage,
          'patterns_tried': appliedPatterns.length,
        },
      );
    }
  }

  // ----------------------------
  // Normalization helpers
  // ----------------------------

  String _normalizeOcrText(String input) {
    // Normalize newlines and common OCR variants
    var text = input.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

    // Replace common currency symbol variants/spaces
    text = text
        .replaceAll('EUR', '€')
        .replaceAll('EURO', '€')
        .replaceAll(RegExp(r'\s+€'), ' €')
        .replaceAll(RegExp(r'€\s+'), '€');

    // Remove weird non-breaking spaces
    text = text.replaceAll('\u00A0', ' ');

    // Normalize repeated spaces
    text = text.replaceAll(RegExp(r'[ \t]+'), ' ');

    return text.trim();
  }

  String _normalizeLine(String line) {
    var s = line.replaceAll('\u00A0', ' ').trimRight();
    // Some OCR inserts spaces around ":" or "#"
    s = s.replaceAll(RegExp(r'\s*:\s*'), ': ');
    s = s.replaceAll(RegExp(r'\s*#\s*'), '#');
    // Normalize multiple spaces
    s = s.replaceAll(RegExp(r'[ \t]{2,}'), ' ');
    return s.trim();
  }

  // ----------------------------
  // Merchant
  // ----------------------------

  /// Extract merchant name from text
  String? _extractMerchantName(String text, List<String> appliedPatterns) {
    final lines = text.split('\n').map(_normalizeLine).where((l) => l.isNotEmpty).toList();

    // Prefer top-most "all caps" looking line in first 3 lines
    for (int i = 0; i < math.min(3, lines.length); i++) {
      final line = lines[i].trim();
      if (line.length < 3 || line.length > 60) continue;
      if (_isCommonNonMerchantText(line)) continue;
      if (line.contains(':') || line.contains('#')) continue;

      final letters = RegExp(r'[A-Za-zÄÖÅäöåÉÈÊËéèêëÜüß]').allMatches(line).length;
      if (letters >= 4) {
        final upper = line.toUpperCase();
        final sameAsUpper = (line == upper);
        if (sameAsUpper) {
          appliedPatterns.add('heuristic_merchant_caps');
          return line;
        }
      }
    }

    // Try regex patterns (project-defined)
    for (int i = 0; i < math.min(5, lines.length); i++) {
      final line = lines[i].trim();
      if (line.isEmpty || line.length < 3) continue;

      for (final pattern in RegexPatterns.merchantPatterns) {
        final match = pattern.firstMatch(line);
        if (match != null) {
          appliedPatterns.add('merchant_pattern_${RegexPatterns.merchantPatterns.indexOf(pattern)}');
          return match.group(1)?.trim();
        }
      }
    }

    // Heuristic: first meaningful line that's not date/amount/address-ish
    for (int i = 0; i < math.min(6, lines.length); i++) {
      final line = lines[i].trim();
      if (line.isEmpty || line.length < 3 || line.length > 60) continue;

      if (_isCommonNonMerchantText(line)) continue;
      if (RegexPatterns.datePatterns.any((p) => p.hasMatch(line))) continue;
      if (RegExp(r'^\s*(date|time|receipt|invoice)\b', caseSensitive: false).hasMatch(line)) {
        continue;
      }
      // skip lines that are mostly digits (address/zip)
      if (RegExp(r'^\d').hasMatch(line)) continue;

      // avoid lines containing currency or typical totals
      if (RegExp(r'[€$£¥₹]').hasMatch(line)) continue;

      appliedPatterns.add('heuristic_merchant');
      return line;
    }

    return null;
  }

  // ----------------------------
  // Date & Time
  // ----------------------------

  /// Extract purchase date from text
  DateTime? _extractDate(String text, List<String> appliedPatterns) {
    // First: try "Date: YYYY-MM-DD" explicitly (common in template)
    final explicit = RegExp(
      r'\bdate\s*[:\-]?\s*(\d{4})[\/\-.](\d{1,2})[\/\-.](\d{1,2})\b',
      caseSensitive: false,
    ).firstMatch(text);
    if (explicit != null) {
      try {
        appliedPatterns.add('date_explicit_ymd');
        final y = int.parse(explicit.group(1)!);
        final m = int.parse(explicit.group(2)!);
        final d = int.parse(explicit.group(3)!);
        return DateTime(y, m, d);
      } catch (_) {}
    }

    // Then: project-defined patterns
    for (final pattern in RegexPatterns.datePatterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        try {
          appliedPatterns.add('date_pattern_${RegexPatterns.datePatterns.indexOf(pattern)}');
          return _parseDate(match);
        } catch (e) {
          logger.w('Failed to parse date: ${match.group(0)} - $e');
        }
      }
    }

    return null;
  }

  /// Extract time string (HH:mm[:ss]) from text
  String? _extractTime(String text, List<String> appliedPatterns) {
    // Prefer "Time: 13:30:15"
    final m = RegExp(
      r'\btime\s*[:\-]?\s*([01]?\d|2[0-3]):([0-5]\d)(?::([0-5]\d))?\b',
      caseSensitive: false,
    ).firstMatch(text);

    if (m != null) {
      appliedPatterns.add('time_explicit');
      final hh = m.group(1)!.padLeft(2, '0');
      final mm = m.group(2)!.padLeft(2, '0');
      final ss = m.group(3);
      return ss == null ? '$hh:$mm' : '$hh:$mm:${ss.padLeft(2, '0')}';
    }

    // Fallback: any time occurrence (but avoid matching parts of prices like 12.58)
    final any = RegExp(
      r'\b([01]?\d|2[0-3]):([0-5]\d)(?::([0-5]\d))?\b',
      caseSensitive: false,
    ).firstMatch(text);

    if (any != null) {
      appliedPatterns.add('time_any');
      final hh = any.group(1)!.padLeft(2, '0');
      final mm = any.group(2)!.padLeft(2, '0');
      final ss = any.group(3);
      return ss == null ? '$hh:$mm' : '$hh:$mm:${ss.padLeft(2, '0')}';
    }

    return null;
  }

  /// Parse date from regex match (kept for compatibility with RegexPatterns)
  DateTime _parseDate(RegExpMatch match) {
    final groups = [
      match.group(1)!,
      match.group(2)!,
      match.group(3)!,
    ];

    final fullMatch = match.group(0)!;
    logger.d('Parsing date match: "$fullMatch", groups: $groups');

    int year, month, day;

    if (groups[0].length == 4) {
      // YYYY-MM-DD / YYYY/MM/DD
      year = int.parse(groups[0]);
      month = int.parse(groups[1]);
      day = int.parse(groups[2]);
      logger.d('Detected YYYY-MM-DD format: $year-$month-$day');
    } else if (groups[2].length == 4) {
      // DD/MM/YYYY
      day = int.parse(groups[0]);
      month = int.parse(groups[1]);
      year = int.parse(groups[2]);
      logger.d('Detected DD/MM/YYYY format: $day/$month/$year');
    } else {
      // DD/MM/YY -> 20xx
      day = int.parse(groups[0]);
      month = int.parse(groups[1]);
      year = 2000 + int.parse(groups[2]);
      logger.d('Detected DD/MM/YY format: $day/$month/$year');
    }

    if (month < 1 || month > 12) throw FormatException('Invalid month: $month');
    if (day < 1 || day > 31) throw FormatException('Invalid day: $day');
    if (year < 1900 || year > 2100) throw FormatException('Invalid year: $year');

    final result = DateTime(year, month, day);
    logger.d('Parsed date result: ${result.toIso8601String()}');
    return result;
  }

  // ----------------------------
  // Amounts
  // ----------------------------

  /// Extract amounts (total, subtotal, tax) from text
  Map<String, double> _extractAmounts(
    String text,
    String? language,
    List<String> appliedPatterns,
  ) {
    final amounts = <String, double>{};

    final total = _extractAmountByType('total', text, appliedPatterns);
    if (total != null) amounts['total_amount'] = total;

    final subtotal = _extractAmountByType('subtotal', text, appliedPatterns);
    if (subtotal != null) amounts['subtotal_amount'] = subtotal;

    final tax = _extractAmountByType('tax', text, appliedPatterns);
    if (tax != null) amounts['tax_amount'] = tax;

    return amounts;
  }

  /// Extract specific amount type from text (RegexPatterns-based)
  double? _extractAmountByType(
    String type,
    String text,
    List<String> appliedPatterns,
  ) {
    logger.d('Extracting amount type: $type from text');

    List<RegExp> patterns;
    switch (type) {
      case 'total':
        patterns = RegexPatterns.totalPatterns;
        break;
      case 'subtotal':
        patterns = RegexPatterns.subtotalPatterns;
        break;
      case 'tax':
        patterns = RegexPatterns.taxPatterns;
        break;
      default:
        return null;
    }

    final foundAmounts = <double>[];

    for (final pattern in patterns) {
      final matches = pattern.allMatches(text);
      logger.d('Pattern ${patterns.indexOf(pattern)} for $type found ${matches.length} matches');
      for (final match in matches) {
        // 金額は通常グループ2にマッチする（グループ1はキーワード）
        final amountStr = match.groupCount >= 2 ? match.group(2) : match.group(match.groupCount);
        if (amountStr != null) {
          final amount = _parseAmount(amountStr);
          if (amount != null && amount > 0) {
            foundAmounts.add(amount);
            appliedPatterns.add('${type}_pattern_${patterns.indexOf(pattern)}');
          }
        }
      }
    }

    return foundAmounts.isNotEmpty ? foundAmounts.reduce(math.max) : null;
  }

  /// Parse amount string to double (robust for EU/US formats + OCR noise)
  double? _parseAmount(String amountStr) {
    try {
      var s = amountStr.trim();

      // Common OCR fixes inside numeric contexts
      // (e.g., "I5.60" -> "15.60", "O" -> "0")
      s = s.replaceAll(RegExp(r'(?<=\d)[Oo](?=\d)'), '0');
      s = s.replaceAll(RegExp(r'(?<=\D)[Il](?=\d)'), '1');

      // Remove currency symbols and spaces
      String cleaned = s
          .replaceAll(RegExp(r'[€$£¥₹]'), '')
          .replaceAll(RegExp(r'\b(kr|eur|usd|gbp|sek|nok|dkk)\b', caseSensitive: false), '')
          .replaceAll(RegExp(r'\s'), '')
          .replaceAll(RegExp(r'[^\d,.\-]'), '');

      if (cleaned.isEmpty) return null;

      // Handle parentheses for negative amounts (rare in receipts)
      if (cleaned.startsWith('(') && cleaned.endsWith(')')) {
        cleaned = '-${cleaned.substring(1, cleaned.length - 1)}';
      }

      // Decide decimal separator:
      // - "1.234,56" -> 1234.56
      // - "1,234.56" -> 1234.56
      // - "1234,56" -> 1234.56
      // - "1234.56" -> 1234.56
      final hasComma = cleaned.contains(',');
      final hasDot = cleaned.contains('.');

      if (hasComma && hasDot) {
        // Determine last separator as decimal
        final lastComma = cleaned.lastIndexOf(',');
        final lastDot = cleaned.lastIndexOf('.');
        if (lastComma > lastDot) {
          // EU: dot thousand, comma decimal
          cleaned = cleaned.replaceAll('.', '').replaceAll(',', '.');
        } else {
          // US: comma thousand, dot decimal
          cleaned = cleaned.replaceAll(',', '');
        }
      } else if (hasComma && !hasDot) {
        // If comma appears once and has 1-2 decimals -> decimal comma
        final parts = cleaned.split(',');
        if (parts.length == 2 && parts[1].length <= 2) {
          cleaned = cleaned.replaceAll(',', '.');
        } else {
          // otherwise treat as thousand separators
          cleaned = cleaned.replaceAll(',', '');
        }
      } else {
        // dot only or none -> ok
      }

      return double.parse(cleaned);
    } catch (e) {
      logger.w('Failed to parse amount: $amountStr - $e');
      return null;
    }
  }

  /// Extract amounts from table format using structure-based detection (language-independent)
  /// Table format example:
  /// Tax rate | Tax | Subtotal | Total
  /// 14%      | €1.76 | €12.58 | €14.34
  /// 
  /// This method detects tables based on structure (multiple amounts in same row)
  /// rather than specific keywords, making it language-independent.
  Map<String, double> _extractAmountsFromTable(
    List<String> lines,
    List<String> appliedPatterns, {
    List<TextLine>? textLines,
  }) {
    final amounts = <String, double>{};
    logger.d('📊 Starting structure-based table detection (language-independent)');
    
    // Amount pattern (language-independent - works with any currency)
    final amountPattern = RegExp(
      r'([€$£¥₹]?\s*[-]?\d{1,3}(?:[.,]\d{3})*(?:[.,]\d{2})|[€$£¥₹]?\s*[-]?\d+(?:[.,]\d{2})|[-]?\d+%)',
      caseSensitive: false,
    );
    
    // Percentage pattern
    final percentPattern = RegExp(r'\d+%');
    
    if (textLines != null && textLines.isNotEmpty) {
      // Use boundingBox information for structure-based detection
      logger.d('📊 Using boundingBox information for table detection');
      return _extractAmountsFromTableWithBoundingBox(textLines, appliedPatterns, amountPattern, percentPattern);
    } else {
      // Fallback: text-based structure detection
      logger.d('📊 Using text-based structure detection (no boundingBox available)');
      return _extractAmountsFromTableTextBased(lines, appliedPatterns, amountPattern, percentPattern);
    }
  }
  
  /// Extract amounts from table using boundingBox information (structure-based, language-independent)
  Map<String, double> _extractAmountsFromTableWithBoundingBox(
    List<TextLine> textLines,
    List<String> appliedPatterns,
    RegExp amountPattern,
    RegExp percentPattern,
  ) {
    final amounts = <String, double>{};
    const yTolerance = 10.0; // Pixels tolerance for same line
    
    // Step 1: Detect table structure - find rows with multiple amounts (same Y coordinate)
    // Group lines by Y coordinate to find table rows
    final linesByY = <double, List<TextLine>>{};
    for (final line in textLines) {
      final yCoord = line.boundingBox?[1] ?? 0.0;
      bool foundGroup = false;
      for (final groupY in linesByY.keys) {
        if ((yCoord - groupY).abs() <= yTolerance) {
          linesByY[groupY]!.add(line);
          foundGroup = true;
          break;
        }
      }
      if (!foundGroup) {
        linesByY[yCoord] = [line];
      }
    }
    
    // Step 2: Find table structure - look for rows with 3+ amounts
    for (int i = 0; i < textLines.length; i++) {
      final line = textLines[i];
      final yCoord = line.boundingBox?[1] ?? 0.0;
      
      // Find all lines on the same Y coordinate
      List<TextLine>? sameYLines;
      for (final groupY in linesByY.keys) {
        if ((yCoord - groupY).abs() <= yTolerance) {
          sameYLines = linesByY[groupY];
          break;
        }
      }
      
      if (sameYLines == null || sameYLines.isEmpty) continue;
      
      // Count total amounts in all lines on the same Y coordinate
      int amountCount = 0;
      String combinedText = '';
      for (final yLine in sameYLines) {
        combinedText += yLine.text + ' ';
        final matches = amountPattern.allMatches(yLine.text);
        amountCount += matches.length;
      }
      combinedText = combinedText.trim();
      
      // If we found 3 or more amounts in the same Y coordinate, it might be a table data row
      if (amountCount >= 3) {
        logger.d('📊 Potential table data row detected at line $i (Y: ${yCoord.toStringAsFixed(1)}): $amountCount amounts found in "${combinedText}"');
        
        // Step 3: Look for header row (previous line with few amounts)
        if (i > 0) {
          final candidateHeader = textLines[i - 1];
          final headerAmountMatches = amountPattern.allMatches(candidateHeader.text);
          final headerHasPercent = percentPattern.hasMatch(candidateHeader.text);
          final headerAmountCount = headerAmountMatches.length;
          
          // Header row criteria: few amounts (0-1) or percentage only
          if (headerAmountCount <= 1 || headerHasPercent) {
            logger.d('📊 Found table: header="${candidateHeader.text}", data="${combinedText}"');
            
            // Step 4: Extract values from data row using column positions
            // Create a combined TextLine for the data row
            final combinedDataLine = _combineTextLines(sameYLines);
            final extracted = _extractTableValuesFromBoundingBox(
              candidateHeader,
              combinedDataLine,
              appliedPatterns,
              amountPattern,
              percentPattern,
            );
            
            if (extracted.isNotEmpty) {
              amounts.addAll(extracted);
              appliedPatterns.add('table_format_structure_based');
              logger.d('📊 Table extraction completed: $amounts');
              return amounts; // Return early if table found
            }
          }
        }
      }
    }
    
    logger.d('📊 No table structure detected');
    return amounts;
  }
  
  /// Combine multiple TextLines on the same Y coordinate into a single TextLine
  TextLine _combineTextLines(List<TextLine> textLines) {
    if (textLines.isEmpty) {
      throw ArgumentError('Cannot combine empty list of TextLines');
    }
    if (textLines.length == 1) {
      return textLines.first;
    }
    
    // Sort by X coordinate (left to right)
    final sorted = List<TextLine>.from(textLines);
    sorted.sort((a, b) {
      final aX = a.boundingBox?[0] ?? 0.0;
      final bX = b.boundingBox?[0] ?? 0.0;
      return aX.compareTo(bX);
    });
    
    // Combine text
    final combinedText = sorted.map((l) => l.text).join(' ');
    
    // Combine elements
    final combinedElements = sorted.expand((l) => l.elements).toList();
    
    // Calculate combined bounding box
    double minX = double.infinity, minY = double.infinity;
    double maxX = double.negativeInfinity, maxY = double.negativeInfinity;
    for (final line in sorted) {
      final bbox = line.boundingBox;
      if (bbox != null && bbox.length >= 4) {
        minX = math.min(minX, bbox[0]);
        minY = math.min(minY, bbox[1]);
        maxX = math.max(maxX, bbox[0] + bbox[2]);
        maxY = math.max(maxY, bbox[1] + bbox[3]);
      }
    }
    
    final combinedBBox = [minX, minY, maxX - minX, maxY - minY];
    
    return TextLine(
      text: combinedText,
      confidence: sorted.map((l) => l.confidence).reduce((a, b) => a + b) / sorted.length,
      boundingBox: combinedBBox,
      elements: combinedElements,
    );
  }
  
  /// Extract table values using boundingBox column positions
  Map<String, double> _extractTableValuesFromBoundingBox(
    TextLine headerLine,
    TextLine dataLine,
    List<String> appliedPatterns,
    RegExp amountPattern,
    RegExp percentPattern,
  ) {
    final amounts = <String, double>{};
    
    // Extract header column positions (X coordinates)
    final headerColumns = <double>[];
    if (headerLine.elements.isNotEmpty) {
      for (final element in headerLine.elements) {
        final bbox = element.boundingBox;
        if (bbox != null && bbox.length >= 4) {
          headerColumns.add(bbox[0]); // X coordinate
        }
      }
    } else {
      // Fallback: use header line boundingBox
      final headerBbox = headerLine.boundingBox;
      if (headerBbox != null && headerBbox.length >= 4) {
        // Estimate column positions (assume 4 columns)
        final width = headerBbox[2];
        final startX = headerBbox[0];
        for (int i = 0; i < 4; i++) {
          headerColumns.add(startX + (width / 4) * i);
        }
      }
    }
    
    // Extract data row values with their X coordinates
    final dataValues = <({String text, double x})>[];
    if (dataLine.elements.isNotEmpty) {
      for (final element in dataLine.elements) {
        final bbox = element.boundingBox;
        if (bbox != null && bbox.length >= 4) {
          final x = bbox[0];
          final text = element.text.trim();
          // Check if it's an amount or percentage
          if (amountPattern.hasMatch(text) || percentPattern.hasMatch(text)) {
            dataValues.add((text: text, x: x));
          }
        }
      }
    }
    
    // Sort data values by X coordinate (left to right)
    dataValues.sort((a, b) => a.x.compareTo(b.x));
    
    logger.d('📊 Header columns: $headerColumns, Data values: ${dataValues.map((v) => "${v.text}@${v.x.toStringAsFixed(1)}").toList()}');
    
    // Extract amounts (skip percentage)
    final amountValues = dataValues
        .where((v) => !v.text.contains('%'))
        .map((v) => _parseAmount(v.text))
        .where((a) => a != null && a! > 0)
        .cast<double>()
        .toList();
    
    // Extract percentage if present
    final percentValue = dataValues
        .where((v) => v.text.contains('%'))
        .map((v) => percentPattern.firstMatch(v.text))
        .where((m) => m != null)
        .map((m) => int.parse(m!.group(0)!.replaceAll('%', '')))
        .firstOrNull;
    
    if (percentValue != null) {
      logger.d('📊 Found tax rate: $percentValue%');
      appliedPatterns.add('table_tax_rate_${percentValue}%');
    }
    
    logger.d('📊 Extracted ${amountValues.length} amounts: $amountValues');
    
    // Assign values based on count and position
    // Typical order: Tax, Subtotal, Total (or just Subtotal, Total)
    if (amountValues.length >= 3) {
      // Usually: Tax, Subtotal, Total
      amounts['tax_amount'] = amountValues[0];
      amounts['subtotal_amount'] = amountValues[1];
      amounts['total_amount'] = amountValues[2];
      logger.d('📊 Assigned: tax=${amountValues[0]}, subtotal=${amountValues[1]}, total=${amountValues[2]}');
    } else if (amountValues.length == 2) {
      // If only 2 values, assume Subtotal and Total
      amounts['subtotal_amount'] = amountValues[0];
      amounts['total_amount'] = amountValues[1];
      logger.d('📊 Assigned: subtotal=${amountValues[0]}, total=${amountValues[1]}');
    }
    
    return amounts;
  }
  
  /// Fallback: Extract amounts from table using text-based structure detection
  Map<String, double> _extractAmountsFromTableTextBased(
    List<String> lines,
    List<String> appliedPatterns,
    RegExp amountPattern,
    RegExp percentPattern,
  ) {
    final amounts = <String, double>{};
    
    for (int i = 0; i < lines.length - 1; i++) {
      final headerLine = lines[i];
      final dataLine = lines[i + 1];
      
      // Check if header line has few amounts (0-1) or percentage only
      final headerAmountMatches = amountPattern.allMatches(headerLine);
      final headerHasPercent = percentPattern.hasMatch(headerLine);
      final headerAmountCount = headerAmountMatches.length;
      
      // Check if data line has multiple amounts
      final dataAmountMatches = amountPattern.allMatches(dataLine);
      final dataAmountCount = dataAmountMatches.length;
      
      // Structure-based detection: header (few amounts) + data (multiple amounts)
      if ((headerAmountCount <= 1 || headerHasPercent) && dataAmountCount >= 2) {
        logger.d('📊 Found potential table structure (text-based): header="${headerLine}", data="${dataLine}"');
        
        // Extract amounts from data line
        final amountValues = dataAmountMatches
            .map((m) => m.group(0)!.trim())
            .where((v) => !v.contains('%'))
            .map((v) => _parseAmount(v))
            .where((a) => a != null && a! > 0)
            .cast<double>()
            .toList();
        
        logger.d('📊 Extracted ${amountValues.length} amounts: $amountValues');
        
        if (amountValues.length >= 2) {
          if (amountValues.length >= 3) {
            amounts['tax_amount'] = amountValues[0];
            amounts['subtotal_amount'] = amountValues[1];
            amounts['total_amount'] = amountValues[2];
          } else {
            amounts['subtotal_amount'] = amountValues[0];
            amounts['total_amount'] = amountValues[1];
          }
          appliedPatterns.add('table_format_text_based');
          logger.d('📊 Table extraction (text-based): $amounts');
          return amounts;
        }
      }
    }
    
    return amounts;
  }

  /// Extract amounts line by line (adds VAT-specific support + better selection)
  /// Now with multi-candidate support and consistency checking
  Map<String, double> _extractAmountsLineByLine(
    List<String> lines,
    String? language,
    List<String> appliedPatterns, {
    List<TextLine>? textLines,
  }) {
    final amounts = <String, double>{};
    logger.d('Starting line-by-line amount extraction with consistency checking');

    // Check for table format (Tax Breakdown table) - structure-based, language-independent
    final tableAmounts = _extractAmountsFromTable(lines, appliedPatterns, textLines: textLines);
    if (tableAmounts.isNotEmpty) {
      logger.d('📊 Found table format, extracted amounts: $tableAmounts');
      amounts.addAll(tableAmounts);
      // Continue with regular extraction as fallback for any missing values
    }

    // Debug: Log pattern counts
    logger.d('🔍 Pattern counts: subtotal=${RegexPatterns.subtotalPatterns.length}, tax=${RegexPatterns.taxPatterns.length}, total=${RegexPatterns.totalPatterns.length}');
    if (RegexPatterns.subtotalPatterns.isNotEmpty) {
      logger.d('🔍 First subtotal pattern: ${RegexPatterns.subtotalPatterns[0].pattern}');
    }
    if (RegexPatterns.taxPatterns.isNotEmpty) {
      logger.d('🔍 First tax pattern: ${RegexPatterns.taxPatterns[0].pattern}');
    }
    if (RegexPatterns.totalPatterns.isNotEmpty) {
      logger.d('🔍 First total pattern: ${RegexPatterns.totalPatterns[0].pattern}');
    }

    // Extra fallback patterns (template-friendly) - declared early for use in trySet
    // Generated dynamically from LanguageKeywords for multi-language support
    final totalLabel = PatternGenerator.generateLabelPattern('total');
    final subtotalLabel = PatternGenerator.generateLabelPattern('subtotal');
    final taxLabel = PatternGenerator.generateLabelPattern('tax');

    // Track multiple candidates per field (for consistency checking)
    final candidatesMap = <String, List<({double amount, int score, int lineIndex, String source})>>{
      'total_amount': [],
      'subtotal_amount': [],
      'tax_amount': [],
    };

    void addCandidate(String key, double amount, int score, int i, String source) {
      candidatesMap[key]!.add((amount: amount, score: score, lineIndex: i, source: source));
    }

    // Keep best candidate for backward compatibility (used in conversion)
    final best = <String, ({double amount, int score, int lineIndex, String source})>{};

    void trySet(String key, double amount, int score, int i, String source) {
      // Add to candidates list (for consistency checking)
      addCandidate(key, amount, score, i, source);
      
      // Also update best (for backward compatibility)
      final current = best[key];
      if (current == null) {
        best[key] = (amount: amount, score: score, lineIndex: i, source: source);
      } else if (score > current.score) {
        // Higher score always wins
        best[key] = (amount: amount, score: score, lineIndex: i, source: source);
      } else if (score == current.score && key == 'total_amount') {
        // For total_amount, if same score, prefer:
        // 1. Explicit "TOTAL" label (not subtotal)
        // 2. Later lines (usually total appears after subtotal)
        // Support multiple languages: Generated dynamically from LanguageKeywords
        final totalWordOnly = PatternGenerator.generateLabelPattern('total');
        final isExplicitTotal = totalWordOnly.hasMatch(lines[i]) && 
                                !subtotalLabel.hasMatch(lines[i].toLowerCase());
        final currentIsExplicit = totalWordOnly.hasMatch(lines[current.lineIndex]) &&
                                   !subtotalLabel.hasMatch(lines[current.lineIndex].toLowerCase());
        
        if (isExplicitTotal && !currentIsExplicit) {
          // New candidate has explicit "TOTAL" and current doesn't
          best[key] = (amount: amount, score: score, lineIndex: i, source: source);
        } else if (i > current.lineIndex && isExplicitTotal == currentIsExplicit) {
          // Both are equally explicit, prefer later lines (total usually appears after subtotal)
          best[key] = (amount: amount, score: score, lineIndex: i, source: source);
        }
      }
    }

    final amountCapture = RegExp(
      r'([€$£¥₹]?\s*[-]?\d{1,3}(?:[.,]\d{3})*(?:[.,]\d{2})|[€$£¥₹]?\s*[-]?\d+(?:[.,]\d{2}))\b',
      caseSensitive: false,
    );

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final lower = line.toLowerCase();
      logger.d('Analyzing line $i: "$line"');

      // Check if line contains subtotal - exclude from total patterns
      final isSubtotalLine = subtotalLabel.hasMatch(lower);

      // 1) Project patterns first (strong signal)
      // Only check total patterns if line is not a subtotal line
      if (!isSubtotalLine) {
        for (int p = 0; p < RegexPatterns.totalPatterns.length; p++) {
          final match = RegexPatterns.totalPatterns[p].firstMatch(line);
          if (match != null) {
            // 金額は通常グループ2にマッチする（グループ1はキーワード）
            final amountStr = match.groupCount >= 2 ? match.group(2) : match.group(match.groupCount);
            final amount = amountStr == null ? null : _parseAmount(amountStr);
            if (amount != null && amount > 0) {
              trySet('total_amount', amount, 100, i, 'total_pattern_$p');
              appliedPatterns.add('total_line_${i}_pattern_$p');
              logger.d('✅ Candidate TOTAL: $amount (score 100) from line $i');
            }
          }
        }
      }

      for (int p = 0; p < RegexPatterns.subtotalPatterns.length; p++) {
        final pattern = RegexPatterns.subtotalPatterns[p];
        final match = pattern.firstMatch(line);
        if (match != null) {
          logger.d('🔍 Subtotal pattern $p matched line $i: "$line"');
          logger.d('🔍 Pattern: ${pattern.pattern}');
          logger.d('🔍 Match groups: ${match.groupCount}, group(1): "${match.group(1)}", group(2): "${match.group(2)}"');
          // 金額は通常グループ2にマッチする（グループ1はキーワード）
          final amountStr = match.groupCount >= 2 ? match.group(2) : match.group(match.groupCount);
          logger.d('🔍 Amount string: "$amountStr"');
          final amount = amountStr == null ? null : _parseAmount(amountStr);
          logger.d('🔍 Parsed amount: $amount');
          if (amount != null && amount > 0) {
            trySet('subtotal_amount', amount, 90, i, 'subtotal_pattern_$p');
            appliedPatterns.add('subtotal_line_${i}_pattern_$p');
            logger.d('✅ Candidate SUBTOTAL: $amount (score 90) from line $i');
          } else {
            logger.d('⚠️ Failed to parse amount or amount <= 0');
          }
        } else if (i == 11 && p == 0) {
          // Debug: Log first pattern attempt on line 11 (usually subtotal line)
          logger.d('🔍 Subtotal pattern $p did NOT match line $i: "$line"');
          logger.d('🔍 Pattern: ${pattern.pattern}');
        }
      }

      for (int p = 0; p < RegexPatterns.taxPatterns.length; p++) {
        final match = RegexPatterns.taxPatterns[p].firstMatch(line);
        if (match != null) {
          // 金額は通常グループ2にマッチする（グループ1はキーワードまたはパーセンテージ）
          final amountStr = match.groupCount >= 2 ? match.group(2) : match.group(match.groupCount);
          final amount = amountStr == null ? null : _parseAmount(amountStr);
          if (amount != null && amount > 0) {
            trySet('tax_amount', amount, 80, i, 'tax_pattern_$p');
            appliedPatterns.add('tax_line_${i}_pattern_$p');
            logger.d('✅ Candidate TAX: $amount (score 80) from line $i');
          }
        }
      }

      // 2) VAT / TOTAL / SUBTOTAL heuristic (template receipts)
      // Example:
      // "Subtotal: €12.58"
      // "VAT 24%: €3.02"
      // "TOTAL: €15.60"
      if (totalLabel.hasMatch(lower)) {
        final m = amountCapture.allMatches(line).toList();
        if (m.isNotEmpty) {
          final amount = _parseAmount(m.last.group(0)!);
          if (amount != null && amount > 0) {
            // TOTAL usually appears near bottom -> add small bonus by position
            final posBonus = (i > (lines.length * 0.6)) ? 10 : 0;
            trySet('total_amount', amount, 85 + posBonus, i, 'total_label');
            appliedPatterns.add('total_label_line_$i');
            logger.d('✅ Candidate TOTAL(label): $amount (score ${85 + posBonus}) from line $i');
          }
        }
      }

      if (subtotalLabel.hasMatch(lower)) {
        logger.d('🔍 Subtotal label matched in line $i: "$line"');
        final m = amountCapture.allMatches(line).toList();
        logger.d('🔍 Found ${m.length} amount matches in line $i');
        if (m.isNotEmpty) {
          final amount = _parseAmount(m.last.group(0)!);
          logger.d('🔍 Parsed amount: $amount from "${m.last.group(0)}"');
          if (amount != null && amount > 0) {
            trySet('subtotal_amount', amount, 75, i, 'subtotal_label');
            appliedPatterns.add('subtotal_label_line_$i');
            logger.d('✅ Candidate SUBTOTAL(label): $amount (score 75) from line $i');
          } else {
            logger.d('⚠️ Failed to parse amount or amount <= 0');
          }
        } else {
          logger.d('⚠️ No amount matches found in line with subtotal label');
        }
      }

      if (taxLabel.hasMatch(lower)) {
        final m = amountCapture.allMatches(line).toList();
        if (m.isNotEmpty) {
          final amount = _parseAmount(m.last.group(0)!);
          if (amount != null && amount > 0) {
            trySet('tax_amount', amount, 70, i, 'tax_label');
            appliedPatterns.add('tax_label_line_$i');
            logger.d('✅ Candidate TAX(label): $amount (score 70) from line $i');
          }
        }
      }
    }

    // Convert candidates to FieldCandidates structure for consistency checking
    // Sort by score (highest first) and take top candidates
    final totalCandidates = _convertToAmountCandidates(
      candidatesMap['total_amount']!,
      'total_amount',
      textLines,
    );
    final subtotalCandidates = _convertToAmountCandidates(
      candidatesMap['subtotal_amount']!,
      'subtotal_amount',
      textLines,
    );
    final taxCandidates = _convertToAmountCandidates(
      candidatesMap['tax_amount']!,
      'tax_amount',
      textLines,
    );

    // Apply position-based score bonuses
    _applyPositionBonuses(totalCandidates, subtotalCandidates, taxCandidates, lines.length);

    final allCandidates = <String, FieldCandidates>{
      'total_amount': FieldCandidates(
        fieldName: 'total_amount',
        candidates: totalCandidates,
      ),
      'subtotal_amount': FieldCandidates(
        fieldName: 'subtotal_amount',
        candidates: subtotalCandidates,
      ),
      'tax_amount': FieldCandidates(
        fieldName: 'tax_amount',
        candidates: taxCandidates,
      ),
    };

    // Apply consistency checking if we have at least 1 field
    final fieldsWithCandidates = allCandidates.values.where((fc) => fc.candidates.isNotEmpty).length;
    
    if (fieldsWithCandidates >= 1) {
      final consistencyResult = _selectBestCandidates(allCandidates);
      
      // Use selected candidates
      for (final entry in consistencyResult.selectedCandidates.entries) {
        final fieldName = entry.key;
        final candidate = entry.value;
        
        // Use corrected value if available
        if (consistencyResult.correctedValues?.containsKey(fieldName) == true) {
          amounts[fieldName] = consistencyResult.correctedValues![fieldName]!;
          appliedPatterns.add('${fieldName}_corrected');
          logger.d('✅ Using corrected value for $fieldName: ${amounts[fieldName]}');
        } else {
          amounts[fieldName] = candidate.amount;
          appliedPatterns.add('${fieldName}_${candidate.source}');
        }
      }
      
      // Log warnings
      if (consistencyResult.warnings.isNotEmpty) {
        for (final warning in consistencyResult.warnings) {
          logger.w('⚠️ Consistency warning: $warning');
        }
      }
      
      // Add needs_verification flag if needed
      if (consistencyResult.needsVerification) {
        appliedPatterns.add('needs_verification');
        logger.w('⚠️ Receipt needs manual verification');
      }
      
      logger.d('Consistency score: ${consistencyResult.consistencyScore.toStringAsFixed(2)}');
    } else {
      // Fallback to simple selection if not enough candidates
      if (best['total_amount'] != null) {
        amounts['total_amount'] = best['total_amount']!.amount;
      }
      if (best['subtotal_amount'] != null) {
        amounts['subtotal_amount'] = best['subtotal_amount']!.amount;
      }
      if (best['tax_amount'] != null) {
        amounts['tax_amount'] = best['tax_amount']!.amount;
      }
    }

    // If subtotal+tax exists but total missing, compute
    if (!amounts.containsKey('total_amount') &&
        amounts.containsKey('subtotal_amount') &&
        amounts.containsKey('tax_amount')) {
      final computed = (amounts['subtotal_amount']! + amounts['tax_amount']!);
      amounts['total_amount'] = double.parse(computed.toStringAsFixed(2));
      appliedPatterns.add('computed_total_from_subtotal_tax');
      logger.d('✅ Computed TOTAL from subtotal+tax: ${amounts['total_amount']}');
    }

    logger.d('Line-by-line extraction completed. Found amounts: $amounts');
    return amounts;
  }

  // ----------------------------
  // Payment / Currency / Receipt No
  // ----------------------------

  PaymentMethod? _extractPaymentMethod(String text, List<String> appliedPatterns) {
    // Prefer explicit payment method patterns (multi-language support)
    // Generated dynamically from LanguageKeywords
    final paymentPatterns = PatternGenerator.generatePaymentMethodPatterns();
    final explicitPattern = paymentPatterns.first; // First pattern is the explicit one
    final m = explicitPattern.firstMatch(text);
    if (m != null) {
      appliedPatterns.add('payment_explicit');
      // Group 2 is the payment method (group 1 is the payment keyword)
      final paymentMethod = m.groupCount >= 2 ? m.group(2) : m.group(1);
      if (paymentMethod != null) {
        return PaymentMethod.fromString(paymentMethod);
      }
    }

    for (final pattern in paymentPatterns.skip(1)) {
      final match = pattern.firstMatch(text.toLowerCase());
      if (match != null) {
        appliedPatterns.add('payment_pattern_${RegexPatterns.paymentMethodPatterns.indexOf(pattern)}');
        return PaymentMethod.fromString(match.group(0)!);
      }
    }
    return null;
  }

  Currency? _extractCurrency(String text, List<String> appliedPatterns) {
    // Strong: symbol presence
    if (text.contains('€')) {
      appliedPatterns.add('currency_symbol_eur');
      return Currency.eur;
    }
    if (text.contains('£')) {
      appliedPatterns.add('currency_symbol_gbp');
      return Currency.gbp;
    }
    if (text.contains('\$')) {
      appliedPatterns.add('currency_symbol_usd');
      return Currency.usd;
    }

    // Fallback: project patterns
    for (final pattern in RegexPatterns.currencyPatterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        final currencyText = match.group(0)!;
        appliedPatterns.add('currency_pattern_${RegexPatterns.currencyPatterns.indexOf(pattern)}');

        switch (currencyText.toLowerCase()) {
          case '€':
          case 'eur':
            return Currency.eur;
          case 'kr':
          case 'sek':
            return Currency.sek;
          case 'nok':
            return Currency.nok;
          case 'dkk':
            return Currency.dkk;
          case '\$':
          case 'usd':
            return Currency.usd;
          case '£':
          case 'gbp':
            return Currency.gbp;
        }
      }
    }
    return null;
  }

  String? _extractReceiptNumber(String text, List<String> appliedPatterns) {
    // Prefer explicit template: Generated dynamically from LanguageKeywords
    final receiptNumberPatterns = PatternGenerator.generateReceiptNumberPatterns();
    final explicit = receiptNumberPatterns.first.firstMatch(text);
    if (explicit != null) {
      appliedPatterns.add('receipt_num_explicit');
      // Group 2 is the receipt number (group 1 is the keyword)
      return explicit.groupCount >= 2 
          ? (explicit.group(2)?.trim() ?? explicit.group(1)?.trim())
          : explicit.group(1)?.trim();
    }

    for (final pattern in receiptNumberPatterns.skip(1)) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        appliedPatterns.add('receipt_num_pattern_${RegexPatterns.receiptNumberPatterns.indexOf(pattern)}');
        // レシート番号は通常グループ2にマッチする（グループ1はキーワード）
        // ただし、#(\d+)形式の場合はグループ1が番号
        final receiptNumber = match.groupCount >= 2 ? match.group(2) : match.group(1);
        return receiptNumber?.trim();
      }
    }

    // Fallback "No.:"
    final fallback = RegExp(r'\b(no\.?|number)\s*[:\-]?\s*([A-Za-z0-9\-]+)\b', caseSensitive: false).firstMatch(text);
    if (fallback != null) {
      appliedPatterns.add('receipt_num_fallback_no');
      return fallback.group(2)?.trim();
    }

    return null;
  }

  // ----------------------------
  // Items
  // ----------------------------

  List<ReceiptItem> _extractItems(String text, List<String> appliedPatterns) {
    final items = <ReceiptItem>[];
    final lines = text.split('\n').map(_normalizeLine).where((l) => l.isNotEmpty).toList();

    // Section guards
    bool inItemsSection = false;

    // Fallback pattern for template items: "Bread €2.50"
    // Also handles "Apples 1kg  €3.20"
    final simpleItemPattern = RegExp(
      r'^(.+?)\s{1,}[€$£¥₹]?\s*([-]?\d{1,3}(?:[.,]\d{3})*(?:[.,]\d{2})|[-]?\d+(?:[.,]\d{2}))\s*$',
      caseSensitive: false,
    );

    bool isFooterOrTotals(String line) {
      final lower = line.toLowerCase();
      return lower.startsWith('subtotal') ||
          lower.startsWith('total') ||
          lower.startsWith('vat') ||
          lower.startsWith('tax') ||
          lower.startsWith('payment') ||
          lower.startsWith('thank') ||
          RegExp(r'^\-+$').hasMatch(lower);
    }

    for (final line in lines) {
      final lower = line.toLowerCase();

      if (lower.startsWith('items')) {
        inItemsSection = true;
        appliedPatterns.add('items_section_detected');
        continue;
      }

      // Stop when totals begin
      if (inItemsSection && isFooterOrTotals(line)) {
        inItemsSection = false;
      }

      // 1) Try project-defined patterns first
      bool matched = false;
      for (final pattern in RegexPatterns.itemLinePatterns) {
        final match = pattern.firstMatch(line);
        if (match != null) {
          try {
            final name = match.group(1)?.trim();
            final quantityStr = match.group(2);
            // 価格は通常最後のグループにマッチする
            // パターン1: グループ4が合計価格、グループ3が単価
            // パターン2: グループ2が価格
            final priceStr = match.groupCount >= 4 ? match.group(4) : (match.groupCount >= 2 ? match.group(match.groupCount) : null);

            if (name != null && priceStr != null) {
              final quantity = int.tryParse(quantityStr ?? '1') ?? 1;
              final price = _parseAmount(priceStr);

              if (price != null && price > 0) {
                final item = ReceiptItem.create(
                  name: name,
                  quantity: quantity,
                  totalPrice: price,
                  category: ItemCategory.detectCategory(name),
                );
                items.add(item);
                appliedPatterns.add('item_pattern_${RegexPatterns.itemLinePatterns.indexOf(pattern)}');
                matched = true;
                break;
              }
            }
          } catch (e) {
            logger.w('Failed to parse item line (pattern): $line - $e');
          }
        }
      }
      if (matched) continue;

      // 2) Template fallback: only parse inside items section if detected,
      // but if not detected, still allow item parsing while excluding obvious headers/totals.
      final allow = inItemsSection ||
          (!isFooterOrTotals(line) &&
              !lower.startsWith('date') &&
              !lower.startsWith('time') &&
              !lower.startsWith('receipt') &&
              !lower.contains('helsinki') &&
              !RegExp(r'^\d').hasMatch(line));

      if (!allow) continue;

      final m = simpleItemPattern.firstMatch(line);
      if (m != null) {
        final name = m.group(1)?.trim();
        final priceStr = m.group(2)?.trim();
        if (name == null || name.isEmpty || priceStr == null) continue;

        // Avoid accidentally parsing totals as items
        if (RegExp(r'\b(total|subtotal|vat|tax|payment)\b', caseSensitive: false).hasMatch(name)) {
          continue;
        }

        final price = _parseAmount(priceStr);
        if (price != null && price > 0) {
          final item = ReceiptItem.create(
            name: name,
            quantity: 1,
            totalPrice: price,
            category: ItemCategory.detectCategory(name),
          );
          items.add(item);
          appliedPatterns.add('item_fallback_simple');
        }
      }
    }

    return items;
  }

  // ----------------------------
  // Confidence & validation
  // ----------------------------

  double _calculateExtractionConfidence(
    Map<String, dynamic> extractedData,
    double ocrConfidence,
    int warningCount,
  ) {
    double confidence = ocrConfidence;

    final criticalFields = ['merchant_name', 'total_amount', 'date'];
    int foundCriticalFields = 0;
    for (final field in criticalFields) {
      if (extractedData.containsKey(field)) foundCriticalFields++;
    }
    confidence += (foundCriticalFields / criticalFields.length) * 0.3;

    final additionalFields = ['subtotal_amount', 'tax_amount', 'payment_method', 'receipt_number', 'currency'];
    int foundAdditionalFields = 0;
    for (final field in additionalFields) {
      if (extractedData.containsKey(field)) foundAdditionalFields++;
    }
    confidence += (foundAdditionalFields / additionalFields.length) * 0.15;

    confidence -= warningCount * 0.1;

    return math.max(0.0, math.min(1.0, confidence));
  }

  void _validateExtractedData(Map<String, dynamic> data, List<String> warnings) {
    if (!data.containsKey('total_amount')) {
      warnings.add('Total amount not found - manual verification recommended');
    }

    final total = data['total_amount'] as double?;
    final subtotal = data['subtotal_amount'] as double?;
    final tax = data['tax_amount'] as double?;

    if (total != null && subtotal != null && tax != null) {
      final calculatedTotal = subtotal + tax;
      final difference = (total - calculatedTotal).abs();
      if (difference > 0.02) {
        warnings.add('Amount calculation mismatch: total($total) != subtotal($subtotal) + tax($tax)');
      }
    }

    if (data.containsKey('date')) {
      try {
        final date = DateTime.parse(data['date']);
        final now = DateTime.now();
        final difference = now.difference(date).inDays;
        if (difference < -730 || difference > 365 * 5) {
          warnings.add('Date seems unusual: ${date.toIso8601String()}');
        }
      } catch (_) {
        warnings.add('Invalid date format');
      }
    }
  }

  // ----------------------------
  // Structured parsing (kept + minor fixes)
  // ----------------------------

  Future<ExtractionResult> _parseWithStructuredData(
    String ocrText,
    List<Map<String, dynamic>> textBlocks,
    String? detectedLanguage,
    double ocrConfidence,
    List<String> appliedPatterns,
    List<String> warnings,
    Stopwatch stopwatch, {
    List<TextLine>? textLines,
  }) async {
    try {
      final extractedData = <String, dynamic>{};

      // Prefer textLines if available (better structure)
      List<String> lines;
      List<Map<String, dynamic>> sortedBlocks;
      
      if (textLines != null && textLines.isNotEmpty) {
        logger.d('Using textLines for extraction (${textLines.length} lines)');
        // Extract lines directly from textLines
        lines = textLines.map((line) => line.text).toList();
        
        // Convert textLines to sortedBlocks format for compatibility with existing methods
        sortedBlocks = textLines.map((line) {
          return {
            'text': line.text,
            'confidence': line.confidence,
            'boundingBox': line.boundingBox ?? [0.0, 0.0, 0.0, 0.0],
            'elements': line.elements.map((e) => {
              'text': e.text,
              'confidence': e.confidence,
              'boundingBox': e.boundingBox ?? [0.0, 0.0, 0.0, 0.0],
            }).toList(),
          };
        }).toList();
        
        // Sort by Y coordinate (already sorted, but ensure)
        sortedBlocks.sort((a, b) {
          final aTop = (a['boundingBox'] as List)[1];
          final bTop = (b['boundingBox'] as List)[1];
          return aTop.compareTo(bTop);
        });
      } else {
        logger.d('Using textBlocks for extraction (${textBlocks.length} blocks)');
        // Extract lines from structured text blocks (fallback)
        lines = _extractLinesFromTextBlocks(textBlocks);
        sortedBlocks = List<Map<String, dynamic>>.from(textBlocks);
        sortedBlocks.sort((a, b) {
          final aTop = (a['boundingBox'] as List)[1];
          final bTop = (b['boundingBox'] as List)[1];
          return aTop.compareTo(bTop);
        });
      }
      
      // Combine consecutive lines that belong together (only if not using textLines)
      final combinedLines = textLines != null && textLines.isNotEmpty 
          ? lines  // textLines are already combined, no need to combine again
          : _combineRelatedLines(lines);
      logger.d('Using ${combinedLines.length} lines for extraction');

      final merchantName = _extractMerchantFromBlocks(sortedBlocks, appliedPatterns);
      if (merchantName != null) {
        extractedData['merchant_name'] = merchantName;
      } else {
        warnings.add('Merchant name not found');
      }

      final date = _extractDateFromBlocks(sortedBlocks, appliedPatterns) ?? _extractDate(ocrText, appliedPatterns);
      if (date != null) {
        extractedData['date'] = date.toIso8601String();
      } else {
        warnings.add('Purchase date not found');
      }

      final time = _extractTime(ocrText, appliedPatterns);
      if (time != null) {
        extractedData['time'] = time;
      }

      // Use combined lines for amount extraction
      final amounts = _extractAmountsLineByLine(
        combinedLines, 
        detectedLanguage, 
        appliedPatterns,
        textLines: textLines,
      );
      logger.d('Extracted amounts from blocks: $amounts');
      extractedData.addAll(amounts);

      // Fallback to block-based extraction for any missing amounts
      // Check if we're missing any key amounts (total, subtotal, or tax)
      final missingAmounts = <String>[];
      if (!extractedData.containsKey('total_amount')) {
        missingAmounts.add('total_amount');
      }
      if (!extractedData.containsKey('subtotal_amount')) {
        missingAmounts.add('subtotal_amount');
      }
      if (!extractedData.containsKey('tax_amount')) {
        missingAmounts.add('tax_amount');
      }

      if (missingAmounts.isNotEmpty) {
        logger.d('Missing amounts detected: $missingAmounts, trying block-based extraction');
        final fallbackAmounts = _extractAmountsFromBlocks(sortedBlocks, appliedPatterns);
        if (fallbackAmounts.isNotEmpty) {
          // Only add missing amounts to avoid overwriting good matches
          for (final key in fallbackAmounts.keys) {
            if (!extractedData.containsKey(key)) {
              extractedData[key] = fallbackAmounts[key];
              logger.d('Added missing amount from blocks: $key = ${fallbackAmounts[key]}');
            }
          }
        }
      }

      final paymentMethod = _extractPaymentMethodFromBlocks(sortedBlocks, appliedPatterns) ?? _extractPaymentMethod(ocrText, appliedPatterns);
      if (paymentMethod != null) {
        extractedData['payment_method'] = paymentMethod.name;
      }

      final currency = _extractCurrencyFromBlocks(sortedBlocks, appliedPatterns) ?? _extractCurrency(ocrText, appliedPatterns);
      if (currency != null) {
        extractedData['currency'] = currency.code;
      }

      final receiptNumber =
          _extractReceiptNumberFromBlocks(sortedBlocks, appliedPatterns) ?? _extractReceiptNumber(ocrText, appliedPatterns);
      if (receiptNumber != null) {
        extractedData['receipt_number'] = receiptNumber;
      }

      // Items from text fallback (block-based item extraction can be added later)
      final items = _extractItems(ocrText, appliedPatterns);
      if (items.isNotEmpty) {
        extractedData['items'] = items
            .map((item) => {
                  'name': item.name,
                  'quantity': item.quantity,
                  'unit_price': item.unitPrice,
                  'total_price': item.totalPrice,
                  'category': item.category,
                })
            .toList();
      }

      final confidence = _calculateExtractionConfidence(
        extractedData,
        ocrConfidence,
        warnings.length,
      );

      stopwatch.stop();
      final processingTime = stopwatch.elapsedMilliseconds;

      logger.d('Structured extraction data: $extractedData');
      _validateExtractedData(extractedData, warnings);
      logger.d('Structured validation warnings: $warnings');

      logger.i('Structured receipt extraction completed: ${extractedData.length} fields, '
          'confidence: ${confidence.toStringAsFixed(2)}, '
          'warnings: ${warnings.length}');

      return ExtractionResult.success(
        extractedData: extractedData,
        processingTime: processingTime,
        confidence: confidence,
        warnings: warnings,
        appliedPatterns: appliedPatterns,
        metadata: {
          'detected_language': detectedLanguage,
          'ocr_confidence': ocrConfidence,
          'text_blocks': textBlocks.length,
          'text_lines': textLines?.length ?? 0,
          'parsing_method': textLines != null && textLines.isNotEmpty ? 'structured_textlines' : 'structured',
        },
      );
    } catch (e) {
      logger.e('Structured parsing failed, falling back to text parsing: $e');
      return _parseWithTextOnly(ocrText, detectedLanguage, ocrConfidence, appliedPatterns, warnings, stopwatch);
    }
  }

  Future<ExtractionResult> _parseWithTextOnly(
    String ocrText,
    String? detectedLanguage,
    double ocrConfidence,
    List<String> appliedPatterns,
    List<String> warnings,
    Stopwatch stopwatch,
  ) async {
    final extractedData = <String, dynamic>{};

    if (ocrText.trim().isEmpty) {
      throw InsufficientDataException(['raw_text']);
    }

    final normalizedText = _normalizeOcrText(ocrText);

    final merchantName = _extractMerchantName(normalizedText, appliedPatterns);
    if (merchantName != null) {
      extractedData['merchant_name'] = merchantName;
    } else {
      warnings.add('Merchant name not found');
    }

    final date = _extractDate(normalizedText, appliedPatterns);
    if (date != null) {
      extractedData['date'] = date.toIso8601String();
    } else {
      warnings.add('Purchase date not found');
    }

    final time = _extractTime(normalizedText, appliedPatterns);
    if (time != null) {
      extractedData['time'] = time;
    }

    final lines = normalizedText.split('\n').map(_normalizeLine).where((l) => l.isNotEmpty).toList();
    final combinedLines = _combineRelatedLines(lines);
    final amounts = _extractAmountsLineByLine(combinedLines, detectedLanguage, appliedPatterns);
    extractedData.addAll(amounts);

    final paymentMethod = _extractPaymentMethod(normalizedText, appliedPatterns);
    if (paymentMethod != null) {
      extractedData['payment_method'] = paymentMethod.name;
    }

    final currency = _extractCurrency(normalizedText, appliedPatterns);
    if (currency != null) {
      extractedData['currency'] = currency.code;
    }

    final receiptNumber = _extractReceiptNumber(normalizedText, appliedPatterns);
    if (receiptNumber != null) {
      extractedData['receipt_number'] = receiptNumber;
    }

    final items = _extractItems(normalizedText, appliedPatterns);
    if (items.isNotEmpty) {
      extractedData['items'] = items
          .map((item) => {
                'name': item.name,
                'quantity': item.quantity,
                'unit_price': item.unitPrice,
                'total_price': item.totalPrice,
                'category': item.category,
              })
          .toList();
    }

    final confidence = _calculateExtractionConfidence(
      extractedData,
      ocrConfidence,
      warnings.length,
    );

    stopwatch.stop();
    final processingTime = stopwatch.elapsedMilliseconds;

    logger.d('Final extracted data: $extractedData');
    _validateExtractedData(extractedData, warnings);
    logger.d('Validation warnings: $warnings');

    logger.i('Receipt extraction completed: ${extractedData.length} fields, '
        'confidence: ${confidence.toStringAsFixed(2)}, '
        'warnings: ${warnings.length}');

    return ExtractionResult.success(
      extractedData: extractedData,
      processingTime: processingTime,
      confidence: confidence,
      warnings: warnings,
      appliedPatterns: appliedPatterns,
      metadata: {
        'detected_language': detectedLanguage,
        'ocr_confidence': ocrConfidence,
        'text_length': normalizedText.length,
        'patterns_applied': appliedPatterns.length,
        'parsing_method': 'text_fallback',
      },
    );
  }

  // ----------------------------
  // Structured helpers (original + small robustness)
  // ----------------------------

  String? _extractMerchantFromBlocks(List<Map<String, dynamic>> blocks, List<String> appliedPatterns) {
    for (int i = 0; i < math.min(4, blocks.length); i++) {
      final text = (blocks[i]['text'] as String).trim();
      if (text.length > 3 && text.length < 60 && !_isCommonNonMerchantText(text) && !text.contains(':') && !text.contains('#')) {
        appliedPatterns.add('structured_merchant');
        return text;
      }
    }
    return null;
  }

  DateTime? _extractDateFromBlocks(List<Map<String, dynamic>> blocks, List<String> appliedPatterns) {
    logger.d('🔍 Extracting date from ${blocks.length} blocks (textLines)');
    for (int i = 0; i < blocks.length; i++) {
      final block = blocks[i];
      final text = (block['text'] as String).trim();
      logger.d('  Checking block $i: "$text"');
      for (final pattern in RegexPatterns.datePatterns) {
        final match = pattern.firstMatch(text);
        if (match != null) {
          try {
            appliedPatterns.add('structured_date');
            final date = _parseDate(match);
            logger.d('  ✅ Found date in block $i: "$text" → ${date.toIso8601String()}');
            return date;
          } catch (e) {
            logger.w('Failed to parse structured date: ${match.group(0)} - $e');
          }
        }
      }
    }
    logger.d('  ❌ No date found in blocks');
    return null;
  }

  Map<String, double> _extractAmountsFromBlocks(List<Map<String, dynamic>> blocks, List<String> appliedPatterns) {
    final amounts = <String, double>{};
    final List<Map<String, dynamic>> candidateAmounts = [];

    // Generate dynamic patterns from LanguageKeywords
    // IMPORTANT: Check subtotal keywords first, then tax, then total
    // This ensures "Välisumma" (subtotal) is matched before "summa" (total)
    final subtotalKeywords = LanguageKeywords.getAllKeywords('subtotal');
    final taxKeywords = LanguageKeywords.getAllKeywords('tax');
    final totalKeywords = LanguageKeywords.getAllKeywords('total');
    
    // Escape keywords for regex
    final escapedSubtotal = subtotalKeywords.map((k) => RegExp.escape(k)).join('|');
    final escapedTax = taxKeywords.map((k) => RegExp.escape(k)).join('|');
    final escapedTotal = totalKeywords.map((k) => RegExp.escape(k)).join('|');
    
    // Create patterns in priority order: subtotal, tax, total
    final amountPattern = r'([-]?\d{1,3}(?:[.,]\d{3})*(?:[.,]\d{2})|[-]?\d+(?:[.,]\d{2}))';
    final currencyPattern = r'[€\$£¥₹kr]?';
    
    // Pattern 1: Subtotal (highest priority)
    final subtotalPattern = RegExp(
      r'\b(${escapedSubtotal})\b(?:\s+\d+%)?\s*:?\s*${currencyPattern}\s*${amountPattern}',
      caseSensitive: false,
    );
    // Pattern 2: Tax
    final taxPattern = RegExp(
      r'\b(${escapedTax})\b(?:\s+\d+%)?\s*:?\s*${currencyPattern}\s*${amountPattern}',
      caseSensitive: false,
    );
    // Pattern 3: Total (lowest priority, checked last)
    final totalPattern = RegExp(
      r'\b(${escapedTotal})\b(?:\s+\d+%)?\s*:?\s*${currencyPattern}\s*${amountPattern}',
      caseSensitive: false,
    );
    
    final amountOnlyPattern = RegExp(r'^[€\$£¥₹kr]?\s*([-]?\d+[.,]\d{2})\s*$');

    for (final block in blocks) {
      final rawText = block['text'] as String;
      final text = _normalizeLine(rawText);
      final boundingBox = block['boundingBox'] as List;
      final yPosition = boundingBox[1];

      // Try patterns in priority order: subtotal, tax, total
      RegExpMatch? labelMatch;
      String? matchedLabel;
      String? category;
      
      // Check subtotal first
      labelMatch = subtotalPattern.firstMatch(text);
      if (labelMatch != null) {
        matchedLabel = labelMatch.group(1)!.toLowerCase();
        category = 'subtotal';
      } else {
        // Check tax
        labelMatch = taxPattern.firstMatch(text);
        if (labelMatch != null) {
          matchedLabel = labelMatch.group(1)!.toLowerCase();
          category = 'tax';
        } else {
          // Check total last
          labelMatch = totalPattern.firstMatch(text);
          if (labelMatch != null) {
            matchedLabel = labelMatch.group(1)!.toLowerCase();
            category = 'total';
          }
        }
      }
      
      if (labelMatch != null && matchedLabel != null && category != null) {
        final amountStr = labelMatch.group(2)!;
        final amount = _parseAmount(amountStr);

        if (amount != null && amount > 0) {
          final priority = _getLabelPriority(matchedLabel);
          candidateAmounts.add({
            'type': category,
            'amount': amount,
            'text': text,
            'y_position': yPosition,
            'priority': priority,
          });
          logger.d('Found labeled amount: $matchedLabel = $amount from "$text" at y=$yPosition, categorized as: $category, priority: $priority');
        }
        continue;
      }

      final amountMatch = amountOnlyPattern.firstMatch(text);
      if (amountMatch != null) {
        final amountStr = amountMatch.group(1)!;
        final amount = _parseAmount(amountStr);
        if (amount != null && amount > 5.0) {
          candidateAmounts.add({
            'type': 'unknown',
            'amount': amount,
            'text': text,
            'y_position': yPosition,
            'priority': 0,
          });
          logger.d('Found standalone amount: $amount from "$text" at y=$yPosition');
        }
      }
    }

    candidateAmounts.sort((a, b) {
      final priorityCompare = (b['priority'] as int).compareTo(a['priority'] as int);
      if (priorityCompare != 0) return priorityCompare;
      return (a['y_position'] as double).compareTo(b['y_position'] as double);
    });

    logger.d('Processing ${candidateAmounts.length} candidate amounts from blocks');
    for (final candidate in candidateAmounts) {
      final type = candidate['type'] as String;
      final amount = candidate['amount'] as double;
      final text = candidate['text'] as String;

      logger.d('Processing candidate: type=$type, amount=$amount, text="$text"');

      if (type == 'total' && !amounts.containsKey('total_amount')) {
        amounts['total_amount'] = amount;
        appliedPatterns.add('structured_total');
        logger.d('✅ Assigned total_amount: $amount from "$text"');
      } else if (type == 'subtotal' && !amounts.containsKey('subtotal_amount')) {
        amounts['subtotal_amount'] = amount;
        appliedPatterns.add('structured_subtotal');
        logger.d('✅ Assigned subtotal_amount: $amount from "$text"');
      } else if (type == 'tax' && !amounts.containsKey('tax_amount')) {
        amounts['tax_amount'] = amount;
        appliedPatterns.add('structured_tax');
        logger.d('✅ Assigned tax_amount: $amount from "$text"');
      } else if (type == 'unknown' && !amounts.containsKey('total_amount') && amount > 10.0) {
        amounts['total_amount'] = amount;
        appliedPatterns.add('structured_standalone_amount');
        logger.d('✅ Assigned unknown amount as total_amount: $amount from "$text"');
      } else {
        logger.d('⚠️ Skipped candidate: type=$type (already exists or conditions not met)');
      }
    }
    
    logger.d('Final amounts from blocks: $amounts');

    // Compute total if possible
    if (!amounts.containsKey('total_amount') &&
        amounts.containsKey('subtotal_amount') &&
        amounts.containsKey('tax_amount')) {
      final computed = (amounts['subtotal_amount']! + amounts['tax_amount']!);
      amounts['total_amount'] = double.parse(computed.toStringAsFixed(2));
      appliedPatterns.add('structured_computed_total');
    }

    return amounts;
  }

  String _categorizeAmountLabel(String label) {
    final lowerLabel = label.toLowerCase();
    
    // IMPORTANT: Check subtotal BEFORE total, because "subtotal" contains "total"
    // Use LanguageKeywords for multi-language support
    final subtotalKeywords = LanguageKeywords.getAllKeywords('subtotal');
    for (final keyword in subtotalKeywords) {
      if (lowerLabel.contains(keyword.toLowerCase())) {
        return 'subtotal';
      }
    }
    
    // Check tax keywords
    final taxKeywords = LanguageKeywords.getAllKeywords('tax');
    for (final keyword in taxKeywords) {
      if (lowerLabel.contains(keyword.toLowerCase())) {
        return 'tax';
      }
    }
    
    // Check total keywords (after subtotal to avoid false matches)
    final totalKeywords = LanguageKeywords.getAllKeywords('total');
    for (final keyword in totalKeywords) {
      if (lowerLabel.contains(keyword.toLowerCase())) {
        return 'total';
      }
    }
    
    return 'unknown';
  }

  int _getLabelPriority(String label) {
    final lowerLabel = label.toLowerCase();
    
    // IMPORTANT: Check subtotal BEFORE total, because "subtotal" contains "total"
    // Use LanguageKeywords for multi-language support
    final subtotalKeywords = LanguageKeywords.getAllKeywords('subtotal');
    for (final keyword in subtotalKeywords) {
      if (lowerLabel.contains(keyword.toLowerCase())) {
        return 2;
      }
    }
    
    // Check tax keywords
    final taxKeywords = LanguageKeywords.getAllKeywords('tax');
    for (final keyword in taxKeywords) {
      if (lowerLabel.contains(keyword.toLowerCase())) {
        return 1;
      }
    }
    
    // Check total keywords (after subtotal to avoid false matches)
    final totalKeywords = LanguageKeywords.getAllKeywords('total');
    for (final keyword in totalKeywords) {
      if (lowerLabel.contains(keyword.toLowerCase())) {
        return 3;
      }
    }
    
    return 0;
  }

  PaymentMethod? _extractPaymentMethodFromBlocks(List<Map<String, dynamic>> blocks, List<String> appliedPatterns) {
    logger.d('🔍 Extracting payment method from ${blocks.length} blocks (textLines)');
    for (int i = 0; i < blocks.length; i++) {
      final block = blocks[i];
      final text = (block['text'] as String);
      final lowerText = text.toLowerCase();
      logger.d('  Checking block $i: "$text"');
      for (int p = 0; p < RegexPatterns.paymentMethodPatterns.length; p++) {
        final pattern = RegexPatterns.paymentMethodPatterns[p];
        final match = pattern.firstMatch(lowerText);
        if (match != null) {
          appliedPatterns.add('structured_payment_pattern_$p');
          // For explicit payment pattern (first pattern), group 2 is the payment method
          // For other patterns, group 0 is the payment method
          String? paymentMethodStr;
          if (p == 0 && match.groupCount >= 2) {
            paymentMethodStr = match.group(2);
          } else {
            paymentMethodStr = match.group(0);
          }
          if (paymentMethodStr != null) {
            final method = PaymentMethod.fromString(paymentMethodStr);
            logger.d('  ✅ Found payment method in block $i: "$text" → ${method.name} (from "$paymentMethodStr")');
            return method;
          }
        }
      }
    }
    logger.d('  ❌ No payment method found in blocks');
    return null;
  }

  Currency? _extractCurrencyFromBlocks(List<Map<String, dynamic>> blocks, List<String> appliedPatterns) {
    for (final block in blocks) {
      final text = block['text'] as String;
      if (text.contains('€')) {
        appliedPatterns.add('structured_currency_eur');
        return Currency.eur;
      }
      for (final pattern in RegexPatterns.currencyPatterns) {
        final match = pattern.firstMatch(text);
        if (match != null) {
          appliedPatterns.add('structured_currency');
          final currencyText = match.group(0)!;

          switch (currencyText.toLowerCase()) {
            case '€':
            case 'eur':
              return Currency.eur;
            case 'kr':
            case 'sek':
              return Currency.sek;
            case 'nok':
              return Currency.nok;
            case 'dkk':
              return Currency.dkk;
            case '\$':
            case 'usd':
              return Currency.usd;
            case '£':
            case 'gbp':
              return Currency.gbp;
          }
        }
      }
    }
    return null;
  }

  String? _extractReceiptNumberFromBlocks(List<Map<String, dynamic>> blocks, List<String> appliedPatterns) {
    final receiptNumberPatterns = PatternGenerator.generateReceiptNumberPatterns();
    for (final block in blocks) {
      final text = block['text'] as String;
      // Multi-language support for receipt number (generated dynamically)
      final explicit = receiptNumberPatterns.first.firstMatch(text);
      if (explicit != null) {
        appliedPatterns.add('structured_receipt_number_explicit');
        // Group 2 is the receipt number (group 1 is the keyword)
        return explicit.groupCount >= 2
            ? (explicit.group(2)?.trim() ?? explicit.group(1)?.trim())
            : explicit.group(1)?.trim();
      }

      for (final pattern in receiptNumberPatterns.skip(1)) {
        final match = pattern.firstMatch(text);
        if (match != null) {
          appliedPatterns.add('structured_receipt_number');
          // レシート番号は通常グループ2にマッチする（グループ1はキーワード）
          // ただし、#(\d+)形式の場合はグループ1が番号
          final receiptNumber = match.groupCount >= 2 ? match.group(2) : match.group(1);
          return receiptNumber?.trim();
        }
      }
    }
    return null;
  }

  bool _isCommonNonMerchantText(String text) {
    final lowerText = text.toLowerCase().trim();
    final commonWords = [
      'receipt',
      'kuitti',
      'kvitto',
      'reçu',
      'rechnung',
      'ricevuta',
      'recibo',
      'date',
      'time',
      'item',
      'items',
      'total',
      'tax',
      'vat',
      'subtotal',
      'payment',
      'card',
      'cash',
      'thank',
      'you',
    ];

    for (final word in commonWords) {
      if (lowerText.contains(word)) {
        return true;
      }
    }

    return false;
  }

  /// Extract lines from structured text blocks
  List<String> _extractLinesFromTextBlocks(List<Map<String, dynamic>> textBlocks) {
    final lines = <String>[];

    // Group text blocks by their Y position (same Y = same line)
    final linesByY = <double, List<Map<String, dynamic>>>{};

    for (final block in textBlocks) {
      final boundingBox = block['boundingBox'] as List<dynamic>?;
      if (boundingBox != null && boundingBox.length >= 2) {
        final y = (boundingBox[1] as num).toDouble();
        // Round Y to group nearby lines (within 5 pixels)
        final roundedY = (y / 5).round() * 5.0;

        if (!linesByY.containsKey(roundedY)) {
          linesByY[roundedY] = [];
        }
        linesByY[roundedY]!.add(block);
      }
    }

    // Sort by Y position and create lines
    final sortedYs = linesByY.keys.toList()..sort();
    for (final y in sortedYs) {
      final blocksInLine = linesByY[y]!;
      // Sort blocks in line by X position
      blocksInLine.sort((a, b) {
        final aBox = a['boundingBox'] as List<dynamic>;
        final bBox = b['boundingBox'] as List<dynamic>;
        final aX = (aBox[0] as num).toDouble();
        final bX = (bBox[0] as num).toDouble();
        return aX.compareTo(bX);
      });

      // Combine text from all blocks in the line
      final lineText = blocksInLine.map((b) => b['text'] as String).join(' ').trim();
      if (lineText.isNotEmpty) {
        lines.add(lineText);
      }
    }

    return lines;
  }

  /// Combine consecutive lines that belong together
  /// For example: "TOTAL:" and "€15.60" should be combined into "TOTAL: €15.60"
  List<String> _combineRelatedLines(List<String> lines) {
    if (lines.isEmpty) return lines;

    final combinedLines = <String>[];
    int i = 0;

    while (i < lines.length) {
      final currentLine = lines[i].trim();

      // Check if current line ends with a label pattern (e.g., "TOTAL:", "Subtotal:", "VAT 24%:")
      final labelPattern = RegExp(
        r'(total|subtotal|tax|vat|sum|yhteensä|alv|summa|moms|tva|gesamt|mwst|totale|iva)(?:\s+\d+%)?\s*:?\s*$',
        caseSensitive: false,
      );

      if (labelPattern.hasMatch(currentLine) && i + 1 < lines.length) {
        // Current line is a label, check if next line is an amount
        final nextLine = lines[i + 1].trim();
        final amountPattern = RegExp(
          r'^[€\$£¥₹kr]?\s*[\d,]+[.,]\d{1,2}\s*$',
        );

        if (amountPattern.hasMatch(nextLine)) {
          // Combine label and amount
          final combined = '$currentLine $nextLine';
          combinedLines.add(combined);
          logger.d('Combined lines: "$currentLine" + "$nextLine" = "$combined"');
          i += 2; // Skip both lines
          continue;
        }
      }

      // Check if current line is just a label without amount, and next line might be the amount
      // This handles cases where label and amount are clearly separated
      if (currentLine.endsWith(':') && i + 1 < lines.length) {
        final nextLine = lines[i + 1].trim();
        // If next line looks like an amount, combine them
        if (RegExp(r'^[€\$£¥₹kr]?\s*[\d,]+[.,]\d{1,2}').hasMatch(nextLine)) {
          final combined = '$currentLine $nextLine';
          combinedLines.add(combined);
          logger.d('Combined label and amount: "$currentLine" + "$nextLine" = "$combined"');
          i += 2;
          continue;
        }
      }

      // No combination needed, add line as-is
      combinedLines.add(currentLine);
      i++;
    }

    return combinedLines;
  }

  // ----------------------------
  // Consistency Checking (Step 2)
  // ----------------------------

  /// 整合性チェックと最適解の選択
  ConsistencyResult _selectBestCandidates(
    Map<String, FieldCandidates> allCandidates,
  ) {
    // 各フィールドの上位候補を取得（最大3つ）
    final totalCandidates = allCandidates['total_amount']?.getTopN(3) ?? [];
    final subtotalCandidates = allCandidates['subtotal_amount']?.getTopN(3) ?? [];
    final taxCandidates = allCandidates['tax_amount']?.getTopN(3) ?? [];

    // 候補が少ない場合はそのまま返す
    if (totalCandidates.isEmpty && subtotalCandidates.isEmpty && taxCandidates.isEmpty) {
      return ConsistencyResult(
        selectedCandidates: {},
        consistencyScore: 0.0,
        warnings: ['No candidates found'],
        needsVerification: true,
      );
    }

    double bestScore = -1.0;
    Map<String, AmountCandidate> bestSelection = {};
    List<String> warnings = [];

    // 全組み合わせを評価
    // Total, Subtotal, Taxの組み合わせを試す
    final totalList = totalCandidates.isNotEmpty ? totalCandidates : [null];
    final subtotalList = subtotalCandidates.isNotEmpty ? subtotalCandidates : [null];
    final taxList = taxCandidates.isNotEmpty ? taxCandidates : [null];

    for (final total in totalList) {
      for (final subtotal in subtotalList) {
        for (final tax in taxList) {
          // 少なくとも1つの候補が必要（整合性チェックは2つ以上で有効）
          final candidateCount = [
            total != null,
            subtotal != null,
            tax != null,
          ].where((has) => has).length;

          if (candidateCount < 1) continue;

          // 2つ以上の候補がある場合のみ整合性スコアを計算
          // 1つだけの場合は候補の信頼度スコアのみ使用
          double score;
          if (candidateCount >= 2) {
            score = _calculateConsistencyScore(
              total: total,
              subtotal: subtotal,
              tax: tax,
            );
          } else {
            // 1つだけの場合は候補のスコアを正規化（0.0-1.0）
            final singleCandidate = total ?? subtotal ?? tax;
            score = singleCandidate != null ? (singleCandidate.score / 100.0) : 0.0;
          }

          if (score > bestScore) {
            bestScore = score;
            bestSelection = {};
            if (total != null) bestSelection['total_amount'] = total;
            if (subtotal != null) bestSelection['subtotal_amount'] = subtotal;
            if (tax != null) bestSelection['tax_amount'] = tax;
          }
        }
      }
    }
    
    // 候補が見つからなかった場合、最良の単一候補を選択
    if (bestSelection.isEmpty) {
      if (totalCandidates.isNotEmpty) {
        bestSelection['total_amount'] = totalCandidates.first;
        bestScore = totalCandidates.first.score / 100.0;
      } else if (subtotalCandidates.isNotEmpty) {
        bestSelection['subtotal_amount'] = subtotalCandidates.first;
        bestScore = subtotalCandidates.first.score / 100.0;
      } else if (taxCandidates.isNotEmpty) {
        bestSelection['tax_amount'] = taxCandidates.first;
        bestScore = taxCandidates.first.score / 100.0;
      }
    }

    // 警告の生成
    if (bestScore < 0.7 && bestSelection.length >= 2) {
      warnings.add('Low consistency score: ${bestScore.toStringAsFixed(2)}');
    }
    
    // ログ出力
    logger.d('🔍 Consistency check: ${bestSelection.length} fields selected, score: ${bestScore.toStringAsFixed(2)}');
    for (final entry in bestSelection.entries) {
      logger.d('  Selected ${entry.key}: ${entry.value.amount} (score: ${entry.value.score}, line: ${entry.value.lineIndex})');
    }

    // 矛盾検知と自動修正
    Map<String, double>? correctedValues;
    if (bestSelection.containsKey('total_amount') &&
        bestSelection.containsKey('subtotal_amount') &&
        bestSelection.containsKey('tax_amount')) {
      final total = bestSelection['total_amount']!.amount;
      final subtotal = bestSelection['subtotal_amount']!.amount;
      final tax = bestSelection['tax_amount']!.amount;
      final expectedTotal = subtotal + tax;
      final difference = (total - expectedTotal).abs();

      if (difference > 0.01) {
        // 1セント以上の差
        warnings.add(
          'Amount mismatch: total ($total) != subtotal ($subtotal) + tax ($tax) = $expectedTotal (diff: ${difference.toStringAsFixed(2)})',
        );

        // 自動修正の試行（10セント以内なら修正）
        if (difference < 0.10) {
          correctedValues = {
            'total_amount': double.parse(expectedTotal.toStringAsFixed(2)),
          };
          warnings.add('Auto-corrected total: $total → $expectedTotal');
          logger.d('✅ Auto-corrected total amount');
        } else {
          warnings.add('Large difference (${difference.toStringAsFixed(2)}), manual verification required');
        }
      }
    }

    return ConsistencyResult(
      selectedCandidates: bestSelection,
      consistencyScore: bestScore,
      warnings: warnings,
      needsVerification: bestScore < 0.6 || (correctedValues == null && warnings.isNotEmpty),
      correctedValues: correctedValues,
    );
  }

  /// 候補リストをAmountCandidateに変換
  List<AmountCandidate> _convertToAmountCandidates(
    List<({double amount, int score, int lineIndex, String source})> candidates,
    String fieldName,
    List<TextLine>? textLines,
  ) {
    // スコアでソート（高い順）
    final sorted = List<({double amount, int score, int lineIndex, String source})>.from(candidates);
    sorted.sort((a, b) => b.score.compareTo(a.score));
    
    // 上位5個まで取得
    return sorted.take(5).map((c) {
      return AmountCandidate(
        amount: c.amount,
        score: c.score,
        lineIndex: c.lineIndex,
        source: c.source,
        fieldName: fieldName,
        boundingBox: textLines != null && c.lineIndex < textLines.length
            ? textLines[c.lineIndex].boundingBox
            : null,
        confidence: textLines != null && c.lineIndex < textLines.length
            ? textLines[c.lineIndex].confidence
            : null,
      );
    }).toList();
  }

  /// 位置情報によるスコアボーナス
  void _applyPositionBonuses(
    List<AmountCandidate> totalCandidates,
    List<AmountCandidate> subtotalCandidates,
    List<AmountCandidate> taxCandidates,
    int totalLines,
  ) {
    // Totalは下側にあるほどボーナス
    for (final candidate in totalCandidates) {
      final positionRatio = candidate.lineIndex / totalLines;
      if (positionRatio > 0.6) {
        candidate.score += 10; // 下側にいるほど高スコア
      } else if (positionRatio > 0.5) {
        candidate.score += 5;
      }
    }

    // SubtotalはTotalより上にあるべき（後で整合性チェックで評価）
    // ここでは位置による基本ボーナスのみ
    for (final candidate in subtotalCandidates) {
      final positionRatio = candidate.lineIndex / totalLines;
      if (positionRatio > 0.3 && positionRatio < 0.7) {
        candidate.score += 5; // 中間あたり
      }
    }

    // TaxはSubtotalの近くにあることが多い
    for (final candidate in taxCandidates) {
      final positionRatio = candidate.lineIndex / totalLines;
      if (positionRatio > 0.4 && positionRatio < 0.8) {
        candidate.score += 5;
      }
    }
  }

  /// 整合性スコアの計算
  double _calculateConsistencyScore({
    AmountCandidate? total,
    AmountCandidate? subtotal,
    AmountCandidate? tax,
  }) {
    double score = 0.0;

    // 1. 基本的な整合性チェック（最重要）
    if (total != null && subtotal != null && tax != null) {
      final expectedTotal = subtotal.amount + tax.amount;
      final difference = (total.amount - expectedTotal).abs();
      const tolerance = 0.01; // 1セントの許容誤差

      if (difference <= tolerance) {
        score += 0.5; // 完全一致
      } else if (difference <= 0.10) {
        score += 0.3; // 10セント以内
      } else if (difference <= 1.0) {
        score += 0.1; // 1ユーロ以内
      }
      // それ以上は0点
    } else if ((subtotal != null && tax != null) || (total != null && (subtotal != null || tax != null))) {
      // 部分的に一致する場合、小さなスコア
      score += 0.1;
    }

    // 2. 候補の信頼度スコア（正規化）
    final candidates = [total, subtotal, tax].whereType<AmountCandidate>().toList();
    if (candidates.isNotEmpty) {
      final avgCandidateScore = candidates.map((c) => c.score).reduce((a, b) => a + b) / candidates.length;
      score += (avgCandidateScore / 100.0) * 0.3; // 最大0.3点
    }

    // 3. 位置関係の整合性
    if (total != null && subtotal != null) {
      // TotalはSubtotalより下にあるべき
      if (total.lineIndex > subtotal.lineIndex) {
        score += 0.1;
      }
    }

    // 4. OCR信頼度（あれば）
    final candidatesWithConfidence = candidates.where((c) => c.confidence != null).toList();
    if (candidatesWithConfidence.isNotEmpty) {
      final avgConfidence = candidatesWithConfidence
              .map((c) => c.confidence!)
              .reduce((a, b) => a + b) /
          candidatesWithConfidence.length;
      score += avgConfidence * 0.1; // 最大0.1点
    }

    return score.clamp(0.0, 1.0);
  }
}
