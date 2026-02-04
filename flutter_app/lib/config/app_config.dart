import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  // Environment
  static String get environment => dotenv.env['FLUTTER_ENV'] ?? 'development';
  static bool get isDevelopment => environment.toLowerCase() == 'development';
  static bool get isProduction => environment.toLowerCase() == 'production';

  // POS API (used for auth and billing)
  static String get apiBaseUrl => dotenv.env['API_BASE_URL'] ?? 'https://pos.sciometa.com';

  // App identifier for billing
  static const String appId = 'receipt';

  // Supabase - AccountApp (receipts metadata)
  static String get accountAppSupabaseUrl => dotenv.env['ACCOUNTAPP_SUPABASE_URL'] ?? '';
  static String get accountAppSupabaseAnonKey => dotenv.env['ACCOUNTAPP_SUPABASE_ANON_KEY'] ?? '';

  // App info
  static String get appName => 'Receipt Scanner';

  // Auth API endpoints (via POS API)
  static String get authLoginUrl => '$apiBaseUrl/api/auth/login';
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
}
