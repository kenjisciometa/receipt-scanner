import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

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
  });

  factory LLMExtractionResult.fromJson(Map<String, dynamic> json) {
    return LLMExtractionResult(
      merchantName: json['merchant_name'],
      date: json['date'],
      time: json['time'],
      items: (json['items'] as List? ?? [])
          .map((e) => ExtractedItem.fromJson(e))
          .toList(),
      subtotal: (json['subtotal'] as num?)?.toDouble(),
      taxBreakdown: (json['tax_breakdown'] as List? ?? [])
          .map((e) => TaxBreakdownItem.fromJson(e))
          .toList(),
      taxTotal: (json['tax_total'] as num?)?.toDouble(),
      total: (json['total'] as num?)?.toDouble(),
      currency: json['currency'],
      paymentMethod: json['payment_method'],
      receiptNumber: json['receipt_number'],
      rawResponse: json['raw_response'] ?? '',
      processingTimeMs: json['processing_time_ms'] ?? 0,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
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
      quantity: json['quantity'] ?? 1,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      taxRate: (json['tax_rate'] as num?)?.toDouble(),
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

  TaxBreakdownItem({
    required this.rate,
    required this.taxableAmount,
    required this.taxAmount,
  });

  factory TaxBreakdownItem.fromJson(Map<String, dynamic> json) {
    return TaxBreakdownItem(
      rate: (json['rate'] as num?)?.toDouble() ?? 0.0,
      taxableAmount: (json['taxable_amount'] as num?)?.toDouble() ?? 0.0,
      taxAmount: (json['tax_amount'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'rate': rate,
        'taxable_amount': taxableAmount,
        'tax_amount': taxAmount,
      };
}

/// LlamaCpp Service for receipt extraction
class LlamaCppService {
  /// Server URL - defaults to localhost for USB connection
  /// Use `adb reverse tcp:8080 tcp:8080` to forward from Android to PC
  final String serverUrl;
  final Duration timeout;

  LlamaCppService({
    this.serverUrl = 'http://localhost:8080',
    this.timeout = const Duration(seconds: 30),
  });

  /// Check if llama-server is available
  Future<bool> checkServer() async {
    try {
      final response = await http
          .get(Uri.parse('$serverUrl/health'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['status'] == 'ok';
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Extract receipt data from image file
  Future<LLMExtractionResult> extractFromFile(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    return extractFromBytes(bytes);
  }

  /// Extract receipt data from image bytes
  Future<LLMExtractionResult> extractFromBytes(Uint8List imageBytes) async {
    final base64Image = base64Encode(imageBytes);
    return extractFromBase64(base64Image);
  }

  /// Extract receipt data from base64 encoded image
  Future<LLMExtractionResult> extractFromBase64(String base64Image) async {
    final stopwatch = Stopwatch()..start();

    try {
      final response = await http
          .post(
            Uri.parse('$serverUrl/v1/chat/completions'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'model': 'qwen2.5-vl',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {
                      'type': 'image_url',
                      'image_url': {'url': 'data:image/png;base64,$base64Image'}
                    },
                    {'type': 'text', 'text': _extractionPrompt}
                  ]
                }
              ],
              'max_tokens': 2048,
              'temperature': 0.1,
            }),
          )
          .timeout(timeout);

      stopwatch.stop();

      if (response.statusCode != 200) {
        throw Exception('LLM API error: ${response.statusCode}');
      }

      final data = jsonDecode(response.body);
      final rawResponse = data['choices'][0]['message']['content'] as String;
      final extracted = _parseResponse(rawResponse);

      return LLMExtractionResult(
        merchantName: extracted['merchant_name'],
        date: extracted['date'],
        time: extracted['time'],
        items: (extracted['items'] as List? ?? [])
            .map((e) => ExtractedItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        subtotal: (extracted['subtotal'] as num?)?.toDouble(),
        taxBreakdown: (extracted['tax_breakdown'] as List? ?? [])
            .map((e) => TaxBreakdownItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        taxTotal: (extracted['tax_total'] as num?)?.toDouble(),
        total: (extracted['total'] as num?)?.toDouble(),
        currency: extracted['currency'],
        paymentMethod: extracted['payment_method'],
        receiptNumber: extracted['receipt_number'],
        rawResponse: rawResponse,
        processingTimeMs: stopwatch.elapsedMilliseconds,
        confidence: _calculateConfidence(extracted),
      );
    } catch (e) {
      stopwatch.stop();
      throw Exception(
          'LLM extraction failed after ${stopwatch.elapsedMilliseconds}ms: $e');
    }
  }

  /// Parse JSON from LLM response
  Map<String, dynamic> _parseResponse(String rawResponse) {
    try {
      // Find JSON in response
      final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(rawResponse);
      if (jsonMatch == null) {
        return {};
      }
      return jsonDecode(jsonMatch.group(0)!) as Map<String, dynamic>;
    } catch (e) {
      return {};
    }
  }

  /// Calculate confidence score
  double _calculateConfidence(Map<String, dynamic> extracted) {
    double score = 0;
    double maxScore = 0;

    // Critical fields
    if (extracted['total'] != null && (extracted['total'] as num) > 0) {
      score += 3;
    }
    maxScore += 3;

    if (extracted['merchant_name'] != null) {
      score += 2;
    }
    maxScore += 2;

    final date = extracted['date'];
    if (date != null && RegExp(r'\d{4}-\d{2}-\d{2}').hasMatch(date)) {
      score += 2;
    }
    maxScore += 2;

    // Important fields
    final items = extracted['items'] as List?;
    if (items != null && items.isNotEmpty) {
      score += 2;
    }
    maxScore += 2;

    final taxBreakdown = extracted['tax_breakdown'] as List?;
    if (taxBreakdown != null && taxBreakdown.isNotEmpty) {
      score += 2;
    }
    maxScore += 2;

    // Optional fields
    if (extracted['subtotal'] != null) score += 1;
    maxScore += 1;
    if (extracted['currency'] != null) score += 1;
    maxScore += 1;
    if (extracted['payment_method'] != null) score += 1;
    maxScore += 1;

    return (score / maxScore * 100).round() / 100;
  }

  static const String _extractionPrompt = '''
You are a receipt OCR system. Extract all information from this receipt image and return ONLY valid JSON:

{
  "merchant_name": "Store/restaurant name",
  "date": "YYYY-MM-DD format",
  "time": "HH:MM format or null",
  "items": [
    {"name": "Item name", "quantity": 1, "price": 0.00, "tax_rate": 0}
  ],
  "subtotal": 0.00,
  "tax_breakdown": [
    {"rate": 10, "taxable_amount": 0.00, "tax_amount": 0.00}
  ],
  "tax_total": 0.00,
  "total": 0.00,
  "currency": "EUR/USD/SEK/etc",
  "payment_method": "cash/card/etc or null",
  "receipt_number": "receipt/transaction number or null"
}

Rules:
- Return ONLY the JSON object, no explanations or markdown
- Include ALL tax rates found on the receipt in tax_breakdown
- Each item should have its tax_rate if visible
- Use null for fields you cannot find
- Prices must be numbers, not strings
- Date must be YYYY-MM-DD format''';
}
