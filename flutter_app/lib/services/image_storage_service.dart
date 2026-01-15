import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import 'auth_service.dart';

/// Image Storage Service - uploads receipt images via ReactPOS API to NAS
class ImageStorageService {
  /// Upload receipt image to NAS via ReactPOS API
  /// Returns the storage URL path for the uploaded image
  static Future<String?> uploadReceiptImage(String localFilePath) async {
    try {
      if (!AuthService.isAuthenticated) {
        throw Exception('User not authenticated');
      }

      final file = File(localFilePath);
      if (!await file.exists()) {
        throw Exception('File not found: $localFilePath');
      }

      // Read file bytes and convert to base64
      final Uint8List bytes = await file.readAsBytes();
      final base64Image = base64Encode(bytes);

      _log('Uploading image: ${bytes.length} bytes');

      // Get auth headers
      final headers = await AuthService.getAuthHeaders();

      // Upload via ReactPOS API
      final response = await http.post(
        Uri.parse(AppConfig.storageUploadUrl),
        headers: headers,
        body: jsonEncode({
          'image': base64Image,
        }),
      ).timeout(const Duration(seconds: 60));

      _log('Upload response status: ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true && data['storage_url'] != null) {
          final storageUrl = '${AppConfig.apiBaseUrl}${data['storage_url']}';
          _log('Upload successful: $storageUrl');
          return storageUrl;
        } else {
          _log('Upload failed: ${data['error']}');
          return null;
        }
      } else if (response.statusCode == 401) {
        throw Exception('Authentication required');
      } else {
        _log('Upload failed: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      _log('Error uploading image: $e');
      return null;
    }
  }

  /// Upload receipt image from bytes
  static Future<String?> uploadReceiptImageFromBytes(Uint8List bytes) async {
    try {
      if (!AuthService.isAuthenticated) {
        throw Exception('User not authenticated');
      }

      final base64Image = base64Encode(bytes);

      _log('Uploading image from bytes: ${bytes.length} bytes');

      final headers = await AuthService.getAuthHeaders();

      final response = await http.post(
        Uri.parse(AppConfig.storageUploadUrl),
        headers: headers,
        body: jsonEncode({
          'image': base64Image,
        }),
      ).timeout(const Duration(seconds: 60));

      _log('Upload response status: ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true && data['storage_url'] != null) {
          final storageUrl = '${AppConfig.apiBaseUrl}${data['storage_url']}';
          _log('Upload successful: $storageUrl');
          return storageUrl;
        }
      }

      _log('Upload failed: ${response.statusCode}');
      return null;
    } catch (e) {
      _log('Error uploading image from bytes: $e');
      return null;
    }
  }

  /// Get image from storage via ReactPOS API
  /// Returns the image bytes
  static Future<Uint8List?> getImage(String storageUrl) async {
    try {
      final headers = await AuthService.getAuthHeaders();

      final response = await http.get(
        Uri.parse(storageUrl),
        headers: headers,
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return response.bodyBytes;
      }

      _log('Get image failed: ${response.statusCode}');
      return null;
    } catch (e) {
      _log('Error getting image: $e');
      return null;
    }
  }

  /// Delete image from storage via ReactPOS API
  static Future<bool> deleteImage(String storageUrl) async {
    try {
      final headers = await AuthService.getAuthHeaders();

      final response = await http.delete(
        Uri.parse(storageUrl),
        headers: headers,
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['success'] == true;
      }

      _log('Delete image failed: ${response.statusCode}');
      return false;
    } catch (e) {
      _log('Error deleting image: $e');
      return false;
    }
  }

  /// List images for current organization
  static Future<List<String>> listImages({String? year, String? month}) async {
    try {
      final headers = await AuthService.getAuthHeaders();

      var url = AppConfig.storageUploadUrl;
      final params = <String, String>{};
      if (year != null) params['year'] = year;
      if (month != null) params['month'] = month;

      if (params.isNotEmpty) {
        url = '$url?${params.entries.map((e) => '${e.key}=${e.value}').join('&')}';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true && data['files'] != null) {
          return List<String>.from(data['files']);
        }
      }

      return [];
    } catch (e) {
      _log('Error listing images: $e');
      return [];
    }
  }

  /// Check if storage is configured (always true for API-based storage)
  static bool get isConfigured => true;

  static void _log(String message) {
    // ignore: avoid_print
    print('[ImageStorageService] $message');
  }
}
