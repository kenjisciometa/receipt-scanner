/// Helper function to parse a value that might be num or String to double
double? _parseDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  if (value is String) {
    final parsed = double.tryParse(value);
    return parsed;
  }
  return null;
}

/// Helper function to parse a value that might be num or String to int
int? _parseInt(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toInt();
  if (value is String) {
    final parsed = int.tryParse(value);
    return parsed;
  }
  return null;
}

/// LLM Extraction Result
class LLMExtractionResult {
  final String? merchantName;
  final String? date;
  final String? time;
  final List<ExtractedItem> items;
  final double? subtotal;
  final List<TaxBreakdownItem> taxBreakdown;
  final double? taxTotal;
  final double? total;
  final String? currency;
  final String? paymentMethod;
  final String? receiptNumber;
  final String rawResponse;
  final int processingTimeMs;
  final double confidence;
  final String? reasoning;
  final String? step1Result;

  LLMExtractionResult({
    this.merchantName,
    this.date,
    this.time,
    required this.items,
    this.subtotal,
    required this.taxBreakdown,
    this.taxTotal,
    this.total,
    this.currency,
    this.paymentMethod,
    this.receiptNumber,
    required this.rawResponse,
    required this.processingTimeMs,
    required this.confidence,
    this.reasoning,
    this.step1Result,
  });

  factory LLMExtractionResult.fromJson(Map<String, dynamic> json) {
    return LLMExtractionResult(
      merchantName: json['merchant_name'],
      date: json['date'],
      time: json['time'],
      items: (json['items'] as List? ?? [])
          .map((e) => ExtractedItem.fromJson(e))
          .toList(),
      subtotal: _parseDouble(json['subtotal']),
      taxBreakdown: (json['tax_breakdown'] as List? ?? [])
          .map((e) => TaxBreakdownItem.fromJson(e))
          .toList(),
      taxTotal: _parseDouble(json['tax_total']),
      total: _parseDouble(json['total']),
      currency: json['currency'],
      paymentMethod: json['payment_method'],
      receiptNumber: json['receipt_number'],
      rawResponse: json['raw_response'] ?? '',
      processingTimeMs: _parseInt(json['processing_time_ms']) ?? 0,
      confidence: _parseDouble(json['confidence']) ?? 0.0,
      reasoning: json['reasoning'],
      step1Result: json['step1_result'],
    );
  }

  Map<String, dynamic> toJson() => {
        'merchant_name': merchantName,
        'date': date,
        'time': time,
        'items': items.map((e) => e.toJson()).toList(),
        'subtotal': subtotal,
        'tax_breakdown': taxBreakdown.map((e) => e.toJson()).toList(),
        'tax_total': taxTotal,
        'total': total,
        'currency': currency,
        'payment_method': paymentMethod,
        'receipt_number': receiptNumber,
        'raw_response': rawResponse,
        'processing_time_ms': processingTimeMs,
        'confidence': confidence,
        'reasoning': reasoning,
        'step1_result': step1Result,
      };
}

class ExtractedItem {
  final String name;
  final int quantity;
  final double price;
  final double? taxRate;

  ExtractedItem({
    required this.name,
    required this.quantity,
    required this.price,
    this.taxRate,
  });

  factory ExtractedItem.fromJson(Map<String, dynamic> json) {
    return ExtractedItem(
      name: json['name'] ?? '',
      quantity: _parseInt(json['quantity']) ?? 1,
      price: _parseDouble(json['price']) ?? 0.0,
      taxRate: _parseDouble(json['tax_rate']),
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'quantity': quantity,
        'price': price,
        'tax_rate': taxRate,
      };
}

class TaxBreakdownItem {
  final double rate;
  final double taxableAmount;
  final double taxAmount;
  final double grossAmount;

  TaxBreakdownItem({
    required this.rate,
    required this.taxableAmount,
    required this.taxAmount,
    required this.grossAmount,
  });

  factory TaxBreakdownItem.fromJson(Map<String, dynamic> json) {
    final taxableAmount = _parseDouble(json['taxable_amount']) ?? 0.0;
    final taxAmount = _parseDouble(json['tax_amount']) ?? 0.0;
    final grossAmount = _parseDouble(json['gross_amount'])
        ?? (taxableAmount + taxAmount);

    return TaxBreakdownItem(
      rate: _parseDouble(json['rate']) ?? 0.0,
      taxableAmount: taxableAmount,
      taxAmount: taxAmount,
      grossAmount: grossAmount,
    );
  }

  Map<String, dynamic> toJson() => {
        'rate': rate,
        'taxable_amount': taxableAmount,
        'tax_amount': taxAmount,
        'gross_amount': grossAmount,
      };
}
