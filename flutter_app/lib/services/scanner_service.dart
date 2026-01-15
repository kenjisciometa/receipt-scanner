import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import 'auth_service.dart';

class ScannerService {
  static Future<Map<String, dynamic>> extractReceipt(String base64Image) async {
    final url = AppConfig.scannerExtractUrl;

    print('[ScannerService] ========================================');
    print('[ScannerService] Starting extraction...');
    print('[ScannerService] URL: $url');
    print('[ScannerService] Image length: ${base64Image.length}');

    try {
      final headers = await AuthService.getAuthHeaders();
      print('[ScannerService] Headers: ${headers.keys.toList()}');

      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode({
          'image': base64Image,  // Fixed: was 'image_base64'
        }),
      ).timeout(const Duration(seconds: 180));

      print('[ScannerService] Response status: ${response.statusCode}');

      // Log full response
      print('[ScannerService] Response body:');
      print(response.body);

      if (response.statusCode == 401) {
        throw Exception('Authentication required. Please login again.');
      }

      // Check if response is HTML (error page)
      if (response.body.trim().startsWith('<') || response.body.trim().startsWith('<!')) {
        print('[ScannerService] ERROR: Received HTML instead of JSON!');
        throw Exception('Server returned HTML error page. Endpoint may not exist.');
      }

      final responseData = jsonDecode(response.body) as Map<String, dynamic>;
      print('[ScannerService] Parsed JSON successfully');
      print('[ScannerService] success: ${responseData['success']}');

      if (response.statusCode != 200) {
        throw Exception(responseData['error'] ?? 'API error');
      }

      return responseData;
    } catch (error) {
      print('[ScannerService] ERROR: $error');
      if (error.toString().contains('SocketException') ||
          error.toString().contains('TimeoutException')) {
        throw Exception('Network error. Please check your internet connection.');
      }
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> checkScannerStatus() async {
    final url = AppConfig.scannerExtractUrl;
    print('[ScannerService] Checking status: $url');

    try {
      final headers = await AuthService.getAuthHeaders();

      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      ).timeout(const Duration(seconds: 10));

      print('[ScannerService] Status check response: ${response.statusCode}');

      if (response.statusCode == 401) {
        throw Exception('Authentication required. Please login again.');
      }

      // Check if response is HTML
      if (response.body.trim().startsWith('<')) {
        print('[ScannerService] Status check returned HTML');
        return {'llm_available': false, 'error': 'Endpoint not found'};
      }

      final responseData = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode != 200) {
        throw Exception(responseData['error'] ?? 'API error');
      }

      return responseData;
    } catch (error) {
      print('[ScannerService] Status check error: $error');
      if (error.toString().contains('SocketException') ||
          error.toString().contains('TimeoutException')) {
        throw Exception('Network error. Please check your internet connection.');
      }
      rethrow;
    }
  }
}
