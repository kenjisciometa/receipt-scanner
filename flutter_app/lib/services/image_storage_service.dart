import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path;
import '../config/app_config.dart';

class ImageStorageService {
  /// Get user ID from auth
  static String? get _userId => Supabase.instance.client.auth.currentUser?.id;

  /// Upload receipt image to Wasabi S3
  /// Returns the public URL of the uploaded image
  static Future<String?> uploadReceiptImage(String localFilePath) async {
    try {
      final userId = _userId;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      if (!isConfigured) {
        throw Exception('Wasabi storage not configured');
      }

      final file = File(localFilePath);
      if (!await file.exists()) {
        throw Exception('File not found: $localFilePath');
      }

      // Generate unique filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = path.extension(localFilePath).toLowerCase();
      final objectKey = 'receipts/$userId/$timestamp$extension';

      // Read file bytes
      final Uint8List bytes = await file.readAsBytes();

      // Determine content type
      String contentType = 'image/jpeg';
      if (extension == '.png') {
        contentType = 'image/png';
      } else if (extension == '.webp') {
        contentType = 'image/webp';
      }

      // Upload using AWS Signature V4
      final success = await _uploadToS3(
        bucket: AppConfig.wasabiBucket,
        objectKey: objectKey,
        bytes: bytes,
        contentType: contentType,
      );

      if (success) {
        // Return public URL
        final publicUrl = '${AppConfig.wasabiEndpoint}/${AppConfig.wasabiBucket}/$objectKey';
        return publicUrl;
      }

      return null;
    } catch (e) {
      _log('Error uploading image to Wasabi: $e');
      return null;
    }
  }

  /// Upload bytes to S3 using AWS Signature V4
  static Future<bool> _uploadToS3({
    required String bucket,
    required String objectKey,
    required Uint8List bytes,
    required String contentType,
  }) async {
    final accessKey = AppConfig.wasabiAccessKey;
    final secretKey = AppConfig.wasabiSecretKey;
    final region = AppConfig.wasabiRegion;
    final endpoint = AppConfig.wasabiEndpoint;

    // Parse endpoint
    final uri = Uri.parse('$endpoint/$bucket/$objectKey');
    final host = uri.host;

    // Current time
    final now = DateTime.now().toUtc();
    final dateStamp = _formatDate(now);
    final amzDate = _formatAmzDate(now);

    // Hash of payload
    final payloadHash = sha256.convert(bytes).toString();

    // Headers
    final headers = <String, String>{
      'Host': host,
      'Content-Type': contentType,
      'x-amz-content-sha256': payloadHash,
      'x-amz-date': amzDate,
      'x-amz-acl': 'public-read',
    };

    // Create canonical request
    final signedHeaders = (headers.keys.toList()..sort()).map((k) => k.toLowerCase()).join(';');
    final canonicalHeaders = (headers.keys.toList()..sort())
        .map((k) => '${k.toLowerCase()}:${headers[k]!.trim()}')
        .join('\n');

    final canonicalRequest = [
      'PUT',
      '/$bucket/$objectKey',
      '', // query string
      '$canonicalHeaders\n',
      signedHeaders,
      payloadHash,
    ].join('\n');

    // Create string to sign
    final credentialScope = '$dateStamp/$region/s3/aws4_request';
    final canonicalRequestHash = sha256.convert(utf8.encode(canonicalRequest)).toString();

    final stringToSign = [
      'AWS4-HMAC-SHA256',
      amzDate,
      credentialScope,
      canonicalRequestHash,
    ].join('\n');

    // Calculate signature
    final signature = _calculateSignature(secretKey, dateStamp, region, 's3', stringToSign);

    // Authorization header
    final authorization = 'AWS4-HMAC-SHA256 '
        'Credential=$accessKey/$credentialScope, '
        'SignedHeaders=$signedHeaders, '
        'Signature=$signature';

    headers['Authorization'] = authorization;

    // Make request
    try {
      final response = await http.put(
        uri,
        headers: headers,
        body: bytes,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      } else {
        _log('S3 upload failed: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      _log('S3 upload error: $e');
      return false;
    }
  }

  /// Calculate AWS Signature V4
  static String _calculateSignature(
    String secretKey,
    String dateStamp,
    String region,
    String service,
    String stringToSign,
  ) {
    final kDate = _hmacSha256(utf8.encode('AWS4$secretKey'), utf8.encode(dateStamp));
    final kRegion = _hmacSha256(kDate, utf8.encode(region));
    final kService = _hmacSha256(kRegion, utf8.encode(service));
    final kSigning = _hmacSha256(kService, utf8.encode('aws4_request'));
    final signature = _hmacSha256(kSigning, utf8.encode(stringToSign));
    return signature.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static List<int> _hmacSha256(List<int> key, List<int> data) {
    final hmac = Hmac(sha256, key);
    return hmac.convert(data).bytes;
  }

  static String _formatDate(DateTime date) {
    return '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
  }

  static String _formatAmzDate(DateTime date) {
    return '${_formatDate(date)}T${date.hour.toString().padLeft(2, '0')}${date.minute.toString().padLeft(2, '0')}${date.second.toString().padLeft(2, '0')}Z';
  }

  /// Delete image from Wasabi
  static Future<bool> deleteImage(String imageUrl) async {
    try {
      // Extract object key from URL
      final uri = Uri.parse(imageUrl);
      final pathSegments = uri.pathSegments;
      if (pathSegments.length < 2) {
        return false;
      }

      final bucket = pathSegments[0];
      final objectKey = pathSegments.skip(1).join('/');

      return await _deleteFromS3(bucket: bucket, objectKey: objectKey);
    } catch (e) {
      _log('Error deleting image from Wasabi: $e');
      return false;
    }
  }

  /// Delete object from S3
  static Future<bool> _deleteFromS3({
    required String bucket,
    required String objectKey,
  }) async {
    final accessKey = AppConfig.wasabiAccessKey;
    final secretKey = AppConfig.wasabiSecretKey;
    final region = AppConfig.wasabiRegion;
    final endpoint = AppConfig.wasabiEndpoint;

    final uri = Uri.parse('$endpoint/$bucket/$objectKey');
    final host = uri.host;

    final now = DateTime.now().toUtc();
    final dateStamp = _formatDate(now);
    final amzDate = _formatAmzDate(now);

    // Empty payload hash for DELETE
    final payloadHash = sha256.convert([]).toString();

    final headers = <String, String>{
      'Host': host,
      'x-amz-content-sha256': payloadHash,
      'x-amz-date': amzDate,
    };

    final signedHeaders = (headers.keys.toList()..sort()).map((k) => k.toLowerCase()).join(';');
    final canonicalHeaders = (headers.keys.toList()..sort())
        .map((k) => '${k.toLowerCase()}:${headers[k]!.trim()}')
        .join('\n');

    final canonicalRequest = [
      'DELETE',
      '/$bucket/$objectKey',
      '',
      '$canonicalHeaders\n',
      signedHeaders,
      payloadHash,
    ].join('\n');

    final credentialScope = '$dateStamp/$region/s3/aws4_request';
    final canonicalRequestHash = sha256.convert(utf8.encode(canonicalRequest)).toString();

    final stringToSign = [
      'AWS4-HMAC-SHA256',
      amzDate,
      credentialScope,
      canonicalRequestHash,
    ].join('\n');

    final signature = _calculateSignature(secretKey, dateStamp, region, 's3', stringToSign);

    final authorization = 'AWS4-HMAC-SHA256 '
        'Credential=$accessKey/$credentialScope, '
        'SignedHeaders=$signedHeaders, '
        'Signature=$signature';

    headers['Authorization'] = authorization;

    try {
      final response = await http.delete(uri, headers: headers);
      return response.statusCode == 204 || response.statusCode == 200;
    } catch (e) {
      _log('S3 delete error: $e');
      return false;
    }
  }

  /// Generate a presigned URL for accessing a private object
  /// This allows temporary access without making the bucket public
  static String? getPresignedUrl(String imageUrl, {int expiresInSeconds = 3600}) {
    try {
      final accessKey = AppConfig.wasabiAccessKey;
      final secretKey = AppConfig.wasabiSecretKey;
      final region = AppConfig.wasabiRegion;

      // Extract bucket and object key from URL
      final uri = Uri.parse(imageUrl);
      final pathSegments = uri.pathSegments;
      if (pathSegments.length < 2) {
        _log('Invalid image URL format: $imageUrl');
        return null;
      }

      final bucket = pathSegments[0];
      final objectKey = pathSegments.skip(1).join('/');
      final host = uri.host;

      // Current time
      final now = DateTime.now().toUtc();
      final dateStamp = _formatDate(now);
      final amzDate = _formatAmzDate(now);

      // Credential scope
      final credentialScope = '$dateStamp/$region/s3/aws4_request';
      final credential = Uri.encodeComponent('$accessKey/$credentialScope');

      // Query parameters for presigned URL
      final queryParams = <String, String>{
        'X-Amz-Algorithm': 'AWS4-HMAC-SHA256',
        'X-Amz-Credential': credential,
        'X-Amz-Date': amzDate,
        'X-Amz-Expires': expiresInSeconds.toString(),
        'X-Amz-SignedHeaders': 'host',
      };

      // Build canonical query string (sorted)
      final sortedKeys = queryParams.keys.toList()..sort();
      final canonicalQueryString = sortedKeys
          .map((k) => '$k=${queryParams[k]}')
          .join('&');

      // Canonical headers
      final canonicalHeaders = 'host:$host\n';
      final signedHeaders = 'host';

      // Canonical request
      final canonicalRequest = [
        'GET',
        '/$bucket/$objectKey',
        canonicalQueryString,
        canonicalHeaders,
        signedHeaders,
        'UNSIGNED-PAYLOAD',
      ].join('\n');

      // String to sign
      final canonicalRequestHash = sha256.convert(utf8.encode(canonicalRequest)).toString();
      final stringToSign = [
        'AWS4-HMAC-SHA256',
        amzDate,
        '$dateStamp/$region/s3/aws4_request',
        canonicalRequestHash,
      ].join('\n');

      // Calculate signature
      final signature = _calculateSignature(secretKey, dateStamp, region, 's3', stringToSign);

      // Build presigned URL
      final presignedUrl = 'https://$host/$bucket/$objectKey?$canonicalQueryString&X-Amz-Signature=$signature';

      return presignedUrl;
    } catch (e) {
      _log('Error generating presigned URL: $e');
      return null;
    }
  }

  /// Check if Wasabi is configured
  static bool get isConfigured {
    return AppConfig.wasabiAccessKey.isNotEmpty &&
        AppConfig.wasabiSecretKey.isNotEmpty &&
        AppConfig.wasabiAccessKey != 'your_wasabi_access_key';
  }

  static void _log(String message) {
    // ignore: avoid_print
    print('[ImageStorageService] $message');
  }
}
