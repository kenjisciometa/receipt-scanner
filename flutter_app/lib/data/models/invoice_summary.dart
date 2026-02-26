/// Lightweight invoice summary model for duplicate detection.
///
/// Contains only the fields necessary for caching and duplicate comparison:
/// - id, merchantName, invoiceNumber, invoiceDate, totalAmount, currency, source
class InvoiceSummary {
  final String id;
  final String? merchantName;
  final String? invoiceNumber;
  final DateTime? invoiceDate;
  final double? totalAmount;
  final String currency;
  final InvoiceSource source;

  const InvoiceSummary({
    required this.id,
    this.merchantName,
    this.invoiceNumber,
    this.invoiceDate,
    this.totalAmount,
    this.currency = 'EUR',
    this.source = InvoiceSource.manual,
  });

  factory InvoiceSummary.fromJson(Map<String, dynamic> json) {
    return InvoiceSummary(
      id: json['id'] as String,
      merchantName: json['merchant_name'] as String?,
      invoiceNumber: json['invoice_number'] as String?,
      invoiceDate: json['invoice_date'] != null
          ? DateTime.tryParse(json['invoice_date'] as String)
          : null,
      totalAmount: (json['total_amount'] as num?)?.toDouble(),
      currency: json['currency'] as String? ?? 'EUR',
      source: InvoiceSource.fromString(json['source'] as String?),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'merchant_name': merchantName,
        'invoice_number': invoiceNumber,
        'invoice_date': invoiceDate?.toIso8601String().split('T')[0],
        'total_amount': totalAmount,
        'currency': currency,
        'source': source.name,
      };
}

/// Source of the invoice
enum InvoiceSource {
  manual,
  gmail;

  static InvoiceSource fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'gmail':
        return InvoiceSource.gmail;
      case 'manual':
      default:
        return InvoiceSource.manual;
    }
  }

  String get displayName {
    switch (this) {
      case InvoiceSource.manual:
        return 'Manual Scan';
      case InvoiceSource.gmail:
        return 'Gmail';
    }
  }
}

/// Result of a duplicate check
class DuplicateMatch {
  final InvoiceSummary invoice;
  final List<String> matchedFields;

  const DuplicateMatch({
    required this.invoice,
    required this.matchedFields,
  });

  /// Calculate match score (number of matched fields)
  int get matchScore => matchedFields.length;

  /// Check if total_amount was matched
  bool get matchedAmount => matchedFields.contains('total_amount');

  /// Check if invoice_date was matched
  bool get matchedDate => matchedFields.contains('invoice_date');

  /// Check if invoice_number was matched
  bool get matchedNumber => matchedFields.contains('invoice_number');

  /// Human-readable description of matched fields
  String get matchDescription {
    final descriptions = <String>[];
    if (matchedAmount) descriptions.add('Amount');
    if (matchedDate) descriptions.add('Date');
    if (matchedNumber) descriptions.add('Invoice #');
    return descriptions.join(', ');
  }
}
