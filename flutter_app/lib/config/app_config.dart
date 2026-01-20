import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  // Environment
  static String get environment => dotenv.env['FLUTTER_ENV'] ?? 'development';
  static bool get isDevelopment => environment.toLowerCase() == 'development';
  static bool get isProduction => environment.toLowerCase() == 'production';

  // POS API
  static String get apiBaseUrl => dotenv.env['API_BASE_URL'] ?? 'https://pos.sciometa.com';

  // Supabase - Auth (sciometa-pos)
  static String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';
  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';

  // Supabase - AccountApp (receipts metadata)
  static String get accountAppSupabaseUrl => dotenv.env['ACCOUNTAPP_SUPABASE_URL'] ?? '';
  static String get accountAppSupabaseAnonKey => dotenv.env['ACCOUNTAPP_SUPABASE_ANON_KEY'] ?? '';

  // App info
  static String get appName => 'Receipt Scanner';

  // API endpoints
  static String get scannerExtractUrl => '$apiBaseUrl/api/scanner/extract';
  static String get receiptStorageUploadUrl => '$apiBaseUrl/api/storage/receipts';
  static String get invoiceStorageUploadUrl => '$apiBaseUrl/api/storage/invoices';

  // Storage base URL for retrieving images
  static String get storageBaseUrl => '$apiBaseUrl/api/storage/receipts';
}
