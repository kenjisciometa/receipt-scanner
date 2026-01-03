import 'dart:math' as math;

import '../../core/constants/language_keywords.dart';
import '../../core/constants/pattern_generator.dart';
import '../../core/constants/regex_patterns.dart';
import '../../core/errors/exceptions.dart';
import '../../data/models/receipt.dart';
import '../../data/models/receipt_item.dart';
import '../../data/models/tax_breakdown.dart';
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
  // New fields for item sum consistency
  final double? itemsSum;
  final int? itemsCount;
  final bool? itemsSumMatchesSubtotal;
  final bool? itemsSumMatchesTotal;

  ConsistencyResult({
    required this.selectedCandidates,
    required this.consistencyScore,
    this.warnings = const [],
    this.needsVerification = false,
    this.correctedValues,
    this.itemsSum,
    this.itemsCount,
    this.itemsSumMatchesSubtotal,
    this.itemsSumMatchesTotal,
  });
}

/// Helper class for item candidates during structured extraction
class ItemCandidate {
  final String name;
  final int quantity;
  final double totalPrice;
  final int lineIndex;
  final double yCenter;
  final double xCenter;
  final double confidence;
  
  ItemCandidate({
    required this.name,
    required this.quantity,
    required this.totalPrice,
    required this.lineIndex,
    required this.yCenter,
    required this.xCenter,
    required this.confidence,
  });
}

/// Helper class for tax breakdown candidates
class TaxBreakdownCandidate {
  final double rate;
  final double amount;
  final int lineIndex;
  final int score;
  final String source;
  final List<double>? boundingBox;
  final double? confidence;
  
  TaxBreakdownCandidate({
    required this.rate,
    required this.amount,
    required this.lineIndex,
    required this.score,
    required this.source,
    this.boundingBox,
    this.confidence,
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
  
  /// Check if header text indicates an item table (product list)
  bool _isItemTableHeader(String headerText) {
    final lower = headerText.toLowerCase();
    
    // LanguageKeywordsからアイテムテーブルのキーワードを取得
    final itemTableKeywords = LanguageKeywords.getAllKeywords('item_table_header');
    
    int keywordCount = 0;
    for (final keyword in itemTableKeywords) {
      if (lower.contains(keyword.toLowerCase())) {
        keywordCount++;
      }
    }
    
    // 2つ以上のキーワードが含まれている場合、アイテムテーブル
    return keywordCount >= 2;
  }
  
  /// Check if header text indicates a summary table (Subtotal, Tax, Total)
  bool _isSummaryTableHeader(String headerText) {
    final lower = headerText.toLowerCase();
    
    // LanguageKeywordsから既存のカテゴリを使用
    final totalKeywords = LanguageKeywords.getAllKeywords('total');
    final subtotalKeywords = LanguageKeywords.getAllKeywords('subtotal');
    final taxKeywords = LanguageKeywords.getAllKeywords('tax');
    
    // サマリーテーブルのキーワードを統合
    final summaryTableKeywords = [
      ...totalKeywords,
      ...subtotalKeywords,
      ...taxKeywords,
    ];
    
    for (final keyword in summaryTableKeywords) {
      if (lower.contains(keyword.toLowerCase())) {
        return true;
      }
    }
    
    return false;
  }
  
  /// Check if a header is a valid summary table header
  bool _isValidSummaryTableHeader(String headerText, int amountCount, bool hasPercent) {
    final lower = headerText.toLowerCase();
    
    // LanguageKeywordsからキーワードを取得
    final totalKeywords = LanguageKeywords.getAllKeywords('total');
    final subtotalKeywords = LanguageKeywords.getAllKeywords('subtotal');
    final taxKeywords = LanguageKeywords.getAllKeywords('tax');
    final itemTableKeywords = LanguageKeywords.getAllKeywords('item_table_header');
    
    // サマリーテーブルのキーワードを統合
    final summaryTableKeywords = [
      ...totalKeywords,
      ...subtotalKeywords,
      ...taxKeywords,
    ];
    
    // サマリーテーブルのキーワードが含まれているか確認
    final hasSummaryKeyword = summaryTableKeywords.any((keyword) => 
      lower.contains(keyword.toLowerCase())
    );
    
    // アイテムテーブルのキーワードが含まれていないか確認
    final hasItemKeyword = itemTableKeywords.any((keyword) => 
      lower.contains(keyword.toLowerCase())
    );
    
    // 条件:
    // 1. サマリーテーブルのキーワードを含む
    // 2. アイテムテーブルのキーワードを含まない
    // 3. 金額が1つ以下、またはパーセンテージを含む
    if (hasItemKeyword && !hasSummaryKeyword) {
      return false; // アイテムテーブル
    }
    
    if (hasSummaryKeyword && (amountCount <= 1 || hasPercent)) {
      return true; // サマリーテーブル
    }
    
    return false;
  }
  
  /// Check if a data row is from a summary table
  bool _isSummaryTableDataRow(String rowText) {
    final lower = rowText.toLowerCase();
    
    // LanguageKeywordsからキーワードを取得
    final totalKeywords = LanguageKeywords.getAllKeywords('total');
    final subtotalKeywords = LanguageKeywords.getAllKeywords('subtotal');
    final taxKeywords = LanguageKeywords.getAllKeywords('tax');
    final itemTableKeywords = LanguageKeywords.getAllKeywords('item_table_header');
    
    // サマリーテーブルのキーワードを統合
    final summaryTableKeywords = [
      ...totalKeywords,
      ...subtotalKeywords,
      ...taxKeywords,
    ];
    
    // サマリーテーブルのキーワードが含まれているか確認
    final hasSummaryKeyword = summaryTableKeywords.any((keyword) => 
      lower.contains(keyword.toLowerCase())
    );
    
    // アイテムテーブルのキーワードが含まれていないか確認
    final hasItemKeyword = itemTableKeywords.any((keyword) => 
      lower.contains(keyword.toLowerCase())
    );
    
    // 条件:
    // 1. サマリーテーブルのキーワードを含む、または
    // 2. アイテムテーブルのキーワードを含まない（かつ金額が3つ以上）
    if (hasItemKeyword && !hasSummaryKeyword) {
      return false; // アイテムテーブルの行
    }
    
    return true; // サマリーテーブルの行
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
    
    // Step 2: Find table structure - look for header row and all data rows
    TextLine? headerLine;
    int headerIndex = -1;
    final dataRows = <TextLine>[];
    
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
      
      // Check if this is a header row (few amounts or percentage only)
      final headerAmountMatches = amountPattern.allMatches(combinedText);
      final headerHasPercent = percentPattern.hasMatch(combinedText);
      final headerAmountCount = headerAmountMatches.length;
      
      if ((headerAmountCount <= 1 || headerHasPercent) && headerLine == null) {
        // 改善: テーブルタイプの判定
        final isItemTable = _isItemTableHeader(combinedText);
        final isSummaryTable = _isSummaryTableHeader(combinedText);
        
        if (isItemTable && !isSummaryTable) {
          // アイテムテーブルの場合はスキップ
          logger.d('📊 Skipping item table header at line $i: "${combinedText}"');
          continue;
        }
        
        // サマリーテーブルのヘッダー、またはアイテムテーブルでない場合
        if (isSummaryTable || (!isItemTable && headerAmountCount <= 1)) {
          headerLine = _combineTextLines(sameYLines);
          headerIndex = i;
          logger.d('📊 Found summary table header at line $i: "${combinedText}"');
        }
      } else if (headerLine != null && amountCount >= 3 && i > headerIndex) {
        // データ行の検証
        if (_isSummaryTableDataRow(combinedText)) {
          final combinedDataLine = _combineTextLines(sameYLines);
          dataRows.add(combinedDataLine);
          logger.d('📊 Found summary table data row at line $i (Y: ${yCoord.toStringAsFixed(1)}): $amountCount amounts in "${combinedText}"');
        } else {
          logger.d('📊 Skipping item table data row at line $i: "${combinedText}"');
        }
      }
    }
    
    // Step 3: Process all data rows if we found a header
    if (headerLine != null && dataRows.isNotEmpty) {
      logger.d('📊 Processing ${dataRows.length} data row(s) from table');
      
      double totalTax = 0.0;
      double totalSubtotal = 0.0;
      double? finalTotal;
      
      for (int rowIndex = 0; rowIndex < dataRows.length; rowIndex++) {
        final dataRow = dataRows[rowIndex];
        final extracted = _extractTableValuesFromBoundingBox(
          headerLine!,
          dataRow,
          appliedPatterns,
          amountPattern,
          percentPattern,
        );
        
        if (extracted.isNotEmpty) {
          // Accumulate values from multiple rows
          if (extracted.containsKey('tax_amount')) {
            totalTax += extracted['tax_amount']!;
          }
          if (extracted.containsKey('subtotal_amount')) {
            totalSubtotal += extracted['subtotal_amount']!;
          }
          // For multiple rows, each row's total is that row's subtotal + tax
          // The final total should be the sum of all rows' subtotals + taxes
          // So we don't use individual row totals, but calculate from accumulated values
          
          logger.d('📊 Row ${rowIndex + 1}: tax=${extracted['tax_amount']}, subtotal=${extracted['subtotal_amount']}, row_total=${extracted['total_amount']}');
        }
      }
      
      // Set accumulated values
      if (totalTax > 0) {
        amounts['tax_amount'] = double.parse(totalTax.toStringAsFixed(2));
      }
      if (totalSubtotal > 0) {
        amounts['subtotal_amount'] = double.parse(totalSubtotal.toStringAsFixed(2));
      }
      
      // For multiple tax rate rows, calculate final total from accumulated subtotal + tax
      // This ensures correctness: Total = Sum of all Subtotals + Sum of all Taxes
      if (totalSubtotal > 0 && totalTax > 0) {
        amounts['total_amount'] = double.parse((totalSubtotal + totalTax).toStringAsFixed(2));
        logger.d('📊 Calculated final total from accumulated values: ${amounts['subtotal_amount']} + ${amounts['tax_amount']} = ${amounts['total_amount']}');
      } else if (finalTotal != null && dataRows.length == 1) {
        // For single row, use the row's total directly
        amounts['total_amount'] = finalTotal;
      }
      
      if (amounts.isNotEmpty) {
        appliedPatterns.add('table_format_structure_based_multiple_rates');
        logger.d('📊 Table extraction completed (multiple rates): $amounts');
        return amounts;
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
  /// Now supports multiple tax rate rows
  Map<String, double> _extractAmountsFromTableTextBased(
    List<String> lines,
    List<String> appliedPatterns,
    RegExp amountPattern,
    RegExp percentPattern,
  ) {
    final amounts = <String, double>{};
    
    // Step 1: Find header row
    int? headerIndex;
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final headerAmountMatches = amountPattern.allMatches(line);
      final headerHasPercent = percentPattern.hasMatch(line);
      final headerAmountCount = headerAmountMatches.length;
      
      // Header row criteria: few amounts (0-1) or percentage only
      if ((headerAmountCount <= 1 || headerHasPercent) && headerIndex == null) {
        // 改善: テーブルタイプの判定
        final isItemTable = _isItemTableHeader(line);
        final isSummaryTable = _isSummaryTableHeader(line);
        
        if (isItemTable && !isSummaryTable) {
          // アイテムテーブルの場合はスキップ
          logger.d('📊 Skipping item table header (text-based) at line $i: "$line"');
          continue;
        }
        
        // サマリーテーブルのヘッダー、またはアイテムテーブルでない場合
        if (isSummaryTable || (!isItemTable && headerAmountCount <= 1)) {
          headerIndex = i;
          logger.d('📊 Found summary table header (text-based) at line $i: "$line"');
          break;
        }
      }
    }
    
    if (headerIndex == null) {
      return amounts;
    }
    
    // Step 2: Find all data rows after header
    final dataRows = <String>[];
    for (int i = headerIndex + 1; i < lines.length; i++) {
      final line = lines[i];
      final dataAmountMatches = amountPattern.allMatches(line);
      final dataAmountCount = dataAmountMatches.length;
      
      // Data row criteria: 3+ amounts (Tax rate, Tax, Subtotal, Total)
      if (dataAmountCount >= 3) {
        // データ行の検証
        if (_isSummaryTableDataRow(line)) {
          dataRows.add(line);
          logger.d('📊 Found summary table data row (text-based) at line $i: "$line"');
        } else {
          logger.d('📊 Skipping item table data row (text-based) at line $i: "$line"');
        }
      } else if (dataAmountCount >= 2 && dataRows.isNotEmpty) {
        // Might be continuation or summary row, check if it has percentage
        if (percentPattern.hasMatch(line)) {
          // データ行の検証
          if (_isSummaryTableDataRow(line)) {
            dataRows.add(line);
            logger.d('📊 Found additional summary table data row at line $i: "$line"');
          } else {
            logger.d('📊 Skipping item table data row (text-based) at line $i: "$line"');
          }
        } else {
          // Likely not a table row anymore, stop
          break;
        }
      } else if (dataRows.isNotEmpty) {
        // No more table rows
        break;
      }
    }
    
    if (dataRows.isEmpty) {
      return amounts;
    }
    
    logger.d('📊 Processing ${dataRows.length} data row(s) from table (text-based)');
    
    // Step 3: Process all data rows and accumulate values
    double totalTax = 0.0;
    double totalSubtotal = 0.0;
    
    for (int rowIndex = 0; rowIndex < dataRows.length; rowIndex++) {
      final dataLine = dataRows[rowIndex];
      final dataAmountMatches = amountPattern.allMatches(dataLine);
      
      // Extract amounts from data line
      final amountValues = dataAmountMatches
          .map((m) => m.group(0)!.trim())
          .where((v) => !v.contains('%'))
          .map((v) => _parseAmount(v))
          .where((a) => a != null && a! > 0)
          .cast<double>()
          .toList();
      
      logger.d('📊 Row ${rowIndex + 1}: Extracted ${amountValues.length} amounts: $amountValues');
      
      if (amountValues.length >= 3) {
        // Usually: Tax, Subtotal, Total (row-specific)
        totalTax += amountValues[0];
        totalSubtotal += amountValues[1];
        // Note: amountValues[2] is this row's total (subtotal + tax for this row)
        // For multiple rows, we calculate final total from accumulated values
        logger.d('📊 Row ${rowIndex + 1}: tax=${amountValues[0]}, subtotal=${amountValues[1]}, row_total=${amountValues[2]}');
      } else if (amountValues.length == 2) {
        // Assume: Subtotal, Total (row-specific)
        totalSubtotal += amountValues[0];
        logger.d('📊 Row ${rowIndex + 1}: subtotal=${amountValues[0]}, row_total=${amountValues[1]}');
      }
    }
    
    // Set accumulated values
    if (totalTax > 0) {
      amounts['tax_amount'] = double.parse(totalTax.toStringAsFixed(2));
    }
    if (totalSubtotal > 0) {
      amounts['subtotal_amount'] = double.parse(totalSubtotal.toStringAsFixed(2));
    }
    
    // For multiple tax rate rows, calculate final total from accumulated subtotal + tax
    // This ensures correctness: Total = Sum of all Subtotals + Sum of all Taxes
    if (totalSubtotal > 0 && totalTax > 0) {
      amounts['total_amount'] = double.parse((totalSubtotal + totalTax).toStringAsFixed(2));
      logger.d('📊 Calculated final total from accumulated values: $totalSubtotal + $totalTax = ${amounts['total_amount']}');
    } else if (totalSubtotal > 0) {
      // If no tax found, use subtotal as total (shouldn't happen in tax breakdown table)
      amounts['total_amount'] = double.parse(totalSubtotal.toStringAsFixed(2));
    }
    
    if (amounts.isNotEmpty) {
      appliedPatterns.add('table_format_text_based_multiple_rates');
      logger.d('📊 Table extraction (text-based, multiple rates): $amounts');
    }
    
    return amounts;
  }

  /// Extract amounts line by line (adds VAT-specific support + better selection)
  /// Now with unified candidate collection (table + line-based) and consistency checking
  Map<String, double> _extractAmountsLineByLine(
    List<String> lines,
    String? language,
    List<String> appliedPatterns, {
    List<TextLine>? textLines,
    List<ReceiptItem>? items,
  }) {
    logger.d('Starting unified amount extraction with consistency checking');
    
    // 1. すべての候補を統合収集（テーブル + 行ベース + アイテム合計）
    final allCandidates = _collectAllCandidates(
      lines,
      language,
      appliedPatterns,
      textLines: textLines,
      items: items,
    );
    
    // 2. 整合性チェックで最適解を選択（アイテム合計情報も渡す）
    // TODO: ItemSumの整合性チェックを一時的に無効化（Item検出が不安定なため）
    // final itemsSum = _calculateItemsSum(items);
    final itemsSum = null; // 一時的に無効化
    final itemsCount = items?.length;
    final consistencyResult = _selectBestCandidates(allCandidates, itemsSum: itemsSum, itemsCount: itemsCount);
    
    // 3. 結果をマップに変換
    final amounts = <String, double>{};
    for (final entry in consistencyResult.selectedCandidates.entries) {
      final fieldName = entry.key;
      final candidate = entry.value;
      
      // 修正された値があればそれを使用
      if (consistencyResult.correctedValues?.containsKey(fieldName) == true) {
        amounts[fieldName] = consistencyResult.correctedValues![fieldName]!;
        appliedPatterns.add('${fieldName}_corrected');
        logger.d('✅ Using corrected value for $fieldName: ${amounts[fieldName]}');
      } else {
        amounts[fieldName] = candidate.amount;
        appliedPatterns.add('${fieldName}_${candidate.source}');
        logger.d('✅ Selected $fieldName: ${candidate.amount} (source: ${candidate.source}, score: ${candidate.score})');
      }
    }
    
    // 4. 警告をログに記録
    if (consistencyResult.warnings.isNotEmpty) {
      for (final warning in consistencyResult.warnings) {
        logger.w('⚠️ Consistency warning: $warning');
      }
    }
    
    // 5. 要確認フラグをメタデータに追加
    if (consistencyResult.needsVerification) {
      appliedPatterns.add('needs_verification');
      logger.w('⚠️ Receipt needs manual verification');
    }
    
    logger.d('Unified extraction completed. Found amounts: $amounts');
    logger.d('Consistency score: ${consistencyResult.consistencyScore.toStringAsFixed(2)}');
    
    // 6. フォールバック: 整合性チェックで選択されなかったフィールドがあれば計算
    if (!amounts.containsKey('total_amount') &&
        amounts.containsKey('subtotal_amount') &&
        amounts.containsKey('tax_amount')) {
      final computed = (amounts['subtotal_amount']! + amounts['tax_amount']!);
      amounts['total_amount'] = double.parse(computed.toStringAsFixed(2));
      appliedPatterns.add('computed_total_from_subtotal_tax');
      logger.d('✅ Computed TOTAL from subtotal+tax: ${amounts['total_amount']}');
    }
    
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
        final paymentMethod = match.groupCount >= 2 ? match.group(2) : match.group(1);
        if (paymentMethod != null) {
          return PaymentMethod.fromString(paymentMethod);
        }
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

  /// Extract items using structured textLines (with position information)
  List<ReceiptItem> _extractItemsFromTextLines(
    List<TextLine> textLines,
    List<String> appliedPatterns, {
    double? imageWidth,
    double? imageHeight,
  }) {
    final items = <ReceiptItem>[];
    
    // Get image size from first line's bounding box context or use defaults
    double imgWidth = imageWidth ?? 1000.0;
    double imgHeight = imageHeight ?? 1000.0;
    
    // Try to infer image size from bounding boxes if not provided
    if (imageWidth == null || imageHeight == null) {
      double maxX = 0.0;
      double maxY = 0.0;
      for (final line in textLines) {
        if (line.boundingBox != null && line.boundingBox!.length >= 4) {
          final x = line.boundingBox![0];
          final y = line.boundingBox![1];
          final w = line.boundingBox![2];
          final h = line.boundingBox![3];
          maxX = math.max(maxX, x + w);
          maxY = math.max(maxY, y + h);
        }
      }
      if (maxX > 0 && maxY > 0) {
        imgWidth = maxX;
        imgHeight = maxY;
      }
    }
    
    logger.d('📦 Extracting items from ${textLines.length} textLines (image: ${imgWidth.toInt()}x${imgHeight.toInt()})');
    
    // Extract features for each line to identify items
    final itemCandidates = <ItemCandidate>[];
    
    for (int i = 0; i < textLines.length; i++) {
      final line = textLines[i];
      final text = line.text.trim();
      if (text.isEmpty) continue;
      
      // Calculate normalized position
      double xCenter = 0.5;
      double yCenter = 0.5;
      if (line.boundingBox != null && line.boundingBox!.length >= 4) {
        final x = line.boundingBox![0];
        final y = line.boundingBox![1];
        final w = line.boundingBox![2];
        final h = line.boundingBox![3];
        xCenter = (x + w / 2) / imgWidth;
        yCenter = (y + h / 2) / imgHeight;
      }
      
      // Check if this line is likely an item
      final lowerText = text.toLowerCase();
      
      // Exclude obvious non-items
      if (isFooterOrTotals(text) ||
          lowerText.startsWith('date') ||
          lowerText.startsWith('time') ||
          lowerText.startsWith('receipt') ||
          RegExp(r'^\d{1,2}[.\/-]\d{1,2}').hasMatch(text)) {
        continue;
      }
      
      // Check if line contains amount-like pattern
      final amountPattern = RegExp(r'([€\$£¥₹]?)\s*([-]?\d{1,3}(?:[.,]\d{3})*(?:[.,]\d{2})|[-]?\d+(?:[.,]\d{2}))');
      final amountMatch = amountPattern.firstMatch(text);
      
      if (amountMatch != null) {
        // This line likely contains a price
        final priceStr = amountMatch.group(2);
        if (priceStr == null) continue;
        final price = _parseAmount(priceStr);
        
        if (price != null && price > 0) {
          // Extract item name (text before the amount)
          final amountStart = amountMatch.start;
          final itemName = text.substring(0, amountStart).trim();
          
          if (itemName.isNotEmpty && 
              !RegExp(r'\b(total|subtotal|vat|tax|payment)\b', caseSensitive: false).hasMatch(itemName)) {
            
            // Check for quantity markers
            int quantity = 1;
            final quantityPattern = RegExp(r'(\d+)\s*[×x]|[×x]\s*(\d+)|qty[:\s]*(\d+)|quantity[:\s]*(\d+)', caseSensitive: false);
            final qtyMatch = quantityPattern.firstMatch(text);
            if (qtyMatch != null) {
              final qtyStr = qtyMatch.group(1) ?? qtyMatch.group(2) ?? qtyMatch.group(3) ?? qtyMatch.group(4);
              if (qtyStr != null) {
                quantity = int.tryParse(qtyStr) ?? 1;
              }
            }
            
            // Calculate confidence based on position and features
            double confidence = 0.5;
            
            // Boost confidence if in middle section (typical item area)
            if (yCenter >= 0.3 && yCenter <= 0.7) {
              confidence += 0.2;
            }
            
            // Boost confidence if price is on the right side
            if (xCenter > 0.6) {
              confidence += 0.2;
            }
            
            // Boost confidence if has item-like pattern
            if (RegExp(r'[a-zA-Z]{2,}.*?\s+[€\$£¥₹]?\s*\d').hasMatch(text)) {
              confidence += 0.1;
            }
            
            itemCandidates.add(ItemCandidate(
              name: itemName,
              quantity: quantity,
              totalPrice: price,
              lineIndex: i,
              yCenter: yCenter,
              xCenter: xCenter,
              confidence: confidence,
            ));
          }
        }
      } else {
        // No amount found, but might be item name only (price might be on next line or same Y)
        // Check if this line looks like an item name
        if (RegExp(r'^[a-zA-Z][a-zA-Z\s\-\.]{2,}$').hasMatch(text) &&
            yCenter >= 0.3 && yCenter <= 0.7 &&
            !isFooterOrTotals(text)) {
          
          // Look for price on nearby lines (same Y or next line)
          double? nearbyPrice;
          int? nearbyQuantity;
          
          // Check same Y coordinate (horizontal alignment)
          for (int j = 0; j < textLines.length; j++) {
            if (i == j) continue;
            final otherLine = textLines[j];
            if (otherLine.boundingBox != null && otherLine.boundingBox!.length >= 4) {
              final otherY = (otherLine.boundingBox![1] + otherLine.boundingBox![3] / 2) / imgHeight;
              final otherX = (otherLine.boundingBox![0] + otherLine.boundingBox![2] / 2) / imgWidth;
              
              // Same Y coordinate (within tolerance) and on the right
              if ((otherY - yCenter).abs() < 0.02 && otherX > 0.6) {
                final amountMatch = amountPattern.firstMatch(otherLine.text);
                if (amountMatch != null) {
                  final priceStr = amountMatch.group(2);
                  if (priceStr != null) {
                    nearbyPrice = _parseAmount(priceStr);
                    break;
                  }
                }
              }
            }
          }
          
          // If no horizontal match, check next line
          if (nearbyPrice == null && i + 1 < textLines.length) {
            final nextLine = textLines[i + 1];
            final nextAmountMatch = amountPattern.firstMatch(nextLine.text);
            if (nextAmountMatch != null) {
              final priceStr = nextAmountMatch.group(2);
              if (priceStr != null) {
                nearbyPrice = _parseAmount(priceStr);
              }
            }
          }
          
          if (nearbyPrice != null && nearbyPrice! > 0) {
            itemCandidates.add(ItemCandidate(
              name: text,
              quantity: nearbyQuantity ?? 1,
              totalPrice: nearbyPrice!,
              lineIndex: i,
              yCenter: yCenter,
              xCenter: xCenter,
              confidence: 0.4, // Lower confidence for separated name/price
            ));
          }
        }
      }
    }
    
    // Sort candidates by Y position (top to bottom) and filter by confidence
    itemCandidates.sort((a, b) => a.yCenter.compareTo(b.yCenter));
    
    // Filter and create items
    for (final candidate in itemCandidates) {
      if (candidate.confidence >= 0.5) {
        final item = ReceiptItem.create(
          name: candidate.name,
          quantity: candidate.quantity,
          totalPrice: candidate.totalPrice,
          category: ItemCategory.detectCategory(candidate.name),
        );
        items.add(item);
        appliedPatterns.add('item_structured_textlines');
        logger.d('  ✓ Item extracted: "${candidate.name}" (qty: ${candidate.quantity}, price: ${candidate.totalPrice}, conf: ${candidate.confidence.toStringAsFixed(2)})');
      }
    }
    
    logger.d('📦 Structured item extraction completed: ${items.length} items found');
    return items;
  }
  
  /// Estimate image width from textLines bounding boxes
  double? _estimateImageWidth(List<TextLine> textLines) {
    double maxX = 0.0;
    for (final line in textLines) {
      if (line.boundingBox != null && line.boundingBox!.length >= 4) {
        final x = line.boundingBox![0];
        final w = line.boundingBox![2];
        maxX = math.max(maxX, x + w);
      }
    }
    return maxX > 0 ? maxX : null;
  }
  
  /// Estimate image height from textLines bounding boxes
  double? _estimateImageHeight(List<TextLine> textLines) {
    double maxY = 0.0;
    for (final line in textLines) {
      if (line.boundingBox != null && line.boundingBox!.length >= 4) {
        final y = line.boundingBox![1];
        final h = line.boundingBox![3];
        maxY = math.max(maxY, y + h);
      }
    }
    return maxY > 0 ? maxY : null;
  }
  
  /// Check if a line is a footer or totals line
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

  List<ReceiptItem> _extractItems(String text, List<String> appliedPatterns, {List<TextLine>? textLines, double? imageWidth, double? imageHeight}) {
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

      // Extract items first (needed for items sum consistency check)
      List<ReceiptItem> items;
      if (textLines != null && textLines.isNotEmpty) {
        final imageWidth = _estimateImageWidth(textLines);
        final imageHeight = _estimateImageHeight(textLines);
        items = _extractItemsFromTextLines(textLines, appliedPatterns, 
            imageWidth: imageWidth, imageHeight: imageHeight);
        if (items.length < 2) {
          final textItems = _extractItems(ocrText, appliedPatterns);
          if (textItems.length > items.length) {
            items = textItems;
            appliedPatterns.add('item_text_fallback');
          }
        }
      } else {
        items = _extractItems(ocrText, appliedPatterns);
      }
      
      // Use combined lines for amount extraction (with items for consistency check)
      final amounts = _extractAmountsLineByLine(
        combinedLines, 
        detectedLanguage, 
        appliedPatterns,
        textLines: textLines,
        items: items,
      );
      logger.d('Extracted amounts from blocks: $amounts');
      extractedData.addAll(amounts);
      
      // Extract TaxBreakdown (multiple tax rates)
      final taxBreakdownCandidates = _collectTaxBreakdownCandidates(
        combinedLines,
        detectedLanguage,
        appliedPatterns,
        textLines: textLines,
        amountCandidates: {
          'subtotal_amount': amounts.containsKey('subtotal_amount')
              ? [AmountCandidate(
                  amount: amounts['subtotal_amount']!,
                  score: 100,
                  lineIndex: -1,
                  source: 'selected',
                  fieldName: 'subtotal_amount',
                )]
              : [],
        },
      );
      
      if (taxBreakdownCandidates.isNotEmpty) {
        // TaxBreakdownをextractedDataに追加
        final taxBreakdownList = taxBreakdownCandidates.map((candidate) => {
          'rate': candidate.rate,
          'amount': candidate.amount,
        }).toList();
        extractedData['tax_breakdown'] = taxBreakdownList;
        
        // Tax Totalを計算
        final taxTotal = taxBreakdownCandidates
            .map((c) => c.amount)
            .fold(0.0, (sum, amount) => sum + amount);
        extractedData['tax_total'] = double.parse(taxTotal.toStringAsFixed(2));
        
        logger.d('✅ TaxBreakdown extracted: $taxBreakdownList, Tax Total: ${extractedData['tax_total']}');
      }

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

      // Items extraction: prefer structured textLines if available
      // (Note: Items are already extracted above for consistency check, so we just use them)
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
  // Line-Based Candidate Collection (Phase 2)
  // ----------------------------

  /// 行ベースから候補を収集（既存ロジックの拡張）
  Map<String, List<AmountCandidate>> _collectLineBasedCandidates(
    List<String> lines,
    String? language,
    List<String> appliedPatterns, {
    List<TextLine>? textLines,
  }) {
    logger.d('🔍 Collecting line-based candidates from ${lines.length} lines');
    final candidates = <String, List<AmountCandidate>>{
      'total_amount': [],
      'subtotal_amount': [],
      'tax_amount': [],
    };
    
    // TaxBreakdown候補の収集は_collectTaxBreakdownCandidatesで行うため、ここでは削除
    // （重複を避けるため、_collectLineBasedCandidates内でのtaxBreakdownCandidates作成は削除）

    // Extra fallback patterns (template-friendly) - declared early for use
    // Generated dynamically from LanguageKeywords for multi-language support
    final totalLabel = PatternGenerator.generateLabelPattern('total');
    final subtotalLabel = PatternGenerator.generateLabelPattern('subtotal');
    final taxLabel = PatternGenerator.generateLabelPattern('tax');
    logger.d('🔍 Label patterns: total=${totalLabel.pattern}, subtotal=${subtotalLabel.pattern}');
    
    // パーセンテージ情報を保存（後でSubtotalから計算するため）
    final taxPercentageInfo = <({int lineIndex, double percent, List<double>? boundingBox, double? confidence})>[];

    // 金額パターン: 通貨記号（オプション）+ スペース（オプション）+ マイナス（オプション）+ 数字
    // $400, €12.34, 100.00, 1,234.56 などをマッチ
    final amountCapture = RegExp(
      r'([€$£¥₹]?\s*[-]?\d{1,3}(?:[.,]\d{3})*(?:[.,]\d{2})?|[€$£¥₹]?\s*[-]?\d+(?:[.,]\d{2})?)(?:\s|$|[^\d.,€$£¥₹-])',
      caseSensitive: false,
    );

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final lower = line.toLowerCase();

      // Check if line contains subtotal - exclude from total patterns
      final isSubtotalLine = subtotalLabel.hasMatch(lower);

      // 1) Project patterns first (strong signal)
      // Only check total patterns if line is not a subtotal line
      if (!isSubtotalLine) {
        for (int p = 0; p < RegexPatterns.totalPatterns.length; p++) {
          final match = RegexPatterns.totalPatterns[p].firstMatch(line);
          if (match != null) {
            final amountStr = match.groupCount >= 2 ? match.group(2) : match.group(match.groupCount);
            final amount = amountStr == null ? null : _parseAmount(amountStr);
            if (amount != null && amount > 0) {
              candidates['total_amount']!.add(AmountCandidate(
                amount: amount,
                score: 100,
                lineIndex: i,
                source: 'total_pattern_$p',
                fieldName: 'total_amount',
                boundingBox: textLines != null && i < textLines.length
                    ? textLines[i].boundingBox
                    : null,
                confidence: textLines != null && i < textLines.length
                    ? textLines[i].confidence
                    : null,
              ));
            }
          }
        }
      }

      for (int p = 0; p < RegexPatterns.subtotalPatterns.length; p++) {
        final pattern = RegexPatterns.subtotalPatterns[p];
        final match = pattern.firstMatch(line);
        if (match != null) {
          final amountStr = match.groupCount >= 2 ? match.group(2) : match.group(match.groupCount);
          final amount = amountStr == null ? null : _parseAmount(amountStr);
          if (amount != null && amount > 0) {
            candidates['subtotal_amount']!.add(AmountCandidate(
              amount: amount,
              score: 90,
              lineIndex: i,
              source: 'subtotal_pattern_$p',
              fieldName: 'subtotal_amount',
              boundingBox: textLines != null && i < textLines.length
                  ? textLines[i].boundingBox
                  : null,
              confidence: textLines != null && i < textLines.length
                  ? textLines[i].confidence
                  : null,
            ));
          }
        }
      }

      for (int p = 0; p < RegexPatterns.taxPatterns.length; p++) {
        final match = RegexPatterns.taxPatterns[p].firstMatch(line);
        if (match != null) {
          final amountStr = match.groupCount >= 2 ? match.group(2) : match.group(match.groupCount);
          final amount = amountStr == null ? null : _parseAmount(amountStr);
          if (amount != null && amount > 0) {
            candidates['tax_amount']!.add(AmountCandidate(
              amount: amount,
              score: 80,
              lineIndex: i,
              source: 'tax_pattern_$p',
              fieldName: 'tax_amount',
              boundingBox: textLines != null && i < textLines.length
                  ? textLines[i].boundingBox
                  : null,
              confidence: textLines != null && i < textLines.length
                  ? textLines[i].confidence
                  : null,
            ));
          }
        }
      }

      // 2) VAT / TOTAL / SUBTOTAL heuristic (template receipts)
      if (totalLabel.hasMatch(lower)) {
        logger.d('🔍 Line $i matches total label: "$line"');
        final m = amountCapture.allMatches(line).toList();
        if (m.isNotEmpty) {
          final amount = _parseAmount(m.last.group(0)!);
          if (amount != null && amount > 0) {
            final posBonus = (i > (lines.length * 0.6)) ? 10 : 0;
            // 明示的なキーワードマッチは高優先度（items sumより優先）
            logger.d('✅ Adding total candidate: $amount (score: ${95 + posBonus}, line: $i)');
            candidates['total_amount']!.add(AmountCandidate(
              amount: amount,
              score: 95 + posBonus, // 85 → 95に上げる（明示的なマッチを優先）
              lineIndex: i,
              source: 'total_label',
              fieldName: 'total_amount',
              boundingBox: textLines != null && i < textLines.length
                  ? textLines[i].boundingBox
                  : null,
              confidence: textLines != null && i < textLines.length
                  ? textLines[i].confidence
                  : null,
            ));
          } else {
            logger.d('⚠️ Line $i matches total label but amount parsing failed: "$line"');
          }
        } else {
          logger.d('⚠️ Line $i matches total label but no amount found: "$line"');
        }
      }

      if (subtotalLabel.hasMatch(lower)) {
        logger.d('🔍 Line $i matches subtotal label: "$line"');
        final m = amountCapture.allMatches(line).toList();
        logger.d('🔍 Amount matches found: ${m.length}, matches: ${m.map((match) => match.group(0)).toList()}');
        if (m.isNotEmpty) {
          final amountStr = m.last.group(0)!;
          logger.d('🔍 Extracted amount string: "$amountStr"');
          final amount = _parseAmount(amountStr);
          if (amount != null && amount > 0) {
            // 明示的なキーワードマッチは高優先度（items sumより優先）
            logger.d('✅ Adding subtotal candidate: $amount (score: 95, line: $i)');
            candidates['subtotal_amount']!.add(AmountCandidate(
              amount: amount,
              score: 95, // 75 → 95に上げる（明示的なマッチを優先）
              lineIndex: i,
              source: 'subtotal_label',
              fieldName: 'subtotal_amount',
              boundingBox: textLines != null && i < textLines.length
                  ? textLines[i].boundingBox
                  : null,
              confidence: textLines != null && i < textLines.length
                  ? textLines[i].confidence
                  : null,
            ));
          } else {
            logger.d('⚠️ Line $i matches subtotal label but amount parsing failed: "$line", parsed: $amount');
          }
        } else {
          logger.d('⚠️ Line $i matches subtotal label but no amount found: "$line"');
          // フォールバック: より柔軟なパターンで再試行
          final fallbackPattern = RegExp(r'[\$€£¥₹]?\s*(\d{1,3}(?:[.,]\d{3})*(?:[.,]\d{2})?|\d+(?:[.,]\d{2})?)', caseSensitive: false);
          final fallbackMatches = fallbackPattern.allMatches(line).toList();
          logger.d('🔍 Fallback pattern matches: ${fallbackMatches.length}, matches: ${fallbackMatches.map((match) => match.group(0)).toList()}');
          if (fallbackMatches.isNotEmpty) {
            final amountStr = fallbackMatches.last.group(1) ?? fallbackMatches.last.group(0)!;
            logger.d('🔍 Fallback extracted amount string: "$amountStr"');
            final amount = _parseAmount(amountStr);
            if (amount != null && amount > 0) {
              logger.d('✅ Adding subtotal candidate (fallback): $amount (score: 95, line: $i)');
              candidates['subtotal_amount']!.add(AmountCandidate(
                amount: amount,
                score: 95,
                lineIndex: i,
                source: 'subtotal_label_fallback',
                fieldName: 'subtotal_amount',
                boundingBox: textLines != null && i < textLines.length
                    ? textLines[i].boundingBox
                    : null,
                confidence: textLines != null && i < textLines.length
                    ? textLines[i].confidence
                    : null,
              ));
            }
          }
        }
      }

      if (taxLabel.hasMatch(lower)) {
        // 複数のパーセンテージと金額のペアを抽出（例: "Tax 14% 10, Tax 24% 5"）
        final percentPattern = RegExp(r'(\d+(?:[.,]\d+)?)\s*%');
        final allPercentMatches = percentPattern.allMatches(line).toList();
        
        // 金額を抽出（パーセンテージの数字を除外）
        final allAmountMatches = amountCapture.allMatches(line).toList();
        
        logger.d('🔍 Tax line $i: Found ${allPercentMatches.length} percentage matches, ${allAmountMatches.length} amount matches');
        
        // パーセンテージと金額のペアを抽出
        if (allPercentMatches.isNotEmpty && allAmountMatches.isNotEmpty) {
          // 複数のTax rateがある場合（例: "Tax 14% 10, Tax 24% 5"）
          for (final percentMatch in allPercentMatches) {
            final percentStr = percentMatch.group(1)!.replaceAll(',', '.');
            final percent = double.tryParse(percentStr);
            if (percent == null || percent <= 0 || percent > 100) continue;
            
            // このパーセンテージに対応する金額を探す（ハイブリッド方式）
            double? matchedAmount;
            
            // 優先順位1: `:`マークを境界として使用
            final colonIndex = line.indexOf(':');
            if (colonIndex != -1) {
              logger.d('🔍 Using colon (:) as boundary for tax amount extraction');
              for (final amountMatch in allAmountMatches) {
                final matchStart = amountMatch.start;
                if (matchStart > colonIndex) {
                  // `:`の後の金額
                  final amountStr = amountMatch.group(0)!;
                  final amount = _parseAmount(amountStr);
                  if (amount != null && amount > 0) {
                    // パーセンテージの値と一致しないことを確認
                    if ((amount - percent).abs() > 0.1) {
                      matchedAmount = amount;
                      logger.d('✅ Found tax amount after colon: $matchedAmount (percent: $percent%)');
                      break;
                    }
                  }
                }
              }
            }
            
            // 優先順位2: BBOX情報を活用（`: `マークがない場合）
            if (matchedAmount == null && textLines != null && i < textLines.length) {
              final textLine = textLines[i];
              final elements = textLine.elements;
              
              if (elements != null && elements.isNotEmpty) {
                logger.d('🔍 Using BBOX information for tax amount extraction');
                // Taxラベルを含むelementを特定
                int? taxLabelElementIndex;
                for (int j = 0; j < elements.length; j++) {
                  final elementText = elements[j].text.toLowerCase();
                  if (taxLabel.hasMatch(elementText) && percentPattern.hasMatch(elements[j].text)) {
                    // このelementにパーセンテージが含まれているか確認
                    final elementPercentMatch = percentPattern.firstMatch(elements[j].text);
                    if (elementPercentMatch != null) {
                      final elementPercentStr = elementPercentMatch.group(1)!.replaceAll(',', '.');
                      final elementPercent = double.tryParse(elementPercentStr);
                      if (elementPercent != null && (elementPercent - percent).abs() < 0.01) {
                        taxLabelElementIndex = j;
                        logger.d('✅ Found tax label element at index $j with percent $percent%');
                        break;
                      }
                    }
                  }
                }
                
                if (taxLabelElementIndex != null) {
                  final taxLabelBbox = elements[taxLabelElementIndex].boundingBox;
                  if (taxLabelBbox != null && taxLabelBbox.length >= 4) {
                    final taxLabelRightX = taxLabelBbox[0] + taxLabelBbox[2];
                    
                    // Taxラベルの右側にある金額を探す
                    for (int j = taxLabelElementIndex + 1; j < elements.length; j++) {
                      final elementBbox = elements[j].boundingBox;
                      if (elementBbox != null && elementBbox.length >= 4) {
                        final elementLeftX = elementBbox[0];
                        
                        // Taxラベルの右側にある要素
                        if (elementLeftX > taxLabelRightX) {
                          final amountMatch = amountCapture.firstMatch(elements[j].text);
                          if (amountMatch != null) {
                            final amountStr = amountMatch.group(0)!;
                            final amount = _parseAmount(amountStr);
                            if (amount != null && amount > 0) {
                              // パーセンテージの値と一致しないことを確認
                              if ((amount - percent).abs() > 0.1) {
                                matchedAmount = amount;
                                logger.d('✅ Found tax amount using BBOX: $matchedAmount (percent: $percent%, element index: $j)');
                                break;
                              }
                            }
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
            
            // 優先順位3: 既存のロジック（パーセンテージの値を除外）
            if (matchedAmount == null) {
              logger.d('🔍 Using fallback logic (excluding percentage value)');
              for (final amountMatch in allAmountMatches) {
                final amountStr = amountMatch.group(0)!;
                final cleanedAmountStr = amountStr.replaceAll(RegExp(r'[€$£¥₹\s-]'), '');
                final amountValue = double.tryParse(cleanedAmountStr.replaceAll(',', '.'));
                
                // パーセンテージの値と一致する場合はスキップ
                if (amountValue != null && (amountValue - percent).abs() < 0.01) {
                  continue;
                }
                
                final amount = _parseAmount(amountStr);
                if (amount != null && amount > 0) {
                  // パーセンテージの値と一致しないことを確認（より厳密なチェック）
                  if ((amount - percent).abs() > 0.1) {
                    matchedAmount = amount;
                    logger.d('✅ Found tax amount using fallback: $matchedAmount (percent: $percent%)');
                    break;
                  }
                }
              }
            }
            
            // TaxBreakdown候補の収集は_collectTaxBreakdownCandidatesで行うため、ここでは削除
            // （重複を避けるため、_collectLineBasedCandidates内でのtaxBreakdownCandidates作成は削除）
            // ただし、tax_amount候補は引き続き追加する（単一のTax行の場合）
            if (matchedAmount != null) {
              // tax_amount候補として追加（TaxBreakdownではなく）
              logger.d('✅ Adding tax candidate (direct amount): $matchedAmount (score: 70, line: $i)');
              candidates['tax_amount']!.add(AmountCandidate(
                amount: matchedAmount,
                score: 70,
                lineIndex: i,
                source: 'tax_label',
                fieldName: 'tax_amount',
                boundingBox: textLines != null && i < textLines.length
                    ? textLines[i].boundingBox
                    : null,
                confidence: textLines != null && i < textLines.length
                    ? textLines[i].confidence
                    : null,
              ));
            } else if (candidates['subtotal_amount']!.isNotEmpty) {
              // パーセンテージのみの場合、Subtotalから計算してtax_amount候補として追加
              final bestSubtotal = candidates['subtotal_amount']!
                  .reduce((a, b) => a.score > b.score ? a : b);
              final calculatedTax = bestSubtotal.amount * percent / 100.0;
              
              logger.d('✅ Calculated tax from percentage: ${bestSubtotal.amount} × $percent% = $calculatedTax');
              candidates['tax_amount']!.add(AmountCandidate(
                amount: double.parse(calculatedTax.toStringAsFixed(2)),
                score: 75,
                lineIndex: i,
                source: 'tax_label_percentage',
                fieldName: 'tax_amount',
                boundingBox: textLines != null && i < textLines.length
                    ? textLines[i].boundingBox
                    : null,
                confidence: textLines != null && i < textLines.length
                    ? textLines[i].confidence
                    : null,
              ));
            }
          }
        } else {
          // 単一のTax行（既存のロジック）
          final percentMatch = allPercentMatches.isNotEmpty ? allPercentMatches.first : null;
          double? percent;
          if (percentMatch != null) {
            final percentStr = percentMatch.group(1)!.replaceAll(',', '.');
            percent = double.tryParse(percentStr);
            if (percent != null && (percent <= 0 || percent > 100)) {
              percent = null;
            }
          }
          
          // 金額を抽出（ハイブリッド方式: `:`マーク > BBOX情報 > 既存ロジック）
          double? directAmount;
          if (allAmountMatches.isNotEmpty) {
            // 優先順位1: `:`マークを境界として使用
            final colonIndex = line.indexOf(':');
            if (colonIndex != -1) {
              logger.d('🔍 Using colon (:) as boundary for tax amount extraction (single tax line)');
              for (final match in allAmountMatches) {
                final matchStart = match.start;
                if (matchStart > colonIndex) {
                  // `:`の後の金額
                  final amountStr = match.group(0)!;
                  final amount = _parseAmount(amountStr);
                  if (amount != null && amount > 0) {
                    // パーセンテージの値と一致しないことを確認
                    if (percent == null || (amount - percent).abs() > 0.1) {
                      directAmount = amount;
                      logger.d('✅ Found tax amount after colon: $directAmount (percent: $percent%)');
                      break;
                    }
                  }
                }
              }
            }
            
            // 優先順位2: BBOX情報を活用（`: `マークがない場合）
            if (directAmount == null && textLines != null && i < textLines.length) {
              final textLine = textLines[i];
              final elements = textLine.elements;
              
              if (elements != null && elements.isNotEmpty) {
                logger.d('🔍 Using BBOX information for tax amount extraction (single tax line)');
                // Taxラベルを含むelementを特定
                int? taxLabelElementIndex;
                for (int j = 0; j < elements.length; j++) {
                  if (taxLabel.hasMatch(elements[j].text.toLowerCase())) {
                    taxLabelElementIndex = j;
                    logger.d('✅ Found tax label element at index $j');
                    break;
                  }
                }
                
                if (taxLabelElementIndex != null) {
                  final taxLabelBbox = elements[taxLabelElementIndex].boundingBox;
                  if (taxLabelBbox != null && taxLabelBbox.length >= 4) {
                    final taxLabelRightX = taxLabelBbox[0] + taxLabelBbox[2];
                    
                    // Taxラベルの右側にある金額を探す
                    for (int j = taxLabelElementIndex + 1; j < elements.length; j++) {
                      final elementBbox = elements[j].boundingBox;
                      if (elementBbox != null && elementBbox.length >= 4) {
                        final elementLeftX = elementBbox[0];
                        
                        // Taxラベルの右側にある要素
                        if (elementLeftX > taxLabelRightX) {
                          final amountMatch = amountCapture.firstMatch(elements[j].text);
                          if (amountMatch != null) {
                            final amountStr = amountMatch.group(0)!;
                            final amount = _parseAmount(amountStr);
                            if (amount != null && amount > 0) {
                              // パーセンテージの値と一致しないことを確認
                              if (percent == null || (amount - percent).abs() > 0.1) {
                                directAmount = amount;
                                logger.d('✅ Found tax amount using BBOX: $directAmount (percent: $percent%, element index: $j)');
                                break;
                              }
                            }
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
            
            // 優先順位3: 既存のロジック（パーセンテージの値を除外）
            if (directAmount == null) {
              logger.d('🔍 Using fallback logic (excluding percentage value) (single tax line)');
              for (final match in allAmountMatches.reversed) {
                final amountStr = match.group(0)!;
                
                // パーセンテージの数字を除外
                if (percentMatch != null) {
                  final percentValueStr = percentMatch.group(1)!.replaceAll(',', '.');
                  final percentValue = double.tryParse(percentValueStr);
                  
                  final cleanedAmountStr = amountStr.replaceAll(RegExp(r'[€$£¥₹\s-]'), '');
                  final amountValue = double.tryParse(cleanedAmountStr.replaceAll(',', '.'));
                  
                  if (amountValue != null && percentValue != null && 
                      (amountValue - percentValue).abs() < 0.01) {
                    continue;
                  }
                  
                  if (cleanedAmountStr == percentValueStr) {
                    continue;
                  }
                }
                
                final amount = _parseAmount(amountStr);
                if (amount != null && amount > 0) {
                  if (percentMatch != null) {
                    final percentValue = double.tryParse(percentMatch.group(1)!.replaceAll(',', '.'));
                    if (percentValue != null && (amount - percentValue).abs() > 0.1) {
                      directAmount = amount;
                      logger.d('✅ Found tax amount using fallback: $directAmount (percent: $percentValue%)');
                      break;
                    }
                  } else {
                    directAmount = amount;
                    logger.d('✅ Found tax amount using fallback: $directAmount');
                    break;
                  }
                }
              }
            }
          }
          
          // 優先順位: 金額 > パーセンテージ
          if (directAmount != null) {
            // 金額が直接記載されている場合（優先）
            logger.d('✅ Adding tax candidate (direct amount): $directAmount (score: 70, line: $i)');
            candidates['tax_amount']!.add(AmountCandidate(
              amount: directAmount,
              score: 70,
              lineIndex: i,
              source: 'tax_label',
              fieldName: 'tax_amount',
              boundingBox: textLines != null && i < textLines.length
                  ? textLines[i].boundingBox
                  : null,
              confidence: textLines != null && i < textLines.length
                  ? textLines[i].confidence
                  : null,
            ));
          } else if (percent != null && percent > 0) {
            // パーセンテージのみの場合、Subtotalから計算
            logger.d('🔍 Line $i contains tax percentage only: $percent%');
            
            if (candidates['subtotal_amount']!.isNotEmpty) {
              final bestSubtotal = candidates['subtotal_amount']!
                  .reduce((a, b) => a.score > b.score ? a : b);
              final calculatedTax = bestSubtotal.amount * percent / 100.0;
              
              logger.d('✅ Calculated tax from percentage: ${bestSubtotal.amount} × $percent% = $calculatedTax');
              candidates['tax_amount']!.add(AmountCandidate(
                amount: double.parse(calculatedTax.toStringAsFixed(2)),
                score: 75,
                lineIndex: i,
                source: 'tax_label_percentage',
                fieldName: 'tax_amount',
                boundingBox: textLines != null && i < textLines.length
                    ? textLines[i].boundingBox
                    : null,
                confidence: textLines != null && i < textLines.length
                    ? textLines[i].confidence
                    : null,
              ));
            } else {
              logger.d('🔍 Tax percentage found but no subtotal candidate yet, saving for later: $percent%');
              taxPercentageInfo.add((
                lineIndex: i,
                percent: percent,
                boundingBox: textLines != null && i < textLines.length
                    ? textLines[i].boundingBox
                    : null,
                confidence: textLines != null && i < textLines.length
                    ? textLines[i].confidence
                    : null,
              ));
            }
          }
        }
      }
    }

    // 位置情報によるスコアボーナスを適用
    _applyPositionBonuses(
      candidates['total_amount']!,
      candidates['subtotal_amount']!,
      candidates['tax_amount']!,
      lines.length,
    );
    
    // パーセンテージ情報からTax額を計算（Subtotal候補がある場合）
    if (taxPercentageInfo.isNotEmpty && candidates['subtotal_amount']!.isNotEmpty) {
      // 最も信頼度の高いSubtotal候補を使用
      final bestSubtotal = candidates['subtotal_amount']!
          .reduce((a, b) => a.score > b.score ? a : b);
      
      for (final percentageInfo in taxPercentageInfo) {
        final calculatedTax = bestSubtotal.amount * percentageInfo.percent / 100.0;
        
        logger.d('✅ Calculated tax from percentage (post-processing): ${bestSubtotal.amount} × ${percentageInfo.percent}% = $calculatedTax');
        candidates['tax_amount']!.add(AmountCandidate(
          amount: double.parse(calculatedTax.toStringAsFixed(2)),
          score: 75, // パーセンテージから計算した場合は少し低めのスコア
          lineIndex: percentageInfo.lineIndex,
          source: 'tax_label_percentage',
          fieldName: 'tax_amount',
          boundingBox: percentageInfo.boundingBox,
          confidence: percentageInfo.confidence,
        ));
      }
    }

    logger.d('🔍 Line-based candidates collected: total=${candidates['total_amount']!.length}, subtotal=${candidates['subtotal_amount']!.length}, tax=${candidates['tax_amount']!.length}');
    for (final candidate in candidates['total_amount']!) {
      logger.d('  Total candidate: ${candidate.amount} (score: ${candidate.score}, source: ${candidate.source}, line: ${candidate.lineIndex})');
    }
    for (final candidate in candidates['subtotal_amount']!) {
      logger.d('  Subtotal candidate: ${candidate.amount} (score: ${candidate.score}, source: ${candidate.source}, line: ${candidate.lineIndex})');
    }
    for (final candidate in candidates['tax_amount']!) {
      logger.d('  Tax candidate: ${candidate.amount} (score: ${candidate.score}, source: ${candidate.source}, line: ${candidate.lineIndex})');
    }

    // TaxBreakdown候補の収集は_collectTaxBreakdownCandidatesで行うため、ここでは返さない
    return candidates;
  }
  
  /// TaxBreakdown候補を収集（ハイブリッド方式を使用）
  List<TaxBreakdownCandidate> _collectTaxBreakdownCandidates(
    List<String> lines,
    String? language,
    List<String> appliedPatterns, {
    List<TextLine>? textLines,
    Map<String, List<AmountCandidate>>? amountCandidates,
  }) {
    final taxBreakdownCandidates = <TaxBreakdownCandidate>[];
    final taxLabel = PatternGenerator.generateLabelPattern('tax');
    final percentPattern = RegExp(r'(\d+(?:[.,]\d+)?)\s*%');
    final amountCapture = RegExp(
      r'([€$£¥₹]?\s*[-]?\d{1,3}(?:[.,]\d{3})*(?:[.,]\d{2})?|[€$£¥₹]?\s*[-]?\d+(?:[.,]\d{2})?)(?:\s|$|[^\d.,€$£¥₹-])',
      caseSensitive: false,
    );
    
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final lower = line.toLowerCase();
      
      if (taxLabel.hasMatch(lower)) {
        final allPercentMatches = percentPattern.allMatches(line).toList();
        final allAmountMatches = amountCapture.allMatches(line).toList();
        
        if (allPercentMatches.isNotEmpty && allAmountMatches.isNotEmpty) {
          for (final percentMatch in allPercentMatches) {
            final percentStr = percentMatch.group(1)!.replaceAll(',', '.');
            final percent = double.tryParse(percentStr);
            if (percent == null || percent <= 0 || percent > 100) continue;
            
            double? matchedAmount;
            
            // 優先順位1: `:`マークを境界として使用
            final colonIndex = line.indexOf(':');
            if (colonIndex != -1) {
              logger.d('🔍 Using colon (:) as boundary for tax breakdown extraction (line $i)');
              for (final amountMatch in allAmountMatches) {
                final matchStart = amountMatch.start;
                if (matchStart > colonIndex) {
                  // `:`の後の金額
                  final amountStr = amountMatch.group(0)!;
                  final amount = _parseAmount(amountStr);
                  if (amount != null && amount > 0) {
                    // パーセンテージの値と一致しないことを確認
                    if ((amount - percent).abs() > 0.1) {
                      matchedAmount = amount;
                      logger.d('✅ Found tax breakdown amount after colon: $matchedAmount (percent: $percent%)');
                      break;
                    }
                  }
                }
              }
            }
            
            // 優先順位2: BBOX情報を活用（`: `マークがない場合）
            if (matchedAmount == null && textLines != null && i < textLines.length) {
              final textLine = textLines[i];
              final elements = textLine.elements;
              
              if (elements != null && elements.isNotEmpty) {
                logger.d('🔍 Using BBOX information for tax breakdown extraction (line $i)');
                // Taxラベルを含むelementを特定
                int? taxLabelElementIndex;
                for (int j = 0; j < elements.length; j++) {
                  final elementText = elements[j].text.toLowerCase();
                  if (taxLabel.hasMatch(elementText) && percentPattern.hasMatch(elements[j].text)) {
                    // このelementにパーセンテージが含まれているか確認
                    final elementPercentMatch = percentPattern.firstMatch(elements[j].text);
                    if (elementPercentMatch != null) {
                      final elementPercentStr = elementPercentMatch.group(1)!.replaceAll(',', '.');
                      final elementPercent = double.tryParse(elementPercentStr);
                      if (elementPercent != null && (elementPercent - percent).abs() < 0.01) {
                        taxLabelElementIndex = j;
                        logger.d('✅ Found tax label element at index $j with percent $percent%');
                        break;
                      }
                    }
                  }
                }
                
                if (taxLabelElementIndex != null) {
                  final taxLabelBbox = elements[taxLabelElementIndex].boundingBox;
                  if (taxLabelBbox != null && taxLabelBbox.length >= 4) {
                    final taxLabelRightX = taxLabelBbox[0] + taxLabelBbox[2];
                    
                    // Taxラベルの右側にある金額を探す
                    for (int j = taxLabelElementIndex + 1; j < elements.length; j++) {
                      final elementBbox = elements[j].boundingBox;
                      if (elementBbox != null && elementBbox.length >= 4) {
                        final elementLeftX = elementBbox[0];
                        
                        // Taxラベルの右側にある要素
                        if (elementLeftX > taxLabelRightX) {
                          final amountMatch = amountCapture.firstMatch(elements[j].text);
                          if (amountMatch != null) {
                            final amountStr = amountMatch.group(0)!;
                            final amount = _parseAmount(amountStr);
                            if (amount != null && amount > 0) {
                              // パーセンテージの値と一致しないことを確認
                              if ((amount - percent).abs() > 0.1) {
                                matchedAmount = amount;
                                logger.d('✅ Found tax breakdown amount using BBOX: $matchedAmount (percent: $percent%, element index: $j)');
                                break;
                              }
                            }
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
            
            // 優先順位3: 既存のロジック（パーセンテージの値を除外）
            if (matchedAmount == null) {
              logger.d('🔍 Using fallback logic for tax breakdown (excluding percentage value) (line $i)');
              for (final amountMatch in allAmountMatches) {
                final amountStr = amountMatch.group(0)!;
                final cleanedAmountStr = amountStr.replaceAll(RegExp(r'[€$£¥₹\s-]'), '');
                final amountValue = double.tryParse(cleanedAmountStr.replaceAll(',', '.'));
                
                // パーセンテージの値と一致する場合はスキップ
                if (amountValue != null && (amountValue - percent).abs() < 0.01) {
                  continue;
                }
                
                final amount = _parseAmount(amountStr);
                if (amount != null && amount > 0) {
                  // パーセンテージの値と一致しないことを確認（より厳密なチェック）
                  if ((amount - percent).abs() > 0.1) {
                    matchedAmount = amount;
                    logger.d('✅ Found tax breakdown amount using fallback: $matchedAmount (percent: $percent%)');
                    break;
                  }
                }
              }
            }
            
            if (matchedAmount != null) {
              taxBreakdownCandidates.add(TaxBreakdownCandidate(
                rate: percent,
                amount: matchedAmount,
                lineIndex: i,
                score: 80,
                source: 'tax_label_with_rate',
                boundingBox: textLines != null && i < textLines.length
                    ? textLines[i].boundingBox
                    : null,
                confidence: textLines != null && i < textLines.length
                    ? textLines[i].confidence
                    : null,
              ));
            } else if (amountCandidates?['subtotal_amount']?.isNotEmpty == true) {
              final bestSubtotal = amountCandidates!['subtotal_amount']!
                  .reduce((a, b) => a.score > b.score ? a : b);
              final calculatedTax = bestSubtotal.amount * percent / 100.0;
              
              logger.d('✅ Calculated tax breakdown from percentage: ${percent}% = $calculatedTax (from subtotal: ${bestSubtotal.amount})');
              taxBreakdownCandidates.add(TaxBreakdownCandidate(
                rate: percent,
                amount: double.parse(calculatedTax.toStringAsFixed(2)),
                lineIndex: i,
                score: 75,
                source: 'tax_label_percentage_calculated',
                boundingBox: textLines != null && i < textLines.length
                    ? textLines[i].boundingBox
                    : null,
                confidence: textLines != null && i < textLines.length
                    ? textLines[i].confidence
                    : null,
              ));
            }
          }
        }
      }
    }
    
    return taxBreakdownCandidates;
  }

  // ----------------------------
  // Unified Candidate Collection (Phase 3)
  // ----------------------------

  /// すべての候補を統合収集
  Map<String, FieldCandidates> _collectAllCandidates(
    List<String> lines,
    String? language,
    List<String> appliedPatterns, {
    List<TextLine>? textLines,
    List<ReceiptItem>? items,
  }) {
    // 1. テーブル候補を収集
    final tableCandidates = _collectTableCandidates(
      lines,
      textLines,
      appliedPatterns,
    );
    
    // 2. 行ベース候補を収集
    final lineBasedCandidates = _collectLineBasedCandidates(
      lines,
      language,
      appliedPatterns,
      textLines: textLines,
    );
    
    // 3. アイテム合計からの候補を収集（一時的に無効化）
    // TODO: ItemSumの候補収集を一時的に無効化（Item検出が不安定なため）
    // final itemsSumCandidates = _collectItemsSumCandidates(items, appliedPatterns);
    final itemsSumCandidates = <AmountCandidate>[];
    
    // 4. 統合
    final allCandidates = <String, List<AmountCandidate>>{
      'total_amount': [],
      'subtotal_amount': [],
      'tax_amount': [],
    };
    
    // テーブル候補を追加
    for (final candidate in tableCandidates) {
      allCandidates[candidate.fieldName]!.add(candidate);
    }
    
    // 行ベース候補を追加
    for (final fieldName in lineBasedCandidates.keys) {
      allCandidates[fieldName]!.addAll(lineBasedCandidates[fieldName]!);
    }
    
    // アイテム合計候補を追加
    for (final candidate in itemsSumCandidates) {
      allCandidates[candidate.fieldName]!.add(candidate);
    }
    
    // 5. 重複候補の処理（同じ金額の候補は統合またはスコア調整）
    _mergeDuplicateCandidates(allCandidates);
    
    // 6. FieldCandidatesに変換
    return {
      'total_amount': FieldCandidates(
        fieldName: 'total_amount',
        candidates: allCandidates['total_amount']!,
      ),
      'subtotal_amount': FieldCandidates(
        fieldName: 'subtotal_amount',
        candidates: allCandidates['subtotal_amount']!,
      ),
      'tax_amount': FieldCandidates(
        fieldName: 'tax_amount',
        candidates: allCandidates['tax_amount']!,
      ),
    };
  }
  
  /// Calculate sum of all items
  double? _calculateItemsSum(List<ReceiptItem>? items) {
    if (items == null || items.isEmpty) {
      return null;
    }
    
    double sum = 0.0;
    for (final item in items) {
      sum += item.totalPrice;
    }
    
    return sum > 0 ? double.parse(sum.toStringAsFixed(2)) : null;
  }
  
  /// Collect candidates from items sum
  List<AmountCandidate> _collectItemsSumCandidates(
    List<ReceiptItem>? items,
    List<String> appliedPatterns,
  ) {
    final candidates = <AmountCandidate>[];
    
    if (items == null || items.isEmpty) {
      return candidates;
    }
    
    final itemsSum = _calculateItemsSum(items);
    if (itemsSum == null || itemsSum <= 0) {
      return candidates;
    }
    
    // Calculate score based on items
    final score = _calculateItemsSumScore(items);
    
    logger.d('💰 Items sum calculated: $itemsSum (${items.length} items, score: $score)');
    
    // Add as Subtotal candidate
    candidates.add(AmountCandidate(
      amount: itemsSum,
      score: score,
      lineIndex: -1, // Items sum doesn't have a specific line
      source: 'items_sum_subtotal',
      fieldName: 'subtotal_amount',
      label: 'Items Sum',
    ));
    appliedPatterns.add('items_sum_subtotal_candidate');
    
    // Add as Total candidate (if no tax is detected, items sum might be the total)
    // This will be evaluated in consistency check
    candidates.add(AmountCandidate(
      amount: itemsSum,
      score: score - 10, // Slightly lower score for total (prefer explicit total labels)
      lineIndex: -1,
      source: 'items_sum_total',
      fieldName: 'total_amount',
      label: 'Items Sum (as Total)',
    ));
    appliedPatterns.add('items_sum_total_candidate');
    
    return candidates;
  }
  
  /// Calculate confidence score for items sum
  int _calculateItemsSumScore(List<ReceiptItem> items) {
    if (items.isEmpty) return 0;
    
    // Base score
    int score = 60;
    
    // Bonus for having multiple items
    if (items.length >= 3) {
      score += 10;
    }
    if (items.length >= 5) {
      score += 10;
    }
    
    // Bonus if all items have totalPrice
    final allHavePrice = items.every((item) => item.totalPrice > 0);
    if (allHavePrice) {
      score += 10;
    }
    
    return score.clamp(0, 100);
  }

  /// 重複候補の統合
  void _mergeDuplicateCandidates(
    Map<String, List<AmountCandidate>> candidates,
  ) {
    for (final fieldName in candidates.keys) {
      final fieldCandidates = candidates[fieldName]!;
      final merged = <double, AmountCandidate>{};
      
      for (final candidate in fieldCandidates) {
        final key = candidate.amount;
        if (merged.containsKey(key)) {
          // 既存の候補と統合（スコアを高い方に）
          final existing = merged[key]!;
          if (candidate.score > existing.score) {
            merged[key] = candidate;
          }
          // ソース情報を更新（複数ソースから検出されたことを記録）
          // 注: sourceは変更できないため、スコアで反映
        } else {
          merged[key] = candidate;
        }
      }
      
      // スコアでソート（高い順）
      final sorted = merged.values.toList();
      sorted.sort((a, b) => b.score.compareTo(a.score));
      
      candidates[fieldName] = sorted;
    }
  }

  // ----------------------------
  // Consistency Checking (Step 2)
  // ----------------------------

  /// 整合性チェックと最適解の選択
  ConsistencyResult _selectBestCandidates(
    Map<String, FieldCandidates> allCandidates, {
    double? itemsSum,
    int? itemsCount,
  }) {
    // 各フィールドの上位候補を取得（最大3つ）
    // ただし、明示的なマッチがある場合は、items sumの候補を除外
    var totalCandidates = allCandidates['total_amount']?.getTopN(3) ?? [];
    var subtotalCandidates = allCandidates['subtotal_amount']?.getTopN(3) ?? [];
    var taxCandidates = allCandidates['tax_amount']?.getTopN(3) ?? [];
    
    // 明示的なラベルマッチ（subtotal_label, total_label, tax_label等）をチェック
    final hasExplicitSubtotalLabel = subtotalCandidates.any((c) => c.source == 'subtotal_label');
    final hasExplicitTotalLabel = totalCandidates.any((c) => c.source == 'total_label');
    final hasExplicitTaxLabel = taxCandidates.any((c) => 
      c.source.startsWith('tax_label') || c.source.startsWith('tax_pattern')
    );
    
    // 明示的なラベルマッチが存在する場合、テーブル抽出の候補を除外
    if (hasExplicitSubtotalLabel || hasExplicitTotalLabel || hasExplicitTaxLabel) {
      subtotalCandidates = subtotalCandidates.where((c) => !c.source.startsWith('table_extraction')).toList();
      totalCandidates = totalCandidates.where((c) => !c.source.startsWith('table_extraction')).toList();
      taxCandidates = taxCandidates.where((c) => !c.source.startsWith('table_extraction')).toList();
      logger.d('🔍 Filtered table extraction candidates (explicit label matches found)');
    }
    
    // 明示的なマッチがある場合、items sumの候補を除外
    final hasExplicitTotal = totalCandidates.any((c) => c.source.startsWith('total_') || c.source.startsWith('table_extraction'));
    final hasExplicitSubtotal = subtotalCandidates.any((c) => c.source.startsWith('subtotal_') || c.source.startsWith('table_extraction'));
    
    if (hasExplicitSubtotal) {
      // 明示的なSubtotalがある場合、items sumの候補を除外
      subtotalCandidates = subtotalCandidates.where((c) => !c.source.startsWith('items_sum')).toList();
      logger.d('🔍 Filtered subtotal candidates: removed items_sum candidates (explicit match found)');
    }
    
    if (hasExplicitTotal) {
      // 明示的なTotalがある場合、items sumから計算された候補を除外（ただし、明示的なSubtotalがない場合は残す）
      if (hasExplicitSubtotal) {
        totalCandidates = totalCandidates.where((c) => !c.source.startsWith('items_sum')).toList();
        logger.d('🔍 Filtered total candidates: removed items_sum candidates (explicit matches found)');
      }
    }

    // 候補が少ない場合はそのまま返す
    if (totalCandidates.isEmpty && subtotalCandidates.isEmpty && taxCandidates.isEmpty) {
      return ConsistencyResult(
        selectedCandidates: {},
        consistencyScore: 0.0,
        warnings: ['No candidates found'],
        needsVerification: true,
        itemsSum: itemsSum,
        itemsCount: itemsCount,
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
              itemsSum: itemsSum,
            );
            
            // 明示的なキーワードマッチの候補にボーナスを追加
            // これにより、items sumから計算された候補よりも優先される
            // Taxがない場合でも、明示的なTotal/Subtotalの組み合わせを優先
            int explicitMatchCount = 0;
            if (total != null && (total.source.startsWith('total_') || total.source.startsWith('table_extraction'))) {
              explicitMatchCount++;
            }
            if (subtotal != null && (subtotal.source.startsWith('subtotal_') || subtotal.source.startsWith('table_extraction'))) {
              explicitMatchCount++;
            }
            if (tax != null && (tax.source.startsWith('tax_') || tax.source.startsWith('table_extraction'))) {
              explicitMatchCount++;
            }
            
            // 複数の明示的なマッチがある場合、より大きなボーナス
            if (explicitMatchCount >= 2) {
              score += 0.20; // 2つ以上の明示的なマッチに大きなボーナス
              logger.d('✅ Explicit match bonus: $explicitMatchCount explicit matches (+0.20)');
            } else if (explicitMatchCount == 1) {
              score += 0.15; // 1つの明示的なマッチに中程度のボーナス
              logger.d('✅ Explicit match bonus: 1 explicit match (+0.15)');
            }
          } else {
            // 1つだけの場合は候補のスコアを正規化（0.0-1.0）
            final singleCandidate = total ?? subtotal ?? tax;
            score = singleCandidate != null ? (singleCandidate.score / 100.0) : 0.0;
            
            // 明示的なキーワードマッチの場合は追加ボーナス
            if (singleCandidate != null && 
                (singleCandidate.source.startsWith('total_') || 
                 singleCandidate.source.startsWith('subtotal_') || 
                 singleCandidate.source.startsWith('tax_') ||
                 singleCandidate.source.startsWith('table_extraction'))) {
              score += 0.10;
            }
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
    
    // アイテム合計との整合性チェック（一時的に無効化）
    bool? itemsSumMatchesSubtotal;
    bool? itemsSumMatchesTotal;
    // TODO: ItemSumの整合性チェックを一時的に無効化（Item検出が不安定なため）
    // if (itemsSum != null) {
    //   if (bestSelection.containsKey('subtotal_amount')) {
    //     final subtotal = bestSelection['subtotal_amount']!.amount;
    //     final difference = (itemsSum - subtotal).abs();
    //     itemsSumMatchesSubtotal = difference <= 0.01;
    //     if (difference > 0.01) {
    //       warnings.add('Items sum ($itemsSum) != Subtotal ($subtotal), diff: ${difference.toStringAsFixed(2)}');
    //     }
    //   }
    //   
    //   if (bestSelection.containsKey('total_amount')) {
    //     final total = bestSelection['total_amount']!.amount;
    //     final difference = (itemsSum - total).abs();
    //     itemsSumMatchesTotal = difference <= 0.01;
    //     if (difference > 0.01) {
    //       // Check if itemsSum + tax matches total
    //       if (bestSelection.containsKey('tax_amount')) {
    //         final tax = bestSelection['tax_amount']!.amount;
    //         final expectedTotal = itemsSum + tax;
    //         final totalDiff = (total - expectedTotal).abs();
    //         if (totalDiff <= 0.01) {
    //           itemsSumMatchesTotal = true;
    //         } else {
    //           warnings.add('Items sum + Tax ($expectedTotal) != Total ($total), diff: ${totalDiff.toStringAsFixed(2)}');
    //         }
    //       } else {
    //         warnings.add('Items sum ($itemsSum) != Total ($total), diff: ${difference.toStringAsFixed(2)}');
    //       }
    //     }
    //   }
    // }
    
    // ログ出力
    logger.d('🔍 Consistency check: ${bestSelection.length} fields selected, score: ${bestScore.toStringAsFixed(2)}');
    if (itemsSum != null) {
      logger.d('  Items sum: $itemsSum (${itemsSumMatchesSubtotal != null ? (itemsSumMatchesSubtotal! ? '✓ matches subtotal' : '✗ differs from subtotal') : 'N/A'})');
    }
    for (final entry in bestSelection.entries) {
      logger.d('  Selected ${entry.key}: ${entry.value.amount} (score: ${entry.value.score}, line: ${entry.value.lineIndex})');
    }

    // 矛盾検知と自動修正
    Map<String, double>? correctedValues;
    
    // Auto-correction based on items sum（一時的に無効化）
    // TODO: ItemSumの自動修正を一時的に無効化（Item検出が不安定なため）
    // ただし、明示的なキーワードマッチがある場合は修正しない（明示的な値を優先）
    if (false && itemsSum != null && itemsSum > 0) {
      if (bestSelection.containsKey('subtotal_amount')) {
        final subtotalCandidate = bestSelection['subtotal_amount']!;
        final subtotal = subtotalCandidate.amount;
        final difference = (itemsSum - subtotal).abs();
        final relativeDifference = itemsSum > 0 ? difference / itemsSum : 0.0;
        
        // 明示的なキーワードマッチがある場合は修正しない
        final hasExplicitMatch = subtotalCandidate.source.startsWith('subtotal_') || 
                                 subtotalCandidate.source.startsWith('table_extraction');
        
        // 10セント以内の差で、かつ明示的なマッチがない場合のみ修正
        if (!hasExplicitMatch && difference <= 0.10 && difference > 0.01) {
          correctedValues ??= {};
          correctedValues['subtotal_amount'] = double.parse(itemsSum.toStringAsFixed(2));
          warnings.add('Auto-corrected Subtotal: $subtotal → $itemsSum (based on items sum)');
          logger.d('✅ Auto-corrected Subtotal based on items sum: $subtotal → $itemsSum');
        } else if (hasExplicitMatch && relativeDifference > 0.10) {
          logger.d('⚠️ Keeping explicit Subtotal ($subtotal) despite items sum difference ($itemsSum, ${(relativeDifference * 100).toStringAsFixed(1)}%)');
        }
      }
      
      if (bestSelection.containsKey('tax_amount') && bestSelection.containsKey('total_amount')) {
        final totalCandidate = bestSelection['total_amount']!;
        final tax = bestSelection['tax_amount']!.amount;
        final total = totalCandidate.amount;
        final expectedTotal = itemsSum + tax;
        final difference = (total - expectedTotal).abs();
        final relativeDifference = expectedTotal > 0 ? difference / expectedTotal : 0.0;
        
        // 明示的なキーワードマッチがある場合は修正しない
        final hasExplicitMatch = totalCandidate.source.startsWith('total_') || 
                                 totalCandidate.source.startsWith('table_extraction');
        
        // 10セント以内の差で、かつ明示的なマッチがない場合のみ修正
        if (!hasExplicitMatch && difference <= 0.10 && difference > 0.01) {
          correctedValues ??= {};
          correctedValues['total_amount'] = double.parse(expectedTotal.toStringAsFixed(2));
          warnings.add('Auto-corrected Total: $total → $expectedTotal (based on items sum + tax)');
          logger.d('✅ Auto-corrected Total based on items sum + tax: $total → $expectedTotal');
        } else if (hasExplicitMatch && relativeDifference > 0.10) {
          logger.d('⚠️ Keeping explicit Total ($total) despite items sum + tax difference ($expectedTotal, ${(relativeDifference * 100).toStringAsFixed(1)}%)');
        }
      }
    }
    
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
      itemsSum: itemsSum,
      itemsCount: itemsCount,
      itemsSumMatchesSubtotal: itemsSumMatchesSubtotal,
      itemsSumMatchesTotal: itemsSumMatchesTotal,
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

  // ----------------------------
  // Table Candidate Collection (Phase 1)
  // ----------------------------

  /// テーブルから候補を収集
  List<AmountCandidate> _collectTableCandidates(
    List<String> lines,
    List<TextLine>? textLines,
    List<String> appliedPatterns,
  ) {
    final candidates = <AmountCandidate>[];
    
    // テーブル検出（既存メソッドを使用）
    final tableAmounts = _extractAmountsFromTable(
      lines,
      appliedPatterns,
      textLines: textLines,
    );
    
    if (tableAmounts.isEmpty) {
      logger.d('📊 No table detected, skipping table candidate collection');
      return candidates;
    }
    
    logger.d('📊 Table detected, converting to candidates: $tableAmounts');
    
    // テーブルから抽出された値を候補に変換
    // テーブル抽出は構造的に信頼度が高いため、スコアを高く設定
    if (tableAmounts.containsKey('total_amount')) {
      candidates.add(AmountCandidate(
        amount: tableAmounts['total_amount']!,
        score: 95,  // テーブル抽出は高信頼度
        lineIndex: -1,  // テーブル行は複数行にまたがる可能性
        source: 'table_extraction_total',
        fieldName: 'total_amount',
        boundingBox: null,  // テーブル全体の位置情報は複雑なため省略
        confidence: 1.0,  // テーブル抽出は構造的に信頼度が高い
      ));
      logger.d('📊 Added table candidate: total_amount=${tableAmounts['total_amount']}');
    }
    
    if (tableAmounts.containsKey('subtotal_amount')) {
      candidates.add(AmountCandidate(
        amount: tableAmounts['subtotal_amount']!,
        score: 95,
        lineIndex: -1,
        source: 'table_extraction_subtotal',
        fieldName: 'subtotal_amount',
        boundingBox: null,
        confidence: 1.0,
      ));
      logger.d('📊 Added table candidate: subtotal_amount=${tableAmounts['subtotal_amount']}');
    }
    
    if (tableAmounts.containsKey('tax_amount')) {
      candidates.add(AmountCandidate(
        amount: tableAmounts['tax_amount']!,
        score: 95,
        lineIndex: -1,
        source: 'table_extraction_tax',
        fieldName: 'tax_amount',
        boundingBox: null,
        confidence: 1.0,
      ));
      logger.d('📊 Added table candidate: tax_amount=${tableAmounts['tax_amount']}');
    }
    
    return candidates;
  }

  /// 整合性スコアの計算
  double _calculateConsistencyScore({
    AmountCandidate? total,
    AmountCandidate? subtotal,
    AmountCandidate? tax,
    double? itemsSum,
  }) {
    double score = 0.0;

    // 1. 基本的な整合性チェック（最重要）
    if (total != null && subtotal != null && tax != null) {
      // 3つすべてがある場合：subtotal + tax == total
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
    } else if (total != null && subtotal != null && tax == null) {
      // Taxがない場合でも、total - subtotal でTaxを推定して整合性チェック
      final estimatedTax = total.amount - subtotal.amount;
      // Taxが正の値で合理的な範囲内（0-50%程度）の場合、整合性があると判断
      if (estimatedTax >= 0 && estimatedTax <= subtotal.amount * 0.5) {
        // 明示的なキーワードマッチがある場合は高スコア
        final hasExplicitTotal = total.source.startsWith('total_') || total.source.startsWith('table_extraction');
        final hasExplicitSubtotal = subtotal.source.startsWith('subtotal_') || subtotal.source.startsWith('table_extraction');
        
        if (hasExplicitTotal && hasExplicitSubtotal) {
          // 明示的なマッチがある場合、高スコア（Taxが検出されていなくても整合性がある）
          score += 0.4; // Taxがある場合の0.5より少し低いが、十分高い
          logger.d('✅ Subtotal + estimated Tax matches Total: ${subtotal.amount} + $estimatedTax ≈ ${total.amount} (+0.4, explicit match)');
        } else {
          // 明示的なマッチがない場合、中程度のスコア
          score += 0.2;
          logger.d('✅ Subtotal + estimated Tax matches Total: ${subtotal.amount} + $estimatedTax ≈ ${total.amount} (+0.2)');
        }
      } else if (estimatedTax < 0) {
        // Total < Subtotal の場合は矛盾（ただし、明示的なマッチがあれば許容）
        final hasExplicitTotal = total.source.startsWith('total_') || total.source.startsWith('table_extraction');
        final hasExplicitSubtotal = subtotal.source.startsWith('subtotal_') || subtotal.source.startsWith('table_extraction');
        if (hasExplicitTotal && hasExplicitSubtotal) {
          // 明示的なマッチがある場合、小さなスコア（データが矛盾している可能性があるが、明示的な値なので優先）
          score += 0.1;
          logger.d('⚠️ Total < Subtotal, but explicit match found: ${total.amount} < ${subtotal.amount} (+0.1)');
        }
      }
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

    // 5. テーブル抽出の信頼度ボーナス（新規）
    int tableSourceCount = 0;
    if (total?.source.startsWith('table_extraction') == true) tableSourceCount++;
    if (subtotal?.source.startsWith('table_extraction') == true) tableSourceCount++;
    if (tax?.source.startsWith('table_extraction') == true) tableSourceCount++;
    
    // テーブルから複数のフィールドが検出された場合、ボーナス
    if (tableSourceCount >= 2) {
      score += 0.05;  // テーブル抽出の整合性ボーナス
      logger.d('📊 Table extraction bonus: $tableSourceCount fields from table (+0.05)');
    }
    
    // 6. アイテム合計との整合性チェック（一時的に無効化）
    // TODO: ItemSumの整合性チェックを一時的に無効化（Item検出が不安定なため）
    // ただし、明示的なキーワードマッチがある場合は優先度を下げる
    if (false && itemsSum != null && itemsSum > 0) {
      // 明示的なキーワードマッチかどうかをチェック
      final hasExplicitSubtotal = subtotal?.source.startsWith('subtotal_') == true || 
                                   subtotal?.source.startsWith('total_pattern') == true;
      final hasExplicitTotal = total?.source.startsWith('total_') == true || 
                               total?.source.startsWith('total_pattern') == true;
      
      // Items sum と Subtotal の整合性
      if (subtotal != null) {
        final difference = (itemsSum - subtotal.amount).abs();
        final relativeDifference = itemsSum > 0 ? difference / itemsSum : 0.0;
        
        // 明示的なキーワードマッチがあり、items sumとの差が10%以上ある場合は無視
        if (hasExplicitSubtotal && relativeDifference > 0.10) {
          logger.d('💰 Ignoring items sum for Subtotal: explicit match (${subtotal.amount}) differs significantly from items sum ($itemsSum, ${(relativeDifference * 100).toStringAsFixed(1)}%)');
        } else if (difference <= 0.01) {
          // 完全一致または1セント以内
          score += 0.15;
          logger.d('💰 Items sum matches Subtotal: $itemsSum == ${subtotal.amount} (+0.15)');
        } else if (difference <= 0.10) {
          // 10セント以内
          score += 0.10;
          logger.d('💰 Items sum close to Subtotal: $itemsSum vs ${subtotal.amount}, diff: ${difference.toStringAsFixed(2)} (+0.10)');
        }
      }
      
      // Items sum + Tax と Total の整合性
      if (tax != null && total != null) {
        final expectedTotal = itemsSum + tax.amount;
        final difference = (total.amount - expectedTotal).abs();
        final relativeDifference = expectedTotal > 0 ? difference / expectedTotal : 0.0;
        
        // 明示的なキーワードマッチがあり、items sumとの差が10%以上ある場合は無視
        if (hasExplicitTotal && relativeDifference > 0.10) {
          logger.d('💰 Ignoring items sum for Total: explicit match (${total.amount}) differs significantly from items sum + tax ($expectedTotal, ${(relativeDifference * 100).toStringAsFixed(1)}%)');
        } else if (difference <= 0.01) {
          // 完全一致または1セント以内
          score += 0.15;
          logger.d('💰 Items sum + Tax matches Total: $itemsSum + ${tax.amount} == ${total.amount} (+0.15)');
        } else if (difference <= 0.10) {
          // 10セント以内
          score += 0.10;
          logger.d('💰 Items sum + Tax close to Total: $expectedTotal vs ${total.amount}, diff: ${difference.toStringAsFixed(2)} (+0.10)');
        }
      }
      
      // Items sum と Total の整合性（Taxが検出されていない場合）
      if (tax == null && total != null) {
        final difference = (itemsSum - total.amount).abs();
        final relativeDifference = itemsSum > 0 ? difference / itemsSum : 0.0;
        
        // 明示的なキーワードマッチがあり、items sumとの差が10%以上ある場合は無視
        if (hasExplicitTotal && relativeDifference > 0.10) {
          logger.d('💰 Ignoring items sum for Total: explicit match (${total.amount}) differs significantly from items sum ($itemsSum, ${(relativeDifference * 100).toStringAsFixed(1)}%)');
        } else if (difference <= 0.01) {
          score += 0.10;
          logger.d('💰 Items sum matches Total (no tax): $itemsSum == ${total.amount} (+0.10)');
        } else if (difference <= 0.10) {
          score += 0.05;
          logger.d('💰 Items sum close to Total (no tax): $itemsSum vs ${total.amount}, diff: ${difference.toStringAsFixed(2)} (+0.05)');
        }
      }
    }

    return score.clamp(0.0, 1.0);
  }
}
