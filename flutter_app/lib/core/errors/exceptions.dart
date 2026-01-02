/// Base exception class for the Receipt Scanner app
abstract class ReceiptScannerException implements Exception {
  const ReceiptScannerException(this.message, this.code);
  
  final String message;
  final String code;
  
  @override
  String toString() => 'ReceiptScannerException($code): $message';
}

/// Camera-related exceptions
class CameraException extends ReceiptScannerException {
  const CameraException(String message) : super(message, 'CAMERA_ERROR');
}

class CameraPermissionException extends CameraException {
  const CameraPermissionException() : super('Camera permission not granted');
}

class CameraNotAvailableException extends CameraException {
  const CameraNotAvailableException() : super('Camera not available on this device');
}

class CameraInitializationException extends CameraException {
  const CameraInitializationException() : super('Failed to initialize camera');
}

/// Image processing exceptions
class ImageProcessingException extends ReceiptScannerException {
  const ImageProcessingException(String message, [this.step]) : super(message, 'IMAGE_PROCESSING_ERROR');
  
  final String? step;
  
  @override
  String toString() => step != null 
      ? 'ImageProcessingException($code): $message at step: $step'
      : super.toString();
}

class ImageLoadException extends ImageProcessingException {
  const ImageLoadException() : super('Failed to load image', 'LOAD');
}

class ImageCorruptedException extends ImageProcessingException {
  const ImageCorruptedException() : super('Image file is corrupted', 'CORRUPTED');
}

class ImageTooLargeException extends ImageProcessingException {
  const ImageTooLargeException() : super('Image file is too large', 'TOO_LARGE');
}

class ImageFormatNotSupportedException extends ImageProcessingException {
  const ImageFormatNotSupportedException(String format) : super('Image format $format is not supported', 'UNSUPPORTED_FORMAT');
}

class AngleCorrectionException extends ImageProcessingException {
  const AngleCorrectionException() : super('Failed to correct image angle', 'ANGLE_CORRECTION');
}

class BrightnessAdjustmentException extends ImageProcessingException {
  const BrightnessAdjustmentException() : super('Failed to adjust image brightness', 'BRIGHTNESS_ADJUSTMENT');
}

class PerspectiveCorrectionException extends ImageProcessingException {
  const PerspectiveCorrectionException() : super('Failed to correct image perspective', 'PERSPECTIVE_CORRECTION');
}

/// OCR-related exceptions
class OCRException extends ReceiptScannerException {
  const OCRException(String message, [this.confidence]) : super(message, 'OCR_ERROR');
  
  final double? confidence;
  
  @override
  String toString() => confidence != null 
      ? 'OCRException($code): $message (confidence: ${confidence!.toStringAsFixed(2)})'
      : super.toString();
}

class TextRecognitionException extends OCRException {
  const TextRecognitionException() : super('Failed to recognize text in image');
}

class LowConfidenceException extends OCRException {
  const LowConfidenceException(double confidence) : super('OCR confidence too low', confidence);
}

class NoTextFoundException extends OCRException {
  const NoTextFoundException() : super('No text found in image');
}

class LanguageDetectionException extends OCRException {
  const LanguageDetectionException() : super('Failed to detect text language');
}

/// Data extraction exceptions
class DataExtractionException extends ReceiptScannerException {
  const DataExtractionException(String message, [this.missingFields = const []]) : super(message, 'DATA_EXTRACTION_ERROR');
  
  final List<String> missingFields;
  
  @override
  String toString() => missingFields.isNotEmpty 
      ? 'DataExtractionException($code): $message. Missing fields: ${missingFields.join(', ')}'
      : super.toString();
}

class InsufficientDataException extends DataExtractionException {
  const InsufficientDataException(List<String> missingFields) : super('Insufficient data extracted from receipt', missingFields);
}

class InvalidAmountException extends DataExtractionException {
  const InvalidAmountException(String amount) : super('Invalid amount format: $amount');
}

class InvalidDateException extends DataExtractionException {
  const InvalidDateException(String date) : super('Invalid date format: $date');
}

class MerchantNotFoundException extends DataExtractionException {
  const MerchantNotFoundException() : super('Merchant name not found');
}

class TotalAmountNotFoundException extends DataExtractionException {
  const TotalAmountNotFoundException() : super('Total amount not found');
}

/// Database and storage exceptions
class StorageException extends ReceiptScannerException {
  const StorageException(String message) : super(message, 'STORAGE_ERROR');
}

class DatabaseException extends StorageException {
  const DatabaseException(String message) : super('Database error: $message');
}

class FileStorageException extends StorageException {
  const FileStorageException(String message) : super('File storage error: $message');
}

class InsufficientStorageException extends StorageException {
  const InsufficientStorageException() : super('Insufficient storage space');
}

class FileNotFoundStorageException extends StorageException {
  const FileNotFoundStorageException(String path) : super('File not found: $path');
}

class PermissionDeniedException extends StorageException {
  const PermissionDeniedException(String permission) : super('Permission denied: $permission');
}

/// Network and connectivity exceptions
class NetworkException extends ReceiptScannerException {
  const NetworkException(String message) : super(message, 'NETWORK_ERROR');
}

class NoInternetConnectionException extends NetworkException {
  const NoInternetConnectionException() : super('No internet connection');
}

class TimeoutException extends NetworkException {
  const TimeoutException() : super('Network request timeout');
}

class ServerException extends NetworkException {
  const ServerException(int statusCode) : super('Server error: $statusCode');
}

/// Validation exceptions
class ValidationException extends ReceiptScannerException {
  const ValidationException(String message, [this.field]) : super(message, 'VALIDATION_ERROR');
  
  final String? field;
  
  @override
  String toString() => field != null 
      ? 'ValidationException($code): $message (field: $field)'
      : super.toString();
}

class RequiredFieldException extends ValidationException {
  const RequiredFieldException(String field) : super('Field is required', field);
}

class InvalidFormatException extends ValidationException {
  const InvalidFormatException(String field, String format) : super('Invalid format for $field: expected $format', field);
}

class ValueOutOfRangeException extends ValidationException {
  const ValueOutOfRangeException(String field, String range) : super('Value out of range for $field: $range', field);
}

/// Export exceptions
class ExportException extends ReceiptScannerException {
  const ExportException(String message, [this.format]) : super(message, 'EXPORT_ERROR');
  
  final String? format;
  
  @override
  String toString() => format != null 
      ? 'ExportException($code): $message (format: $format)'
      : super.toString();
}

class UnsupportedExportFormatException extends ExportException {
  const UnsupportedExportFormatException(String format) : super('Export format not supported', format);
}

class ExportFileCreationException extends ExportException {
  const ExportFileCreationException(String format) : super('Failed to create export file', format);
}

/// Configuration exceptions
class ConfigurationException extends ReceiptScannerException {
  const ConfigurationException(String message) : super(message, 'CONFIGURATION_ERROR');
}

class InvalidSettingException extends ConfigurationException {
  const InvalidSettingException(String setting) : super('Invalid setting: $setting');
}

class MissingConfigurationException extends ConfigurationException {
  const MissingConfigurationException(String config) : super('Missing configuration: $config');
}