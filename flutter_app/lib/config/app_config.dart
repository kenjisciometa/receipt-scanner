import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  // Environment
  static String get environment => dotenv.env['FLUTTER_ENV'] ?? 'development';
  static bool get isDevelopment => environment.toLowerCase() == 'development';
  static bool get isProduction => environment.toLowerCase() == 'production';

  // POS API (used for auth proxy)
  static String get apiBaseUrl => dotenv.env['API_BASE_URL'] ?? 'https://pos.sciometa.com';

  // Sciometa Auth (used for billing API direct calls)
  static String get sciometaAuthUrl => dotenv.env['SCIOMETA_AUTH_URL'] ?? 'https://auth.sciometa.com';

  // App identifier for Sciometa Auth
  static const String appId = 'receipt';

  // Supabase - AccountApp (receipts metadata)
  static String get accountAppSupabaseUrl => dotenv.env['ACCOUNTAPP_SUPABASE_URL'] ?? '';
  static String get accountAppSupabaseAnonKey => dotenv.env['ACCOUNTAPP_SUPABASE_ANON_KEY'] ?? '';

  // App info
  static String get appName => 'Receipt Scanner';

  // Auth API endpoints (via POS API proxy)
  static String get authLoginUrl => '$apiBaseUrl/api/auth/login';
  static String get authRefreshUrl => '$apiBaseUrl/api/auth/refresh';

  // Billing API endpoints (direct to Sciometa Auth)
  static String get billingAppAccessUrl => '$sciometaAuthUrl/api/billing/app-access';
  static String get billingStartTrialUrl => '$sciometaAuthUrl/api/billing/start-trial';
  static String get billingCreateCheckoutUrl => '$sciometaAuthUrl/api/billing/create-checkout';

  // Scanner API endpoints
  static String get scannerExtractUrl => '$apiBaseUrl/api/scanner/extract';
  static String get receiptStorageUploadUrl => '$apiBaseUrl/api/storage/receipts';
  static String get invoiceStorageUploadUrl => '$apiBaseUrl/api/storage/invoices';

  // Storage base URL for retrieving images
  static String get storageBaseUrl => '$apiBaseUrl/api/storage/receipts';
}
