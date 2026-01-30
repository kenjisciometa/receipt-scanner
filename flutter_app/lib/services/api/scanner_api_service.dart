import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

import '../../config/app_config.dart';
import '../llm/llama_cpp_service.dart';

/// Scanner API Service - calls POS API for receipt extraction
class ScannerApiService {
  final Duration timeout;
  final Future<Map<String, String>> Function() getAuthHeaders;

  ScannerApiService({
    this.timeout = const Duration(seconds: 180), // 3 minutes for 3-stage extraction
    required this.getAuthHeaders,
  });

  /// Extract receipt data from image file via POS API
  Future<LLMExtractionResult> extractFromFile(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    print('[ScannerAPI] Image file size: ${bytes.length} bytes');
    final result = await extractFromBytes(bytes);
    print('[ScannerAPI] extractFromFile: Got result, documentType=${result.documentType}');
    return result;
  }

  /// Extract receipt data from image bytes via POS API
  Future<LLMExtractionResult> extractFromBytes(Uint8List imageBytes) async {
    final base64Image = base64Encode(imageBytes);
    print('[ScannerAPI] Base64 image length: ${base64Image.length}');
    final result = await extractFromBase64(base64Image);
    print('[ScannerAPI] extractFromBytes: Got result');
    return result;
  }

  /// Extract receipt data from base64 encoded image via POS API
  Future<LLMExtractionResult> extractFromBase64(String base64Image) async {
    final stopwatch = Stopwatch()..start();
    final url = AppConfig.scannerExtractUrl;

    print('');
    print('========================================');
    print('[ScannerAPI] Starting extraction...');
    print('[ScannerAPI] URL: $url');
    print('========================================');

    try {
      final headers = await getAuthHeaders();
      print('[ScannerAPI] Headers: ${headers.keys.toList()}');

      print('[ScannerAPI] Sending POST request...');
      final response = await http
          .post(
            Uri.parse(url),
            headers: headers,
            body: jsonEncode({
              'image': base64Image,
            }),
          )
          .timeout(timeout);

      stopwatch.stop();

      print('[ScannerAPI] Response status: ${response.statusCode}');
      print('[ScannerAPI] Response headers: ${response.headers}');

      // Log first 500 chars of response body for debugging
      final bodyPreview = response.body.length > 500
          ? response.body.substring(0, 500)
          : response.body;
      print('[ScannerAPI] Response body preview: $bodyPreview');

      // Check if response is HTML (error page)
      if (response.body.trim().startsWith('<') || response.body.trim().startsWith('<!')) {
        print('[ScannerAPI] ERROR: Received HTML instead of JSON!');
        print('[ScannerAPI] This usually means the endpoint does not exist or returned an error page.');
        throw Exception('Received HTML response instead of JSON. Check if /api/scanner/extract endpoint is deployed.');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      print('[ScannerAPI] Parsed JSON successfully');
      print('[ScannerAPI] success: ${data['success']}');

      // Check for API-level errors
      if (response.statusCode != 200 || data['success'] != true) {
        final errorMessage = data['error'] ?? 'Unknown error';
        print('[ScannerAPI] API Error: $errorMessage');
        throw Exception('Scanner API error: $errorMessage');
      }

      print('[ScannerAPI] Extraction successful!');
      print('[ScannerAPI] Processing time: ${data['processing_time_ms']}ms');

      // Debug: Print invoice fields from response
      print('[ScannerAPI] document_type: ${data['document_type']}');
      print('[ScannerAPI] vendor_address: ${data['vendor_address']}');
      print('[ScannerAPI] vendor_tax_id: ${data['vendor_tax_id']}');
      print('[ScannerAPI] customer_name: ${data['customer_name']}');
      print('[ScannerAPI] invoice_number: ${data['invoice_number']}');
      print('[ScannerAPI] due_date: ${data['due_date']}');

      // Parse response from POS API
      final extractionResult = LLMExtractionResult(
        merchantName: data['merchant_name'],
        date: data['date'],
        time: data['time'],
        items: (data['items'] as List? ?? [])
            .map((e) => ExtractedItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        subtotal: _parseDouble(data['subtotal']),
        taxBreakdown: (data['tax_breakdown'] as List? ?? [])
            .map((e) => TaxBreakdownItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        taxTotal: _parseDouble(data['tax_total']),
        total: _parseDouble(data['total']),
        currency: data['currency'],
        paymentMethod: data['payment_method'],
        receiptNumber: data['receipt_number'],
        rawResponse: data['raw_response'] ?? response.body,
        processingTimeMs: data['processing_time_ms'] ?? stopwatch.elapsedMilliseconds,
        confidence: _parseDouble(data['confidence']) ?? 0.0,
        reasoning: data['reasoning'],
        step1Result: data['step1_result'],
        // Document type and Invoice-specific fields
        documentType: data['document_type'],
        vendorAddress: data['vendor_address'],
        vendorTaxId: data['vendor_tax_id'],
        customerName: data['customer_name'],
        invoiceNumber: data['invoice_number'],
        dueDate: data['due_date'],
      );
      print('[ScannerAPI] LLMExtractionResult created, returning...');
      return extractionResult;
    } catch (e) {
      stopwatch.stop();
      print('[ScannerAPI] EXCEPTION: $e');
      print('[ScannerAPI] Time elapsed: ${stopwatch.elapsedMilliseconds}ms');
      throw Exception(
          'Scanner API extraction failed after ${stopwatch.elapsedMilliseconds}ms: $e');
    }
  }

  /// Check if Scanner API is available
  Future<bool> checkServer() async {
    final url = AppConfig.scannerExtractUrl;
    print('[ScannerAPI] Checking server availability: $url');

    try {
      final headers = await getAuthHeaders();

      final response = await http
          .get(
            Uri.parse(url),
            headers: headers,
          )
          .timeout(const Duration(seconds: 10));

      print('[ScannerAPI] Health check status: ${response.statusCode}');

      if (response.statusCode == 200) {
        // Check if response is HTML
        if (response.body.trim().startsWith('<')) {
          print('[ScannerAPI] Health check returned HTML - endpoint may not exist');
          return false;
        }

        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final available = data['llm_available'] == true;
        print('[ScannerAPI] LLM available: $available');
        return available;
      }

      print('[ScannerAPI] Health check failed: ${response.statusCode}');
      return false;
    } catch (e) {
      print('[ScannerAPI] Health check exception: $e');
      return false;
    }
  }
}

double? _parseDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}
