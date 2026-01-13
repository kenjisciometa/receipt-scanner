import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

import '../../main.dart';

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

  /// Extract receipt data from base64 encoded image (2-step approach)
  Future<LLMExtractionResult> extractFromBase64(String base64Image) async {
    final stopwatch = Stopwatch()..start();

    try {
      // ===== STEP 1: Extract information naturally =====
      final step1Response = await http
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
                    {'type': 'text', 'text': _step1ExtractionPrompt}
                  ]
                }
              ],
              'max_tokens': 2048,
              'temperature': 0.3,
            }),
          )
          .timeout(timeout);

      if (step1Response.statusCode != 200) {
        throw Exception('LLM API error (step 1): ${step1Response.statusCode}');
      }

      final step1Data = jsonDecode(step1Response.body);
      final extractedText = step1Data['choices'][0]['message']['content'] as String;

      // Log Step 1 result for debugging
      logger.i('===== STEP 1 EXTRACTION RESULT =====');
      logger.i(extractedText);
      logger.i('===== END STEP 1 =====');

      // ===== STEP 2: Convert to JSON =====
      final step2Response = await http
          .post(
            Uri.parse('$serverUrl/v1/chat/completions'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'model': 'qwen2.5-vl',
              'messages': [
                {
                  'role': 'user',
                  'content': '$_step2JsonPrompt\n\n---\nExtracted receipt information:\n$extractedText'
                }
              ],
              'max_tokens': 2048,
              'temperature': 0.1,
            }),
          )
          .timeout(timeout);

      stopwatch.stop();

      if (step2Response.statusCode != 200) {
        throw Exception('LLM API error (step 2): ${step2Response.statusCode}');
      }

      final step2Data = jsonDecode(step2Response.body);
      final jsonResponse = step2Data['choices'][0]['message']['content'] as String;
      final extracted = _parseResponse(jsonResponse);

      // Combine both responses for debugging
      final combinedRawResponse = '=== STEP 1 (抽出) ===\n$extractedText\n\n=== STEP 2 (JSON) ===\n$jsonResponse';

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
        rawResponse: combinedRawResponse,
        processingTimeMs: stopwatch.elapsedMilliseconds,
        confidence: _calculateConfidence(extracted),
        reasoning: extracted['reasoning'],
        step1Result: extractedText,
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

  /// Step 1: Natural language extraction (focus on accuracy)
  static const String _step1ExtractionPrompt = '''
Please extract the following information from this receipt image:

1. Store name
2. Date and time
3. Purchased items (name, quantity, price)
4. Tax breakdown table (usually at the bottom of the receipt)
   - Each tax rate (e.g., 14%, 25.5%)
   - Tax amount for each rate
   - Taxable amount (net/before tax) for each rate
   - Gross amount (including tax) for each rate
5. Total amount
6. Payment method (card, cash, etc.)
7. Receipt number

CRITICAL: Tax breakdown accuracy
- Read the tax breakdown table VERY carefully
- For EACH tax rate, report the EXACT numbers you see for:
  * Tax amount (the tax portion)
  * Taxable amount (net amount before tax)
  * Gross amount (total including tax for this rate)
- Read column headers to identify which column is which
- Double-check each number - accuracy is essential
''';

  /// Step 2: Convert to JSON format
  static const String _step2JsonPrompt = '''
Convert the extracted receipt information to JSON format.

CRITICAL: Use the EXACT values from the extracted text below. Do NOT re-interpret or recalculate.
Copy the numbers exactly as they appear in the extraction.

Output JSON format:
{
  "merchant_name": "Store name",
  "date": "YYYY-MM-DD",
  "time": "HH:MM",
  "items": [{"name": "Item name", "quantity": 1, "price": 0.00, "tax_rate": 14}],
  "subtotal": 0.00,
  "tax_breakdown": [
    {"rate": 14, "tax_amount": 0.00, "taxable_amount": 0.00, "gross_amount": 0.00}
  ],
  "tax_total": 0.00,
  "total": 0.00,
  "currency": "EUR",
  "payment_method": "card/cash",
  "receipt_number": "string or null",
  "reasoning": "日本語で説明"
}

Rules:
- Return ONLY JSON (no markdown)
- All amounts must be numbers, not strings
- IMPORTANT: Copy values directly from the extracted text - do not recalculate or guess
- For tax_breakdown: use the exact tax_amount, taxable_amount, and gross_amount from the extraction
- The "reasoning" field MUST be in Japanese: briefly explain which values you used from the extraction
''';
}
