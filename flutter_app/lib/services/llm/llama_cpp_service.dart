import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

/// Helper function to print long strings without truncation
void _printLong(String text, {int chunkSize = 800}) {
  for (var i = 0; i < text.length; i += chunkSize) {
    final end = (i + chunkSize < text.length) ? i + chunkSize : text.length;
    print(text.substring(i, end));
  }
}

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
  final String? reasoning; // 日本語での解釈過程（開発用）
  final String? step1Result; // Step 1の抽出結果（開発用）

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
    // Use provided gross_amount or calculate it
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

/// LlamaCpp Service for receipt extraction
class LlamaCppService {
  /// Server URL - defaults to localhost for USB connection
  /// Use `adb reverse tcp:8080 tcp:8080` to forward from Android to PC
  final String serverUrl;
  final Duration timeout;

  LlamaCppService({
    this.serverUrl = 'http://localhost:8080',
    this.timeout = const Duration(seconds: 120), // Increased for 2-step processing
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

  /// Extract receipt data from base64 encoded image (3-step approach)
  Future<LLMExtractionResult> extractFromBase64(String base64Image) async {
    final stopwatch = Stopwatch()..start();

    try {
      // ===== STAGE 1: Tax Table Extraction (focused task) =====
      print('');
      print('########################################');
      print('######## STAGE 1: TAX TABLE ########');
      print('########################################');

      final stage1Response = await http
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
                    {'type': 'text', 'text': _stage1TaxTablePrompt}
                  ]
                }
              ],
              'max_tokens': 1024,
              'temperature': 0.1,
            }),
          )
          .timeout(timeout);

      if (stage1Response.statusCode != 200) {
        throw Exception('LLM API error (stage 1): ${stage1Response.statusCode}');
      }

      final stage1Data = jsonDecode(stage1Response.body);
      final taxTableText = stage1Data['choices'][0]['message']['content'] as String;

      print('');
      _printLong(taxTableText);
      print('');
      print('######## END STAGE 1 ########');
      print('');

      // ===== STAGE 2: Other Information Extraction =====
      print('########################################');
      print('######## STAGE 2: OTHER INFO ########');
      print('########################################');

      final stage2Response = await http
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
                    {'type': 'text', 'text': _stage2OtherInfoPrompt}
                  ]
                }
              ],
              'max_tokens': 2048,
              'temperature': 0.3,
            }),
          )
          .timeout(timeout);

      if (stage2Response.statusCode != 200) {
        throw Exception('LLM API error (stage 2): ${stage2Response.statusCode}');
      }

      final stage2Data = jsonDecode(stage2Response.body);
      final otherInfoText = stage2Data['choices'][0]['message']['content'] as String;

      print('');
      _printLong(otherInfoText);
      print('');
      print('######## END STAGE 2 ########');
      print('');

      // ===== STAGE 3: JSON Conversion (text only, no image) =====
      print('########################################');
      print('######## STAGE 3: JSON OUTPUT ########');
      print('########################################');

      final stage3Response = await http
          .post(
            Uri.parse('$serverUrl/v1/chat/completions'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'model': 'qwen2.5-vl',
              'messages': [
                {
                  'role': 'user',
                  'content': '''$_stage3JsonPrompt

=== TAX TABLE DATA (from Stage 1) ===
$taxTableText

=== OTHER RECEIPT INFO (from Stage 2) ===
$otherInfoText
'''
                }
              ],
              'max_tokens': 2048,
              'temperature': 0.1,
            }),
          )
          .timeout(timeout);

      stopwatch.stop();

      if (stage3Response.statusCode != 200) {
        throw Exception('LLM API error (stage 3): ${stage3Response.statusCode}');
      }

      final stage3Data = jsonDecode(stage3Response.body);
      final jsonResponse = stage3Data['choices'][0]['message']['content'] as String;
      final extracted = _parseResponse(jsonResponse);

      print('');
      _printLong(jsonResponse);
      print('');
      print('######## END STAGE 3 ########');
      print('');

      // Log Amount Breakdown
      print('========================================');
      print('===== FINAL AMOUNT BREAKDOWN =====');
      print('========================================');
      final taxBreakdown = extracted['tax_breakdown'] as List? ?? [];
      for (int i = 0; i < taxBreakdown.length; i++) {
        final tax = taxBreakdown[i];
        print('Tax Rate ${i + 1}: ${tax['rate']}%');
        print('  - Tax Amount: ${tax['tax_amount']}');
        print('  - Taxable Amount: ${tax['taxable_amount']}');
        print('  - Gross Amount: ${tax['gross_amount']}');
      }
      print('Total: ${extracted['total']}');
      print('========================================');
      print('');

      // Combine all responses for debugging
      final combinedRawResponse = '=== STAGE 1 (税金テーブル) ===\n$taxTableText\n\n=== STAGE 2 (その他情報) ===\n$otherInfoText\n\n=== STAGE 3 (JSON) ===\n$jsonResponse';

      return LLMExtractionResult(
        merchantName: extracted['merchant_name'],
        date: extracted['date'],
        time: extracted['time'],
        items: (extracted['items'] as List? ?? [])
            .map((e) => ExtractedItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        subtotal: _parseDouble(extracted['subtotal']),
        taxBreakdown: (extracted['tax_breakdown'] as List? ?? [])
            .where((e) {
              // Filter out non-numeric rates (e.g., "YHTEENSÄ", "TOTAL")
              final rate = e['rate'];
              return rate is num || (rate is String && double.tryParse(rate) != null);
            })
            .map((e) => TaxBreakdownItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        taxTotal: _parseDouble(extracted['tax_total']),
        total: _parseDouble(extracted['total']),
        currency: extracted['currency'],
        paymentMethod: extracted['payment_method'],
        receiptNumber: extracted['receipt_number'],
        rawResponse: combinedRawResponse,
        processingTimeMs: stopwatch.elapsedMilliseconds,
        confidence: _calculateConfidence(extracted),
        reasoning: extracted['reasoning'],
        step1Result: taxTableText,
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

  /// Simple test with exact same prompt as web UI for comparison
  Future<String> testSimplePrompt(String base64Image) async {
    const testPrompt = 'このレシートからTAXテーブルを読み取り合計金額と各税率いくらか調べてください';

    print('');
    print('########################################');
    print('######## SIMPLE TEST PROMPT ########');
    print('########################################');
    print('Prompt: $testPrompt');
    print('########################################');

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
                  {'type': 'text', 'text': testPrompt}
                ]
              }
            ],
            'max_tokens': 1024,
            'temperature': 0.1,
          }),
        )
        .timeout(timeout);

    if (response.statusCode != 200) {
      throw Exception('LLM API error (test): ${response.statusCode}');
    }

    final data = jsonDecode(response.body);
    final result = data['choices'][0]['message']['content'] as String;

    print('');
    print('######## TEST RESULT ########');
    _printLong(result);
    print('');
    print('######## END TEST ########');
    print('');

    return result;
  }

  /// Stage 1: Tax table extraction ONLY (simple prompt for better accuracy)
  static const String _stage1TaxTablePrompt = '''
Read the TAX table from this receipt and find out the total amount and how much each tax rate is.

For each tax rate, report:
- Tax rate (%)
- Tax amount
- Taxable amount (net, before tax)
- Gross amount (total including tax)

Also report the TOTAL amount of the receipt.
''';

  /// Stage 2: Other receipt information (excluding tax table)
  static const String _stage2OtherInfoPrompt = '''
Extract the following information from this receipt (DO NOT extract tax table - that's done separately):

1. Store/Merchant name
2. Date (format: YYYY-MM-DD)
3. Time (format: HH:MM)
4. Receipt number
5. Payment method (card, cash, etc.)
6. Currency (EUR, USD, etc.)
7. List of purchased items with:
   - Item name
   - Quantity
   - Unit price or total price

Output format:
STORE: [name]
DATE: [YYYY-MM-DD]
TIME: [HH:MM]
RECEIPT#: [number]
PAYMENT: [method]
CURRENCY: [code]
ITEMS:
- [name], qty: [X], price: [XX.XX]
- [name], qty: [X], price: [XX.XX]
''';

  /// Stage 3: JSON conversion (text only, combine Stage 1 & 2 results)
  static const String _stage3JsonPrompt = '''
Convert the extracted receipt data to JSON format.

CRITICAL RULES:
- Use ONLY the values provided below from Stage 1 and Stage 2
- Do NOT recalculate or modify any numbers
- Copy values EXACTLY as provided

Output JSON format:
{
  "merchant_name": "string",
  "date": "YYYY-MM-DD",
  "time": "HH:MM",
  "items": [{"name": "string", "quantity": 1, "price": 0.00, "tax_rate": null}],
  "subtotal": null,
  "tax_breakdown": [
    {"rate": 14, "tax_amount": 0.00, "taxable_amount": 0.00, "gross_amount": 0.00}
  ],
  "tax_total": 0.00,
  "total": 0.00,
  "currency": "EUR",
  "payment_method": "string",
  "receipt_number": "string or null"
}

Rules:
- Return ONLY valid JSON (no markdown code blocks)
- All amounts as numbers, not strings
- "rate" must be a number
- Use null for unknown values
''';
}
