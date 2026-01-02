/// Application-wide constants
class AppConstants {
  // UI Constants
  static const double defaultPadding = 16.0;
  static const double smallPadding = 8.0;
  static const double largePadding = 24.0;
  static const double defaultBorderRadius = 12.0;
  static const double smallBorderRadius = 8.0;
  static const double largeBorderRadius = 16.0;
  
  // Camera Constants
  static const double cameraAspectRatio = 4/3;
  static const int maxCameraResolutionWidth = 1920;
  static const int maxCameraResolutionHeight = 1440;
  
  // Image Processing Constants
  static const int thumbnailSize = 150;
  static const int previewSize = 400;
  static const int maxOriginalImageSize = 4000;
  static const List<String> supportedImageFormats = ['jpg', 'jpeg', 'png', 'pdf'];
  
  // Animation Constants
  static const Duration shortAnimation = Duration(milliseconds: 150);
  static const Duration mediumAnimation = Duration(milliseconds: 300);
  static const Duration longAnimation = Duration(milliseconds: 500);
  
  // Network Constants
  static const Duration connectionTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 30);
  
  // Storage Constants
  static const int maxStoredReceipts = 1000;
  static const int maxImageCacheSizeMB = 500;
  static const Duration cacheExpiration = Duration(days: 30);
  
  // Error Messages
  static const String genericErrorMessage = 'An unexpected error occurred';
  static const String networkErrorMessage = 'Network connection error';
  static const String cameraErrorMessage = 'Camera access error';
  static const String storageErrorMessage = 'Storage access error';
  static const String processingErrorMessage = 'Image processing error';
  
  // Success Messages
  static const String receiptSavedMessage = 'Receipt saved successfully';
  static const String dataExportedMessage = 'Data exported successfully';
  static const String settingsUpdatedMessage = 'Settings updated';
  
  // Validation Constants
  static const int maxMerchantNameLength = 100;
  static const int maxReceiptItemNameLength = 200;
  static const double maxReceiptAmount = 999999.99;
  static const double minReceiptAmount = 0.01;
  
  // Date Format Constants
  static const String defaultDateFormat = 'yyyy-MM-dd';
  static const String displayDateFormat = 'MMM dd, yyyy';
  static const String timeFormat = 'HH:mm';
  static const String dateTimeFormat = 'yyyy-MM-dd HH:mm';
  
  // File Extensions
  static const String jpegExtension = '.jpg';
  static const String pngExtension = '.png';
  static const String pdfExtension = '.pdf';
  static const String csvExtension = '.csv';
  static const String jsonExtension = '.json';
}