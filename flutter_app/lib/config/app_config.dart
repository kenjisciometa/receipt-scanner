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

  // Supabase - AccountApp (receipts storage)
  static String get accountAppSupabaseUrl => dotenv.env['ACCOUNTAPP_SUPABASE_URL'] ?? '';
  static String get accountAppSupabaseAnonKey => dotenv.env['ACCOUNTAPP_SUPABASE_ANON_KEY'] ?? '';

  // Wasabi S3 Storage
  static String get wasabiAccessKey => dotenv.env['WASABI_ACCESS_KEY'] ?? '';
  static String get wasabiSecretKey => dotenv.env['WASABI_SECRET_KEY'] ?? '';
  static String get wasabiBucket => dotenv.env['WASABI_BUCKET'] ?? 'receipt-images';
  static String get wasabiRegion => dotenv.env['WASABI_REGION'] ?? 'eu-central-1';
  static String get wasabiEndpoint => dotenv.env['WASABI_ENDPOINT'] ?? 'https://s3.eu-central-1.wasabisys.com';

  // App info
  static String get appName => 'Receipt Scanner';

  // Scanner API endpoints
  static String get scannerExtractUrl => '$apiBaseUrl/api/scanner/extract';
}
