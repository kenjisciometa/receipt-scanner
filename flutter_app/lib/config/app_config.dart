import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  static String get apiBaseUrl => dotenv.env['API_BASE_URL'] ?? 'https://pos.sciometa.com';
  static String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';
  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';
  static String get appName => 'Receipt Scanner';

  // Scanner API endpoints
  static String get scannerExtractUrl => '$apiBaseUrl/api/scanner/extract';
  static String get scannerStatusUrl => '$apiBaseUrl/api/scanner/extract';
}