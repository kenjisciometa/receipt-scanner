import '../constants/language_keywords.dart';

/// Features extracted from a TextLine for ML model input
/// These features are used for sequence labeling (NER-style) classification
class TextLineFeatures {
  const TextLineFeatures({
    // Position features (normalized 0-1)
    required this.xCenter,
    required this.yCenter,
    required this.width,
    required this.height,
    
    // Position flags
    required this.isRightSide,
    required this.isBottomArea,
    required this.isMiddleSection,
    required this.lineIndexNorm,
    
    // Text features
    required this.hasCurrencySymbol,
    required this.hasPercent,
    required this.hasAmountLike,
    required this.hasTotalKeyword,
    required this.hasTaxKeyword,
    required this.hasSubtotalKeyword,
    required this.hasDateLike,
    required this.hasQuantityMarker,
    required this.hasItemLike,
    required this.digitCount,
    required this.alphaCount,
    required this.containsColon,
  });

  /// Normalized X center position (0.0 - 1.0)
  final double xCenter;
  
  /// Normalized Y center position (0.0 - 1.0)
  final double yCenter;
  
  /// Normalized width (0.0 - 1.0)
  final double width;
  
  /// Normalized height (0.0 - 1.0)
  final double height;
  
  /// Whether the line is on the right side (x_center > 0.65)
  final bool isRightSide;
  
  /// Whether the line is in the bottom area (y_center > 0.7)
  final bool isBottomArea;
  
  /// Whether the line is in the middle section (0.3 <= y_center <= 0.7)
  final bool isMiddleSection;
  
  /// Normalized line index (line_index / total_lines)
  final double lineIndexNorm;
  
  /// Whether the line contains a currency symbol (€, £, kr, EUR, etc.)
  final bool hasCurrencySymbol;
  
  /// Whether the line contains a percent symbol (%)
  final bool hasPercent;
  
  /// Whether the line contains an amount-like pattern (12.34, 12,34, etc.)
  final bool hasAmountLike;
  
  /// Whether the line contains total keywords (total, sum, yhteensä, etc.)
  final bool hasTotalKeyword;
  
  /// Whether the line contains tax keywords (vat, tax, mwst, etc.)
  final bool hasTaxKeyword;
  
  /// Whether the line contains subtotal keywords (subtotal, zwischensumme, etc.)
  final bool hasSubtotalKeyword;
  
  /// Whether the line contains a date-like pattern
  final bool hasDateLike;
  
  /// Whether the line contains quantity markers (×, x, QTY, quantity, etc.)
  final bool hasQuantityMarker;
  
  /// Whether the line looks like an item (text + space + amount pattern)
  final bool hasItemLike;
  
  /// Number of digits in the line
  final int digitCount;
  
  /// Number of alphabetic characters in the line
  final int alphaCount;
  
  /// Whether the line contains a colon
  final bool containsColon;
  
  /// Convert features to a list of numerical values for ML model input
  List<double> toFeatureVector() {
    return [
      // Position features (4)
      xCenter,
      yCenter,
      width,
      height,
      
      // Position flags (4)
      isRightSide ? 1.0 : 0.0,
      isBottomArea ? 1.0 : 0.0,
      isMiddleSection ? 1.0 : 0.0,
      lineIndexNorm,
      
      // Text features (13)
      hasCurrencySymbol ? 1.0 : 0.0,
      hasPercent ? 1.0 : 0.0,
      hasAmountLike ? 1.0 : 0.0,
      hasTotalKeyword ? 1.0 : 0.0,
      hasTaxKeyword ? 1.0 : 0.0,
      hasSubtotalKeyword ? 1.0 : 0.0,
      hasDateLike ? 1.0 : 0.0,
      hasQuantityMarker ? 1.0 : 0.0,
      hasItemLike ? 1.0 : 0.0,
      digitCount / 100.0, // Normalize to 0-1 range (assuming max 100 digits)
      alphaCount / 100.0, // Normalize to 0-1 range (assuming max 100 chars)
      containsColon ? 1.0 : 0.0,
    ];
  }
  
  @override
  String toString() {
    return 'TextLineFeatures(x:${xCenter.toStringAsFixed(2)}, y:${yCenter.toStringAsFixed(2)}, '
        'right:$isRightSide, bottom:$isBottomArea, middle:$isMiddleSection, '
        'currency:$hasCurrencySymbol, amount:$hasAmountLike, total:$hasTotalKeyword)';
  }
}

/// Utility class for extracting features from TextLine
class TextLineFeatureExtractor {
  /// Extract features from a TextLine
  static TextLineFeatures extractFeatures({
    required String text,
    required List<double>? boundingBox,
    required int lineIndex,
    required int totalLines,
    required double imageWidth,
    required double imageHeight,
  }) {
    // Normalize bounding box coordinates
    double xCenter = 0.5;
    double yCenter = 0.5;
    double width = 0.0;
    double height = 0.0;
    
    if (boundingBox != null && boundingBox.length >= 4) {
      final x = boundingBox[0];
      final y = boundingBox[1];
      final w = boundingBox[2];
      final h = boundingBox[3];
      
      // Normalize to 0-1 range
      xCenter = (x + w / 2) / imageWidth;
      yCenter = (y + h / 2) / imageHeight;
      width = w / imageWidth;
      height = h / imageHeight;
    }
    
    // Position flags
    final isRightSide = xCenter > 0.65;
    final isBottomArea = yCenter > 0.7;
    final isMiddleSection = yCenter >= 0.3 && yCenter <= 0.7;
    final lineIndexNorm = totalLines > 0 ? lineIndex / totalLines : 0.0;
    
    // Text features
    final lowerText = text.toLowerCase();
    final hasCurrencySymbol = _hasCurrencySymbol(text);
    final hasPercent = text.contains('%');
    final hasAmountLike = _hasAmountLike(text);
    final hasTotalKeyword = _hasTotalKeyword(lowerText);
    final hasTaxKeyword = _hasTaxKeyword(lowerText);
    final hasSubtotalKeyword = _hasSubtotalKeyword(lowerText);
    final hasDateLike = _hasDateLike(text);
    final hasQuantityMarker = _hasQuantityMarker(text);
    final hasItemLike = _hasItemLike(text);
    final digitCount = text.split('').where((c) => c.contains(RegExp(r'\d'))).length;
    final alphaCount = text.split('').where((c) => c.contains(RegExp(r'[a-zA-Z]'))).length;
    final containsColon = text.contains(':');
    
    return TextLineFeatures(
      xCenter: xCenter,
      yCenter: yCenter,
      width: width,
      height: height,
      isRightSide: isRightSide,
      isBottomArea: isBottomArea,
      isMiddleSection: isMiddleSection,
      lineIndexNorm: lineIndexNorm,
      hasCurrencySymbol: hasCurrencySymbol,
      hasPercent: hasPercent,
      hasAmountLike: hasAmountLike,
      hasTotalKeyword: hasTotalKeyword,
      hasTaxKeyword: hasTaxKeyword,
      hasSubtotalKeyword: hasSubtotalKeyword,
      hasDateLike: hasDateLike,
      hasQuantityMarker: hasQuantityMarker,
      hasItemLike: hasItemLike,
      digitCount: digitCount,
      alphaCount: alphaCount,
      containsColon: containsColon,
    );
  }
  
  static bool _hasCurrencySymbol(String text) {
    return RegExp(r'[€\$£¥₹]|EUR|USD|GBP|SEK|NOK|DKK|CHF', caseSensitive: false).hasMatch(text);
  }
  
  static bool _hasAmountLike(String text) {
    // Pattern: 12.34, 12,34, 1 234,56, etc.
    return RegExp(r'\d{1,3}(?:[.,]\d{3})*(?:[.,]\d{2})|\d+(?:[.,]\d{2})').hasMatch(text);
  }
  
  static bool _hasTotalKeyword(String lowerText) {
    final keywords = LanguageKeywords.getAllKeywords('total');
    return keywords.any((keyword) => lowerText.contains(keyword.toLowerCase()));
  }
  
  static bool _hasTaxKeyword(String lowerText) {
    final keywords = LanguageKeywords.getAllKeywords('tax');
    return keywords.any((keyword) => lowerText.contains(keyword.toLowerCase()));
  }
  
  static bool _hasSubtotalKeyword(String lowerText) {
    final keywords = LanguageKeywords.getAllKeywords('subtotal');
    return keywords.any((keyword) => lowerText.contains(keyword.toLowerCase()));
  }
  
  static bool _hasDateLike(String text) {
    // Pattern: DD/MM/YYYY, DD.MM.YYYY, YYYY-MM-DD, etc.
    return RegExp(r'\d{1,2}[.\/-]\d{1,2}[.\/-]\d{2,4}|\d{4}[.\/-]\d{1,2}[.\/-]\d{1,2}').hasMatch(text);
  }
  
  static bool _hasQuantityMarker(String text) {
    // Pattern: ×2, x2, QTY: 2, quantity: 2, etc.
    return RegExp(r'\d+\s*[×x]|[×x]\s*\d+|qty[:\s]*\d+|quantity[:\s]*\d+', caseSensitive: false).hasMatch(text);
  }
  
  static bool _hasItemLike(String text) {
    // Pattern: text + space + amount (simple heuristic)
    // More sophisticated pattern: at least 2 alphabetic chars, space, then amount
    final itemPattern = RegExp(r'[a-zA-Z]{2,}.*?\s+[€\$£¥₹]?\s*\d{1,3}(?:[.,]\d{3})*(?:[.,]\d{2})|\d+(?:[.,]\d{2})');
    return itemPattern.hasMatch(text) && 
           !RegExp(r'\b(total|subtotal|vat|tax|payment)\b', caseSensitive: false).hasMatch(text);
  }
}

