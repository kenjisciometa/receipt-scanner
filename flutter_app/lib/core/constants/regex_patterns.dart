import 'pattern_generator.dart';

/// Regular expression patterns for receipt data extraction
/// Supports multiple European languages: Finnish, Swedish, French, German, Italian, Spanish
/// 
/// This class now uses PatternGenerator for dynamic pattern generation from LanguageKeywords.
/// Patterns are cached for performance.
class RegexPatterns {
  
  // ========== AMOUNT PATTERNS ==========
  
  // Cached patterns (generated on first access)
  static List<RegExp>? _cachedTotalPatterns;
  static List<RegExp>? _cachedSubtotalPatterns;
  static List<RegExp>? _cachedTaxPatterns;
  static List<RegExp>? _cachedPaymentMethodPatterns;
  static List<RegExp>? _cachedReceiptNumberPatterns;
  
  /// Clear all cached patterns (useful for testing or after LanguageKeywords updates)
  static void clearCache() {
    _cachedTotalPatterns = null;
    _cachedSubtotalPatterns = null;
    _cachedTaxPatterns = null;
    _cachedPaymentMethodPatterns = null;
    _cachedReceiptNumberPatterns = null;
  }
  
  /// Total amount patterns for all supported languages
  /// Generated dynamically from LanguageKeywords
  static List<RegExp> get totalPatterns {
    _cachedTotalPatterns ??= PatternGenerator.generateAmountPatterns(
      category: 'total',
    );
    return _cachedTotalPatterns!;
  }
  
  /// Subtotal amount patterns for all supported languages
  /// Generated dynamically from LanguageKeywords
  static List<RegExp> get subtotalPatterns {
    _cachedSubtotalPatterns ??= PatternGenerator.generateAmountPatterns(
      category: 'subtotal',
    );
    return _cachedSubtotalPatterns!;
  }
  
  // Legacy patterns removed - now generated dynamically
  // Old patterns are preserved in git history if needed
  static final List<RegExp> _legacySubtotalPatterns = [
    // Legacy patterns - kept for reference
  ];
  
  // ========== TAX PATTERNS ==========
  
  /// Tax/VAT patterns for all supported languages
  /// Generated dynamically from LanguageKeywords with percentage support
  static List<RegExp> get taxPatterns {
    _cachedTaxPatterns ??= PatternGenerator.generateTaxPatterns();
    return _cachedTaxPatterns!;
  }
  
  // Legacy patterns removed - now generated dynamically
  static final List<RegExp> _legacyTaxPatterns = [
    // Legacy patterns - kept for reference
  ];
  
  // ========== DATE PATTERNS ==========
  
  /// Date patterns for various European formats
  /// IMPORTANT: Order matters! More specific patterns (YYYY-MM-DD) should come first
  static final List<RegExp> datePatterns = [
    // YYYY-MM-DD, YYYY/MM/DD, YYYY.MM.DD (prioritize 4-digit year first)
    RegExp(r'(\d{4})[.\/-](\d{1,2})[.\/-](\d{1,2})', multiLine: true),
    
    // DD.MM.YYYY, DD/MM/YYYY, DD-MM-YYYY (4-digit year)
    RegExp(r'(\d{1,2})[.\/-](\d{1,2})[.\/-](\d{4})', multiLine: true),
    
    // DD.MM.YYYY, DD/MM/YYYY, DD-MM-YYYY (2-4 digit year - check last)
    RegExp(r'(\d{1,2})[.\/-](\d{1,2})[.\/-](\d{2,4})', multiLine: true),
    
    // Finnish date format
    RegExp(r'(\d{1,2})\.(\d{1,2})\.(\d{4})', multiLine: true),
    
    // Swedish date format
    RegExp(r'(\d{4})-(\d{1,2})-(\d{1,2})', multiLine: true),
    
    // French date format (DD/MM/YYYY)
    RegExp(r'(\d{1,2})\/(\d{1,2})\/(\d{4})', multiLine: true),
    
    // German date format (DD.MM.YYYY)
    RegExp(r'(\d{1,2})\.(\d{1,2})\.(\d{4})', multiLine: true),
    
    // Time patterns
    RegExp(r'(\d{1,2}):(\d{2})(?::(\d{2}))?', multiLine: true),
  ];
  
  // ========== PAYMENT METHOD PATTERNS ==========
  
  /// Payment method patterns for all supported languages
  /// Generated dynamically from LanguageKeywords
  static List<RegExp> get paymentMethodPatterns {
    _cachedPaymentMethodPatterns ??= PatternGenerator.generatePaymentMethodPatterns();
    return _cachedPaymentMethodPatterns!;
  }
  
  // Legacy patterns removed - now generated dynamically
  static final List<RegExp> _legacyPaymentMethodPatterns = [
    // Legacy patterns - kept for reference
  ];
  
  // ========== MERCHANT NAME PATTERNS ==========
  
  /// Merchant name patterns (usually at the top of receipt)
  static final List<RegExp> merchantPatterns = [
    // General patterns for business names
    RegExp(r'^[A-Z][a-zA-Z ]{2,40}$', multiLine: true),
    
    // Patterns with common business suffixes
    RegExp(r'([a-zA-Z ]+) (AB|Oy|Ltd|Inc|GmbH|SARL|SRL|SL)', multiLine: true),
    
    // Store/shop patterns  
    RegExp(r'store|shop|market|supermarket|kauppa|magasin|geschaeft|negozio|tienda', multiLine: true, caseSensitive: false),
  ];
  
  // ========== CURRENCY PATTERNS ==========
  
  /// Currency symbol and code patterns
  static final List<RegExp> currencyPatterns = [
    // Currency symbols
    RegExp(r'[€\$£¥₹kr]', multiLine: true),
    
    // Currency codes
    RegExp(r'\b(EUR|USD|GBP|SEK|NOK|DKK|CHF)\b', multiLine: true),
  ];
  
  // ========== ITEM LINE PATTERNS ==========
  
  /// Receipt item line patterns
  static final List<RegExp> itemLinePatterns = [
    // Pattern: Item name + quantity + price
    RegExp(r'^([A-Za-z0-9\s\-\.]+)\s+(\d+)\s*[×x]\s*([€\$£¥₹kr]?[\d,]+[.,]?\d*)\s*([€\$£¥₹kr]?[\d,]+[.,]?\d*)$', multiLine: true),
    
    // Pattern: Item name + price only
    RegExp(r'^([A-Za-z0-9\s\-\.]+)\s+([€\$£¥₹kr]?[\d,]+[.,]\d{1,2})$', multiLine: true),
  ];
  
  // ========== UTILITY PATTERNS ==========
  
  /// General number extraction
  static final RegExp numberPattern = RegExp(r'[\d,]+[.,]?\d*');
  
  /// Amount extraction with optional currency
  static final RegExp amountPattern = RegExp(r'([€\$£¥₹kr]?)\s*([\d,\s]+[.,]\d{1,2})');
  
  /// Receipt number patterns for all supported languages
  /// Generated dynamically from LanguageKeywords
  static List<RegExp> get receiptNumberPatterns {
    _cachedReceiptNumberPatterns ??= PatternGenerator.generateReceiptNumberPatterns();
    return _cachedReceiptNumberPatterns!;
  }
  
  // Legacy patterns removed - now generated dynamically
  static final List<RegExp> _legacyReceiptNumberPatterns = [
    // Legacy patterns - kept for reference
  ];
}