import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../config/app_config.dart';

/// Result of sending a document to Procountor
class ProcountorSendResult {
  final bool success;
  final int? invoiceId;
  final bool attachmentSent;
  final String? error;

  ProcountorSendResult({
    required this.success,
    this.invoiceId,
    this.attachmentSent = false,
    this.error,
  });
}

/// Service for Procountor integration via AccountApp API
class ProcountorApiService {
  final Future<Map<String, String>> Function() getAuthHeaders;

  ProcountorApiService({required this.getAuthHeaders});

  /// Send a receipt or invoice to Procountor as a purchase invoice
  Future<ProcountorSendResult> sendToProcountor({
    required String documentId,
    required String documentType, // 'receipt' or 'invoice'
  }) async {
    try {
      final headers = await getAuthHeaders();
      final url = AppConfig.procountorSendUrl;

      if (kDebugMode) {
        print('[ProcountorAPI] Sending $documentType $documentId to Procountor');
        print('[ProcountorAPI] URL: $url');
      }

      final response = await http
          .post(
            Uri.parse(url),
            headers: headers,
            body: jsonEncode({
              'receiptId': documentId,
              'documentType': documentType,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (kDebugMode) {
        print('[ProcountorAPI] Response status: ${response.statusCode}');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && data['success'] == true) {
        return ProcountorSendResult(
          success: true,
          invoiceId: data['invoiceId'] as int?,
          attachmentSent: data['attachmentSent'] as bool? ?? false,
        );
      } else {
        final error = data['error'] as String? ?? 'Unknown error';
        if (kDebugMode) {
          print('[ProcountorAPI] Error: $error');
        }
        return ProcountorSendResult(
          success: false,
          error: error,
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('[ProcountorAPI] Exception: $e');
      }
      return ProcountorSendResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Test Procountor connection
  Future<bool> testConnection() async {
    try {
      final headers = await getAuthHeaders();
      final url = AppConfig.procountorTestUrl;

      final response = await http
          .post(Uri.parse(url), headers: headers)
          .timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return response.statusCode == 200 && data['success'] == true;
    } catch (e) {
      if (kDebugMode) {
        print('[ProcountorAPI] Test connection failed: $e');
      }
      return false;
    }
  }
}
