import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../services/remote_config_service.dart';

class AppConfig {
  // Environment
  static String get environment => dotenv.env['FLUTTER_ENV'] ?? 'development';
  static bool get isDevelopment => environment.toLowerCase() == 'development';
  static bool get isProduction => environment.toLowerCase() == 'production';

  // POS API (used for auth and billing)
  static String get apiBaseUrl => dotenv.env['API_BASE_URL'] ?? 'https://pos.sciometa.com';

  // App identifier for billing
  static const String appId = 'receipt';

  // Supabase - Data storage (AccountantApp - receipts, invoices, etc.)
  // Fetched from server, with .env fallback for development
  static String get accountAppSupabaseUrl {
    // Use data_supabase_url for receipt/invoice data storage
    final remote = RemoteConfigService.config.dataSupabaseUrl;
    if (remote.isNotEmpty) return remote;
    // Fallback to legacy field
    final legacy = RemoteConfigService.config.accountappSupabaseUrl;
    if (legacy.isNotEmpty) return legacy;
    return dotenv.env['ACCOUNTAPP_SUPABASE_URL'] ?? '';
  }

  static String get accountAppSupabaseAnonKey {
    // Use data_supabase_anon_key for receipt/invoice data storage
    final remote = RemoteConfigService.config.dataSupabaseAnonKey;
    if (remote.isNotEmpty) return remote;
    // Fallback to legacy field
    final legacy = RemoteConfigService.config.accountappSupabaseAnonKey;
    if (legacy.isNotEmpty) return legacy;
    return dotenv.env['ACCOUNTAPP_SUPABASE_ANON_KEY'] ?? '';
  }

  // Supabase - Auth (POS - for user authentication)
  static String get authSupabaseUrl {
    final remote = RemoteConfigService.config.authSupabaseUrl;
    return remote.isNotEmpty ? remote : (dotenv.env['AUTH_SUPABASE_URL'] ?? accountAppSupabaseUrl);
  }

  static String get authSupabaseAnonKey {
    final remote = RemoteConfigService.config.authSupabaseAnonKey;
    return remote.isNotEmpty ? remote : (dotenv.env['AUTH_SUPABASE_ANON_KEY'] ?? accountAppSupabaseAnonKey);
  }

  // App info
  static String get appName => 'Expense Docs Scanner';

  // Auth API endpoints (via POS API)
  static String get authLoginUrl => '$apiBaseUrl/api/auth/login';
  static String get authSignupUrl => '$apiBaseUrl/api/auth/signup';
  static String get authRefreshUrl => '$apiBaseUrl/api/auth/refresh';

  // Billing API endpoints (via POS API)
  static String get billingAppAccessUrl => '$apiBaseUrl/api/billing/app-access';
  static String get billingStartTrialUrl => '$apiBaseUrl/api/billing/start-trial';
  static String get billingCheckoutUrl => '$apiBaseUrl/api/billing/checkout';
  static String get billingVerifyGooglePlayUrl => '$apiBaseUrl/api/billing/verify-google-play';

  // Scanner API endpoints
  static String get scannerExtractUrl => '$apiBaseUrl/api/scanner/extract';
  static String get receiptStorageUploadUrl => '$apiBaseUrl/api/storage/receipts';
  static String get invoiceStorageUploadUrl => '$apiBaseUrl/api/storage/invoices';

  // Storage base URL for retrieving images
  static String get storageBaseUrl => '$apiBaseUrl/api/storage/receipts';

  // Gmail integration (via AccountApp API)
  static String get accountAppApiBaseUrl => dotenv.env['ACCOUNTAPP_API_URL'] ?? 'https://tax.sciometa.com';
  static String get gmailConnectionsUrl => '$accountAppApiBaseUrl/api/gmail/connections';
  static String get gmailRegisterTokenUrl => '$accountAppApiBaseUrl/api/gmail/register-token';
  static String get gmailDisconnectUrl => '$accountAppApiBaseUrl/api/gmail/disconnect';
  static String get gmailSyncUrl => '$accountAppApiBaseUrl/api/gmail/sync';
  static String get gmailExtractedUrl => '$accountAppApiBaseUrl/api/gmail/extracted';

  // Invoice summary API (for duplicate detection cache)
  static String get invoiceSummaryUrl => '$accountAppApiBaseUrl/api/invoices/summary';

  // Google OAuth (Web client ID for server-side token exchange)
  // Fetched from server, with .env fallback for development
  static String get googleWebClientId {
    final remote = RemoteConfigService.config.googleWebClientId;
    return remote.isNotEmpty ? remote : (dotenv.env['GOOGLE_WEB_CLIENT_ID'] ?? '');
  }
}
