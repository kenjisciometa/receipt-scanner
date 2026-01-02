import 'dart:core';
import 'language_keywords.dart';

/// Pattern generator for creating regex patterns from language keywords
class PatternGenerator {
  /// Generate amount patterns (for Total, Subtotal, Tax)
  /// 
  /// [category] - Category name ('total', 'subtotal', 'tax')
  /// [specificLanguages] - Optional list of language codes to include
  /// [amountPattern] - Pattern for matching amounts
  /// [currencyPattern] - Pattern for matching currency symbols
  static List<RegExp> generateAmountPatterns({
    required String category,
    List<String>? specificLanguages,
    String amountPattern = r'([-]?\d{1,3}(?:[.,]\d{3})*(?:[.,]\d{2})|[-]?\d+(?:[.,]\d{2}))', // Match amounts like 12.58, 1,234.56, etc.
    String currencyPattern = r'[€\$£¥₹kr]?',
  }) {
    final keywords = specificLanguages != null
        ? LanguageKeywords.getKeywordsForLanguages(category, specificLanguages)
        : LanguageKeywords.getAllKeywords(category);

    if (keywords.isEmpty) {
      return [];
    }

    // Escape special regex characters in keywords
    final escapedKeywords = keywords.map((k) => RegExp.escape(k)).join('|');

    return [
      // Pattern 1: "Keyword: €12.34" or "Keyword €12.34" format (currency optional, space optional)
      // Matches: "Subtotal: €12.58", "Subtotal €12.58", "Välisumma: €12.58"
      RegExp(
        '($escapedKeywords)[:\\s]*$currencyPattern?\\s*$amountPattern',
        multiLine: true,
        caseSensitive: false,
      ),
      // Pattern 2: "Keyword: €12.34" format (currency directly before amount, no space)
      RegExp(
        '($escapedKeywords)[:\\s]*$currencyPattern$amountPattern',
        multiLine: true,
        caseSensitive: false,
      ),
      // Pattern 3: "Keyword: € 12.34" format (with space after currency, explicit colon)
      RegExp(
        '($escapedKeywords):\\s*$currencyPattern\\s*$amountPattern',
        multiLine: true,
        caseSensitive: false,
      ),
      // Pattern 4: "Keyword                €12.34" format (spaced layout, currency optional)
      RegExp(
        '($escapedKeywords):\\s*$currencyPattern?$amountPattern',
        multiLine: true,
        caseSensitive: false,
      ),
    ];
  }

  /// Generate tax patterns with percentage support
  static List<RegExp> generateTaxPatterns({
    List<String>? specificLanguages,
  }) {
    final taxKeywords = specificLanguages != null
        ? LanguageKeywords.getKeywordsForLanguages('tax', specificLanguages)
        : LanguageKeywords.getAllKeywords('tax');

    if (taxKeywords.isEmpty) {
      return [];
    }

    final escapedKeywords = taxKeywords.map((k) => RegExp.escape(k)).join('|');
    final amountPattern = r'([-]?\d{1,3}(?:[.,]\d{3})*(?:[.,]\d{2})|[-]?\d+(?:[.,]\d{2}))'; // Match amounts like 3.02, 1,234.56, etc.
    final currencyPattern = r'[€\$£¥₹kr]?';

    return [
      // Pattern 1: "VAT: €3.02" or "ALV: €3.02"
      RegExp(
        '\\b($escapedKeywords)\\b[:\\s]*$currencyPattern\\s*$amountPattern',
        multiLine: true,
        caseSensitive: false,
      ),
      // Pattern 2: "VAT 24%: €3.02" or "ALV 24%: €3.02"
      RegExp(
        '\\b($escapedKeywords)\\b\\s+\\d+%[:\\s]*$currencyPattern\\s*$amountPattern',
        multiLine: true,
        caseSensitive: false,
      ),
      // Pattern 3: "24% VAT: €3.02" or "24% ALV: €3.02"
      RegExp(
        '\\d+%.*\\b($escapedKeywords)\\b[:\\s]*$currencyPattern\\s*$amountPattern',
        multiLine: true,
        caseSensitive: false,
      ),
    ];
  }

  /// Generate payment method patterns
  static List<RegExp> generatePaymentMethodPatterns() {
    final paymentKeywords = LanguageKeywords.getAllKeywords('payment');
    final cashKeywords = LanguageKeywords.getAllKeywords('payment_method_cash');
    final cardKeywords = LanguageKeywords.getAllKeywords('payment_method_card');

    final escapedPayment = paymentKeywords.map((k) => RegExp.escape(k)).join('|');
    final escapedCash = cashKeywords.map((k) => RegExp.escape(k)).join('|');
    final escapedCard = cardKeywords.map((k) => RegExp.escape(k)).join('|');

    return [
      // Explicit payment method pattern: "Payment: CARD" or "Maksutapa: KORTTI" or "Maksutapa KORTTI" (no colon)
      RegExp(
        '\\b($escapedPayment)\\s*[:\\-]?\\s*($escapedCash|$escapedCard|cash|card|credit|debit|visa|mastercard|maestro|kortti|kort|karte|carta|tarjeta)\\b',
        caseSensitive: false,
      ),
      // Card pattern (standalone or after payment keyword)
      RegExp(
        '\\b($escapedCard|card|credit|debit|visa|mastercard|maestro|kortti|kort|karte|carta|tarjeta)\\b',
        caseSensitive: false,
      ),
      // Cash pattern
      RegExp(
        '\\b($escapedCash|cash|contant|käteinen|kontanter|espèces|bar|contanti|efectivo)\\b',
        caseSensitive: false,
      ),
      // Digital payment patterns
      RegExp(
        '\\b(paypal|apple pay|google pay|contactless|nfc|mobile|digital|online)\\b',
        caseSensitive: false,
      ),
    ];
  }

  /// Generate receipt number patterns
  static List<RegExp> generateReceiptNumberPatterns() {
    final receiptKeywords = LanguageKeywords.getAllKeywords('receipt');
    final escapedReceipt = receiptKeywords.map((k) => RegExp.escape(k)).join('|');

    return [
      // Pattern 1: "Receipt #: 001234" or "Kuitti nro: 001234"
      RegExp(
        '\\b($escapedReceipt)\\s*#?\\s*(?:nro|nr|no|number)?\\s*[:\\-]?\\s*([A-Za-z0-9\\-]+)\\b',
        caseSensitive: false,
      ),
      // Pattern 2: "Invoice #: 001234"
      RegExp(
        '\\b(invoice|faktura|facture|fattura)\\s*#?\\s*[:\\-]?\\s*([A-Za-z0-9\\-]+)\\b',
        caseSensitive: false,
      ),
      // Pattern 3: "#001234"
      RegExp(r'#(\d{3,})'),
    ];
  }

  /// Generate label detection pattern (for totalLabel, subtotalLabel, etc.)
  /// Used for simple keyword matching without amount extraction
  static RegExp generateLabelPattern(String category) {
    final keywords = LanguageKeywords.getAllKeywords(category);
    if (keywords.isEmpty) {
      // Return a pattern that never matches
      return RegExp(r'(?!.*)');
    }
    final escapedKeywords = keywords.map((k) => RegExp.escape(k)).join('|');
    return RegExp(
      '\\b($escapedKeywords)\\b',
      caseSensitive: false,
    );
  }

  /// Generate combined label pattern for multiple categories
  /// Useful for detecting any of multiple categories (e.g., total or subtotal)
  static RegExp generateCombinedLabelPattern(List<String> categories) {
    final allKeywords = <String>{};
    for (final category in categories) {
      allKeywords.addAll(LanguageKeywords.getAllKeywords(category));
    }
    if (allKeywords.isEmpty) {
      return RegExp(r'(?!.*)');
    }
    final escapedKeywords = allKeywords.map((k) => RegExp.escape(k)).join('|');
    return RegExp(
      '\\b($escapedKeywords)\\b',
      caseSensitive: false,
    );
  }
}

