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
  final String? reasoning; // 日本語での解釈過程（開発用）

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
      processingTimeMs: (json['processing_time_ms'] as num?)?.toInt() ?? 0,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      reasoning: json['reasoning'],
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
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
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
  final double grossAmount;

  TaxBreakdownItem({
    required this.rate,
    required this.taxableAmount,
    required this.taxAmount,
    required this.grossAmount,
  });

  factory TaxBreakdownItem.fromJson(Map<String, dynamic> json) {
    final taxableAmount = (json['taxable_amount'] as num?)?.toDouble() ?? 0.0;
    final taxAmount = (json['tax_amount'] as num?)?.toDouble() ?? 0.0;
    // Use provided gross_amount or calculate it
    final grossAmount = (json['gross_amount'] as num?)?.toDouble()
        ?? (taxableAmount + taxAmount);

    return TaxBreakdownItem(
      rate: (json['rate'] as num?)?.toDouble() ?? 0.0,
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
        reasoning: extracted['reasoning'],
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
You are a receipt OCR system. Extract all information from this receipt image and return ONLY valid JSON.

CRITICAL: Tax Breakdown Table
The tax summary TABLE is at the BOTTOM of the receipt, near the total.

STEP 1: Identify the table structure by reading the COLUMN HEADERS first.
Common headers by language:
- Finnish: Vero (tax), Veroton (net/taxable), Yhteensä (gross/total)
- German: MwSt (tax), Netto (net), Brutto (gross)
- Swedish: Moms (tax), Exkl. (net), Inkl. (gross)
- English: VAT/Tax, Excl./Net, Incl./Gross/Total

STEP 2: The column order varies, but follows this rule:
IMPORTANT: Tax and Net columns are ALWAYS adjacent!
- [Rate] [Tax] [Net] [Gross]  OR
- [Rate] [Net] [Tax] [Gross]
The Gross column is always at the end (rightmost).
Tax and Net are never separated by Gross.
Read the headers to determine which column is which.

STEP 3: Example table (Finnish):
         Vero    Veroton   Yhteensä
  25.5%  0.16    0.62      0.78
  14%    8.43    60.21     68.64
                           69.42

Headers tell us: Vero=tax, Veroton=net, Yhteensä=gross
So row "25.5%": tax_amount=0.16, taxable_amount=0.62, gross_amount=0.78
The last line (69.42) alone is the receipt total.

CRITICAL - Reading Gross Values:
- The RIGHTMOST column contains gross_amount for each tax rate
- These gross values appear DIRECTLY ABOVE the total line
- Read each row's rightmost value carefully: 0.78 and 68.64 (NOT the total 69.42)
- The total (69.42) is on its own line at the bottom

NOTE: There may NOT be a summary row with totals for each column.
The total may appear alone at the bottom.

VERIFICATION (do this for EVERY tax row):
1. Check: gross_amount = taxable_amount + tax_amount (must match within 0.01!)
2. Check: tax_amount = taxable_amount × (rate / 100) (approximately)
3. Check: sum of all gross_amounts = receipt total
4. If ANY math doesn't work:
   - You may have swapped Tax and Net columns - try switching them
   - You may have misread a digit (e.g., 8 vs 6, 3 vs 8)
   - Re-read the rightmost column values carefully

Output JSON:
{
  "merchant_name": "Store name",
  "date": "YYYY-MM-DD",
  "time": "HH:MM or null",
  "items": [{"name": "Item", "quantity": 1, "price": 0.00, "tax_rate": 14}],
  "subtotal": 0.00,
  "tax_breakdown": [
    {"rate": 25.5, "tax_amount": 0.16, "taxable_amount": 0.62, "gross_amount": 0.78},
    {"rate": 14, "tax_amount": 8.43, "taxable_amount": 60.21, "gross_amount": 68.64}
  ],
  "tax_total": 8.59,
  "total": 69.42,
  "currency": "EUR",
  "payment_method": "card/cash/null",
  "receipt_number": "string or null",
  "reasoning": "日本語で解釈過程を説明"
}

Rules:
- Return ONLY JSON, no markdown
- All amounts are numbers, not strings
- gross_amount = taxable_amount + tax_amount (verify for each row!)
- sum of gross_amounts = total (verify!)
- tax_total = sum of all tax_amounts
- "reasoning" field MUST be in Japanese: explain (1) what headers you found, (2) how you identified each column, (3) the verification math for each row (gross = net + tax), and (4) if any corrections were made''';
}
