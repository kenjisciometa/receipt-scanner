/// Application configuration constants and settings
class AppConfig {
  static const String appName = 'Receipt Scanner';
  static const String appVersion = '1.0.0';
  static const String appDescription = 'AI-powered receipt digitization app for European languages';
  
  // Processing configuration
  static const int maxImageWidth = 2000;
  static const int maxImageHeight = 2000;
  static const int previewMaxWidth = 800;
  static const int previewMaxHeight = 800;
  
  // OCR configuration
  static const double minimumConfidenceScore = 0.7;
  static const int maxProcessingTimeoutSeconds = 30;
  
  // Supported languages
  static const List<String> supportedLanguages = [
    'en', // English
    'fi', // Finnish
    'sv', // Swedish
    'fr', // French
    'de', // German
    'it', // Italian
    'es', // Spanish
  ];
  
  // Supported currencies
  static const List<String> supportedCurrencies = [
    'EUR', // Euro
    'SEK', // Swedish Krona
    'NOK', // Norwegian Krone
    'DKK', // Danish Krone
    'USD', // US Dollar
    'GBP', // British Pound
  ];
  
  // File paths
  static const String receiptsDirectory = 'receipts';
  static const String processedImagesDirectory = 'processed_images';
  static const String originalImagesDirectory = 'original_images';
  
  // Database configuration
  static const String databaseName = 'receipt_scanner.db';
  static const int databaseVersion = 1;
  
  // Export formats
  static const List<String> exportFormats = ['CSV', 'JSON'];
  
  // Image quality thresholds
  static const double minimumImageQuality = 0.6;
  static const double goodImageQuality = 0.8;
  static const double excellentImageQuality = 0.9;
  
  // Performance settings
  static const int maxConcurrentProcessing = 3;
  static const Duration processingTimeout = Duration(seconds: 30);
  static const Duration cacheTimeout = Duration(hours: 24);
  
  // UI settings
  static const Duration animationDuration = Duration(milliseconds: 300);
  static const double defaultBorderRadius = 12.0;
  static const double defaultPadding = 16.0;
}

/// Environment-specific configuration
enum Environment {
  development,
  staging,
  production,
}

class EnvironmentConfig {
  static const Environment currentEnvironment = Environment.development;
  
  static bool get isDevelopment => currentEnvironment == Environment.development;
  static bool get isStaging => currentEnvironment == Environment.staging;
  static bool get isProduction => currentEnvironment == Environment.production;
  
  // Logging configuration
  static bool get enableLogging => !isProduction;
  static bool get enableVerboseLogging => isDevelopment;
  static bool get enableCrashReporting => isProduction || isStaging;
}