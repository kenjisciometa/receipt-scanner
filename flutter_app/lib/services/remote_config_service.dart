import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Remote configuration service that fetches config from server.
///
/// This service manages configuration values that are better stored server-side:
/// - Supabase anon keys (publishable but easier to rotate)
/// - Google OAuth client IDs
///
/// Values are cached locally for offline support.
class RemoteConfigService {
  static const String _cacheKey = 'remote_config';
  static const Duration _cacheExpiry = Duration(hours: 24);

  static RemoteConfig? _cachedConfig;
  static bool _isInitialized = false;

  /// Initialize the service and fetch config from server
  static Future<void> initialize(String apiBaseUrl) async {
    if (_isInitialized) return;

    // Try to load from cache first
    await _loadFromCache();

    // Fetch fresh config from server
    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/api/config'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true && data['config'] != null) {
          final config = RemoteConfig.fromJson(data['config'] as Map<String, dynamic>);
          _cachedConfig = config;
          await _saveToCache(config);
          debugPrint('[RemoteConfig] Fetched and cached config from server');
        }
      }
    } catch (e) {
      debugPrint('[RemoteConfig] Failed to fetch config: $e');
      // Use cached values if available
    }

    _isInitialized = true;
  }

  /// Get the current config (cached)
  static RemoteConfig get config {
    return _cachedConfig ?? RemoteConfig.empty();
  }

  /// Check if config is available
  static bool get hasConfig => _cachedConfig != null;

  /// Force refresh config from server
  static Future<bool> refresh(String apiBaseUrl) async {
    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/api/config'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true && data['config'] != null) {
          final config = RemoteConfig.fromJson(data['config'] as Map<String, dynamic>);
          _cachedConfig = config;
          await _saveToCache(config);
          return true;
        }
      }
    } catch (e) {
      debugPrint('[RemoteConfig] Refresh failed: $e');
    }
    return false;
  }

  static Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_cacheKey);
      if (cached != null) {
        final data = jsonDecode(cached) as Map<String, dynamic>;
        final cachedAt = DateTime.tryParse(data['cached_at'] as String? ?? '');

        // Check if cache is still valid
        if (cachedAt != null && DateTime.now().difference(cachedAt) < _cacheExpiry) {
          _cachedConfig = RemoteConfig.fromJson(data['config'] as Map<String, dynamic>);
          debugPrint('[RemoteConfig] Loaded config from cache');
        }
      }
    } catch (e) {
      debugPrint('[RemoteConfig] Failed to load cache: $e');
    }
  }

  static Future<void> _saveToCache(RemoteConfig config) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = {
        'cached_at': DateTime.now().toIso8601String(),
        'config': config.toJson(),
      };
      await prefs.setString(_cacheKey, jsonEncode(data));
    } catch (e) {
      debugPrint('[RemoteConfig] Failed to save cache: $e');
    }
  }
}

/// Remote configuration values
class RemoteConfig {
  // Auth Supabase (POS - for user authentication)
  final String authSupabaseUrl;
  final String authSupabaseAnonKey;

  // Data Supabase (AccountantApp - for receipts, invoices, etc.)
  final String dataSupabaseUrl;
  final String dataSupabaseAnonKey;

  // Legacy fields (for backward compatibility)
  final String accountappSupabaseUrl;
  final String accountappSupabaseAnonKey;

  final String googleWebClientId;

  const RemoteConfig({
    required this.authSupabaseUrl,
    required this.authSupabaseAnonKey,
    required this.dataSupabaseUrl,
    required this.dataSupabaseAnonKey,
    required this.accountappSupabaseUrl,
    required this.accountappSupabaseAnonKey,
    required this.googleWebClientId,
  });

  factory RemoteConfig.empty() => const RemoteConfig(
        authSupabaseUrl: '',
        authSupabaseAnonKey: '',
        dataSupabaseUrl: '',
        dataSupabaseAnonKey: '',
        accountappSupabaseUrl: '',
        accountappSupabaseAnonKey: '',
        googleWebClientId: '',
      );

  factory RemoteConfig.fromJson(Map<String, dynamic> json) {
    return RemoteConfig(
      authSupabaseUrl: json['auth_supabase_url'] as String? ?? '',
      authSupabaseAnonKey: json['auth_supabase_anon_key'] as String? ?? '',
      dataSupabaseUrl: json['data_supabase_url'] as String? ?? '',
      dataSupabaseAnonKey: json['data_supabase_anon_key'] as String? ?? '',
      accountappSupabaseUrl: json['accountapp_supabase_url'] as String? ?? '',
      accountappSupabaseAnonKey: json['accountapp_supabase_anon_key'] as String? ?? '',
      googleWebClientId: json['google_web_client_id'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'auth_supabase_url': authSupabaseUrl,
        'auth_supabase_anon_key': authSupabaseAnonKey,
        'data_supabase_url': dataSupabaseUrl,
        'data_supabase_anon_key': dataSupabaseAnonKey,
        'accountapp_supabase_url': accountappSupabaseUrl,
        'accountapp_supabase_anon_key': accountappSupabaseAnonKey,
        'google_web_client_id': googleWebClientId,
      };

  bool get isValid =>
      dataSupabaseUrl.isNotEmpty &&
      dataSupabaseAnonKey.isNotEmpty &&
      googleWebClientId.isNotEmpty;
}
