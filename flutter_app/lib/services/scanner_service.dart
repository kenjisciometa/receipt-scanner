import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import 'auth_service.dart';

class ScannerService {
  static Future<Map<String, dynamic>> extractReceipt(String base64Image) async {
    try {
      final headers = await AuthService.getAuthHeaders();

      final response = await http.post(
        Uri.parse(AppConfig.scannerExtractUrl),
        headers: headers,
        body: jsonEncode({
          'image_base64': base64Image,
        }),
      );

      if (response.statusCode == 401) {
        throw Exception('Authentication required. Please login again.');
      }

      final responseData = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode != 200) {
        throw Exception(responseData['error'] ?? 'API error');
      }

      return responseData;
    } catch (error) {
      if (error.toString().contains('SocketException') ||
          error.toString().contains('TimeoutException')) {
        throw Exception('Network error. Please check your internet connection.');
      }
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> checkScannerStatus() async {
    try {
      final headers = await AuthService.getAuthHeaders();

      final response = await http.get(
        Uri.parse(AppConfig.scannerStatusUrl),
        headers: headers,
      );

      if (response.statusCode == 401) {
        throw Exception('Authentication required. Please login again.');
      }

      final responseData = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode != 200) {
        throw Exception(responseData['error'] ?? 'API error');
      }

      return responseData;
    } catch (error) {
      if (error.toString().contains('SocketException') ||
          error.toString().contains('TimeoutException')) {
        throw Exception('Network error. Please check your internet connection.');
      }
      rethrow;
    }
  }
}