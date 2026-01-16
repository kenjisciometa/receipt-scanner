import 'package:json_annotation/json_annotation.dart';
import 'package:uuid/uuid.dart';
import 'receipt_item.dart';
import 'tax_breakdown.dart';

part 'receipt.g.dart';

/// Enumeration for receipt processing status
enum ReceiptStatus {
  @JsonValue('pending')
  pending,
  
  @JsonValue('processing')
  processing,
  
  @JsonValue('completed')
  completed,
  
  @JsonValue('failed')
  failed,
  
  @JsonValue('needs_verification')
  needsVerification,
}

/// Enumeration for supported currencies
enum Currency {
  @JsonValue('EUR')
  eur('EUR', '€', 'Euro'),
  
  @JsonValue('SEK')
  sek('SEK', 'kr', 'Swedish Krona'),
  
  @JsonValue('NOK')
  nok('NOK', 'kr', 'Norwegian Krone'),
  
  @JsonValue('DKK')
  dkk('DKK', 'kr', 'Danish Krone'),
  
  @JsonValue('USD')
  usd('USD', '\$', 'US Dollar'),
  
  @JsonValue('GBP')
  gbp('GBP', '£', 'British Pound');
  
  const Currency(this.code, this.symbol, this.name);
  
  final String code;
  final String symbol;
  final String name;
  
  static Currency fromCode(String code) {
    return Currency.values.firstWhere(
      (currency) => currency.code == code.toUpperCase(),
      orElse: () => Currency.eur,
    );
  }
}

/// Enumeration for payment methods
enum PaymentMethod {
  @JsonValue('cash')
  cash('Cash'),
  
  @JsonValue('credit_card')
  creditCard('Credit Card'),
  
  @JsonValue('debit_card')
  debitCard('Debit Card'),
  
  @JsonValue('card')
  card('Card'),
  
  @JsonValue('mobile_payment')
  mobilePayment('Mobile Payment'),
  
  @JsonValue('contactless')
  contactless('Contactless'),
  
  @JsonValue('bank_transfer')
  bankTransfer('Bank Transfer'),
  
  @JsonValue('unknown')
  unknown('Unknown');
  
  const PaymentMethod(this.displayName);
  
  final String displayName;
  
  static PaymentMethod fromString(String? value) {
    if (value == null) return PaymentMethod.unknown;

    final lowerValue = value.toLowerCase();

    // Check cash keywords (multi-language)
    const cashKeywords = ['cash', 'käteinen', 'kontanter', 'espèces', 'bar', 'contanti', 'efectivo', 'contant'];
    for (final keyword in cashKeywords) {
      if (lowerValue.contains(keyword)) {
        return PaymentMethod.cash;
      }
    }

    // Check credit card
    if (lowerValue.contains('credit') || lowerValue.contains('kredit')) {
      return PaymentMethod.creditCard;
    }

    // Check debit card
    if (lowerValue.contains('debit')) {
      return PaymentMethod.debitCard;
    }

    // Check mobile payment
    if (lowerValue.contains('mobile') || lowerValue.contains('app') ||
        lowerValue.contains('paypal') || lowerValue.contains('apple pay')) {
      return PaymentMethod.mobilePayment;
    }

    // Check contactless
    if (lowerValue.contains('contactless') || lowerValue.contains('nfc')) {
      return PaymentMethod.contactless;
    }

    // Check card keywords (multi-language)
    const cardKeywords = ['card', 'kortti', 'kort', 'carte', 'karte', 'carta', 'tarjeta'];
    for (final keyword in cardKeywords) {
      if (lowerValue.contains(keyword)) {
        return PaymentMethod.card;
      }
    }

    return PaymentMethod.unknown;
  }
}

/// Main receipt data model
@JsonSerializable(explicitToJson: true)
class Receipt {
  const Receipt({
    required this.id,
    required this.originalImagePath,
    this.processedImagePath,
    this.rawOcrText,
    this.merchantName,
    this.purchaseDate,
    this.totalAmount,
    this.subtotalAmount,
    this.taxAmount,
    this.taxBreakdown = const [],
    this.taxTotal,
    this.documentType,
    this.paymentMethod,
    this.currency = Currency.eur,
    this.items = const [],
    this.confidence = 0.0,
    this.detectedLanguage,
    required this.createdAt,
    this.modifiedAt,
    this.status = ReceiptStatus.pending,
    this.isVerified = false,
    this.receiptNumber,
    this.notes,
  });

  /// Unique identifier for the receipt
  final String id;
  
  /// Path to the original captured/imported image
  final String originalImagePath;
  
  /// Path to the processed/enhanced image
  final String? processedImagePath;
  
  /// Raw OCR text output
  final String? rawOcrText;
  
  // ========== EXTRACTED DATA ==========
  
  /// Name of the merchant/store
  final String? merchantName;
  
  /// Date and time of purchase
  final DateTime? purchaseDate;
  
  /// Total amount paid
  final double? totalAmount;
  
  /// Subtotal amount (before tax)
  final double? subtotalAmount;
  
  /// Tax/VAT amount
  final double? taxAmount;

  /// Tax breakdown for multiple tax rates
  final List<TaxBreakdown> taxBreakdown;

  /// Total tax amount (sum of all tax breakdown amounts)
  final double? taxTotal;

  /// Document type (e.g., 'receipt', 'invoice')
  final String? documentType;

  /// Method of payment used
  final PaymentMethod? paymentMethod;
  
  /// Currency of the amounts
  final Currency currency;
  
  /// List of individual receipt items
  final List<ReceiptItem> items;
  
  // ========== METADATA ==========
  
  /// OCR confidence score (0.0 - 1.0)
  final double confidence;
  
  /// Detected language code (e.g., 'fi', 'sv', 'en')
  final String? detectedLanguage;
  
  /// When the receipt was created/imported
  final DateTime createdAt;
  
  /// When the receipt was last modified
  final DateTime? modifiedAt;
  
  /// Processing status of the receipt
  final ReceiptStatus status;
  
  /// Whether the data has been manually verified
  final bool isVerified;
  
  /// Receipt/invoice number if available
  final String? receiptNumber;
  
  /// User notes about the receipt
  final String? notes;
  
  // ========== COMPUTED PROPERTIES ==========
  
  /// Whether the receipt has sufficient data for use
  bool get isComplete => merchantName != null && 
                        totalAmount != null && 
                        purchaseDate != null;
  
  /// Whether the receipt needs human verification
  bool get needsVerification => confidence < 0.7 || 
                               status == ReceiptStatus.needsVerification ||
                               !isComplete;
  
  /// Total number of items on the receipt
  int get itemCount => items.length;
  
  /// Calculated total from items (for verification)
  double? get calculatedTotal {
    if (items.isEmpty) return null;
    return items.fold<double>(0.0, (sum, item) => sum + item.totalPrice);
  }
  
  /// Whether there's a discrepancy between stated and calculated totals
  bool get hasTotalDiscrepancy {
    final calculated = calculatedTotal;
    final total = totalAmount;
    if (calculated == null || total == null) return false;
    return (calculated - total).abs() > 0.01;
  }
  
  // ========== FACTORY CONSTRUCTORS ==========
  
  /// Creates a new receipt with generated ID and current timestamp
  factory Receipt.create({
    required String originalImagePath,
    String? processedImagePath,
    String? rawOcrText,
    String? merchantName,
    DateTime? purchaseDate,
    double? totalAmount,
    double? subtotalAmount,
    double? taxAmount,
    List<TaxBreakdown> taxBreakdown = const [],
    double? taxTotal,
    String? documentType,
    PaymentMethod? paymentMethod,
    Currency currency = Currency.eur,
    List<ReceiptItem> items = const [],
    double confidence = 0.0,
    String? detectedLanguage,
    ReceiptStatus status = ReceiptStatus.pending,
    bool isVerified = false,
    String? receiptNumber,
    String? notes,
  }) {
    final now = DateTime.now();
    return Receipt(
      id: const Uuid().v4(),
      originalImagePath: originalImagePath,
      processedImagePath: processedImagePath,
      rawOcrText: rawOcrText,
      merchantName: merchantName,
      purchaseDate: purchaseDate,
      totalAmount: totalAmount,
      subtotalAmount: subtotalAmount,
      taxAmount: taxAmount,
      taxBreakdown: taxBreakdown,
      taxTotal: taxTotal,
      documentType: documentType,
      paymentMethod: paymentMethod,
      currency: currency,
      items: items,
      confidence: confidence,
      detectedLanguage: detectedLanguage,
      createdAt: now,
      modifiedAt: null,
      status: status,
      isVerified: isVerified,
      receiptNumber: receiptNumber,
      notes: notes,
    );
  }
  
  /// Creates Receipt from JSON
  factory Receipt.fromJson(Map<String, dynamic> json) => _$ReceiptFromJson(json);
  
  /// Converts Receipt to JSON
  Map<String, dynamic> toJson() => _$ReceiptToJson(this);
  
  // ========== COPY WITH METHODS ==========
  
  /// Creates a copy of this receipt with updated fields
  Receipt copyWith({
    String? id,
    String? originalImagePath,
    String? processedImagePath,
    String? rawOcrText,
    String? merchantName,
    DateTime? purchaseDate,
    double? totalAmount,
    double? subtotalAmount,
    double? taxAmount,
    List<TaxBreakdown>? taxBreakdown,
    double? taxTotal,
    String? documentType,
    PaymentMethod? paymentMethod,
    Currency? currency,
    List<ReceiptItem>? items,
    double? confidence,
    String? detectedLanguage,
    DateTime? createdAt,
    DateTime? modifiedAt,
    ReceiptStatus? status,
    bool? isVerified,
    String? receiptNumber,
    String? notes,
  }) {
    return Receipt(
      id: id ?? this.id,
      originalImagePath: originalImagePath ?? this.originalImagePath,
      processedImagePath: processedImagePath ?? this.processedImagePath,
      rawOcrText: rawOcrText ?? this.rawOcrText,
      merchantName: merchantName ?? this.merchantName,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      totalAmount: totalAmount ?? this.totalAmount,
      subtotalAmount: subtotalAmount ?? this.subtotalAmount,
      taxAmount: taxAmount ?? this.taxAmount,
      taxBreakdown: taxBreakdown ?? this.taxBreakdown,
      taxTotal: taxTotal ?? this.taxTotal,
      documentType: documentType ?? this.documentType,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      currency: currency ?? this.currency,
      items: items ?? this.items,
      confidence: confidence ?? this.confidence,
      detectedLanguage: detectedLanguage ?? this.detectedLanguage,
      createdAt: createdAt ?? this.createdAt,
      modifiedAt: modifiedAt ?? DateTime.now(),
      status: status ?? this.status,
      isVerified: isVerified ?? this.isVerified,
      receiptNumber: receiptNumber ?? this.receiptNumber,
      notes: notes ?? this.notes,
    );
  }
  
  /// Marks the receipt as verified with current timestamp
  Receipt markAsVerified() {
    return copyWith(
      isVerified: true,
      status: ReceiptStatus.completed,
      modifiedAt: DateTime.now(),
    );
  }
  
  /// Updates the processing status
  Receipt updateStatus(ReceiptStatus newStatus) {
    return copyWith(
      status: newStatus,
      modifiedAt: DateTime.now(),
    );
  }
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Receipt &&
          runtimeType == other.runtimeType &&
          id == other.id;
  
  @override
  int get hashCode => id.hashCode;
  
  @override
  String toString() =>
      'Receipt(id: $id, merchant: $merchantName, total: $totalAmount ${currency.symbol}, status: $status)';
}