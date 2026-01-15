import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  // Environment
  static String get environment => dotenv.env['FLUTTER_ENV'] ?? 'development';
  static bool get isDevelopment => environment.toLowerCase() == 'development';
  static bool get isProduction => environment.toLowerCase() == 'production';

  // POS API
  static String get apiBaseUrl => dotenv.env['API_BASE_URL'] ?? 'https://pos.sciometa.com';

  // Supabase
  static String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';
  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';

  // App info
  static String get appName => 'Receipt Scanner';

  // Scanner API endpoints
  static String get scannerExtractUrl => '$apiBaseUrl/api/scanner/extract';
}
